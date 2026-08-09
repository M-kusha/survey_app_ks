import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
} from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { isDeepStrictEqual } from 'node:util';

import {
  CompanyOwnerDeletionError,
  deleteUserAccount,
  hasRecentAuthentication,
  purgeExpiredAccountDeletionLocks,
} from './account_deletion';
import {
  registerAppointmentParticipant,
  unregisterAppointmentParticipant,
} from './appointment_participants';
import { activeMemberIds, companyAdminIds, notify } from './messaging';
import {
  appointmentConfirmedCopy,
  appointmentCreatedCopy,
  appointmentReminderCopy,
  joinRequestCopy,
  surveyCreatedCopy,
  surveyReminderCopy,
} from './notification_copy';
import { purgeCompany } from './purge';
import { scoreTrustedSurvey } from './trusted_scoring';
import { finalizePendingOnboarding } from './onboarding';
import { joinRequestCompanyId } from './join_requests';
import {
  InvalidProfileImageError,
  ProfileImageStateError,
  uploadOwnProfileImage,
} from './profile_images';

initializeApp();

// Dictated by the database, not chosen.
//
// This project's Firestore lives in `eur3`, a Europe multi-region. Eventarc
// routes events out of a multi-region from one fixed place — `europe-west4` for
// `eur3`, `us-central1` for `nam5` — and a v2 Firestore trigger deployed
// anywhere else simply cannot be created.
//
// The failure is worth recognising by shape: on the first deploy the two
// scheduled functions succeeded and all four Firestore triggers failed.
// Scheduled functions have no such constraint, so a clean split down that line
// means the region, not the code.
//
// Everything is kept here rather than only the triggers. Two regions for six
// functions buys nothing and makes the next person wonder why.
const region = 'europe-west4';

/**
 * Converts a verified user's private registration intent into tenant state.
 * App Check and Firebase Auth are both required; the transaction independently
 * re-checks the Auth record before creating any public/company documents.
 */
export const completeOnboarding = onCall(
  { region, enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'authentication-required');
    }
    if (request.auth.token.email_verified !== true) {
      throw new HttpsError('failed-precondition', 'email-not-verified');
    }

    const data =
      request.data && typeof request.data === 'object'
        ? (request.data as Record<string, unknown>)
        : {};
    return finalizePendingOnboarding(request.auth.uid, {
      companyName: data.companyName,
      companyId: data.companyId,
    });
  },
);

/**
 * Re-encodes and stores the signed-in user's avatar without a bearer token.
 * The callable derives the Storage path from Auth; the client never supplies a
 * uid, object path, MIME type, or Firestore reference.
 */
export const uploadProfileImage = onCall(
  {
    region,
    timeoutSeconds: 60,
    memory: '512MiB',
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'authentication-required');
    }
    if (request.auth.token.email_verified !== true) {
      throw new HttpsError('failed-precondition', 'email-not-verified');
    }

    const data =
      request.data != null && typeof request.data === 'object'
        ? (request.data as Record<string, unknown>)
        : null;
    if (
      data == null ||
      Object.keys(data).length !== 1 ||
      !Object.prototype.hasOwnProperty.call(data, 'jpegBase64')
    ) {
      throw new HttpsError('invalid-argument', 'invalid-profile-image');
    }

    try {
      return await uploadOwnProfileImage(request.auth.uid, data.jpegBase64);
    } catch (error) {
      if (error instanceof InvalidProfileImageError) {
        throw new HttpsError('invalid-argument', 'invalid-profile-image');
      }
      if (error instanceof ProfileImageStateError) {
        throw new HttpsError('failed-precondition', error.message);
      }

      logger.error('profile image upload failed closed', {
        uid: request.auth.uid,
        error: error instanceof Error ? error.message : String(error),
      });
      throw new HttpsError('internal', 'profile-image-upload-incomplete');
    }
  },
);

/**
 * Completes account erasure at the trusted boundary after a recent sign-in.
 * Cleanup is retryable; Auth is deleted only after every data store succeeds.
 */
export const deleteMyAccount = onCall(
  {
    region,
    timeoutSeconds: 540,
    memory: '512MiB',
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'authentication-required');
    }
    if (!hasRecentAuthentication(request.auth.token.auth_time)) {
      throw new HttpsError('failed-precondition', 'recent-login-required');
    }

    try {
      const deleteOwnedCompany =
        request.data != null &&
        typeof request.data === 'object' &&
        request.data.deleteOwnedCompany === true;
      await deleteUserAccount(request.auth.uid, { deleteOwnedCompany });
      return { deleted: true };
    } catch (error) {
      if (error instanceof CompanyOwnerDeletionError) {
        throw new HttpsError('failed-precondition', 'company-owner');
      }

      logger.error('account deletion did not complete; Auth retained', {
        uid: request.auth.uid,
        error: error instanceof Error ? error.message : String(error),
      });
      throw new HttpsError('internal', 'account-deletion-incomplete');
    }
  },
);

