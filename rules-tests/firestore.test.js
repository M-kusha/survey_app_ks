import { strictEqual } from 'node:assert';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { deleteDoc, deleteField, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

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

    await setDoc(doc(db, 'users', ALICE), {
      fullName: 'Alice', role: 'superadmin', companyId: ACME,
    });
    await setDoc(doc(db, 'users', BOB), {
      fullName: 'Bob', role: 'user', companyId: ACME,
    });
    await setDoc(doc(db, 'users', CAROL), {
      fullName: 'Carol', role: 'user', companyId: RIVAL,
    });
    await setDoc(doc(db, 'users', MOLLY), {
      fullName: 'Molly', role: 'moderator', companyId: ACME,
    });
    await setDoc(doc(db, 'users', ADA), {
      fullName: 'Ada', role: 'admin', companyId: ACME,
    });

    await setDoc(doc(db, 'surveys', 'acme-survey'), {
      surveyName: 'Q1 review', companyId: ACME,
    });
    await setDoc(doc(db, 'surveys', 'rival-survey'), {
      surveyName: 'Secret', companyId: RIVAL,
    });
    await setDoc(doc(db, 'surveys', 'acme-survey', 'participants', BOB), {
      userId: BOB, name: 'Bob', score: 40, totalCorrectAnswers: 2,
    });

    await setDoc(doc(db, 'appointments', 'acme-standup'), {
      title: 'Standup', companyId: ACME, participantUserIds: [ALICE],
    });
  });
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();
const anon = () => testEnv.unauthenticatedContext().firestore();

describe('deny by default', () => {
  it('an unauthenticated client can read nothing', async () => {
    await assertFails(getDoc(doc(anon(), 'users', BOB)));
    await assertFails(getDoc(doc(anon(), 'surveys', 'acme-survey')));
    await assertFails(getDoc(doc(anon(), 'appointments', 'acme-standup')));
  });

  // The one deliberate exception. Registration lists companies so a new user
  // can pick one to join, and that screen runs before the account exists — so
  // requiring auth here would silently return an empty list and make joining
  // an existing company impossible.
  it('companies are the deliberate exception, readable before sign-up', async () => {
    await assertSucceeds(getDoc(doc(anon(), 'companies', ACME)));
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
  it('a colleague is readable', async () => {
    await assertSucceeds(getDoc(doc(as(BOB), 'users', ALICE)));
  });

  it('someone at another company is not', async () => {
    await assertFails(getDoc(doc(as(BOB), 'users', CAROL)));
    await assertFails(getDoc(doc(as(CAROL), 'users', BOB)));
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

describe('roles cannot be self-awarded', () => {
  it('a user cannot promote themselves', async () => {
    await assertFails(updateDoc(doc(as(BOB), 'users', BOB), { role: 'superadmin' }));
    await assertFails(updateDoc(doc(as(BOB), 'users', BOB), { role: 'admin' }));
  });

  it('a user can still edit their own harmless fields', async () => {
    await assertSucceeds(
      updateDoc(doc(as(BOB), 'users', BOB), { fullName: 'Bobby' }),
    );
  });

  it('a user cannot move themselves to another company', async () => {
    await assertFails(updateDoc(doc(as(BOB), 'users', BOB), { companyId: RIVAL }));
  });

  it('an admin can change a colleague\'s role', async () => {
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'users', BOB), { role: 'moderator' }),
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
      await setDoc(doc(ctx.firestore(), 'users', DAVE), {
        fullName: 'Dave', role: 'admin', companyId: ACME,
      });
    });

    await assertFails(
      updateDoc(doc(as(DAVE), 'users', DAVE), { role: 'superadmin' }),
    );
  });

  // `isAdmin()` counts moderators, which made this the shortest path from the
  // lowest elevated role to the highest.
  it('a moderator cannot promote themselves', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', DAVE), {
        fullName: 'Dave', role: 'moderator', companyId: ACME,
      });
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
      await setDoc(doc(ctx.firestore(), 'users', DAVE), {
        fullName: 'Dave', role: 'admin', companyId: ACME,
      });
    });

    await assertSucceeds(
      updateDoc(doc(as(DAVE), 'users', DAVE), { fullName: 'Davey' }),
    );
  });
});

