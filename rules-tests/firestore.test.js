import { strictEqual } from 'node:assert';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  collectionGroup,
  deleteDoc,
  deleteField,
  disableNetwork,
  doc,
  documentId,
  enableNetwork,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  startAfter,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

// Two companies and three people, so every "can A see B's data" question has a
// concrete answer.
const ACME = 'company-acme';
const RIVAL = 'company-rival';

const ALICE = 'alice'; // superadmin at Acme
const BOB = 'bob'; //     ordinary user at Acme
const CAROL = 'carol'; //  ordinary user at Rival — the outsider
const DAVE = 'dave'; //    not registered yet
const MOLLY = 'molly'; //  moderator at Acme — runs content, not people
const ADA = 'ada'; //      admin at Acme — runs people

const slot = {
  slotId: 'morning-slot',
  startAt: new Date('2030-01-10T09:00:00.000Z'),
  endAt: new Date('2030-01-10T10:00:00.000Z'),
};

const userDocument = (uid, overrides = {}) => ({
  membership: 'active',
  fullName: uid[0].toUpperCase() + uid.slice(1),
  birthdate: '1990-01-01',
  email: `${uid}@example.test`,
  role: 'user',
  createdAt: new Date(),
  companyId: ACME,
  ...overrides,
});

const signupDocument = (uid, overrides = {}) => ({
  ...userDocument(uid),
  createdAt: serverTimestamp(),
  ...overrides,
});

const pendingSignupDocument = (uid, overrides = {}) => ({
  ...signupDocument(uid, {
    companyId: '',
    pendingOnboardingType: 'joinCompany',
    pendingCompanyId: ACME,
  }),
  ...overrides,
});

const memberDocument = (uid, overrides = {}) => ({
  fullName: uid[0].toUpperCase() + uid.slice(1),
  companyId: ACME,
  role: 'user',
  membership: 'active',
  ...overrides,
});

const updateMember = (db, uid, fields) => {
  const batch = writeBatch(db);
  batch.update(doc(db, 'users', uid), fields);
  batch.update(doc(db, 'memberDirectory', uid), fields);
  return batch.commit();
};

const removeMember = (db, uid) => {
  const batch = writeBatch(db);
  batch.update(doc(db, 'users', uid), {
    companyId: '',
    role: 'user',
    membership: 'active',
  });
  batch.delete(doc(db, 'memberDirectory', uid));
  return batch.commit();
};

const joinCompany = (db, uid, companyId, membership) => {
  const batch = writeBatch(db);
  batch.update(doc(db, 'users', uid), {
    companyId,
    role: 'user',
    membership,
  });
  batch.set(
    doc(db, 'memberDirectory', uid),
    memberDocument(uid, { companyId, membership }),
  );
  return batch.commit();
};

const banMember = (
  db,
  uid,
  { bannedBy = ADA, previousMembership = 'active' } = {},
) => {
  const batch = writeBatch(db);
  batch.set(doc(db, 'companies', ACME, 'bans', uid), {
    name: uid[0].toUpperCase() + uid.slice(1),
    bannedAt: serverTimestamp(),
    bannedBy,
    previousMembership,
  });
  batch.update(doc(db, 'users', uid), { membership: 'pending' });
  batch.update(doc(db, 'memberDirectory', uid), { membership: 'pending' });
  return batch.commit();
};

const unbanMember = (db, uid, previousMembership = 'active') => {
  const batch = writeBatch(db);
  batch.delete(doc(db, 'companies', ACME, 'bans', uid));
  batch.update(doc(db, 'users', uid), {
    membership: previousMembership,
  });
  batch.update(doc(db, 'memberDirectory', uid), {
    membership: previousMembership,
  });
  return batch.commit();
};

const eraseMember = (db, uid) => {
  const batch = writeBatch(db);
  batch.update(doc(db, 'users', uid), {
    companyId: '',
    role: 'user',
    membership: 'active',
  });
  batch.delete(doc(db, 'memberDirectory', uid));
  batch.delete(doc(db, 'companies', ACME, 'bans', uid));
  return batch.commit();
};

const activityDocument = (overrides = {}) => ({
  schemaVersion: 1,
  companyId: ACME,
  action: 'member.role_changed',
  actorUid: ALICE,
  targetUid: BOB,
  occurredAt: new Date('2026-08-11T12:00:00.000Z'),
  before: { role: 'user' },
  after: { role: 'moderator' },
  ...overrides,
});

const surveyDocument = (id, overrides = {}) => ({
  surveyName: 'Q1 review',
  surveyDescription: 'A bounded test survey',
  timeCreated: new Date(),
  questions: [
    { type: 'Single', question: 'Pick one', options: ['A', 'B'] },
  ],
  id,
  participants: [],
  deadline: new Date(Date.now() + 24 * 60 * 60 * 1000),
  timeLimitPerQuestion: 30,
  surveyType: 1,
  companyId: ACME,
  createdBy: ALICE,
  responsesRevision: 0,
  ...overrides,
});

const answerKeyDocument = (id, overrides = {}) => ({
  schemaVersion: 1,
  surveyId: id,
  companyId: ACME,
  questionKeys: [{ type: 'Single', correctAnswer: 0 }],
  ...overrides,
});

const createSurvey = (db, id, overrides = {}, keyOverrides = {}) => {
  const survey = surveyDocument(id, overrides);
  const batch = writeBatch(db);
  batch.set(doc(db, 'surveys', id), survey);
  batch.set(
    doc(db, 'surveyAnswerKeys', id),
    answerKeyDocument(id, { companyId: survey.companyId, ...keyOverrides }),
  );
  return batch.commit();
};

const deleteSurvey = (db, id) => {
  const batch = writeBatch(db);
  batch.delete(doc(db, 'surveyAnswerKeys', id));
  batch.delete(doc(db, 'surveys', id));
  return batch.commit();
};

const submissionDocument = (uid, overrides = {}) => ({
  userId: uid,
  name: uid[0].toUpperCase() + uid.slice(1),
  answers: { Q0: [0] },
  score: 0,
  submittedAt: serverTimestamp(),
  participantSubmitted: true,
  imageProfile: '',
  profileImageRevision: 0,
  textAnswersReviewed: {},
  totalCorrectAnswers: 0,
  gradedQuestionCount: 0,
  gradingStatus: 'processing',
  ...overrides,
});

const appointmentDocument = (id, overrides = {}) => ({
  schemaVersion: 2,
  revision: 1,
  appointmentId: id,
  companyId: ACME,
  createdBy: ALICE,
  title: 'Standup',
  description: 'Weekly standup',
  zoneId: 'Europe/Berlin',
  expirationAt: new Date('2030-01-09T23:59:00.000Z'),
  slots: [slot],
  slotIds: [slot.slotId],
  confirmedSlotId: null,
  participantUserIds: [],
  createdAt: new Date('2026-01-01T00:00:00.000Z'),
  ...overrides,
});

