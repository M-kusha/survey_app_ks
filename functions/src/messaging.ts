import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';

export type Audience = {
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

export type AuthUserLookup = (
  userIds: string[],
) => Promise<{ uid: string; emailVerified: boolean; disabled: boolean }[]>;

async function lookupAuthUsers(userIds: string[]) {
  const result = await getAuth().getUsers(userIds.map((uid) => ({ uid })));
  return result.users;
}

export async function verifiedEnabledAuthIds(
  userIds: string[],
  lookup: AuthUserLookup = lookupAuthUsers,
): Promise<Set<string>> {
  const candidates = [...new Set(userIds)].filter(
    (id) => typeof id === 'string' && id.length > 0 && id.length <= 128,
  );
  const allowed = new Set<string>();

  for (let start = 0; start < candidates.length; start += 100) {
    const chunk = candidates.slice(start, start + 100);
    try {
      const users = await lookup(chunk);
      for (const user of users) {
        if (user.emailVerified && !user.disabled) allowed.add(user.uid);
      }
    } catch {
      throw new Error('notification-audience-auth-unavailable');
    }
  }

  return allowed;
}

async function tokensFor(userIds: string[]): Promise<Map<string, UserDelivery>> {
  const db = getFirestore();
  const result = new Map<string, UserDelivery>();

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
    .filter((doc) => (doc.get('membership') ?? 'active') === 'active')
    .map((doc) => doc.id);

  const authorized = await verifiedEnabledAuthIds(eligible);
  return eligible.filter((id) => authorized.has(id));
}

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
