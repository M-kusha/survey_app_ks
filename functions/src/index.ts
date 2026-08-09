import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { activeMemberIds, companyAdminIds, notify } from './messaging';
import { purgeCompany } from './purge';

initializeApp();

// Kept close to where the users are. Cross-region traffic is the one thing here
// that would cost anything at this scale.
const region = 'europe-west1';

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
      {
        title: isTest ? 'New test' : 'New survey',
        body: `${survey.surveyName ?? ''} is open for responses.`,
        data: { type: 'survey', surveyId: event.params.surveyId },
      },
    );
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
      {
        title: 'New meeting to vote on',
        body: `${appointment.title ?? ''} needs your availability.`,
        data: { type: 'appointment', appointmentId: event.params.appointmentId },
      },
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

    // Everyone who voted, plus everyone who was asked. Somebody who never
    // answered still needs to know when to turn up.
    const companyId = after.companyId as string | undefined;
    const voters = (after.participantUserIds ?? []) as string[];
    const members = companyId ? await activeMemberIds(companyId) : voters;

    await notify(
      { userIds: [...new Set([...voters, ...members])] },
      {
        title: 'Meeting time confirmed',
        body: start
          ? `${after.title ?? 'Your meeting'} — ${start.toUTCString()}`
          : `${after.title ?? 'Your meeting'} has a confirmed time.`,
        data: {
          type: 'appointment',
          appointmentId: event.params.appointmentId,
        },
      },
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

    const companyId = after.companyId as string | undefined;
    if (!companyId) return;

    const admins = await companyAdminIds(companyId);

    await notify(
      { userIds: admins },
      {
        title: 'Someone wants to join',
        body: `${after.fullName ?? 'A new member'} is waiting for approval.`,
        data: { type: 'approval', userId: event.params.userId },
      },
    );
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
        {
          title: 'Closing tomorrow',
          body: `${survey.get('surveyName') ?? 'A survey'} closes in less than a day.`,
          data: { type: 'survey', surveyId: survey.id },
        },
      );
    }

    const appointments = await db
      .collection('appointments')
      .where('expirationDate', '>', Timestamp.fromDate(now))
      .where('expirationDate', '<=', Timestamp.fromDate(cutoff))
      .get();

    for (const appointment of appointments.docs) {
      const companyId = appointment.get('companyId') as string | undefined;
      if (!companyId) continue;

      // A settled meeting wants nothing further from anybody.
      const slots = (appointment.get('availableTimeSlots') ?? []) as {
        isConfirmed?: boolean;
      }[];
      if (slots.some((slot) => slot.isConfirmed)) continue;

      const members = await activeMemberIds(companyId);
      const voted = new Set(
        (appointment.get('participantUserIds') ?? []) as string[],
      );
      const outstanding = members.filter((id) => !voted.has(id));
      if (outstanding.length === 0) continue;

      await notify(
        { userIds: outstanding },
        {
          title: 'Voting closes tomorrow',
          body: `${appointment.get('title') ?? 'A meeting'} still needs your availability.`,
          data: { type: 'appointment', appointmentId: appointment.id },
        },
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