const voteDocument = (uid, overrides = {}) => ({
  userId: uid,
  userName: uid[0].toUpperCase() + uid.slice(1),
  slotId: slot.slotId,
  status: 'joined',
  participated: true,
  ...overrides,
});

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'echomeet-test',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  // Seeding bypasses the rules on purpose — this is the world as it already
  // exists, not something a user is doing.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'companies', ACME), { name: 'Acme', createdBy: ALICE });
    await setDoc(doc(db, 'companies', RIVAL), { name: 'Rival', createdBy: CAROL });
    await setDoc(doc(db, 'companyDirectory', ACME), {
      name: 'Acme',
      joinPolicy: 'open',
    });
    await setDoc(doc(db, 'companyDirectory', RIVAL), {
      name: 'Rival',
      joinPolicy: 'open',
    });

    await setDoc(doc(db, 'users', ALICE), userDocument(ALICE, { role: 'superadmin' }));
    await setDoc(doc(db, 'users', BOB), userDocument(BOB));
    await setDoc(
      doc(db, 'users', CAROL),
      userDocument(CAROL, { companyId: RIVAL }),
    );
    await setDoc(doc(db, 'users', MOLLY), userDocument(MOLLY, { role: 'moderator' }));
    await setDoc(doc(db, 'users', ADA), userDocument(ADA, { role: 'admin' }));
    await setDoc(
      doc(db, 'memberDirectory', ALICE),
      memberDocument(ALICE, { role: 'superadmin' }),
    );
    await setDoc(doc(db, 'memberDirectory', BOB), memberDocument(BOB));
    await setDoc(
      doc(db, 'memberDirectory', CAROL),
      memberDocument(CAROL, { companyId: RIVAL }),
    );
    await setDoc(
      doc(db, 'memberDirectory', MOLLY),
      memberDocument(MOLLY, { role: 'moderator' }),
    );
    await setDoc(
      doc(db, 'memberDirectory', ADA),
      memberDocument(ADA, { role: 'admin' }),
    );

    await setDoc(doc(db, 'surveys', 'acme-survey'), surveyDocument('acme-survey'));
    await setDoc(
      doc(db, 'surveyAnswerKeys', 'acme-survey'),
      answerKeyDocument('acme-survey'),
    );
    await setDoc(
      doc(db, 'surveys', 'rival-survey'),
      surveyDocument('rival-survey', { companyId: RIVAL, createdBy: CAROL }),
    );
    await setDoc(
      doc(db, 'surveyAnswerKeys', 'rival-survey'),
      answerKeyDocument('rival-survey', { companyId: RIVAL }),
    );
    await setDoc(doc(db, 'surveys', 'acme-survey', 'participants', BOB), {
      userId: BOB, name: 'Bob', score: 40, totalCorrectAnswers: 2,
    });

    await setDoc(
      doc(db, 'appointments', 'acme-standup'),
      appointmentDocument('acme-standup'),
    );
    await setDoc(
      doc(db, 'companies', ACME, 'activity', 'base-event'),
      activityDocument(),
    );
  });
});

const as = (uid) =>
  testEnv.authenticatedContext(uid, {
    email: `${uid}@example.test`,
    email_verified: true,
  }).firestore();
const asAuthenticatedAt = (uid, authTime) =>
  testEnv.authenticatedContext(uid, {
    email: `${uid}@example.test`,
    email_verified: true,
    auth_time: authTime,
  }).firestore();
const asUnverified = (uid) =>
  testEnv.authenticatedContext(uid, {
    email: `${uid}@example.test`,
    email_verified: false,
  }).firestore();
const anon = () => testEnv.unauthenticatedContext().firestore();

describe('deny by default', () => {
  it('an unauthenticated client can read nothing', async () => {
    await assertFails(getDoc(doc(anon(), 'users', BOB)));
    await assertFails(getDoc(doc(anon(), 'surveys', 'acme-survey')));
    await assertFails(getDoc(doc(anon(), 'appointments', 'acme-standup')));
  });

  it('only the minimal company directory is readable before sign-up', async () => {
    await assertSucceeds(getDoc(doc(anon(), 'companyDirectory', ACME)));
    await assertFails(getDoc(doc(anon(), 'companies', ACME)));
    await assertFails(getDoc(doc(anon(), 'companyNames', 'acme')));
  });

  it('an unauthenticated client can write nothing', async () => {
    await assertFails(setDoc(doc(anon(), 'companies', 'x'), { name: 'x' }));
    await assertFails(setDoc(doc(anon(), 'users', DAVE), { role: 'superadmin' }));
  });

  it('collections with no rule of their own are closed', async () => {
    await assertFails(getDoc(doc(as(BOB), 'anything', 'else')));
    await assertFails(setDoc(doc(as(BOB), 'anything', 'else'), { a: 1 }));
  });
});

describe('company isolation', () => {
  it('a colleague exposes only the minimal member projection', async () => {
    const db = as(BOB);
    await assertFails(getDoc(doc(db, 'users', ALICE)));
    const member = await assertSucceeds(
      getDoc(doc(db, 'memberDirectory', ALICE)),
    );
    strictEqual(member.data().fullName, 'Alice');
    strictEqual(member.data().email, undefined);
    strictEqual(member.data().birthdate, undefined);
    strictEqual(member.data().fcmTokens, undefined);
  });

  it('someone at another company is not', async () => {
    await assertFails(getDoc(doc(as(BOB), 'users', CAROL)));
    await assertFails(getDoc(doc(as(CAROL), 'users', BOB)));
    await assertFails(getDoc(doc(as(BOB), 'memberDirectory', CAROL)));
    await assertFails(getDoc(doc(as(CAROL), 'memberDirectory', BOB)));
  });

  it('surveys stay inside their company', async () => {
    await assertSucceeds(getDoc(doc(as(BOB), 'surveys', 'acme-survey')));
    await assertFails(getDoc(doc(as(BOB), 'surveys', 'rival-survey')));
    await assertFails(getDoc(doc(as(CAROL), 'surveys', 'acme-survey')));
  });

  it('appointments stay inside their company', async () => {
    await assertSucceeds(getDoc(doc(as(BOB), 'appointments', 'acme-standup')));
    await assertFails(getDoc(doc(as(CAROL), 'appointments', 'acme-standup')));
  });

  it('appointment lists require both tenant and canonical-schema filters', async () => {
    const appointments = collection(as(BOB), 'appointments');
    await assertFails(
      getDocs(query(appointments, where('companyId', '==', ACME))),
    );
    await assertFails(
      getDocs(query(appointments, where('schemaVersion', '==', 2))),
    );

    const ownCanonical = await assertSucceeds(
      getDocs(
        query(
          appointments,
          where('companyId', '==', ACME),
          where('schemaVersion', '==', 2),
        ),
      ),
    );
    strictEqual(ownCanonical.size, 1);
    await assertFails(
      getDocs(
        query(
          appointments,
          where('companyId', '==', RIVAL),
          where('schemaVersion', '==', 2),
        ),
      ),
    );
  });
});

describe('administrative activity is immutable and company-scoped', () => {
  const event = (db, eventId = 'base-event') =>
    doc(db, 'companies', ACME, 'activity', eventId);
  const events = (db) => collection(db, 'companies', ACME, 'activity');

  it('lets only an active owner or admin read an event', async () => {
    await assertSucceeds(getDoc(event(as(ALICE))));
    await assertSucceeds(getDoc(event(as(ADA))));
    await assertSucceeds(getDocs(query(events(as(ADA)), limit(25))));
    await assertFails(getDoc(event(as(BOB))));
    await assertFails(getDoc(event(as(MOLLY))));
    await assertFails(getDoc(event(anon())));
  });

  it('denies a cross-company admin, pending admin and banned admin', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await updateDoc(doc(db, 'users', CAROL), { role: 'admin' });
      await updateDoc(doc(db, 'memberDirectory', CAROL), { role: 'admin' });
    });
    await assertFails(getDoc(event(as(CAROL))));

    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await updateDoc(doc(db, 'users', ADA), { membership: 'pending' });
      await updateDoc(doc(db, 'memberDirectory', ADA), {
        membership: 'pending',
      });
    });
    await assertFails(getDoc(event(as(ADA))));

    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await updateDoc(doc(db, 'users', ADA), { membership: 'active' });
      await updateDoc(doc(db, 'memberDirectory', ADA), {
        membership: 'active',
      });
      await setDoc(doc(db, 'companies', ACME, 'bans', ADA), {
        name: 'Ada',
        bannedAt: new Date(),
        bannedBy: ALICE,
        previousMembership: 'active',
      });
    });
    await assertFails(getDoc(event(as(ADA))));
  });

  it('denies an owner whose account-deletion barrier is active', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'accountDeletionLocks', ALICE), {
        startedAt: new Date(),
      });
    });
    await assertFails(getDoc(event(as(ALICE))));
  });

  it('denies forged append, update and deletion even to owner/admin clients', async () => {
    await assertFails(
      setDoc(
        event(as(ALICE), 'forged'),
        activityDocument({ occurredAt: serverTimestamp() }),
      ),
    );
    await assertFails(
      updateDoc(event(as(ADA)), { action: 'company.ownership_transferred' }),
    );
    await assertFails(deleteDoc(event(as(ALICE))));
  });

  it('requires bounded queries and paginates newest-first with a document cursor', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (let index = 0; index < 30; index += 1) {
        await setDoc(
          event(db, `event-${String(index).padStart(2, '0')}`),
          activityDocument({
            // Two events deliberately share the page-boundary timestamp. The
            // document-id order and snapshot cursor must keep both exactly once.
            occurredAt: new Date(
              Date.UTC(2030, 0, 1, 0, 0, index === 4 ? 5 : index),
            ),
          }),
        );
      }
    });

    const db = as(ALICE);
    await assertFails(getDocs(events(db)));
    await assertFails(
      getDocs(
        query(
          events(db),
          orderBy('occurredAt', 'desc'),
          orderBy(documentId(), 'desc'),
          limit(26),
        ),
      ),
    );

    const first = await assertSucceeds(
      getDocs(
        query(
          events(db),
          orderBy('occurredAt', 'desc'),
          orderBy(documentId(), 'desc'),
          limit(25),
        ),
      ),
    );
    strictEqual(first.size, 25);
    strictEqual(first.docs.at(-1).id, 'event-05');

    const second = await assertSucceeds(
      getDocs(
        query(
          events(db),
          orderBy('occurredAt', 'desc'),
          orderBy(documentId(), 'desc'),
          startAfter(first.docs.at(-1)),
          limit(25),
        ),
      ),
    );
    strictEqual(second.size, 6);
    strictEqual(second.docs[0].id, 'event-04');
    strictEqual(
      new Set([...first.docs, ...second.docs].map((snapshot) => snapshot.id))
        .size,
      31,
    );
  });
});

