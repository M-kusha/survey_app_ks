import type { NotificationLocale, NotificationMessage } from './messaging';

function nameOr(
  locale: NotificationLocale,
  value: unknown,
  fallback: Record<NotificationLocale, string>,
): string {
  return typeof value === 'string' && value.trim().length > 0
    ? value.trim()
    : fallback[locale];
}

const surveyFallback = {
  en: 'A survey',
  de: 'Eine Umfrage',
  sq: 'Një anketë',
} as const;

const meetingFallback = {
  en: 'Your meeting',
  de: 'Ihr Termin',
  sq: 'Takimi juaj',
} as const;

export function joinRequestCopy(
  locale: NotificationLocale,
  fullName: unknown,
): NotificationMessage {
  const name = nameOr(locale, fullName, {
    en: 'A new member',
    de: 'Ein neues Mitglied',
    sq: 'Një anëtar i ri',
  });
  return {
    en: {
      title: 'Someone wants to join',
      body: `${name} is waiting for approval.`,
    },
    de: {
      title: 'Neue Beitrittsanfrage',
      body: `${name} wartet auf Freigabe.`,
    },
    sq: {
      title: 'Kërkesë e re për anëtarësim',
      body: `${name} po pret miratimin.`,
    },
  }[locale];
}

export function surveyCreatedCopy(
  locale: NotificationLocale,
  surveyName: unknown,
  isTest: boolean,
): NotificationMessage {
  const name = nameOr(locale, surveyName, surveyFallback);
  return {
    en: {
      title: isTest ? 'New test' : 'New survey',
      body: `${name} is open for responses.`,
    },
    de: {
      title: isTest ? 'Neuer Test' : 'Neue Umfrage',
      body: `${name} ist jetzt für Antworten geöffnet.`,
    },
    sq: {
      title: isTest ? 'Test i ri' : 'Anketë e re',
      body: `${name} është hapur për përgjigje.`,
    },
  }[locale];
}

export function appointmentCreatedCopy(
  locale: NotificationLocale,
  title: unknown,
): NotificationMessage {
  const name = nameOr(locale, title, meetingFallback);
  return {
    en: {
      title: 'New meeting to vote on',
      body: `${name} needs your availability.`,
    },
    de: {
      title: 'Neue Terminabstimmung',
      body: `${name} benötigt Ihre Verfügbarkeit.`,
    },
    sq: {
      title: 'Takim i ri për votim',
      body: `${name} ka nevojë për disponueshmërinë tuaj.`,
    },
  }[locale];
}

export function appointmentConfirmedCopy(
  locale: NotificationLocale,
  title: unknown,
  startUtc?: string,
): NotificationMessage {
  const name = nameOr(locale, title, meetingFallback);
  return {
    en: {
      title: 'Meeting time confirmed',
      body: startUtc
        ? `${name} — ${startUtc}`
        : `${name} has a confirmed time.`,
    },
    de: {
      title: 'Termin bestätigt',
      body: startUtc
        ? `${name} — ${startUtc}`
        : `${name} hat jetzt einen bestätigten Termin.`,
    },
    sq: {
      title: 'Orari i takimit u konfirmua',
      body: startUtc
        ? `${name} — ${startUtc}`
        : `${name} ka një orar të konfirmuar.`,
    },
  }[locale];
}

export function surveyReminderCopy(
  locale: NotificationLocale,
  surveyName: unknown,
): NotificationMessage {
  const name = nameOr(locale, surveyName, surveyFallback);
  return {
    en: {
      title: 'Closing tomorrow',
      body: `${name} closes in less than a day.`,
    },
    de: {
      title: 'Schließt morgen',
      body: `${name} schließt in weniger als einem Tag.`,
    },
    sq: {
      title: 'Mbyllet nesër',
      body: `${name} mbyllet në më pak se një ditë.`,
    },
  }[locale];
}

export function appointmentReminderCopy(
  locale: NotificationLocale,
  title: unknown,
): NotificationMessage {
  const name = nameOr(locale, title, meetingFallback);
  return {
    en: {
      title: 'Voting closes tomorrow',
      body: `${name} still needs your availability.`,
    },
    de: {
      title: 'Abstimmung schließt morgen',
      body: `${name} benötigt noch Ihre Verfügbarkeit.`,
    },
    sq: {
      title: 'Votimi mbyllet nesër',
      body: `${name} ka ende nevojë për disponueshmërinë tuaj.`,
    },
  }[locale];
}

export function companyClosedCopy(
  locale: NotificationLocale,
  companyName: unknown,
): NotificationMessage {
  const name = nameOr(locale, companyName, {
    en: 'Your company',
    de: 'Ihr Unternehmen',
    sq: 'Kompania juaj',
  });
  return {
    en: {
      title: 'Company closed',
      body: `${name} has been deleted. Your account and notes are unaffected, so you can join another company.`,
    },
    de: {
      title: 'Unternehmen geschlossen',
      body: `${name} wurde gelöscht. Ihr Konto und Ihre Notizen bleiben erhalten; Sie können einem anderen Unternehmen beitreten.`,
    },
    sq: {
      title: 'Kompania u mbyll',
      body: `${name} u fshi. Llogaria dhe shënimet tuaja mbeten të paprekura; mund t'i bashkoheni një kompanie tjetër.`,
    },
  }[locale];
}
