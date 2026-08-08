import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

// Two companies and three people, so every "can A see B's data" question has a
// concrete answer.
const ACME = 'company-acme';
const RIVAL = 'company-rival';

const ALICE = 'alice'; // superadmin at Acme
const BOB = 'bob'; //     ordinary user at Acme
const CAROL = 'carol'; //  ordinary user at Rival — the outsider
const DAVE = 'dave'; //    not registered yet

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
      title: 'Standup', companyId: ACME,
    });
  });
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();
const anon = () => testEnv.unauthenticatedContext().firestore();

describe('deny by default', () => {
  it('an unauthenticated client can read nothing', async () => {
    await assertFails(getDoc(doc(anon(), 'users', BOB)));
    await assertFails(getDoc(doc(anon(), 'surveys', 'acme-survey')));
    await assertFails(getDoc(doc(anon(), 'companies', ACME)));
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