describe('private profiles and the member directory', () => {
  it('lets the owner read private data but denies company-wide profile queries', async () => {
    const db = as(BOB);
    const own = await assertSucceeds(getDoc(doc(db, 'users', BOB)));
    strictEqual(own.data().email, 'bob@example.test');
    await assertFails(getDocs(collection(db, 'users')));

    const members = await assertSucceeds(
      getDocs(
        query(
          collection(db, 'memberDirectory'),
          where('companyId', '==', ACME),
        ),
      ),
    );
    strictEqual(members.size, 4);
  });

  it('requires public profile changes to update both documents atomically', async () => {
    await assertFails(
      updateDoc(doc(as(BOB), 'users', BOB), { fullName: 'Stale directory' }),
    );
    await assertFails(
      updateDoc(doc(as(BOB), 'memberDirectory', BOB), {
        fullName: 'Forged directory',
      }),
    );
    await assertSucceeds(
      updateMember(as(BOB), BOB, { fullName: 'Synchronized Bob' }),
    );
  });

  it('never permits private fields in the company projection', async () => {
    await assertFails(
      updateDoc(doc(as(BOB), 'memberDirectory', BOB), {
        email: 'bob@example.test',
      }),
    );
    await assertFails(
      updateDoc(doc(as(ALICE), 'memberDirectory', BOB), {
        fcmTokens: ['secret-device-token'],
      }),
    );
  });

  it('allows valid private locale updates without touching the projection', async () => {
    await assertSucceeds(
      updateDoc(doc(as(BOB), 'users', BOB), { notificationLocale: 'de' }),
    );
    await assertFails(
      updateDoc(doc(as(BOB), 'users', BOB), { notificationLocale: 'fr' }),
    );
  });

  it('reserves avatar paths and revisions for the trusted upload callable', async () => {
    await assertFails(
      updateMember(as(BOB), BOB, {
        profileImage: 'profile_images/bob/avatar.jpg',
      }),
    );
    await assertFails(
      updateMember(as(BOB), BOB, {
        profileImage:
          'https://firebasestorage.googleapis.com/v0/b/example/o/profile_images%2Fbob.jpg?token=public',
      }),
    );
    await assertFails(
      updateMember(as(BOB), BOB, {
        profileImage: 'profile_images/alice/avatar.jpg',
      }),
    );
    await assertFails(
      updateMember(as(BOB), BOB, { profileImageRevision: 1 }),
    );
  });
});

describe('roles cannot be self-awarded', () => {
  it('a user cannot promote themselves', async () => {
    await assertFails(updateDoc(doc(as(BOB), 'users', BOB), { role: 'superadmin' }));
    await assertFails(updateDoc(doc(as(BOB), 'users', BOB), { role: 'admin' }));
  });

  it('a user can still edit their own harmless fields', async () => {
    await assertSucceeds(
      updateMember(as(BOB), BOB, { fullName: 'Bobby' }),
    );
  });

  it('a user cannot move themselves to another company', async () => {
    await assertFails(updateDoc(doc(as(BOB), 'users', BOB), { companyId: RIVAL }));
  });

  it('even the owner cannot change a colleague\'s role directly', async () => {
    await assertFails(
      updateMember(as(ALICE), BOB, { role: 'moderator' }),
    );
  });

  it('an admin cannot reach into another company', async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), 'users', CAROL), { role: 'moderator' }),
    );
  });

  it('an ordinary user cannot change a colleague\'s role', async () => {
    await assertFails(
      updateDoc(doc(as(BOB), 'users', ALICE), { role: 'user' }),
    );
  });

  // The self-award rule and the admin rule used to be a plain OR, so an admin
  // editing their own document satisfied the admin branch — which never
  // required the role to stay put.
  it('an admin cannot promote themselves', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(
        doc(db, 'users', DAVE),
        userDocument(DAVE, { role: 'admin' }),
      );
      await setDoc(
        doc(db, 'memberDirectory', DAVE),
        memberDocument(DAVE, { role: 'admin' }),
      );
    });

    await assertFails(
      updateDoc(doc(as(DAVE), 'users', DAVE), { role: 'superadmin' }),
    );
  });

  // `isAdmin()` counts moderators, which made this the shortest path from the
  // lowest elevated role to the highest.
  it('a moderator cannot promote themselves', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'users', DAVE),
        userDocument(DAVE, { role: 'moderator' }),
      );
    });

    await assertFails(
      updateDoc(doc(as(DAVE), 'users', DAVE), { role: 'superadmin' }),
    );
  });

  it('an admin cannot award superadmin to a colleague either', async () => {
    // Ownership is established at sign-up by createdCompany() and must not be
    // handed out afterwards.
    await assertFails(
      updateDoc(doc(as(ALICE), 'users', BOB), { role: 'superadmin' }),
    );
  });

  it('an admin can still edit their own harmless fields', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(
        doc(db, 'users', DAVE),
        userDocument(DAVE, { role: 'admin' }),
      );
      await setDoc(
        doc(db, 'memberDirectory', DAVE),
        memberDocument(DAVE, { role: 'admin' }),
      );
    });

    await assertSucceeds(
      updateMember(as(DAVE), DAVE, { fullName: 'Davey' }),
    );
  });
});

describe('sign-up', () => {
  it('an unverified account may persist only its private pending intent', async () => {
    const db = asUnverified(DAVE);
    await assertSucceeds(
      setDoc(doc(db, 'users', DAVE), pendingSignupDocument(DAVE)),
    );
    await assertSucceeds(getDoc(doc(db, 'users', DAVE)));
    await assertFails(getDoc(doc(db, 'memberDirectory', DAVE)));
  });

  it('an unverified account cannot create a member projection or join', async () => {
    const db = asUnverified(DAVE);
    const batch = writeBatch(db);
    batch.set(doc(db, 'users', DAVE), pendingSignupDocument(DAVE));
    batch.set(doc(db, 'memberDirectory', DAVE), memberDocument(DAVE));
    await assertFails(batch.commit());
  });

  it('company, public directory and name-lock creation are server-only', async () => {
    const db = as(DAVE);
    const pendingProfile = pendingSignupDocument(DAVE, {
      pendingOnboardingType: 'createCompany',
      pendingCompanyName: 'Dave Ltd',
    });
    delete pendingProfile.pendingCompanyId;
    await assertSucceeds(
      setDoc(doc(db, 'users', DAVE), pendingProfile),
    );

    const batch = writeBatch(db);
    batch.set(doc(db, 'companies', 'company-dave'), {
      name: 'Dave Ltd',
      createdBy: DAVE,
      createdAt: serverTimestamp(),
      joinPolicy: 'open',
    });
    batch.set(doc(db, 'companyNames', 'dave-ltd'), {
      companyId: 'company-dave',
      createdBy: DAVE,
    });
    batch.set(doc(db, 'companyDirectory', 'company-dave'), {
      name: 'Dave Ltd',
      joinPolicy: 'open',
    });
    await assertFails(batch.commit());
  });

  it('an unverified existing account cannot join even with a forged batch', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'users', DAVE),
        userDocument(DAVE, { companyId: '' }),
      );
    });

    const db = asUnverified(DAVE);
    const batch = writeBatch(db);
    batch.update(doc(db, 'users', DAVE), {
      companyId: ACME,
      role: 'user',
      membership: 'active',
    });
    batch.set(doc(db, 'memberDirectory', DAVE), memberDocument(DAVE));
    await assertFails(batch.commit());
  });

  it('an unverified account cannot read tenant content', async () => {
    await assertFails(
      getDoc(doc(asUnverified(BOB), 'surveys', 'acme-survey')),
    );
    await assertFails(
      getDoc(doc(asUnverified(BOB), 'appointments', 'acme-standup')),
    );
  });

  it('a direct final or elevated profile cannot replace the pending shape', async () => {
    await assertFails(
      setDoc(
        doc(as(DAVE), 'users', DAVE),
        signupDocument(DAVE, { role: 'superadmin' }),
      ),
    );
  });

  it('nobody can write a profile under another uid', async () => {
    await assertFails(
      setDoc(doc(as(DAVE), 'users', BOB), {
        ...pendingSignupDocument(DAVE, { fullName: 'Not Bob' }),
      }),
    );
  });
});