async function notifyJoinRequest(
  userId: string,
  profile: Record<string, unknown>,
): Promise<void> {
  const companyId = joinRequestCompanyId(profile, false);
  if (!companyId) return;

  // A ban mirrors membership to pending for Storage authorization. It is not a
  // new join request, and its atomic ban document is visible by the time this
  // trigger runs. Check it before notifying admins.
  const ban = await getFirestore()
    .collection('companies')
    .doc(companyId)
    .collection('bans')
    .doc(userId)
    .get();
  if (!joinRequestCompanyId(profile, ban.exists)) return;

  const admins = await companyAdminIds(companyId);
  await notify(
    { userIds: admins },
    (locale) => ({
      ...joinRequestCopy(locale, profile.fullName),
      data: { type: 'approval', userId },
    }),
  );
}

/**
 * A new survey or test, announced to the company.
 *
 * The author is left out. Being notified about the thing you just wrote is the
 * fastest way to teach somebody that these notifications are noise.
 */
export const onSurveyCreated = onDocumentCreated(
  { document: 'surveys/{surveyId}', region },
  async (event) => {
    const survey = event.data?.data();
    if (!survey) return;

    const companyId = survey.companyId as string | undefined;
    if (!companyId) return;

    const isTest = survey.surveyType === 1;
    const members = await activeMemberIds(companyId);
    const audience = members.filter((id) => id !== survey.createdBy);

    await notify(
      { userIds: audience },
      (locale) => ({
        ...surveyCreatedCopy(locale, survey.surveyName, isTest),
        data: { type: 'survey', surveyId: event.params.surveyId },
      }),
    );
  },
);

/**
 * Scores an initial response at the trusted boundary.
 *
 * Rules require client-written score fields to be zero sentinels, so a forged
 * first write cannot become an authoritative result. The calculation is
 * deterministic and idempotent if the event is delivered more than once.
 */
export const onSurveyResponseCreated = onDocumentCreated(
  { document: 'surveys/{surveyId}/participants/{participantId}', region },
  async (event) => {
    const responseRef = event.data?.ref;
    const surveyRef = responseRef?.parent.parent;
    if (!responseRef || !surveyRef) return;

    const answerKeyRef = getFirestore()
      .collection('surveyAnswerKeys')
      .doc(event.params.surveyId);

    await getFirestore().runTransaction(async (transaction) => {
      const [current, survey, answerKey] = await Promise.all([
        transaction.get(responseRef),
        transaction.get(surveyRef),
        transaction.get(answerKeyRef),
      ]);
      if (!current.exists || current.get('serverScoredAt')) return;

      if (!survey.exists) {
        transaction.update(responseRef, {
          gradingStatus: 'error',
          serverScoredAt: FieldValue.serverTimestamp(),
        });
        return;
      }

      // This backend-owned value is only an invalidation signal. Clients use
      // the already-open survey query to refresh their own response status
      // without maintaining one participant listener per survey.
      transaction.update(surveyRef, {
        responsesRevision: FieldValue.increment(1),
      });

      try {
        const grade = scoreTrustedSurvey({
          surveyId: event.params.surveyId,
          survey: survey.data() ?? {},
          answerKey: answerKey.data(),
          response: current.data() ?? {},
        });

        transaction.update(responseRef, {
          score: grade.score,
          totalCorrectAnswers: grade.correctCount,
          gradedQuestionCount: grade.gradedCount,
          gradingStatus: grade.gradingStatus,
          serverScoredAt: FieldValue.serverTimestamp(),
        });
      } catch (error) {
        logger.error('trusted survey scoring failed closed', {
          error,
          participantId: event.params.participantId,
          surveyId: event.params.surveyId,
        });
        transaction.update(responseRef, {
          gradingStatus: 'error',
          serverScoredAt: FieldValue.serverTimestamp(),
        });
      }
    });
  },
);

/** Invalidates live participation state after a response is removed. */
export const onSurveyResponseDeleted = onDocumentDeleted(
  { document: 'surveys/{surveyId}/participants/{participantId}', region },
  async (event) => {
    const surveyRef = event.data?.ref.parent.parent;
    if (!surveyRef) return;

    await getFirestore().runTransaction(async (transaction) => {
      const survey = await transaction.get(surveyRef);
      if (!survey.exists) return;
      transaction.update(surveyRef, {
        responsesRevision: FieldValue.increment(1),
      });
    });
  },
);

/**
 * Recomputes the complete grade after a staff member reviews free text.
 *
 * The client may change only the review map. Score and correct-answer totals
 * are written here from the immutable questions and submitted answers, in one
 * transaction. A stale out-of-order event is discarded rather than replacing
 * a newer review's grade.
 */
