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
  CompanyAdministrationError,
  administerCompanyForUser,
} from './company_administration';
import {
  CompanyCreationError,
  createCompanyForCurrentUser as createCompanyForCurrentUserOperation,
} from './company_privileges';
import {
  OwnershipTransferError,
  transferCompanyOwnershipForUser,
} from './ownership_transfer';
import {
  EmailSyncError,
  syncVerifiedEmailForUser,
} from './email_sync';
import {
  registerAppointmentParticipant,
  unregisterAppointmentParticipant,
} from './appointment_participants';
import {
  AppointmentDefinitionError,
  saveAppointmentDefinitionForUser,
} from './appointment_definition';
import {
  ContentDeletionError,
  deleteContentForUser,
} from './content_deletion';
import {
  appointmentConfirmationTransition,
  appointmentIsSettled,
} from './appointment_state';
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
  ProfileImageAuthorizationError,
  ProfileImageRevisionError,
  ProfileImageStateError,
  parseProfileImageUploadPayload,
  uploadOwnProfileImage,
} from './profile_images';
import {
  SurveyPublicationError,
  saveSurveyDefinitionForUser,
} from './survey_publication';

initializeApp();

const region = 'europe-west4';

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

export const saveSurveyDefinition = onCall(
  { region, enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'authentication-required');
    }
    if (request.auth.token.email_verified !== true) {
      throw new HttpsError('failed-precondition', 'email-not-verified');
    }

    try {
      return await saveSurveyDefinitionForUser(
        request.auth.uid,
        request.data,
      );
    } catch (error) {
      if (error instanceof SurveyPublicationError) {
        throw new HttpsError(error.code, error.message);
      }
      logger.error('survey publication failed closed', {
        uid: request.auth.uid,
        errorType:
          error instanceof Error ? error.constructor.name : typeof error,
      });
      throw new HttpsError('internal', 'survey-publication-incomplete');
    }
  },
);

export const saveAppointmentDefinition = onCall(
  { region, enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'authentication-required');
    }
    if (request.auth.token.email_verified !== true) {
      throw new HttpsError('failed-precondition', 'email-not-verified');
    }

    try {
      return await saveAppointmentDefinitionForUser(
        request.auth.uid,
        request.data,
      );
    } catch (error) {
      if (error instanceof AppointmentDefinitionError) {
        throw new HttpsError(error.code, error.message, error.details);
      }
      logger.error('appointment definition failed closed', {
        uid: request.auth.uid,
        errorType:
          error instanceof Error ? error.constructor.name : typeof error,
      });
      throw new HttpsError('internal', 'appointment-definition-incomplete');
    }
  },
);

export const deleteContent = onCall(
  { region, timeoutSeconds: 120, enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'authentication-required');
    }
    if (request.auth.token.email_verified !== true) {
      throw new HttpsError('failed-precondition', 'email-not-verified');
    }

    try {
      return await deleteContentForUser(request.auth.uid, request.data);
    } catch (error) {
      if (error instanceof ContentDeletionError) {
        throw new HttpsError(error.code, error.message);
      }
      logger.error('content deletion failed closed', {
        uid: request.auth.uid,
        errorType: error instanceof Error ? error.constructor.name : typeof error,
      });
      throw new HttpsError('internal', 'content-deletion-incomplete');
    }
  },
);

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

    try {
      const upload = parseProfileImageUploadPayload(request.data);
      return await uploadOwnProfileImage(request.auth.uid, upload);
    } catch (error) {
      if (error instanceof InvalidProfileImageError) {
        throw new HttpsError('invalid-argument', error.message);
      }
      if (error instanceof ProfileImageAuthorizationError) {
        throw new HttpsError('permission-denied', error.message);
      }
      if (error instanceof ProfileImageRevisionError) {
        throw new HttpsError('aborted', error.message);
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

export const createCompanyForCurrentUser = onCall(
  { region, enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'authentication-required');
    }
    if (request.auth.token.email_verified !== true) {
      throw new HttpsError('failed-precondition', 'email-not-verified');
    }

    try {
      return await createCompanyForCurrentUserOperation(
        request.auth.uid,
        request.auth.token.auth_time,
        request.data,
      );
    } catch (error) {
      if (error instanceof CompanyCreationError) {
        throw new HttpsError(error.code, error.message);
      }
      logger.error('company creation failed closed', {
        uid: request.auth.uid,
        errorType: error instanceof Error ? error.constructor.name : typeof error,
      });
      throw new HttpsError('internal', 'company-creation-incomplete');
    }
  },
);