describe('survey submissions', () => {
  it('a participant submits under their own id', async () => {
    await assertSucceeds(
      setDoc(
        doc(as(ALICE), 'surveys', 'acme-survey', 'participants', ALICE),
        submissionDocument(ALICE),
      ),
    );
  });

  it('a participant cannot claim a colleague\'s display name', async () => {
    await assertFails(
      setDoc(
        doc(as(ALICE), 'surveys', 'acme-survey', 'participants', ALICE),
        submissionDocument(ALICE, { name: 'Bob' }),
      ),
    );
  });

  it('nobody self-deletes a response, while staff can delete another response', async () => {
    await assertFails(
      deleteDoc(doc(as(BOB), 'surveys', 'acme-survey', 'participants', BOB)),
    );
    await assertFails(
      setDoc(
        doc(as(BOB), 'surveys', 'acme-survey', 'participants', BOB),
        submissionDocument(BOB),
      ),
    );

    await assertSucceeds(
      setDoc(
        doc(as(ADA), 'surveys', 'acme-survey', 'participants', ADA),
        submissionDocument(ADA),
      ),
    );
    await assertFails(
      deleteDoc(doc(as(ADA), 'surveys', 'acme-survey', 'participants', ADA)),
    );

    await assertSucceeds(
      deleteDoc(doc(as(ADA), 'surveys', 'acme-survey', 'participants', BOB)),
    );
  });

  it('snapshots only the caller canonical avatar path, never a bearer URL', async () => {
    await assertSucceeds(
      setDoc(
        doc(as(ALICE), 'surveys', 'acme-survey', 'participants', ALICE),
        submissionDocument(ALICE, {
          imageProfile: 'profile_images/alice/avatar.jpg',
        }),
      ),
    );

    await assertFails(
      setDoc(
        doc(as(BOB), 'surveys', 'acme-survey', 'participants', BOB),
        submissionDocument(BOB, {
          imageProfile:
            'https://firebasestorage.googleapis.com/v0/b/example/o/profile_images%2Fbob.jpg?token=public',
        }),
      ),
    );
    await assertFails(
      setDoc(
        doc(as(BOB), 'surveys', 'acme-survey', 'participants', BOB),
        submissionDocument(BOB, { profileImageRevision: 'forged' }),
      ),
    );
  });

  it('an admin cannot demote, remove, or delete the company owner', async () => {
    await assertFails(
      updateDoc(doc(as(ADA), 'users', ALICE), { role: 'user' }),
    );
    await assertFails(
      updateDoc(doc(as(ADA), 'users', ALICE), {
        companyId: '',
        role: 'user',
        membership: 'active',
      }),
    );
    await assertFails(deleteDoc(doc(as(ALICE), 'users', ALICE)));
  });

  it('rejects a forged score on the initial write', async () => {
    await assertFails(
      setDoc(
        doc(as(ALICE), 'surveys', 'acme-survey', 'participants', ALICE),
        submissionDocument(ALICE, { score: 100, totalCorrectAnswers: 1 }),
      ),
    );
    await assertFails(
      setDoc(
        doc(as(ALICE), 'surveys', 'acme-survey', 'participants', ALICE),
        submissionDocument(ALICE, {
          gradingStatus: 'final',
          gradedQuestionCount: 1,
        }),
      ),
    );
  });

  it('fails closed when a legacy survey has not received its private key', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await deleteDoc(doc(ctx.firestore(), 'surveyAnswerKeys', 'acme-survey'));
    });

    await assertFails(
      setDoc(
        doc(as(ALICE), 'surveys', 'acme-survey', 'participants', ALICE),
        submissionDocument(ALICE),
      ),
    );
  });

  it('rejects an otherwise valid submission after the Timestamp deadline', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'surveys', 'acme-survey'), {
        deadline: new Date(Date.now() - 60_000),
      });
    });

    await assertFails(
      setDoc(
        doc(as(ALICE), 'surveys', 'acme-survey', 'participants', ALICE),
        submissionDocument(ALICE),
      ),
    );
  });

  it('a participant cannot submit as somebody else', async () => {
    await assertFails(
      setDoc(
        doc(as(BOB), 'surveys', 'acme-survey', 'participants', ALICE),
        submissionDocument(ALICE),
      ),
    );
  });

  it('an outsider cannot submit to another company\'s survey', async () => {
    await assertFails(
      setDoc(
        doc(as(CAROL), 'surveys', 'acme-survey', 'participants', CAROL),
        submissionDocument(CAROL),
      ),
    );
  });

  // The point of the whole file. Scoring runs on the client, so if a
  // participant could rewrite their own result the score would mean nothing.
  it('a participant cannot rewrite their own score', async () => {
    await assertFails(
      updateDoc(doc(as(BOB), 'surveys', 'acme-survey', 'participants', BOB), {
        score: 100,
      }),
    );
    await assertFails(
      updateDoc(doc(as(BOB), 'surveys', 'acme-survey', 'participants', BOB), {
        totalCorrectAnswers: 99,
      }),
    );
  });

  it('staff can write only the review map, never derived totals', async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), 'surveys', 'acme-survey', 'participants', BOB), {
        score: 100, totalCorrectAnswers: 5,
      }),
    );
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'surveys', 'acme-survey', 'participants', BOB), {
        textAnswersReviewed: { 'acme-survey-Q0': true },
      }),
    );
  });

  it('staff review verdicts are bounded booleans', async () => {
    const participant = doc(
      as(ALICE),
      'surveys',
      'acme-survey',
      'participants',
      BOB,
    );
    await assertSucceeds(
      updateDoc(participant, {
        textAnswersReviewed: {
          'acme-survey-Q0': true,
          'acme-survey-Q1': false,
        },
      }),
    );

    for (const verdict of ['true', null, 1]) {
      await assertFails(
        updateDoc(participant, {
          textAnswersReviewed: { 'acme-survey-Q0': verdict },
        }),
      );
    }

    await assertFails(
      updateDoc(participant, {
        textAnswersReviewed: Object.fromEntries(
          Array.from({ length: 101 }, (_, index) => [
            `acme-survey-Q${index}`,
            true,
          ]),
        ),
      }),
    );
  });

  it('a participant reads their own result, an admin reads everyone\'s', async () => {
    await assertSucceeds(
      getDoc(doc(as(BOB), 'surveys', 'acme-survey', 'participants', BOB)),
    );
    await assertSucceeds(
      getDoc(doc(as(ALICE), 'surveys', 'acme-survey', 'participants', BOB)),
    );
  });

  it('one participant cannot read another\'s answers', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'surveys', 'acme-survey', 'participants', ALICE),
        { userId: ALICE, name: 'Alice', score: 90 },
      );
    });
    await assertFails(
      getDoc(doc(as(BOB), 'surveys', 'acme-survey', 'participants', ALICE)),
    );
  });
});