export const onSurveyResponseUpdated = onDocumentUpdated(
  { document: 'surveys/{surveyId}/participants/{participantId}', region },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const responseRef = event.data?.after.ref;
    if (!before || !after || !responseRef) return;

    const beforeReviews = before.textAnswersReviewed ?? {};
    const afterReviews = after.textAnswersReviewed ?? {};
    if (isDeepStrictEqual(beforeReviews, afterReviews)) return;

    const surveyRef = responseRef.parent.parent;
    if (!surveyRef) return;
    const answerKeyRef = getFirestore()
      .collection('surveyAnswerKeys')
      .doc(event.params.surveyId);

    await getFirestore().runTransaction(async (transaction) => {
      const [current, survey, answerKey] = await Promise.all([
        transaction.get(responseRef),
        transaction.get(surveyRef),
        transaction.get(answerKeyRef),
      ]);
      if (!current.exists || !survey.exists) return;

      const currentReviews = current.get('textAnswersReviewed') ?? {};
      // Another review won the race. Its own event will calculate the current
      // grade, so this older invocation must not write stale totals.
      if (!isDeepStrictEqual(currentReviews, afterReviews)) return;

      try {
        const grade = scoreTrustedSurvey({
          surveyId: event.params.surveyId,
          survey: survey.data() ?? {},
          answerKey: answerKey.data(),
          response: current.data() ?? {},
        });

        transaction.update(responseRef, {
          score: grade.score,
          totalCorrectAnswers: grade.correctCount,
          gradedQuestionCount: grade.gradedCount,
          gradingStatus: grade.gradingStatus,
          serverScoredAt: FieldValue.serverTimestamp(),
        });
      } catch (error) {
        logger.error('survey review scoring failed closed', {
          error,
          participantId: event.params.participantId,
          surveyId: event.params.surveyId,
        });
        transaction.update(responseRef, {
          gradingStatus: 'error',
          serverScoredAt: FieldValue.serverTimestamp(),
        });
      }
    });
  },
);

/** A new meeting poll, announced the same way. */
export const onAppointmentCreated = onDocumentCreated(
  { document: 'appointments/{appointmentId}', region },
  async (event) => {
    const appointment = event.data?.data();
    if (!appointment) return;

    const companyId = appointment.companyId as string | undefined;
    if (!companyId) return;

    const members = await activeMemberIds(companyId);

    await notify(
      { userIds: members.filter((id) => id !== appointment.createdBy) },
      (locale) => ({
        ...appointmentCreatedCopy(locale, appointment.title),
        data: { type: 'appointment', appointmentId: event.params.appointmentId },
      }),
    );
  },
);

/** A vote document is the source of truth for the compact parent voter index. */
export const onAppointmentVoteCreated = onDocumentCreated(
  {
    document: 'appointments/{appointmentId}/participants/{participantId}',
    region,
  },
  async (event) => {
    await registerAppointmentParticipant(
      event.params.appointmentId,
      event.data?.get('userId'),
    );
  },
);

/** Remove a voter from the parent only after their final slot vote is gone. */
export const onAppointmentVoteDeleted = onDocumentDeleted(
  {
    document: 'appointments/{appointmentId}/participants/{participantId}',
    region,
  },
  async (event) => {
    await unregisterAppointmentParticipant(
      event.params.appointmentId,
      event.data?.get('userId'),
    );
  },
);

/**
 * A time has been settled.
 *
 * This is the one notification people actually wait for, and the only one where
 * *not* being told has a real cost: the whole point of voting was to find out
 * when the meeting is.
 */
export const onTimeSlotConfirmed = onDocumentUpdated(
  { document: 'appointments/{appointmentId}', region },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const wasConfirmed = (before.confirmedTimeSlots ?? []).length;
    const nowConfirmed = (after.confirmedTimeSlots ?? []).length;

    // Only on the transition. Any other edit to the meeting must not re-announce
    // a time everybody already knows.
    if (nowConfirmed <= wasConfirmed) return;

    const slot = (after.confirmedTimeSlots ?? [])[nowConfirmed - 1] ?? {};
    const start = typeof slot.start === 'string' ? new Date(slot.start) : null;
    const startUtc =
      start != null && !Number.isNaN(start.getTime())
        ? start.toUTCString()
        : undefined;

    // Every member still entitled to this company. Raw voter ids are not an
    // authorization source: they may be stale after a removal or ban.
    const companyId = after.companyId as string | undefined;
    if (!companyId) return;
    const members = await activeMemberIds(companyId);

    await notify(
      { userIds: members },
      (locale) => ({
        ...appointmentConfirmedCopy(locale, after.title, startUtc),
        data: {
          type: 'appointment',
          appointmentId: event.params.appointmentId,
        },
      }),
    );
  },
);

