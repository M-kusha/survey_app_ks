#!/usr/bin/env node
'use strict';

const path = require('path');
const { createRequire } = require('module');

function admin(module) {
  try {
    return require(module);
  } catch (error) {
    if (error.code !== 'MODULE_NOT_FOUND') throw error;
    const fromFunctions = createRequire(
      path.join(__dirname, '..', 'functions', 'package.json'),
    );
    return fromFunctions(module);
  }
}

const { initializeApp, applicationDefault, cert } = admin('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = admin('firebase-admin/firestore');

const PREFIX = 'seed-demo-';
const PEOPLE_PREFIX = 'seed-demo-person-';
const PROJECT_ID = 'echomeet-app';
const DRY_RUN = process.argv.includes('--dry-run');
const HEADCOUNT = 40;

function credential() {
  const key = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  return key ? cert(require(key)) : applicationDefault();
}

let cached;
function firestore() {
  if (!cached) {
    initializeApp({ credential: credential(), projectId: PROJECT_ID });
    cached = getFirestore();
  }
  return cached;
}

const NAMES = [
  'Arta Krasniqi', 'Lukas Brandt', 'Emily Hartley', 'Blerim Gashi',
  'Sophie Weber', 'James Okonkwo', 'Drilon Berisha', 'Hannah Vogel',
  'Oliver Bennett', 'Rina Hoxha', 'Maximilian Schuster', 'Chloe Bennett',
  'Endrit Morina', 'Lena Fischer', 'Thomas Ashcroft', 'Vlora Rexhepi',
  'Jonas Keller', 'Grace Whitfield', 'Arben Shala', 'Marie Hoffmann',
  'Daniel Whitaker', 'Teuta Lleshi', 'Felix Wagner', 'Amelia Croft',
  'Granit Zeqiri', 'Johanna Richter', 'Samuel Hargrove', 'Fatlinda Bytyqi',
  'Sebastian Neumann', 'Isabelle Marsh', 'Leotrim Ismajli', 'Clara Baumann',
  'Nathan Ellery', 'Donjeta Kelmendi', 'Moritz Lehmann', 'Ruby Callaghan',
  'Agon Dervishi', 'Katharina Bauer', 'Harriet Lowe', 'Valon Sylejmani',
];

const ROLES = ['user', 'user', 'user', 'user', 'user', 'user', 'moderator'];

function seededRandom(seed) {
  let state = seed >>> 0;
  return () => {
    state = (state * 1664525 + 1013904223) >>> 0;
    return state / 4294967296;
  };
}

const TEXT_REPLIES = [
  'More natural light would help a lot.',
  'Fewer status meetings, more written updates.',
  'The setup guide is out of date in a few places.',
  'A quiet room that is actually quiet.',
  'Better chairs. That is the whole answer.',
  'Clearer ownership when something breaks.',
  'I would keep the retro and drop the rest.',
  'Give people a real day for learning.',
  'Onboarding needs a checklist, not a tour.',
  'Nothing major. It mostly works.',
  'Standing desks for anyone who wants one.',
  'Document the deployment steps properly.',
];

function personId(index) {
  return `${PEOPLE_PREFIX}${String(index + 1).padStart(2, '0')}`;
}

function buildPeople(companyId) {
  return NAMES.slice(0, HEADCOUNT).map((fullName, index) => ({
    uid: personId(index),
    fullName,
    role: ROLES[index % ROLES.length],
    companyId,
  }));
}

function answerFor(question, random, questionIndex) {
  const [type, , options, correct] = question;

  if (type === 'Text') {
    return [TEXT_REPLIES[Math.floor(random() * TEXT_REPLIES.length)]];
  }

  const count = options.length;

  if (type === 'Single') {
    if (Number.isInteger(correct)) {
      return random() < 0.68 ? [correct] : [Math.floor(random() * count)];
    }
    return [Math.floor(random() * count)];
  }

  if (Array.isArray(correct)) {
    if (random() < 0.55) return [...correct];
    const chosen = new Set(correct);
    if (random() < 0.5 && chosen.size > 1) {
      chosen.delete([...chosen][0]);
    } else {
      const extra = Math.floor(random() * count);
      if (!chosen.has(extra)) chosen.add(extra);
    }
    return [...chosen].sort((a, b) => a - b);
  }

  const picks = new Set();
  const wanted = 1 + Math.floor(random() * Math.min(3, count));
  while (picks.size < wanted) picks.add(Math.floor(random() * count));
  return [...picks].sort((a, b) => a - b);
}

async function loadSeeded(collection) {
  const docs = await firestore().collection(collection).get();
  return docs.docs.filter((doc) => doc.id.startsWith(PREFIX) && !doc.id.startsWith(PEOPLE_PREFIX));
}

async function main() {
  const args = process.argv.slice(2).filter((value) => !value.startsWith('--'));
  const wanted = args[0];

  const companies = await firestore().collection('companies').get();
  const named = (doc) => String(doc.data().name ?? '').trim();
  const match = wanted
    ? companies.docs.find(
        (doc) => doc.id === wanted || named(doc).toLowerCase() === wanted.toLowerCase(),
      )
    : companies.docs.length === 1
      ? companies.docs[0]
      : undefined;
  if (!match) throw new Error('Name the company: node tool/seed_demo_people.js "KosovaSoft"');

  const companyId = match.id;
  console.log(`Target company: "${named(match)}" (${companyId})`);

  const surveys = await loadSeeded('surveys');
  const appointments = await loadSeeded('appointments');
  const quizzes = surveys.filter((doc) => doc.data().surveyType === 1);
  const plain = surveys.filter((doc) => doc.data().surveyType !== 1);
  console.log(`Found ${plain.length} surveys, ${quizzes.length} quizzes, ${appointments.length} meetings`);

  const people = buildPeople(companyId);
  console.log(`People: ${people.length}`);

  const missingKeys = [];
  for (const survey of surveys) {
    const key = await firestore().collection('surveyAnswerKeys').doc(survey.id).get();
    if (!key.exists) missingKeys.push(survey.id);
  }
  if (missingKeys.length) {
    console.log(`Answer keys to backfill: ${missingKeys.length}`);
  }

  if (DRY_RUN) {
    console.log('');
    console.log('DRY RUN - nothing written.');
    console.log(`Would create ${people.length} directory entries and profiles.`);
    console.log(`Would answer ${surveys.length} surveys/quizzes and vote on ${appointments.length} meetings.`);
    console.log('Sample people:');
    for (const person of people.slice(0, 6)) {
      console.log(`  ${person.fullName} (${person.role})`);
    }
    return;
  }

  const now = Timestamp.now();
  let batch = firestore().batch();
  let queued = 0;
  const flush = async (force = false) => {
    if (queued === 0 || (!force && queued < 300)) return;
    await batch.commit();
    batch = firestore().batch();
    queued = 0;
  };
  const write = async (ref, data) => {
    batch.set(ref, data);
    queued += 1;
    await flush();
  };

  for (const surveyId of missingKeys) {
    const survey = surveys.find((doc) => doc.id === surveyId);
    await write(firestore().collection('surveyAnswerKeys').doc(surveyId), {
      schemaVersion: 1,
      surveyId,
      companyId,
      questionKeys: survey.data().questions.map((question) => ({ type: question.type })),
    });
  }

  for (const person of people) {
    await write(firestore().collection('users').doc(person.uid), {
      membership: 'active',
      fullName: person.fullName,
      birthdate: '',
      email: `${person.uid}@example.invalid`,
      role: person.role,
      createdAt: now,
      companyId,
      companyName: named(match),
    });
    await write(firestore().collection('memberDirectory').doc(person.uid), {
      fullName: person.fullName,
      companyId,
      role: person.role,
      membership: 'active',
    });
  }

  let responses = 0;
  for (const [position, survey] of surveys.entries()) {
    const data = survey.data();
    const questions = data.questions ?? [];
    const random = seededRandom(1000 + position * 37);
    const rate = 0.35 + random() * 0.55;

    const keyDoc = await firestore().collection('surveyAnswerKeys').doc(survey.id).get();
    const questionKeys = keyDoc.exists ? keyDoc.get('questionKeys') ?? [] : [];

    const existing = await survey.ref.collection('participants').get();
    for (const doc of existing.docs) {
      if (!doc.id.startsWith(PEOPLE_PREFIX)) continue;
      batch.delete(doc.ref);
      queued += 1;
      await flush();
    }
    await flush(true);

    for (const [personIndex, person] of people.entries()) {
      if (random() > rate) continue;

      const answers = {};
      questions.forEach((question, index) => {
        const key = questionKeys[index] ?? {};
        const correct = question.type === 'Multiple' ? key.correctAnswers : key.correctAnswer;
        const shaped = [question.type, question.question, question.options, correct];
        answers[`Q${index}`] = answerFor(shaped, random, index);
      });

      await write(
        firestore().collection('surveys').doc(survey.id).collection('participants').doc(person.uid),
        {
          userId: person.uid,
          name: person.fullName,
          answers,
          score: 0.0,
          submittedAt: Timestamp.fromMillis(
            now.toMillis() - Math.floor(random() * 6 * 24 * 60 * 60 * 1000),
          ),
          participantSubmitted: true,
          imageProfile: '',
          profileImageRevision: 0,
          textAnswersReviewed: {},
          totalCorrectAnswers: 0,
          gradedQuestionCount: 0,
          gradingStatus: 'processing',
        },
      );
      responses += 1;
      void personIndex;
    }
  }

  let votes = 0;
  for (const [position, appointment] of appointments.entries()) {
    const data = appointment.data();
    const slots = data.slots ?? [];
    const random = seededRandom(5000 + position * 53);
    const rate = 0.4 + random() * 0.5;
    const voters = [];

    const existingVotes = await appointment.ref.collection('participants').get();
    for (const doc of existingVotes.docs) {
      if (!doc.id.startsWith(PEOPLE_PREFIX)) continue;
      batch.delete(doc.ref);
      queued += 1;
      await flush();
    }
    await flush(true);

    for (const person of people) {
      if (random() > rate) continue;
      voters.push(person.uid);

      for (const slot of slots) {
        const roll = random();
        if (roll > 0.75) continue;
        const status = roll < 0.5 ? 'joined' : roll < 0.65 ? 'maybe' : 'declined';
        await write(
          firestore()
            .collection('appointments')
            .doc(appointment.id)
            .collection('participants')
            .doc(`${person.uid}-${slot.slotId}`),
          {
            userId: person.uid,
            userName: person.fullName,
            slotId: slot.slotId,
            status,
            participated: true,
          },
        );
        votes += 1;
      }
    }

    if (voters.length) {
      batch.update(firestore().collection('appointments').doc(appointment.id), {
        participantUserIds: FieldValue.arrayUnion(...voters),
      });
      queued += 1;
      await flush();
    }
  }

  await flush(true);
  console.log('');
  console.log(`Backfilled ${missingKeys.length} answer keys.`);
  console.log(`Created ${people.length} people, ${responses} responses, ${votes} slot votes.`);
  console.log(`Scores are graded by the server trigger; give it a minute to settle.`);
}

async function clean() {
  let removed = 0;
  for (const collection of ['users', 'memberDirectory']) {
    const docs = await firestore().collection(collection).get();
    for (const doc of docs.docs.filter((entry) => entry.id.startsWith(PEOPLE_PREFIX))) {
      await doc.ref.delete();
      removed += 1;
    }
  }
  for (const collection of ['surveys', 'appointments']) {
    const parents = await firestore().collection(collection).get();
    for (const parent of parents.docs.filter((doc) => doc.id.startsWith(PREFIX))) {
      const children = await parent.ref.collection('participants').get();
      for (const child of children.docs) {
        if (child.id.startsWith(PEOPLE_PREFIX)) {
          await child.ref.delete();
          removed += 1;
        }
      }
    }
  }
  console.log(`Removed ${removed} seeded people and their answers.`);
}

(process.argv.includes('--clean') ? clean() : main()).catch((error) => {
  console.error(String(error.message ?? error));
  process.exit(1);
});