export const transferCompanyOwnership = onCall(
  { region, enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'authentication-required');
    }
    if (request.auth.token.email_verified !== true) {
      throw new HttpsError('failed-precondition', 'email-not-verified');
    }

    try {
      return await transferCompanyOwnershipForUser(
        request.auth.uid,
        request.auth.token.auth_time,
        request.data,
      );
    } catch (error) {
      if (error instanceof OwnershipTransferError) {
        throw new HttpsError(error.code, error.message);
      }
      logger.error('ownership transfer failed closed', {
        uid: request.auth.uid,
        errorType: error instanceof Error ? error.constructor.name : typeof error,
      });
      throw new HttpsError('internal', 'ownership-transfer-incomplete');
    }
  },
);

export const syncVerifiedEmail = onCall(
  { region, enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'authentication-required');
    }
    if (request.auth.token.email_verified !== true) {
      throw new HttpsError('failed-precondition', 'email-not-verified');
    }

    try {
      return await syncVerifiedEmailForUser(request.auth.uid, request.data);
    } catch (error) {
      if (error instanceof EmailSyncError) {
        throw new HttpsError(error.code, error.message);
      }
      logger.error('verified email sync failed closed', {
        uid: request.auth.uid,
        errorType: error instanceof Error ? error.constructor.name : typeof error,
      });
      throw new HttpsError('internal', 'verified-email-sync-incomplete');
    }
  },
);

export const administerCompany = onCall(
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
    if (request.auth.token.email_verified !== true) {
      throw new HttpsError('failed-precondition', 'email-not-verified');
    }

    try {
      return await administerCompanyForUser(
        request.auth.uid,
        request.auth.token.auth_time,
        request.data,
      );
    } catch (error) {
      if (error instanceof CompanyAdministrationError) {
        throw new HttpsError(error.code, error.message);
      }
      logger.error('company administration failed closed', {
        uid: request.auth.uid,
        errorType: error instanceof Error ? error.constructor.name : typeof error,
      });
      throw new HttpsError('internal', 'company-administration-incomplete');
    }
  },
);

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

export const onSurveyCreated = onDocumentCreated(
  { document: 'surveys/{surveyId}', region, retry: true },
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

export const onAppointmentCreated = onDocumentCreated(
  { document: 'appointments/{appointmentId}', region, retry: true },
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

export const onAppointmentVoteCreated = onDocumentCreated(
  {
    document: 'appointments/{appointmentId}/participants/{participantId}',
    region,
  },
  async (event) => {
    await registerAppointmentParticipant(
      event.params.appointmentId,
      event.params.participantId,
      event.data?.get('userId'),
    );
  },
);

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

export const onTimeSlotConfirmed = onDocumentUpdated(
  { document: 'appointments/{appointmentId}', region, retry: true },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const confirmation = appointmentConfirmationTransition(before, after);
    if (!confirmation) return;

    const companyId = after.companyId as string | undefined;
    if (!companyId) return;
    const members = await activeMemberIds(companyId);

    await notify(
      { userIds: members },
      (locale) => ({
        ...appointmentConfirmedCopy(
          locale,
          after.title,
          confirmation.startAt,
          confirmation.zoneId,
        ),
        data: {
          type: 'appointment',
          appointmentId: event.params.appointmentId,
        },
      }),
    );
  },
);

export const onJoinRequested = onDocumentUpdated(
  { document: 'users/{userId}', region, retry: true },
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

export const onJoinRequestedAtRegistration = onDocumentCreated(
  { document: 'users/{userId}', region, retry: true },
  async (event) => {
    const profile = event.data?.data();
    if (!profile) return;
    await notifyJoinRequest(event.params.userId, profile);
  },
);

export const remindExpiring = onSchedule(
  {
    schedule: '0 9 * * *',
    timeZone: 'Europe/Berlin',
    region,
    retryCount: 1,
  },
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

      if (appointmentIsSettled(appointment.data())) continue;

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
        if (await purgeCompany(company.id)) {
          logger.info('company purged', { companyId: company.id });
        }
      } catch (error) {
        logger.error('purge failed', { companyId: company.id, error });
      }
    }
  },
);

export const purgeAccountDeletionLocks = onSchedule(
  { schedule: '15 * * * *', timeZone: 'UTC', region },
  async () => {
    const deleted = await purgeExpiredAccountDeletionLocks();
    logger.info('expired account deletion locks purged', { deleted });
  },
);
