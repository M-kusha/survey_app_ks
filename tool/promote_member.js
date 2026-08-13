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
const { getFirestore } = admin('firebase-admin/firestore');
const { getAuth } = admin('firebase-admin/auth');

const PROJECT_ID = 'echomeet-app';
const ROLES = ['user', 'moderator', 'admin', 'superadmin'];

function credential() {
  const key = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  return key ? cert(require(key)) : applicationDefault();
}

initializeApp({ credential: credential(), projectId: PROJECT_ID });
const db = getFirestore();

async function main() {
  const [email, role = 'superadmin', companyWanted] = process.argv
    .slice(2)
    .filter((value) => !value.startsWith('--'));

  if (!email || !ROLES.includes(role)) {
    throw new Error(
      [
        'Usage:',
        '  node tool/promote_member.js <email> [role] [company]',
        '',
        `  role: ${ROLES.join(' | ')} (default superadmin)`,
      ].join('\n'),
    );
  }

  const user = await getAuth().getUserByEmail(email).catch(() => null);
  if (!user) {
    throw new Error(
      `No account exists for ${email}. Register it in the app first, then run this.`,
    );
  }
  if (!user.emailVerified) {
    console.log(`Warning: ${email} has not verified its address yet.`);
  }

  const companies = await db.collection('companies').get();
  const named = (doc) => String(doc.data().name ?? '').trim();
  const company = companyWanted
    ? companies.docs.find(
        (doc) =>
          doc.id === companyWanted ||
          named(doc).toLowerCase() === companyWanted.toLowerCase(),
      )
    : companies.docs.length === 1
      ? companies.docs[0]
      : undefined;
  if (!company) {
    throw new Error(
      [
        'Name the company:',
        ...companies.docs.map((doc) => `  ${named(doc) || '(unnamed)'} -> ${doc.id}`),
      ].join('\n'),
    );
  }

  const profileRef = db.collection('users').doc(user.uid);
  const profile = await profileRef.get();
  if (!profile.exists) {
    throw new Error(
      `${email} has no profile document yet. Finish registration in the app first.`,
    );
  }

  const fullName = String(profile.get('fullName') ?? '').trim() || email;
  const batch = db.batch();

  batch.update(profileRef, {
    companyId: company.id,
    companyName: named(company),
    role,
    membership: 'active',
  });
  batch.set(db.collection('memberDirectory').doc(user.uid), {
    fullName,
    companyId: company.id,
    role,
    membership: 'active',
  });

  await batch.commit();
  console.log(`${fullName} <${email}> is now ${role} of "${named(company)}".`);
}

main().catch((error) => {
  console.error(String(error.message ?? error));
  process.exit(1);
});