describe('survey authoring', () => {
  it('staff must create and update surveys through the trusted callable', async () => {
    await assertFails(
      createSurvey(as(ALICE), 'new-survey', { surveyName: 'New' }),
    );
    await assertFails(
      updateDoc(doc(as(ALICE), 'surveys', 'acme-survey'), {
        surveyName: 'Direct edit',
      }),
    );
  });

  it('an ordinary user cannot create one', async () => {
    await assertFails(
      createSurvey(as(BOB), 'new-survey', {
        surveyName: 'New',
        createdBy: BOB,
      }),
    );
  });

  it('an admin cannot create one for another company', async () => {
    await assertFails(
      createSurvey(as(ALICE), 'new-survey', {
        surveyName: 'New',
        companyId: RIVAL,
      }),
    );
  });

  it('public survey creation and its private key must be one atomic write', async () => {
    await assertFails(
      setDoc(
        doc(as(ALICE), 'surveys', 'public-only'),
        surveyDocument('public-only'),
      ),
    );
    await assertFails(
      setDoc(
        doc(as(ALICE), 'surveyAnswerKeys', 'key-only'),
        answerKeyDocument('key-only'),
      ),
    );
  });

  it('published questions carry no grading key', async () => {
    const survey = await getDoc(doc(as(BOB), 'surveys', 'acme-survey'));
    const question = survey.data().questions[0];
    strictEqual(Object.hasOwn(question, 'correctAnswer'), false);
    strictEqual(Object.hasOwn(question, 'correctAnswers'), false);
  });

  it('private answer keys are readable by staff and nobody else', async () => {
    // Staff review submissions, which means showing which option was right.
    await assertSucceeds(
      getDoc(doc(as(ALICE), 'surveyAnswerKeys', 'acme-survey')),
    );
    await assertSucceeds(
      getDoc(doc(as(MOLLY), 'surveyAnswerKeys', 'acme-survey')),
    );

    // The part that matters: anyone who could still be sitting the test.
    await assertFails(
      getDoc(doc(as(BOB), 'surveyAnswerKeys', 'acme-survey')),
    );
    await assertFails(
      getDoc(doc(as(CAROL), 'surveyAnswerKeys', 'acme-survey')),
    );

    // Another company's key stays closed even to an owner.
    await assertFails(
      getDoc(doc(as(ALICE), 'surveyAnswerKeys', 'rival-survey')),
    );

    // And no sweeping the collection to find them.
    await assertFails(getDocs(collection(as(ALICE), 'surveyAnswerKeys')));
  });

  it('private answer keys are immutable and tenant-bound', async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), 'surveyAnswerKeys', 'acme-survey'), {
        questionKeys: [{ type: 'Single', correctAnswer: 1 }],
      }),
    );
    await assertFails(
      createSurvey(
        as(ALICE),
        'mismatched-key',
        {},
        { companyId: RIVAL },
      ),
    );
  });

  it('a survey cannot be moved between companies', async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), 'surveys', 'acme-survey'), { companyId: RIVAL }),
    );
  });

  it('published questions cannot change underneath existing responses', async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), 'surveys', 'acme-survey'), {
        questions: [
          { type: 'Single', question: 'Changed', options: ['A'] },
        ],
      }),
    );
  });

  it('clients cannot forge the backend response revision', async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), 'surveys', 'acme-survey'), {
        responsesRevision: 1,
      }),
    );
  });

  it('every client must use the trusted survey-deletion boundary', async () => {
    await assertFails(deleteSurvey(as(BOB), 'acme-survey'));
    await assertFails(deleteDoc(doc(as(ALICE), 'surveys', 'acme-survey')));
    await assertFails(deleteSurvey(as(ALICE), 'acme-survey'));
    await assertFails(
      deleteDoc(doc(as(ALICE), 'surveyAnswerKeys', 'acme-survey')),
    );
  });
});

