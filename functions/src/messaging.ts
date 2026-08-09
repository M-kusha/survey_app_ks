import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
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

export type NotificationLocale = 'en' | 'de' | 'sq';

export type NotificationMessage = {
  title: string;
  body: string;
  data?: Record<string, string>;
};

type LocalizedNotification =
  | NotificationMessage
  | ((locale: NotificationLocale) => NotificationMessage);

type UserDelivery = {
  tokens: string[];
  locale: NotificationLocale;
};

/**
 * Keeps notification recipients aligned with the Firebase Auth security
 * boundary. A Firestore profile can outlive its Auth account, and a newly
 * registered profile exists before its email address has been verified.
 */
async function verifiedEnabledAuthIds(userIds: string[]): Promise<Set<string>> {
  const candidates = [...new Set(userIds)].filter(
    (id) => typeof id === 'string' && id.length > 0 && id.length <= 128,
  );
  const allowed = new Set<string>();

  // Admin Auth accepts at most 100 identifiers per getUsers call. Run the
  // chunks sequentially to keep large-company notification bursts bounded.
  for (let start = 0; start < candidates.length; start += 100) {
    const chunk = candidates.slice(start, start + 100);
    try {
      const result = await getAuth().getUsers(chunk.map((uid) => ({ uid })));
      for (const user of result.users) {
        if (user.emailVerified && !user.disabled) allowed.add(user.uid);
      }
    } catch (error) {
      // Fail closed for this whole chunk: an Auth outage or malformed legacy
      // account must delay delivery, never leak company content.
      logger.error('notification audience Auth lookup failed; batch skipped', {
        batchSize: chunk.length,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  return allowed;
}

/** Tokens are stored per user; one person can have a phone, a tablet and a web tab. */
async function tokensFor(userIds: string[]): Promise<Map<string, UserDelivery>> {
  const db = getFirestore();
  const result = new Map<string, UserDelivery>();

  // `getAll` rather than a loop of gets: this runs for every member of a
  // company, and a survey announcement should not cost one round trip each.
  const unique = [...new Set(userIds)].filter((id) => id);
  if (unique.length === 0) return result;

  const refs = unique.map((id) => db.collection('users').doc(id));
  const docs = await db.getAll(...refs);

  for (const doc of docs) {
    const rawTokens = doc.get('fcmTokens');
    const tokens = Array.isArray(rawTokens)
      ? [...new Set(rawTokens)].filter(
          (token): token is string =>
            typeof token === 'string' && token.length > 0 && token.length <= 4096,
        )
      : [];
    const rawLocale = doc.get('notificationLocale');
    const locale: NotificationLocale =
      rawLocale === 'de' || rawLocale === 'sq' ? rawLocale : 'en';
    if (tokens.length > 0) result.set(doc.id, { tokens, locale });
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
  message: LocalizedNotification,
): Promise<void> {
  const byUser = await tokensFor(audience.userIds);
  if (byUser.size === 0) return;

  const byLocale = new Map<
    NotificationLocale,
    { userId: string; token: string }[]
  >();
  for (const [userId, delivery] of byUser) {
    const entries = byLocale.get(delivery.locale) ?? [];
    for (const token of delivery.tokens) entries.push({ userId, token });
    byLocale.set(delivery.locale, entries);
  }

  const db = getFirestore();
  const dead = new Map<string, string[]>();
  let sent = 0;
  let failed = 0;

  // FCM caps a multicast request at 500 registration tokens. Chunking here
  // keeps one heavily multi-device company from failing the entire send.
  for (const [locale, flat] of byLocale) {
    const localized = typeof message === 'function' ? message(locale) : message;
    for (let start = 0; start < flat.length; start += 500) {
      const batch = flat.slice(start, start + 500);
      const response = await getMessaging().sendEachForMulticast({
        tokens: batch.map((entry) => entry.token),
        notification: { title: localized.title, body: localized.body },
        data: localized.data ?? {},
        android: { priority: 'high', notification: { channelId: 'echomeet' } },
        apns: { payload: { aps: { sound: 'default' } } },
        webpush: {
          headers: { Urgency: 'high' },
          fcmOptions: { link: 'https://echomeet-app.web.app/' },
        },
      });

      sent += response.successCount;
      failed += response.failureCount;

      response.responses.forEach((result, index) => {
        if (result.success) return;

        const code = result.error?.code ?? '';
        // Only these two mean "this token will never work again". A transient
        // failure must not cost somebody their registration.
        const permanent =
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token';

        if (!permanent) return;

        const { userId, token } = batch[index];
        dead.set(userId, [...(dead.get(userId) ?? []), token]);
      });
    }
  }

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
    sent,
    failed,
    pruned: dead.size,
  });
}

/** Everyone entitled to a company's content right now. */
export async function activeMemberIds(
  companyId: string,
  options: { includeClosing?: boolean } = {},
): Promise<string[]> {
  const db = getFirestore();

  const [company, members, bans] = await Promise.all([
    db.collection('companies').doc(companyId).get(),
    db.collection('users').where('companyId', '==', companyId).get(),
    db.collection('companies').doc(companyId).collection('bans').get(),
  ]);

  if (!company.exists) return [];

  const deletionAt = company.get('deletionScheduledFor') as
    | Timestamp
    | undefined;
  if (
    !options.includeClosing &&
    deletionAt instanceof Timestamp &&
    deletionAt.toMillis() <= Date.now()
  ) {
    return [];
  }

  const banned = new Set(bans.docs.map((doc) => doc.id));

  const eligible = members.docs
    .filter((doc) => !banned.has(doc.id))
    // Absent reads as active, matching the security rules and the client.
    .filter((doc) => (doc.get('membership') ?? 'active') === 'active')
    .map((doc) => doc.id);

  const authorized = await verifiedEnabledAuthIds(eligible);
  return eligible.filter((id) => authorized.has(id));
}

/** The people who can act on approvals — admins and the owner, never moderators. */
export async function companyAdminIds(companyId: string): Promise<string[]> {
  const db = getFirestore();

  const [activeIds, members] = await Promise.all([
    activeMemberIds(companyId),
    db
      .collection('users')
      .where('companyId', '==', companyId)
      .where('role', 'in', ['admin', 'superadmin'])
      .get(),
  ]);
  const active = new Set(activeIds);

  return members.docs.map((doc) => doc.id).filter((id) => active.has(id));
}
