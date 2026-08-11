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
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
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
  start: '2030-01-10T09:00:00.000Z',
  end: '2030-01-10T10:00:00.000Z',
  expirationDate: '2030-01-10T09:00:00.000Z',
  isConfirmed: false,
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
  companyId: ACME,
  title: 'Standup',
  description: 'Weekly standup',
  availableDates: [slot.start],
  participants: [],
  availableTimeSlots: [slot],
  appointmentId: id,
  expirationDate: '2030-01-09T23:59:00.000Z',
  expirationAt: new Date('2030-01-09T23:59:00.000Z'),
  confirmedTimeSlots: [],
  participantUserIds: [ALICE],
  creationDate: new Date(),
  createdBy: ALICE,
  ...overrides,
});

const voteDocument = (uid, overrides = {}) => ({
  userName: uid[0].toUpperCase() + uid.slice(1),
  date: slot.start,
  timeSlot: slot,
  status: 'joined',
  userId: uid,
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
  });
});

const as = (uid) =>
  testEnv.authenticatedContext(uid, {
    email: `${uid}@example.test`,
    email_verified: true,
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

  it('an admin can change a colleague\'s role', async () => {
    await assertSucceeds(
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

  it('an ordinary user cannot delete a survey', async () => {
    await assertFails(deleteSurvey(as(BOB), 'acme-survey'));
    await assertFails(deleteDoc(doc(as(ALICE), 'surveys', 'acme-survey')));
    await assertSucceeds(deleteSurvey(as(ALICE), 'acme-survey'));
  });
});

// Vote documents are authoritative. A trusted create/delete trigger derives
// participantUserIds; client rules never permit that parent cache to change.
describe('voting on an appointment', () => {
  const appt = () => 'acme-standup';

  it('a colleague cannot forge the parent voter list without a vote', async () => {
    await assertFails(
      updateDoc(doc(as(BOB), 'appointments', appt()), {
        participantUserIds: [ALICE, BOB],
      }),
    );
  });

  it('an admin cannot forge the server-derived parent voter list either', async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), 'appointments', appt()), {
        participantUserIds: [ALICE, BOB],
      }),
    );
  });

  it('an admin can still edit the appointment properly', async () => {
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'appointments', appt()), { title: 'Renamed' }),
    );
  });

  it('a legacy appointment without the server voter cache stays editable', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'appointments', appt()), {
        participantUserIds: deleteField(),
      });
    });

    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'appointments', appt()), { title: 'Legacy edit' }),
    );
    await assertFails(
      updateDoc(doc(as(ALICE), 'appointments', appt()), {
        participantUserIds: [],
      }),
    );
  });

  it('accepts only the caller\'s vote for an exact offered slot', async () => {
    const voteId = `${BOB}-${slot.start}-${slot.end}`;
    await assertSucceeds(
      setDoc(
        doc(as(BOB), 'appointments', appt(), 'participants', voteId),
        voteDocument(BOB),
      ),
    );

    const forged = { ...slot, end: '2030-01-10T11:00:00.000Z' };
    await assertFails(
      setDoc(
        doc(
          as(BOB),
          'appointments',
          appt(),
          'participants',
          `${BOB}-${forged.start}-${forged.end}`,
        ),
        voteDocument(BOB, { timeSlot: forged, date: forged.start }),
      ),
    );
  });

  it('the deterministic vote id makes a repeated vote an update, not a duplicate', async () => {
    const voteId = `${BOB}-${slot.start}-${slot.end}`;
    const ref = doc(as(BOB), 'appointments', appt(), 'participants', voteId);
    await assertSucceeds(setDoc(ref, voteDocument(BOB)));
    await assertSucceeds(setDoc(ref, voteDocument(BOB, { status: 'maybe' })));

    const stored = await getDoc(ref);
    strictEqual(stored.data().status, 'maybe');
  });

  it('an outsider cannot create a vote or vote for another user', async () => {
    await assertFails(
      setDoc(
        doc(
          as(CAROL),
          'appointments',
          appt(),
          'participants',
          `${CAROL}-${slot.start}-${slot.end}`,
        ),
        voteDocument(CAROL),
      ),
    );
    await assertFails(
      setDoc(
        doc(
          as(BOB),
          'appointments',
          appt(),
          'participants',
          `${CAROL}-${slot.start}-${slot.end}`,
        ),
        voteDocument(CAROL),
      ),
    );
  });

  it('a voter can delete their own vote so the trusted trigger can reconcile', async () => {
    const voteId = `${BOB}-${slot.start}-${slot.end}`;
    const ref = doc(as(BOB), 'appointments', appt(), 'participants', voteId);
    await assertSucceeds(setDoc(ref, voteDocument(BOB)));
    await assertSucceeds(deleteDoc(ref));
  });

  it('a voter cannot overwrite another member\'s vote document', async () => {
    const aliceVoteId = `${ALICE}-${slot.start}-${slot.end}`;
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(
          ctx.firestore(),
          'appointments',
          appt(),
          'participants',
          aliceVoteId,
        ),
        voteDocument(ALICE),
      );
    });

    await assertFails(
      updateDoc(
        doc(as(BOB), 'appointments', appt(), 'participants', aliceVoteId),
        { status: 'declined', userId: BOB },
      ),
    );
  });

  it('the Timestamp deadline closes vote writes', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'appointments', appt()), {
        expirationAt: new Date(Date.now() - 60_000),
      });
    });

    const voteId = `${BOB}-${slot.start}-${slot.end}`;
    await assertFails(
      setDoc(
        doc(as(BOB), 'appointments', appt(), 'participants', voteId),
        voteDocument(BOB),
      ),
    );
  });

  it('legacy appointments remain readable but require expirationAt backfill to vote', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'appointments', appt()), {
        expirationAt: deleteField(),
      });
    });

    await assertSucceeds(getDoc(doc(as(BOB), 'appointments', appt())));
    const voteId = `${BOB}-${slot.start}-${slot.end}`;
    await assertFails(
      setDoc(
        doc(as(BOB), 'appointments', appt(), 'participants', voteId),
        voteDocument(BOB),
      ),
    );

    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'appointments', appt()), {
        expirationAt: new Date('2030-01-09T23:59:00.000Z'),
      }),
    );
    await assertSucceeds(
      setDoc(
        doc(as(BOB), 'appointments', appt(), 'participants', voteId),
        voteDocument(BOB),
      ),
    );
  });

  it('an admin can confirm exactly one offered slot and deliberately reopen', async () => {
    const confirmed = { ...slot, isConfirmed: true };
    const ref = doc(as(ALICE), 'appointments', appt());

    await assertSucceeds(
      updateDoc(ref, {
        availableTimeSlots: [confirmed],
        confirmedTimeSlots: [confirmed],
      }),
    );
    await assertFails(
      updateDoc(ref, { confirmedTimeSlots: [confirmed, confirmed] }),
    );
    await assertSucceeds(
      updateDoc(ref, {
        availableTimeSlots: [slot],
        confirmedTimeSlots: [],
      }),
    );
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
  it('a moderator publishes surveys through the backend but may write appointments', async () => {
    await assertFails(
      createSurvey(as(MOLLY), 'new-survey', {
        surveyName: 'By a moderator',
        createdBy: MOLLY,
      }),
    );
    await assertSucceeds(
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

  it('a moderator may delete a survey or a meeting', async () => {
    await assertSucceeds(deleteSurvey(as(MOLLY), 'acme-survey'));
    await assertSucceeds(
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

  it('an admin may do all three', async () => {
    await assertSucceeds(updateMember(as(ADA), BOB, { role: 'moderator' }));
    await assertSucceeds(banMember(as(ADA), BOB));
    await assertSucceeds(
      removeMember(as(ADA), BOB),
    );
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

  it('an admin can lift it, a moderator cannot', async () => {
    await assertFails(unbanMember(as(MOLLY), BOB));
    await assertSucceeds(unbanMember(as(ADA), BOB));
    const restored = await getDoc(doc(as(BOB), 'users', BOB));
    strictEqual(restored.data().membership, 'active');
  });

  it('cannot approve a banned projection without deleting the ban atomically', async () => {
    await assertFails(
      updateMember(as(ADA), BOB, { membership: 'active' }),
    );
  });

  it('an admin atomically erases a banned member without restoring access first', async () => {
    await assertSucceeds(eraseMember(as(ADA), BOB));

    const released = await getDoc(doc(as(BOB), 'users', BOB));
    strictEqual(released.data().companyId, '');
    strictEqual(released.data().role, 'user');
    strictEqual(released.data().membership, 'active');

    const oldBan = await getDoc(
      doc(as(ADA), 'companies', ACME, 'bans', BOB),
    );
    strictEqual(oldBan.exists(), false);
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

  it('an admin can approve them, a moderator cannot', async () => {
    await assertFails(
      updateDoc(doc(as(MOLLY), 'users', BOB), { membership: 'active' }),
    );
    await assertSucceeds(
      updateMember(as(ADA), BOB, { membership: 'active' }),
    );
  });
});

describe('the join policy is admin-only', () => {
  it('an admin may set it', async () => {
    const db = as(ADA);
    const batch = writeBatch(db);
    batch.update(doc(db, 'companies', ACME), { joinPolicy: 'approval' });
    batch.update(doc(db, 'companyDirectory', ACME), {
      joinPolicy: 'approval',
    });
    await assertSucceeds(batch.commit());
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
    const bobVoteId = `${BOB}-${slot.start}-${slot.end}`;
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
          `${BOB}-${slot.start}-${slot.end}`,
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

  it('only the owner may schedule it', async () => {
    // Ada is an admin and still may not: running a company and ending it are
    // different powers.
    await assertFails(
      updateDoc(doc(as(ADA), 'companies', ACME), {
        deletionScheduledFor: future,
        deletionRequestedBy: ADA,
      }),
    );
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'companies', ACME), {
        deletionScheduledFor: future,
        deletionRequestedBy: ALICE,
      }),
    );
  });

  it('the owner may call it off', async () => {
    await schedule(future);
    await assertSucceeds(
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
