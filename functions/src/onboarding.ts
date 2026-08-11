import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import {
  companyNameSlug,
  writeCompanyCreatedActivity,
} from './company_privileges';

export { companyNameSlug } from './company_privileges';

const createCompanyIntent = 'createCompany';
const joinCompanyIntent = 'joinCompany';

type FinalizeOptions = {
  companyName?: unknown;
  companyId?: unknown;
};

export type OnboardingResult = {
  completed: true;
  companyId: string;
  membership: 'active' | 'pending';
};

function optionalString(value: unknown): string | undefined {
  return typeof value === 'string' ? value.trim() : undefined;
}

/**
 * Completes a private pending registration at the Admin SDK boundary.
 *
 * Both branches are transactions. A company, its canonical name lock, its
 * public listing and its owner projection either all appear together or not at
 * all. Joining derives approval state and bans from authoritative documents;
 * no client-supplied role or membership is accepted.
 */
export async function finalizePendingOnboarding(
  uid: string,
  options: FinalizeOptions = {},
): Promise<OnboardingResult> {
  const authUser = await getAuth().getUser(uid);
  if (!authUser.emailVerified || authUser.disabled) {
    throw new HttpsError('failed-precondition', 'email-not-verified');
  }

  const db = getFirestore();
  const profileRef = db.collection('users').doc(uid);
  const deletionLockRef = db.collection('accountDeletionLocks').doc(uid);

  return db.runTransaction(async (transaction) => {
    const [profileSnapshot, deletionLockSnapshot] = await transaction.getAll(
      profileRef,
      deletionLockRef,
    );
    if (deletionLockSnapshot.exists) {
      throw new HttpsError('failed-precondition', 'account-deletion-started');
    }
    if (!profileSnapshot.exists) {
      throw new HttpsError('failed-precondition', 'onboarding-profile-missing');
    }

    const profile = profileSnapshot.data() ?? {};
    const existingCompanyId = optionalString(profile.companyId) ?? '';
    const intent = optionalString(profile.pendingOnboardingType);

    // Network retries can reach the callable after its first transaction
    // committed. Treat the already-final state as success, not a new company.
    if (!intent) {
      if (existingCompanyId) {
        return {
          completed: true,
          companyId: existingCompanyId,
          membership: profile.membership === 'pending' ? 'pending' : 'active',
        };
      }
      throw new HttpsError('failed-precondition', 'onboarding-intent-missing');
    }
    if (existingCompanyId || profile.role !== 'user') {
      throw new HttpsError('failed-precondition', 'onboarding-profile-invalid');
    }

    const fullName = optionalString(profile.fullName);
    if (!fullName || fullName.length > 120) {
      throw new HttpsError('failed-precondition', 'onboarding-profile-invalid');
    }

    if (intent === createCompanyIntent) {
      const name =
        optionalString(options.companyName) ??
        optionalString(profile.pendingCompanyName);
      if (!name || name.length > 120) {
        throw new HttpsError('invalid-argument', 'company-name-invalid');
      }
      const slug = companyNameSlug(name);
      if (!slug) {
        throw new HttpsError('invalid-argument', 'company-name-invalid');
      }

      const nameLockRef = db.collection('companyNames').doc(slug);
      const nameLock = await transaction.get(nameLockRef);
      if (nameLock.exists) {
        throw new HttpsError('already-exists', 'company-name-taken');
      }

      const companyRef = db.collection('companies').doc();
      const directoryRef = db.collection('companyDirectory').doc(companyRef.id);
      const memberRef = db.collection('memberDirectory').doc(uid);
      const activityId = db.collection('companies').doc().id;
      const timestamp = FieldValue.serverTimestamp();

      transaction.create(nameLockRef, {
        companyId: companyRef.id,
        createdBy: uid,
      });
      transaction.create(companyRef, {
        name,
        createdBy: uid,
        createdAt: timestamp,
        joinPolicy: 'open',
      });
      transaction.create(directoryRef, { name, joinPolicy: 'open' });
      transaction.create(memberRef, {
        fullName,
        companyId: companyRef.id,
        role: 'superadmin',
        membership: 'active',
      });
      transaction.update(profileRef, {
        companyId: companyRef.id,
        companyName: name,
        role: 'superadmin',
        membership: 'active',
        pendingOnboardingType: FieldValue.delete(),
        pendingCompanyName: FieldValue.delete(),
        pendingCompanyId: FieldValue.delete(),
      });
      writeCompanyCreatedActivity(
        {
          create: (path, data) => transaction.create(db.doc(path), data),
        },
        {
          id: activityId,
          companyId: companyRef.id,
          actorUid: uid,
          occurredAt: timestamp,
        },
      );

      return {
        completed: true,
        companyId: companyRef.id,
        membership: 'active',
      };
    }

    if (intent !== joinCompanyIntent) {
      throw new HttpsError('failed-precondition', 'onboarding-intent-invalid');
    }

    const companyId =
      optionalString(options.companyId) ?? optionalString(profile.pendingCompanyId);
    if (!companyId || companyId.length > 128) {
      throw new HttpsError('invalid-argument', 'company-unavailable');
    }

    const companyRef = db.collection('companies').doc(companyId);
    const banRef = companyRef.collection('bans').doc(uid);
    const [companySnapshot, banSnapshot] = await transaction.getAll(
      companyRef,
      banRef,
    );
    const company = companySnapshot.data();
    if (!companySnapshot.exists || !company) {
      throw new HttpsError('not-found', 'company-unavailable');
    }
    if ('deletionScheduledFor' in company) {
      throw new HttpsError('failed-precondition', 'company-closing');
    }
    if (banSnapshot.exists) {
      throw new HttpsError('permission-denied', 'company-banned');
    }

    const membership = company.joinPolicy === 'approval' ? 'pending' : 'active';
    transaction.create(db.collection('memberDirectory').doc(uid), {
      fullName,
      companyId,
      role: 'user',
      membership,
    });
    transaction.update(profileRef, {
      companyId,
      role: 'user',
      membership,
      companyName: FieldValue.delete(),
      pendingOnboardingType: FieldValue.delete(),
      pendingCompanyName: FieldValue.delete(),
      pendingCompanyId: FieldValue.delete(),
    });

    return { completed: true, companyId, membership };
  });
}