describe('sign-up', () => {
  it('a new user joining an existing company registers as a plain user', async () => {
    await assertSucceeds(
      setDoc(doc(as(DAVE), 'users', DAVE), {
        fullName: 'Dave', role: 'user', companyId: ACME,
      }),
    );
  });

  // The escalation this rule exists to stop: pick any company at sign-up and
  // hand yourself admin over it.
  it('a new user cannot join an existing company as superadmin', async () => {
    await assertFails(
      setDoc(doc(as(DAVE), 'users', DAVE), {
        fullName: 'Dave', role: 'superadmin', companyId: ACME,
      }),
    );
  });

  it('but may be superadmin of a company they just created', async () => {
    const db = as(DAVE);
    await assertSucceeds(
      setDoc(doc(db, 'companies', 'company-dave'), {
        name: 'Dave Ltd', createdBy: DAVE,
      }),
    );
    await assertSucceeds(
      setDoc(doc(db, 'users', DAVE), {
        fullName: 'Dave', role: 'superadmin', companyId: 'company-dave',
      }),
    );
  });

  it('a company cannot be created in someone else\'s name', async () => {
    await assertFails(
      setDoc(doc(as(DAVE), 'companies', 'company-fake'), {
        name: 'Fake', createdBy: ALICE,
      }),
    );
  });

  it('nobody can write a profile under another uid', async () => {
    await assertFails(
      setDoc(doc(as(DAVE), 'users', BOB), {
        fullName: 'Not Bob', role: 'user', companyId: ACME,
      }),
    );
  });
});

describe('survey submissions', () => {
  it('a participant submits under their own id', async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), 'surveys', 'acme-survey', 'participants', ALICE), {
        userId: ALICE, name: 'Alice', score: 100,
      }),
    );
  });

  it('a participant cannot submit as somebody else', async () => {
    await assertFails(
      setDoc(doc(as(BOB), 'surveys', 'acme-survey', 'participants', ALICE), {
        userId: ALICE, name: 'Alice', score: 100,
      }),
    );
  });

  it('an outsider cannot submit to another company\'s survey', async () => {
    await assertFails(
      setDoc(doc(as(CAROL), 'surveys', 'acme-survey', 'participants', CAROL), {
        userId: CAROL, name: 'Carol', score: 100,
      }),
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

  it('an admin can, which is how free-text review works', async () => {
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'surveys', 'acme-survey', 'participants', BOB), {
        score: 100, totalCorrectAnswers: 5,
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
  it('an admin creates surveys for their own company', async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), 'surveys', 'new-survey'), {
        surveyName: 'New', companyId: ACME,
      }),
    );
  });

  it('an ordinary user cannot create one', async () => {
    await assertFails(
      setDoc(doc(as(BOB), 'surveys', 'new-survey'), {
        surveyName: 'New', companyId: ACME,
      }),
    );
  });

  it('an admin cannot create one for another company', async () => {
    await assertFails(
      setDoc(doc(as(ALICE), 'surveys', 'new-survey'), {
        surveyName: 'New', companyId: RIVAL,
      }),
    );
  });

  it('a survey cannot be moved between companies', async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), 'surveys', 'acme-survey'), { companyId: RIVAL }),
    );
  });

  it('an ordinary user cannot delete a survey', async () => {
    await assertFails(deleteDoc(doc(as(BOB), 'surveys', 'acme-survey')));
    await assertSucceeds(deleteDoc(doc(as(ALICE), 'surveys', 'acme-survey')));
  });
});