// Canonical appointment content is callable-owned. Vote documents remain
// direct writes, keyed by the stable slot id and bounded by server time.
describe('voting on an appointment', () => {
  const appt = () => 'acme-standup';
  const voteId = (uid, slotId = slot.slotId) => `${uid}-${slotId}`;

  it('denies every direct appointment create or content edit', async () => {
    await assertFails(
      setDoc(
        doc(as(ADA), 'appointments', 'direct-create'),
        appointmentDocument('direct-create', { createdBy: ADA }),
      ),
    );
    await assertFails(
      updateDoc(doc(as(ADA), 'appointments', appt()), {
        title: 'Direct edit',
        revision: 1,
      }),
    );
    await assertFails(
      updateDoc(doc(as(ADA), 'appointments', appt()), {
        participantUserIds: [BOB],
        revision: 1,
      }),
    );
  });

  it('allows only a null-to-offered-slot confirmation with revision +1', async () => {
    const ref = doc(as(ADA), 'appointments', appt());

    await assertFails(updateDoc(ref, { confirmedSlotId: slot.slotId }));
    await assertFails(
      updateDoc(ref, { confirmedSlotId: 'not-offered', revision: 2 }),
    );
    await assertFails(
      updateDoc(ref, { confirmedSlotId: slot.slotId, revision: 3 }),
    );
    await assertSucceeds(
      updateDoc(ref, { confirmedSlotId: slot.slotId, revision: 2 }),
    );

    // Reopening/clearing is callable-owned, as is replacing a confirmation.
    await assertFails(updateDoc(ref, { confirmedSlotId: null, revision: 3 }));
    await assertFails(
      updateDoc(ref, { confirmedSlotId: slot.slotId, revision: 3 }),
    );
  });

  it('accepts the backend terminal safe-integer revision without overflowing it', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'appointments', 'terminal-revision'),
        appointmentDocument('terminal-revision', {
          revision: Number.MAX_SAFE_INTEGER,
        }),
      );
    });

    const ref = doc(as(ADA), 'appointments', 'terminal-revision');
    await assertSucceeds(getDoc(ref));
    await assertFails(
      updateDoc(ref, {
        confirmedSlotId: slot.slotId,
        revision: Number.MAX_SAFE_INTEGER + 1,
      }),
    );
  });

  it('fails closed for a legacy string-based appointment document', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'appointments', 'legacy-string'), {
        companyId: ACME,
        title: 'Legacy',
        description: 'Offset-less strings',
        appointmentId: 'legacy-string',
        expirationDate: '2030-01-09T23:59:00',
        availableTimeSlots: [
          { start: '2030-01-10T09:00:00', end: '2030-01-10T10:00:00' },
        ],
      });
    });

    await assertFails(getDoc(doc(as(BOB), 'appointments', 'legacy-string')));
    await assertFails(
      updateDoc(doc(as(ADA), 'appointments', 'legacy-string'), {
        confirmedSlotId: 'legacy-slot',
        revision: 1,
      }),
    );
  });

  it('accepts the caller canonical vote for an offered stable slot id', async () => {
    await assertSucceeds(
      setDoc(
        doc(as(BOB), 'appointments', appt(), 'participants', voteId(BOB)),
        voteDocument(BOB),
      ),
    );
  });

  it('rejects unoffered, mismatched, and legacy timestamp-derived vote ids', async () => {
    await assertFails(
      setDoc(
        doc(
          as(BOB),
          'appointments',
          appt(),
          'participants',
          voteId(BOB, 'not-offered'),
        ),
        voteDocument(BOB, { slotId: 'not-offered' }),
      ),
    );
    await assertFails(
      setDoc(
        doc(
          as(BOB),
          'appointments',
          appt(),
          'participants',
          `${BOB}-2030-01-10T09:00:00-2030-01-10T10:00:00`,
        ),
        voteDocument(BOB),
      ),
    );
    await assertFails(
      setDoc(
        doc(as(BOB), 'appointments', appt(), 'participants', voteId(BOB)),
        {
          ...voteDocument(BOB),
          date: '2030-01-10T09:00:00',
          timeSlot: { start: '2030-01-10T09:00:00' },
        },
      ),
    );
  });

  it('a voter cannot claim a colleague\'s canonical display name', async () => {
    await assertFails(
      setDoc(
        doc(as(BOB), 'appointments', appt(), 'participants', voteId(BOB)),
        voteDocument(BOB, { userName: 'Alice' }),
      ),
    );
  });

  it('uses the current canonical name for new writes without rewriting history', async () => {
    const response = doc(
      as(ALICE),
      'surveys',
      'acme-survey',
      'participants',
      BOB,
    );
    strictEqual((await getDoc(response)).data().name, 'Bob');

    await assertSucceeds(updateMember(as(BOB), BOB, { fullName: 'Robert' }));
    strictEqual((await getDoc(response)).data().name, 'Bob');

    const vote = doc(
      as(BOB),
      'appointments',
      appt(),
      'participants',
      voteId(BOB),
    );
    await assertFails(setDoc(vote, voteDocument(BOB)));
    await assertSucceeds(
      setDoc(vote, voteDocument(BOB, { userName: 'Robert' })),
    );
  });

  it('fails closed when the caller has no member-directory projection', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await deleteDoc(doc(ctx.firestore(), 'memberDirectory', ALICE));
    });

    await assertFails(
      setDoc(
        doc(as(ALICE), 'surveys', 'acme-survey', 'participants', ALICE),
        submissionDocument(ALICE),
      ),
    );
    await assertFails(
      setDoc(
        doc(
          as(ALICE),
          'appointments',
          appt(),
          'participants',
          voteId(ALICE),
        ),
        voteDocument(ALICE),
      ),
    );
  });

  it('a repeated stable vote id updates one document instead of duplicating', async () => {
    const ref = doc(
      as(BOB),
      'appointments',
      appt(),
      'participants',
      voteId(BOB),
    );
    await assertSucceeds(setDoc(ref, voteDocument(BOB)));
    await assertSucceeds(setDoc(ref, voteDocument(BOB, { status: 'maybe' })));
    strictEqual((await getDoc(ref)).data().status, 'maybe');
  });

  it('an outsider cannot vote or write another user stable vote id', async () => {
    await assertFails(
      setDoc(
        doc(
          as(CAROL),
          'appointments',
          appt(),
          'participants',
          voteId(CAROL),
        ),
        voteDocument(CAROL),
      ),
    );
    await assertFails(
      setDoc(
        doc(as(BOB), 'appointments', appt(), 'participants', voteId(CAROL)),
        voteDocument(CAROL),
      ),
    );
  });

  it('a voter can delete their own canonical vote while voting is open', async () => {
    const ref = doc(
      as(BOB),
      'appointments',
      appt(),
      'participants',
      voteId(BOB),
    );
    await assertSucceeds(setDoc(ref, voteDocument(BOB)));
    await assertSucceeds(deleteDoc(ref));
  });

  it('denies self-delete after the server deadline', async () => {
    const ref = doc(
      as(BOB),
      'appointments',
      appt(),
      'participants',
      voteId(BOB),
    );
    await assertSucceeds(setDoc(ref, voteDocument(BOB)));
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'appointments', appt()), {
        expirationAt: new Date(Date.now() - 60_000),
      });
    });

    await assertFails(deleteDoc(ref));
  });

  it('denies self-delete after confirmation but preserves admin cleanup', async () => {
    const selfRef = doc(
      as(BOB),
      'appointments',
      appt(),
      'participants',
      voteId(BOB),
    );
    await assertSucceeds(setDoc(selfRef, voteDocument(BOB)));
    await assertSucceeds(
      updateDoc(doc(as(ADA), 'appointments', appt()), {
        confirmedSlotId: slot.slotId,
        revision: 2,
      }),
    );

    await assertFails(deleteDoc(selfRef));
    await assertSucceeds(
      deleteDoc(
        doc(
          as(ADA),
          'appointments',
          appt(),
          'participants',
          voteId(BOB),
        ),
      ),
    );
  });

  it('server time wins both directions of device-clock disagreement', async () => {
    const futureDeadline = new Date(Date.now() + 60_000);
    const deviceClockAhead = new Date(futureDeadline.getTime() + 86_400_000);
    strictEqual(deviceClockAhead >= futureDeadline, true);
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'appointments', appt()), {
        expirationAt: futureDeadline,
      });
    });

    // A device that incorrectly looks closed cannot change server acceptance.
    await assertSucceeds(
      setDoc(
        doc(as(BOB), 'appointments', appt(), 'participants', voteId(BOB)),
        voteDocument(BOB),
      ),
    );

    const pastDeadline = new Date(Date.now() - 60_000);
    const deviceClockBehind = new Date(pastDeadline.getTime() - 86_400_000);
    strictEqual(deviceClockBehind < pastDeadline, true);
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'appointments', appt()), {
        expirationAt: pastDeadline,
      });
    });

    // A manipulated device that looks open cannot override request.time.
    await assertFails(
      setDoc(
        doc(as(ALICE), 'appointments', appt(), 'participants', voteId(ALICE)),
        voteDocument(ALICE),
      ),
    );
  });

  it('rejects a vote queued before cutoff when it synchronizes after cutoff', async () => {
    const voter = as(BOB);
    await disableNetwork(voter);
    const queuedResult = assertFails(
      setDoc(
        doc(voter, 'appointments', appt(), 'participants', voteId(BOB)),
        voteDocument(BOB),
      ),
    );

    try {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'appointments', appt()), {
          expirationAt: new Date(Date.now() - 1),
        });
      });
    } finally {
      await enableNetwork(voter);
    }

    await queuedResult;
  });

  it('rejects once an emulator-authored server deadline has been reached', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'appointments', appt()), {
        expirationAt: serverTimestamp(),
      });
    });

    await assertFails(
      setDoc(
        doc(as(BOB), 'appointments', appt(), 'participants', voteId(BOB)),
        voteDocument(BOB),
      ),
    );
  });

  it('excludes the exact expiration instant with a strict less-than boundary', () => {
    const rules = readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');
    strictEqual(rules.includes('request.time < data.expirationAt'), true);
    strictEqual(rules.includes('request.time <= data.expirationAt'), false);
  });
});

describe('trusted content deletion write barriers', () => {
  const appointmentId = 'acme-standup';
  const bobVoteId = `${BOB}-${slot.slotId}`;

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(
        doc(db, 'appointments', appointmentId, 'participants', bobVoteId),
        voteDocument(BOB),
      );
      await updateDoc(doc(db, 'surveys', 'acme-survey'), {
        deletionStartedAt: new Date(),
      });
      await updateDoc(doc(db, 'appointments', appointmentId), {
        deletionStartedAt: new Date(),
      });
    });
  });

  it('keeps marked parents and existing children readable until final deletion', async () => {
    await assertSucceeds(getDoc(doc(as(BOB), 'surveys', 'acme-survey')));
    await assertSucceeds(
      getDoc(doc(as(BOB), 'surveys', 'acme-survey', 'participants', BOB)),
    );
    await assertSucceeds(getDoc(doc(as(BOB), 'appointments', appointmentId)));
    await assertSucceeds(
      getDoc(
        doc(as(BOB), 'appointments', appointmentId, 'participants', bobVoteId),
      ),
    );
  });

  it('denies every survey participant mutation after the marker', async () => {
    await assertFails(
      setDoc(
        doc(as(ALICE), 'surveys', 'acme-survey', 'participants', ALICE),
        submissionDocument(ALICE),
      ),
    );
    await assertFails(
      updateDoc(doc(as(ADA), 'surveys', 'acme-survey', 'participants', BOB), {
        textAnswersReviewed: { 'acme-survey-Q0': true },
      }),
    );
    await assertFails(
      deleteDoc(doc(as(ADA), 'surveys', 'acme-survey', 'participants', BOB)),
    );
  });

  it('denies every appointment mutation after the marker', async () => {
    const bobVote = doc(
      as(BOB),
      'appointments',
      appointmentId,
      'participants',
      bobVoteId,
    );
    await assertFails(
      setDoc(
        doc(
          as(ALICE),
          'appointments',
          appointmentId,
          'participants',
          `${ALICE}-${slot.slotId}`,
        ),
        voteDocument(ALICE),
      ),
    );
    await assertFails(updateDoc(bobVote, { status: 'maybe' }));
    await assertFails(deleteDoc(bobVote));
    await assertFails(
      deleteDoc(
        doc(
          as(ADA),
          'appointments',
          appointmentId,
          'participants',
          bobVoteId,
        ),
      ),
    );
    await assertFails(
      updateDoc(doc(as(ADA), 'appointments', appointmentId), {
        confirmedSlotId: slot.slotId,
        revision: 2,
      }),
    );
    await assertFails(deleteDoc(doc(as(ADA), 'appointments', appointmentId)));
  });
});

