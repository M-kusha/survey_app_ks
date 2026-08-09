import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';

/**
 * Who gets told, and how.
 *
 * Everything in here talks to devices by token rather than by topic. Topics are
 * simpler, but membership of a company changes — people are removed, banned and
 * approved — and a topic subscription made on a device outlives all of that. A
 * token list on the user document is the same list the rest of the app already
 * reasons about, so somebody who leaves a company stops hearing from it in the
 * same instant they lose access to it.
 */

export type Audience = {
  /** Explicit recipients. */
  userIds: string[];
};

/** Tokens are stored per user; one person can have a phone, a tablet and a web tab. */
async function tokensFor(userIds: string[]): Promise<Map<string, string[]>> {
  const db = getFirestore();
  const result = new Map<string, string[]>();

  // `getAll` rather than a loop of gets: this runs for every member of a
  // company, and a survey announcement should not cost one round trip each.
  const unique = [...new Set(userIds)].filter((id) => id);
  if (unique.length === 0) return result;

  const refs = unique.map((id) => db.collection('users').doc(id));
  const docs = await db.getAll(...refs);

  for (const doc of docs) {
    const tokens = (doc.get('fcmTokens') as string[] | undefined) ?? [];
    if (tokens.length > 0) result.set(doc.id, tokens);
  }

  return result;
}

/**
 * Sends one notification to a set of people, and prunes tokens that are dead.
 *
 * Pruning matters more than it sounds. Tokens rot — an app is uninstalled, a
 * browser's storage is cleared — and a list that only ever grows means every
 * future send carries a tail of failures that slowly becomes the majority of
 * the work.
 */
export async function notify(
  audience: Audience,
  message: { title: string; body: string; data?: Record<string, string> },
): Promise<void> {
  const byUser = await tokensFor(audience.userIds);
  if (byUser.size === 0) return;

  const flat: { userId: string; token: string }[] = [];
  for (const [userId, tokens] of byUser) {
    for (const token of tokens) flat.push({ userId, token });
  }

  const response = await getMessaging().sendEachForMulticast({
    tokens: flat.map((entry) => entry.token),
    notification: { title: message.title, body: message.body },
    data: message.data ?? {},
    android: { priority: 'high', notification: { channelId: 'echomeet' } },
    apns: { payload: { aps: { sound: 'default' } } },
    webpush: { headers: { Urgency: 'high' } },
  });

  const db = getFirestore();
  const dead = new Map<string, string[]>();

  response.responses.forEach((result, index) => {
    if (result.success) return;

    const code = result.error?.code ?? '';
    // Only these two mean "this token will never work again". A transient
    // failure must not cost somebody their registration.
    const permanent =
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token';

    if (!permanent) return;

    const { userId, token } = flat[index];
    dead.set(userId, [...(dead.get(userId) ?? []), token]);
  });

  await Promise.all(
    [...dead].map(([userId, tokens]) =>
      db
        .collection('users')
        .doc(userId)
        .update({ fcmTokens: FieldValue.arrayRemove(...tokens) })
        .catch(() => undefined),
    ),
  );

  logger.info('notified', {
    recipients: byUser.size,
    sent: response.successCount,
    failed: response.failureCount,
    pruned: dead.size,
  });
}

/** Everyone entitled to a company's content right now. */
export async function activeMemberIds(companyId: string): Promise<string[]> {
  const db = getFirestore();

  const [members, bans] = await Promise.all([
    db.collection('users').where('companyId', '==', companyId).get(),
    db.collection('companies').doc(companyId).collection('bans').get(),
  ]);

  const banned = new Set(bans.docs.map((doc) => doc.id));

  return members.docs
    .filter((doc) => !banned.has(doc.id))
    // Absent reads as active, matching the security rules and the client.
    .filter((doc) => (doc.get('membership') ?? 'active') === 'active')
    .map((doc) => doc.id);
}

/** The people who can act on approvals — admins and the owner, never moderators. */
export async function companyAdminIds(companyId: string): Promise<string[]> {
  const db = getFirestore();

  const members = await db
    .collection('users')
    .where('companyId', '==', companyId)
    .where('role', 'in', ['admin', 'superadmin'])
    .get();

  return members.docs.map((doc) => doc.id);
}