// Voting writes to the appointment document itself, because the set of people
// who have answered lives there. That means relaxing the admin-only update
// rule, and these pin down exactly how far.
describe('voting on an appointment', () => {
  const appt = () => 'acme-standup';

  it('a colleague may add themselves to the voter list', async () => {
    await assertSucceeds(
      updateDoc(doc(as(BOB), 'appointments', appt()), {
        participantUserIds: [ALICE, BOB],
      }),
    );
  });

  it('voting twice is a no-op rather than a second vote', async () => {
    const ref = doc(as(BOB), 'appointments', appt());
    await assertSucceeds(updateDoc(ref, { participantUserIds: [ALICE, BOB] }));
    // arrayUnion semantics: writing the same set again changes nothing, which
    // is what stops the count climbing every time somebody reopens the page.
    await assertSucceeds(updateDoc(ref, { participantUserIds: [ALICE, BOB] }));

    const stored = await getDoc(doc(as(ALICE), 'appointments', appt()));
    strictEqual(stored.data().participantUserIds.length, 2);
  });

  it('nobody can vote on somebody else\'s behalf', async () => {
    await assertFails(
      updateDoc(doc(as(BOB), 'appointments', appt()), {
        participantUserIds: [ALICE, CAROL],
      }),
    );
  });

  it('a voter cannot remove anybody else', async () => {
    await assertFails(
      updateDoc(doc(as(BOB), 'appointments', appt()), {
        participantUserIds: [BOB],
      }),
    );
  });

  it('a voter cannot smuggle another field through with their vote', async () => {
    await assertFails(
      updateDoc(doc(as(BOB), 'appointments', appt()), {
        participantUserIds: [ALICE, BOB],
        title: 'Renamed by a non-admin',
      }),
    );
  });

  it('an outsider cannot vote at all', async () => {
    await assertFails(
      updateDoc(doc(as(CAROL), 'appointments', appt()), {
        participantUserIds: [ALICE, CAROL],
      }),
    );
  });

  it('an admin can still edit the appointment properly', async () => {
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'appointments', appt()), { title: 'Renamed' }),
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
});