describe('notes are private', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'notes', BOB, 'userNotes', 'n1'), { title: 'Bob note' });
      await setDoc(doc(db, 'users', BOB, 'notes', 'n1'), { content: 'secret' });
    });
  });

  it('a user reads and writes their own notes', async () => {
    await assertSucceeds(getDoc(doc(as(BOB), 'notes', BOB, 'userNotes', 'n1')));
    await assertSucceeds(
      setDoc(doc(as(BOB), 'notes', BOB, 'userNotes', 'n2'), { title: 'new' }),
    );
    await assertSucceeds(getDoc(doc(as(BOB), 'users', BOB, 'notes', 'n1')));
  });

  // A colleague, not an outsider — being in the same company must not grant
  // access to someone's private notes.
  it('a colleague cannot read them', async () => {
    await assertFails(getDoc(doc(as(ALICE), 'notes', BOB, 'userNotes', 'n1')));
    await assertFails(getDoc(doc(as(ALICE), 'users', BOB, 'notes', 'n1')));
  });

  it('nobody can write into another user\'s notes', async () => {
    await assertFails(
      setDoc(doc(as(ALICE), 'notes', BOB, 'userNotes', 'n3'), { title: 'x' }),
    );
  });

  it('deletes the list row and rich body only as one atomic cleanup', async () => {
    await assertFails(
      deleteDoc(doc(as(BOB), 'notes', BOB, 'userNotes', 'n1')),
    );
    await assertFails(deleteDoc(doc(as(BOB), 'users', BOB, 'notes', 'n1')));

    const db = as(BOB);
    const batch = writeBatch(db);
    batch.delete(doc(db, 'notes', BOB, 'userNotes', 'n1'));
    batch.delete(doc(db, 'users', BOB, 'notes', 'n1'));
    await assertSucceeds(batch.commit());
  });
});

// The split the user asked for: a moderator runs the content, an admin runs the
// people. Enforced here rather than only in the UI, because the UI is a
// suggestion and this is the rule.
describe('moderators run content, not people', () => {
  it('a moderator publishes surveys and appointments only through backends', async () => {
    await assertFails(
      createSurvey(as(MOLLY), 'new-survey', {
        surveyName: 'By a moderator',
        createdBy: MOLLY,
      }),
    );
    await assertFails(
      setDoc(doc(as(MOLLY), 'appointments', 'new-meeting'), {
        ...appointmentDocument('new-meeting', {
          title: 'By a moderator',
          createdBy: MOLLY,
          participantUserIds: [],
        }),
      }),
    );
  });

  it('a moderator may mark a written answer', async () => {
    await assertSucceeds(
      updateDoc(doc(as(MOLLY), 'surveys', 'acme-survey', 'participants', BOB), {
        textAnswersReviewed: { 'acme-survey-Q0': false },
      }),
    );
  });

  it('a moderator cannot bypass trusted content deletion', async () => {
    await assertFails(deleteSurvey(as(MOLLY), 'acme-survey'));
    await assertFails(
      deleteDoc(doc(as(MOLLY), 'appointments', 'acme-standup')),
    );
  });

  it('a moderator may NOT change anyone\'s role', async () => {
    await assertFails(updateDoc(doc(as(MOLLY), 'users', BOB), { role: 'admin' }));
    await assertFails(
      updateDoc(doc(as(MOLLY), 'users', BOB), { role: 'moderator' }),
    );
  });

  it('a moderator may NOT ban or remove anyone', async () => {
    await assertFails(banMember(as(MOLLY), BOB, { bannedBy: MOLLY }));
    await assertFails(
      updateDoc(doc(as(MOLLY), 'users', BOB), { companyId: '', role: 'user' }),
    );
  });

  it('an admin must use the trusted boundary for all three', async () => {
    await assertFails(updateMember(as(ADA), BOB, { role: 'moderator' }));
    await assertFails(banMember(as(ADA), BOB));
    await assertFails(
      removeMember(as(ADA), BOB),
    );
  });

  it('a direct ban stays denied regardless of an account-deletion lock', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'accountDeletionLocks', BOB), {
        startedAt: new Date(),
        expiresAt: new Date(Date.now() + 60 * 60 * 1000),
      });
    });

    await assertFails(banMember(as(ADA), BOB));

    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await deleteDoc(doc(ctx.firestore(), 'accountDeletionLocks', BOB));
    });
    await assertFails(banMember(as(ADA), BOB));
  });

  it('an admin may not move a colleague into another company', async () => {
    // Removal clears the company. Anything else would be a transfer, and there
    // is no such thing here.
    await assertFails(
      updateDoc(doc(as(ADA), 'users', BOB), { companyId: RIVAL, role: 'user' }),
    );
  });
});

describe('a ban is the company\'s, not the account\'s', () => {
  // The ban lives at companies/{c}/bans/{uid}. That is what lets the account
  // outlive it: the login, the notes and the ability to go elsewhere all stay.
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await updateDoc(doc(db, 'users', BOB), { membership: 'pending' });
      await updateDoc(doc(db, 'memberDirectory', BOB), {
        membership: 'pending',
      });
      await setDoc(doc(db, 'companies', ACME, 'bans', BOB), {
        name: 'Bob',
        bannedAt: new Date(),
        bannedBy: ADA,
        previousMembership: 'active',
      });
    });
  });

  it('a banned member loses the company\'s content', async () => {
    await assertFails(getDoc(doc(as(BOB), 'surveys', 'acme-survey')));
    await assertFails(getDoc(doc(as(BOB), 'appointments', 'acme-standup')));
    await assertFails(getDoc(doc(as(BOB), 'users', ALICE)));
  });

  it('a banned member cannot answer a survey', async () => {
    await assertFails(
      setDoc(
        doc(as(BOB), 'surveys', 'acme-survey', 'participants', BOB),
        submissionDocument(BOB),
      ),
    );
  });

  it('a banned member can read their own profile and their own ban', async () => {
    // Both are needed for the app to say "you are banned from Acme" rather than
    // failing silently and looking broken.
    await assertSucceeds(getDoc(doc(as(BOB), 'users', BOB)));
    await assertSucceeds(getDoc(doc(as(BOB), 'companies', ACME, 'bans', BOB)));
  });

  it('a banned member cannot lift their own ban', async () => {
    await assertFails(deleteDoc(doc(as(BOB), 'companies', ACME, 'bans', BOB)));
  });

  it('a banned member can leave and join elsewhere', async () => {
    // The whole point: the account survives the ban.
    await assertSucceeds(
      removeMember(as(BOB), BOB),
    );
  });

  it('a banned member cannot rejoin the company that banned them', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', BOB), {
        fullName: 'Bob', role: 'user', companyId: '', membership: 'active',
      });
    });

    await assertFails(
      updateDoc(doc(as(BOB), 'users', BOB), {
        companyId: ACME, role: 'user', membership: 'active',
      }),
    );
  });

  it('an admin and moderator cannot lift it without the trusted boundary', async () => {
    await assertFails(unbanMember(as(MOLLY), BOB));
    await assertFails(unbanMember(as(ADA), BOB));
    const restored = await getDoc(doc(as(BOB), 'users', BOB));
    strictEqual(restored.data().membership, 'pending');
  });

  it('cannot approve a banned projection without deleting the ban atomically', async () => {
    await assertFails(
      updateMember(as(ADA), BOB, { membership: 'active' }),
    );
  });

  it('an admin cannot directly erase a banned member', async () => {
    await assertFails(eraseMember(as(ADA), BOB));

    const released = await getDoc(doc(as(BOB), 'users', BOB));
    strictEqual(released.data().companyId, ACME);
    strictEqual(released.data().role, 'user');
    strictEqual(released.data().membership, 'pending');

    const oldBan = await getDoc(
      doc(as(ADA), 'companies', ACME, 'bans', BOB),
    );
    strictEqual(oldBan.exists(), true);
  });

  it('an admin cannot ban themselves out of their own company', async () => {
    await assertFails(banMember(as(ADA), ADA));
  });

  it('an admin cannot ban the owner or a user from another company', async () => {
    await assertFails(banMember(as(ADA), ALICE));
    await assertFails(banMember(as(ADA), CAROL));
  });

});