/**
 * Somebody has asked to join.
 *
 * The gap this fills: approvals arrived in total silence, and the only way to
 * discover one was to happen to open the member list.
 */
export const onJoinRequested = onDocumentUpdated(
  { document: 'users/{userId}', region },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const becamePending =
      (before.membership ?? 'active') !== 'pending' &&
      after.membership === 'pending';

    if (!becamePending) return;

    await notifyJoinRequest(event.params.userId, after);
  },
);

/** Registration creates a pending profile rather than updating an old one. */
export const onJoinRequestedAtRegistration = onDocumentCreated(
  { document: 'users/{userId}', region },
  async (event) => {
    const profile = event.data?.data();
    if (!profile) return;
    await notifyJoinRequest(event.params.userId, profile);
  },
);

/**
 * The daily sweep: what closes tomorrow, and who has not answered it.
 *
 * Aimed only at people who still have something to do. A reminder sent to
 * somebody who already answered is the notification that makes people turn all
 * of them off.
 */
export const remindExpiring = onSchedule(
  { schedule: '0 9 * * *', timeZone: 'Europe/Berlin', region },
  async () => {
    const db = getFirestore();
    const now = new Date();
    const cutoff = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    const surveys = await db
      .collection('surveys')
      .where('deadline', '>', Timestamp.fromDate(now))
      .where('deadline', '<=', Timestamp.fromDate(cutoff))
      .get();

    for (const survey of surveys.docs) {
      const companyId = survey.get('companyId') as string | undefined;
      if (!companyId) continue;

      const [members, answered] = await Promise.all([
        activeMemberIds(companyId),
        survey.ref.collection('participants').get(),
      ]);

      const done = new Set(answered.docs.map((doc) => doc.id));
      const outstanding = members.filter((id) => !done.has(id));
      if (outstanding.length === 0) continue;

      await notify(
        { userIds: outstanding },
        (locale) => ({
          ...surveyReminderCopy(locale, survey.get('surveyName')),
          data: { type: 'survey', surveyId: survey.id },
        }),
      );
    }

    const appointments = await db
      .collection('appointments')
      .where('expirationAt', '>', Timestamp.fromDate(now))
      .where('expirationAt', '<=', Timestamp.fromDate(cutoff))
      .get();

    for (const appointment of appointments.docs) {
      const companyId = appointment.get('companyId') as string | undefined;
      if (!companyId) continue;

      // A settled meeting wants nothing further from anybody.
      const slots = (appointment.get('availableTimeSlots') ?? []) as {
        isConfirmed?: boolean;
      }[];
      if (slots.some((slot) => slot.isConfirmed)) continue;

      // Vote documents are authoritative. The parent index is updated by an
      // at-least-once trigger and can lag for a few seconds, which is not a
      // sound basis for deciding who receives a reminder.
      const [members, votes] = await Promise.all([
        activeMemberIds(companyId),
        appointment.ref.collection('participants').get(),
      ]);
      const voted = new Set(
        votes.docs
          .map((vote) => vote.get('userId'))
          .filter((userId): userId is string => typeof userId === 'string'),
      );
      const outstanding = members.filter((id) => !voted.has(id));
      if (outstanding.length === 0) continue;

      await notify(
        { userIds: outstanding },
        (locale) => ({
          ...appointmentReminderCopy(locale, appointment.get('title')),
          data: { type: 'appointment', appointmentId: appointment.id },
        }),
      );
    }

    logger.info('reminders swept', {
      surveys: surveys.size,
      appointments: appointments.size,
    });
  },
);

/**
 * Carries out company closures whose week has run out.
 *
 * This is the piece the client cannot do properly. Until now the purge ran only
 * when an admin next opened the app — so a company whose owner walked away was
 * scheduled for a deletion that might never arrive.
 */
export const purgeScheduledCompanies = onSchedule(
  { schedule: '30 3 * * *', timeZone: 'Europe/Berlin', region },
  async () => {
    const db = getFirestore();

    const due = await db
      .collection('companies')
      .where('deletionScheduledFor', '<=', Timestamp.now())
      .get();

    for (const company of due.docs) {
      try {
        await purgeCompany(company.id);
        logger.info('company purged', { companyId: company.id });
      } catch (error) {
        // One bad company must not stop the sweep for the rest.
        logger.error('purge failed', { companyId: company.id, error });
      }
    }
  },
);

/** Remove account-deletion write locks after all pre-deletion ID tokens expire. */
export const purgeAccountDeletionLocks = onSchedule(
  { schedule: '15 * * * *', timeZone: 'UTC', region },
  async () => {
    const deleted = await purgeExpiredAccountDeletionLocks();
    logger.info('expired account deletion locks purged', { deleted });
  },
);