// The split the user asked for: a moderator runs the content, an admin runs the
// people. Enforced here rather than only in the UI, because the UI is a
// suggestion and this is the rule.
describe('moderators run content, not people', () => {
  it('a moderator may write surveys and appointments', async () => {
    await assertSucceeds(
      setDoc(doc(as(MOLLY), 'surveys', 'new-survey'), {
        surveyName: 'By a moderator', companyId: ACME,
      }),
    );
    await assertSucceeds(
      setDoc(doc(as(MOLLY), 'appointments', 'new-meeting'), {
        title: 'By a moderator', companyId: ACME,
      }),
    );
  });

  it('a moderator may mark a written answer', async () => {
    await assertSucceeds(
      updateDoc(doc(as(MOLLY), 'surveys', 'acme-survey', 'participants', BOB), {
        score: 80, totalCorrectAnswers: 4,
      }),
    );
  });

  it('a moderator may delete a survey or a meeting', async () => {
    await assertSucceeds(deleteDoc(doc(as(MOLLY), 'surveys', 'acme-survey')));
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
    await assertFails(updateDoc(doc(as(MOLLY), 'users', BOB), { banned: true }));
    await assertFails(
      updateDoc(doc(as(MOLLY), 'users', BOB), { companyId: '', role: 'user' }),
    );
  });

  it('an admin may do all three', async () => {
    await assertSucceeds(updateDoc(doc(as(ADA), 'users', BOB), { role: 'moderator' }));
    await assertSucceeds(updateDoc(doc(as(ADA), 'users', BOB), { banned: true }));
    await assertSucceeds(
      updateDoc(doc(as(ADA), 'users', BOB), { companyId: '', role: 'user' }),
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
      await setDoc(doc(ctx.firestore(), 'companies', ACME, 'bans', BOB), {
        name: 'Bob', bannedAt: new Date(),
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
      setDoc(doc(as(BOB), 'surveys', 'acme-survey', 'participants', BOB), {
        userId: BOB, name: 'Bob', score: 100,
      }),
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
      updateDoc(doc(as(BOB), 'users', BOB), { companyId: '', role: 'user' }),
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
    await assertFails(deleteDoc(doc(as(MOLLY), 'companies', ACME, 'bans', BOB)));
    await assertSucceeds(deleteDoc(doc(as(ADA), 'companies', ACME, 'bans', BOB)));
  });

  it('an admin cannot ban themselves out of their own company', async () => {
    await assertFails(
      setDoc(doc(as(ADA), 'companies', ACME, 'bans', ADA), { name: 'Ada' }),
    );
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
      await setDoc(doc(db, 'companies', RIVAL), {
        name: 'Rival', createdBy: CAROL, joinPolicy: 'approval',
      });
    });
  });

  it('an open company lets you straight in', async () => {
    // Acme has no joinPolicy at all, which must read as open so companies made
    // before the setting existed keep working.
    await assertSucceeds(
      updateDoc(doc(as(BOB), 'users', BOB), {
        companyId: ACME, role: 'user', membership: 'active',
      }),
    );
  });

  it('a company requiring approval holds you pending', async () => {
    await assertSucceeds(
      updateDoc(doc(as(BOB), 'users', BOB), {
        companyId: RIVAL, role: 'user', membership: 'pending',
      }),
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
      await setDoc(doc(ctx.firestore(), 'users', BOB), {
        fullName: 'Bob', role: 'user', companyId: ACME, membership: 'pending',
      });
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
      updateDoc(doc(as(BOB), 'users', BOB), { fullName: 'Robert' }),
    );
    await assertSucceeds(
      updateDoc(doc(as(BOB), 'users', BOB), { companyId: '', role: 'user' }),
    );
  });

  it('an admin can approve them, a moderator cannot', async () => {
    await assertFails(
      updateDoc(doc(as(MOLLY), 'users', BOB), { membership: 'active' }),
    );
    await assertSucceeds(
      updateDoc(doc(as(ADA), 'users', BOB), { membership: 'active' }),
    );
  });
});

describe('the join policy is admin-only', () => {
  it('an admin may set it', async () => {
    await assertSucceeds(
      updateDoc(doc(as(ADA), 'companies', ACME), { joinPolicy: 'approval' }),
    );
  });

  it('a moderator may not', async () => {
    await assertFails(
      updateDoc(doc(as(MOLLY), 'companies', ACME), { joinPolicy: 'open' }),
    );
  });

  it('an ordinary member may not', async () => {
    await assertFails(
      updateDoc(doc(as(BOB), 'companies', ACME), { joinPolicy: 'open' }),
    );
  });
});

describe('closing a company', () => {
  const past = new Date(Date.now() - 60_000);
  const future = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

  const schedule = async (at) => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'companies', ACME), {
        name: 'Acme', createdBy: ALICE, deletionScheduledFor: at,
      });
    });
  };

  it('only the owner may schedule it', async () => {
    // Ada is an admin and still may not: running a company and ending it are
    // different powers.
    await assertFails(
      updateDoc(doc(as(ADA), 'companies', ACME), {
        deletionScheduledFor: future,
      }),
    );
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'companies', ACME), {
        deletionScheduledFor: future,
      }),
    );
  });

  it('the owner may call it off', async () => {
    await schedule(future);
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'companies', ACME), {
        deletionScheduledFor: deleteField(),
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

  it('once the time has passed, the owner may delete it', async () => {
    await schedule(past);
    await assertSucceeds(deleteDoc(doc(as(ALICE), 'companies', ACME)));
  });

  it('an admin still may not, even once due', async () => {
    await schedule(past);
    await assertFails(deleteDoc(doc(as(ADA), 'companies', ACME)));
  });

  it('the name is released only by whoever reserved it', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'companyNames', 'acme'), {
        companyId: ACME, createdBy: ALICE,
      });
    });

    await assertFails(deleteDoc(doc(as(BOB), 'companyNames', 'acme')));
    await assertSucceeds(deleteDoc(doc(as(ALICE), 'companyNames', 'acme')));
  });
});