describe('joining a company', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      // Bob is between companies — the state a removed or banned member lands
      // in, and the one a fresh account starts from.
      await setDoc(doc(db, 'users', BOB), {
        fullName: 'Bob', role: 'user', companyId: '', membership: 'active',
      });
      await deleteDoc(doc(db, 'memberDirectory', BOB));
      await setDoc(doc(db, 'companies', RIVAL), {
        name: 'Rival', createdBy: CAROL, joinPolicy: 'approval',
      });
    });
  });

  it('an open company lets you straight in', async () => {
    // Acme has no joinPolicy at all, which must read as open so companies made
    // before the setting existed keep working.
    await assertSucceeds(
      joinCompany(as(BOB), BOB, ACME, 'active'),
    );
  });

  it('a company requiring approval holds you pending', async () => {
    await assertSucceeds(
      joinCompany(as(BOB), BOB, RIVAL, 'pending'),
    );
  });

  it('you cannot approve yourself into one', async () => {
    // Otherwise "approval required" is a suggestion the client can decline.
    await assertFails(
      updateDoc(doc(as(BOB), 'users', BOB), {
        companyId: RIVAL, role: 'user', membership: 'active',
      }),
    );
  });

  it('you cannot arrive as an admin', async () => {
    await assertFails(
      updateDoc(doc(as(BOB), 'users', BOB), {
        companyId: ACME, role: 'admin', membership: 'active',
      }),
    );
  });
});

describe('pending members are held out', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users', BOB), {
        fullName: 'Bob', role: 'user', companyId: ACME, membership: 'pending',
      });
      await setDoc(
        doc(db, 'memberDirectory', BOB),
        memberDocument(BOB, { membership: 'pending' }),
      );
    });
  });

  it('they cannot read the company\'s content', async () => {
    await assertFails(getDoc(doc(as(BOB), 'surveys', 'acme-survey')));
    await assertFails(getDoc(doc(as(BOB), 'appointments', 'acme-standup')));
  });

  it('they cannot approve themselves', async () => {
    await assertFails(
      updateDoc(doc(as(BOB), 'users', BOB), { membership: 'active' }),
    );
  });

  it('they can still edit their own name, and leave', async () => {
    await assertSucceeds(
      updateMember(as(BOB), BOB, { fullName: 'Robert' }),
    );
    await assertSucceeds(
      removeMember(as(BOB), BOB),
    );
  });

  it('an admin and moderator cannot approve them directly', async () => {
    await assertFails(
      updateDoc(doc(as(MOLLY), 'users', BOB), { membership: 'active' }),
    );
    await assertFails(
      updateMember(as(ADA), BOB, { membership: 'active' }),
    );
  });
});

describe('the join policy is trusted-only', () => {
  it('an admin may not set it directly', async () => {
    const db = as(ADA);
    const batch = writeBatch(db);
    batch.update(doc(db, 'companies', ACME), { joinPolicy: 'approval' });
    batch.update(doc(db, 'companyDirectory', ACME), {
      joinPolicy: 'approval',
    });
    await assertFails(batch.commit());
  });

  it('a moderator may not', async () => {
    const db = as(MOLLY);
    const batch = writeBatch(db);
    batch.update(doc(db, 'companies', ACME), { joinPolicy: 'approval' });
    batch.update(doc(db, 'companyDirectory', ACME), {
      joinPolicy: 'approval',
    });
    await assertFails(batch.commit());
  });

  it('an ordinary member may not', async () => {
    const db = as(BOB);
    const batch = writeBatch(db);
    batch.update(doc(db, 'companies', ACME), { joinPolicy: 'approval' });
    batch.update(doc(db, 'companyDirectory', ACME), {
      joinPolicy: 'approval',
    });
    await assertFails(batch.commit());
  });

  it('even the owner cannot rename without a trusted name-lock transaction', async () => {
    const db = as(ALICE);
    const batch = writeBatch(db);
    batch.update(doc(db, 'companies', ACME), { name: 'Rival' });
    batch.update(doc(db, 'companyDirectory', ACME), { name: 'Rival' });
    await assertFails(batch.commit());
  });
});

describe('account-deletion participation cleanup', () => {
  it('is not exposed as a client collection-group sweep', async () => {
    const bobVoteId = `${BOB}-${slot.slotId}`;
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(
        doc(db, 'appointments', 'acme-standup', 'participants', bobVoteId),
        voteDocument(BOB),
      );
      await updateDoc(doc(db, 'users', BOB), {
        companyId: '',
        role: 'user',
        membership: 'active',
      });
    });

    const ownQuery = query(
      collectionGroup(as(BOB), 'participants'),
      where('userId', '==', BOB),
    );
    await assertFails(getDocs(ownQuery));

    const someoneElsesQuery = query(
      collectionGroup(as(BOB), 'participants'),
      where('userId', '==', ALICE),
    );
    await assertFails(getDocs(someoneElsesQuery));
  });
});

describe('account deletion write lock', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'accountDeletionLocks', BOB), {
        startedAt: new Date(),
        expiresAt: new Date(Date.now() + 60 * 60 * 1000),
      });
    });
  });

  it('blocks another signed-in device from recreating data during erasure', async () => {
    await assertFails(updateDoc(doc(as(BOB), 'users', BOB), { fullName: 'Again' }));
    await assertFails(
      setDoc(doc(as(BOB), 'notes', BOB, 'userNotes', 'late-note'), {
        title: 'Too late',
      }),
    );
    await assertFails(
      setDoc(
        doc(
          as(BOB),
          'appointments',
          'acme-standup',
          'participants',
          `${BOB}-${slot.slotId}`,
        ),
        voteDocument(BOB),
      ),
    );
  });

  it('does not expose or let the client remove the trusted lock', async () => {
    await assertFails(getDoc(doc(as(BOB), 'accountDeletionLocks', BOB)));
    await assertFails(deleteDoc(doc(as(BOB), 'accountDeletionLocks', BOB)));
  });
});

describe('closing a company', () => {
  const past = new Date(Date.now() - 60_000);
  const future = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

  const schedule = async (at) => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'companies', ACME), {
        name: 'Acme',
        createdBy: ALICE,
        deletionScheduledFor: at,
        deletionRequestedBy: ALICE,
      });
    });
  };

  it('owner and admin cannot schedule it directly', async () => {
    const freshAuthTime = Math.floor(Date.now() / 1000) - 60;
    await assertFails(
      updateDoc(doc(asAuthenticatedAt(ADA, freshAuthTime), 'companies', ACME), {
        deletionScheduledFor: future,
        deletionRequestedBy: ADA,
      }),
    );
    await assertFails(
      updateDoc(doc(asAuthenticatedAt(ALICE, freshAuthTime), 'companies', ACME), {
        deletionScheduledFor: future,
        deletionRequestedBy: ALICE,
      }),
    );
  });

  it('the owner cannot cancel it directly', async () => {
    await schedule(future);
    await assertFails(
      updateDoc(doc(as(ALICE), 'companies', ACME), {
        deletionScheduledFor: deleteField(),
        deletionRequestedBy: deleteField(),
      }),
    );
  });

  it('the week cannot be skipped', async () => {
    // The grace period is enforced here, not by a countdown in the app — a
    // client-side wait lasts only until somebody sends the request themselves,
    // and this one destroys everybody's work.
    await schedule(future);
    await assertFails(deleteDoc(doc(as(ALICE), 'companies', ACME)));
  });

  it('an unscheduled company cannot be deleted at all', async () => {
    await assertFails(deleteDoc(doc(as(ALICE), 'companies', ACME)));
  });

  it('even once due, deletion is reserved for the Admin SDK purge', async () => {
    await schedule(past);
    await assertFails(deleteDoc(doc(as(ALICE), 'companies', ACME)));
  });

  it('an admin still may not, even once due', async () => {
    await schedule(past);
    await assertFails(deleteDoc(doc(as(ADA), 'companies', ACME)));
  });

  it('once due, clients cannot read or create new company content', async () => {
    await schedule(past);
    await assertFails(getDoc(doc(as(BOB), 'surveys', 'acme-survey')));
    await assertFails(
      setDoc(
        doc(as(ALICE), 'surveys', 'after-close'),
        surveyDocument('after-close'),
      ),
    );
  });

  it('the name is released only by whoever reserved it', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'companyNames', 'acme'), {
        companyId: ACME, createdBy: ALICE,
      });
    });

    await assertFails(deleteDoc(doc(as(BOB), 'companyNames', 'acme')));
    await assertFails(deleteDoc(doc(as(ALICE), 'companyNames', 'acme')));

    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await deleteDoc(doc(ctx.firestore(), 'companies', ACME));
    });
    await assertSucceeds(deleteDoc(doc(as(ALICE), 'companyNames', 'acme')));
  });
});
