(function exposeLegalCopy(global) {
  'use strict';

  const copy = Object.freeze({
    en: Object.freeze({
      language_label: 'Language',
      open_app: 'Open EchoMeet',
      privacy_link: 'Privacy information',
      deletion_link: 'Account-deletion instructions',
      privacy_eyebrow: 'Privacy publication',
      privacy_title: 'Privacy information',
      privacy_status: 'Owner and legal approval required',
      privacy_intro:
        'This source checkout does not contain owner- and legal-approved details required to publish a privacy policy. This technical page is not an approved privacy policy.',
      privacy_source_title: 'What the application source handles',
      privacy_source_body:
        'The application source handles sign-in email, name, birth date, company membership and role, an optional profile photo, notification token and locale, private notes, survey or test responses and scores, appointment votes, and company administration records.',
      privacy_owner_title: 'Information still required',
      privacy_owner_body:
        "Before release, the operator must approve its identity and contact details, data-use purposes and legal bases, retention and backup practices, service-provider disclosures, user rights, and the policy's effective date.",
      privacy_deletion_title: 'Account deletion',
      privacy_deletion_body:
        'EchoMeet includes an in-app deletion request. The public instructions explain how to reach it without asking for an account identifier.',
      privacy_footer:
        'Publication status: owner input required. No legal commitment is implied by this page.',
      deletion_eyebrow: 'Account and data',
      deletion_title: 'Request deletion of an EchoMeet account',
      deletion_intro:
        'You can request permanent deletion from inside EchoMeet. After password confirmation, EchoMeet starts its trusted cleanup. The sign-in is removed only after that cleanup reports success.',
      deletion_steps_title: 'Deletion steps',
      deletion_step_1:
        'Sign in to the account. Use Reset password first if you cannot sign in.',
      deletion_step_2:
        'Open Settings and choose Delete account in the danger section.',
      deletion_step_3:
        'Enter your password, review the warning, and submit the deletion request.',
      deletion_data_title: 'What the process targets',
      deletion_data_body:
        'The trusted deletion process targets the private profile, profile photo, notification tokens, notes, survey or test participation, meeting votes, and ban references. Shared company content can remain with an anonymous author marker. This page does not define retention, backup, or legal-exception handling.',
      deletion_owner_title: 'If the account owns a company',
      deletion_owner_body:
        "The app shows a separate warning and requires explicit approval before requesting company cleanup. Other members' sign-ins and private notes are outside that company-cleanup request. This information page does not claim that cleanup is complete.",
      deletion_access_title: 'If you cannot sign in',
      deletion_access_body:
        'Use Reset password on the EchoMeet sign-in screen. This page never asks for an email address and does not reveal whether an account exists.',
      deletion_footer:
        'This public page gives the same instructions to everyone and does not look up accounts.',
    }),
    de: Object.freeze({
      language_label: 'Sprache',
      open_app: 'EchoMeet öffnen',
      privacy_link: 'Datenschutzinformationen',
      deletion_link: 'Anleitung zur Kontolöschung',
      privacy_eyebrow: 'Datenschutz-Veröffentlichung',
      privacy_title: 'Datenschutzinformationen',
      privacy_status: 'Genehmigung durch Betreiber und Rechtsprüfung erforderlich',
      privacy_intro:
        'Dieser Quellcode-Stand enthält nicht die vom Betreiber und rechtlich genehmigten Angaben, die zur Veröffentlichung einer Datenschutzerklärung erforderlich sind. Diese technische Seite ist keine genehmigte Datenschutzerklärung.',
      privacy_source_title: 'Was der Anwendungscode verarbeitet',
      privacy_source_body:
        'Der Anwendungscode verarbeitet Anmelde-E-Mail, Name, Geburtsdatum, Unternehmensmitgliedschaft und Rolle, ein optionales Profilbild, Benachrichtigungstoken und Spracheinstellung, private Notizen, Umfrage- oder Testantworten und Ergebnisse, Terminabstimmungen sowie Verwaltungsdaten des Unternehmens.',
      privacy_owner_title: 'Noch erforderliche Angaben',
      privacy_owner_body:
        'Vor der Veröffentlichung muss der Betreiber seine Identität und Kontaktdaten, die Zwecke der Datennutzung und Rechtsgrundlagen, Aufbewahrungs- und Sicherungspraktiken, Angaben zu Dienstleistern, Rechte der Nutzerinnen und Nutzer sowie das Gültigkeitsdatum der Erklärung genehmigen.',
      privacy_deletion_title: 'Kontolöschung',
      privacy_deletion_body:
        'EchoMeet enthält eine Löschanforderung in der App. Die öffentliche Anleitung erklärt den Zugang, ohne nach einer Kontokennung zu fragen.',
      privacy_footer:
        'Veröffentlichungsstatus: Angaben des Betreibers erforderlich. Diese Seite enthält keine rechtliche Zusage.',
      deletion_eyebrow: 'Konto und Daten',
      deletion_title: 'Löschung eines EchoMeet-Kontos anfordern',
      deletion_intro:
        'Sie können die dauerhafte Löschung in EchoMeet anfordern. Nach der Passwortbestätigung startet EchoMeet den vertrauenswürdigen Bereinigungsprozess. Die Anmeldung wird erst entfernt, wenn dieser Prozess Erfolg meldet.',
      deletion_steps_title: 'Schritte zur Löschung',
      deletion_step_1:
        'Melden Sie sich beim Konto an. Nutzen Sie zuerst Passwort zurücksetzen, falls die Anmeldung nicht möglich ist.',
      deletion_step_2:
        'Öffnen Sie Einstellungen und wählen Sie Konto löschen im Gefahrenbereich.',
      deletion_step_3:
        'Geben Sie Ihr Passwort ein, lesen Sie die Warnung und senden Sie die Löschanforderung.',
      deletion_data_title: 'Was der Prozess erfasst',
      deletion_data_body:
        'Der vertrauenswürdige Löschprozess erfasst privates Profil, Profilbild, Benachrichtigungstokens, Notizen, die Teilnahme an Umfragen oder Tests, Terminabstimmungen und Sperrverweise. Gemeinsam genutzte Unternehmensinhalte können mit einer anonymen Autorenmarkierung bestehen bleiben. Diese Seite legt den Umgang mit Aufbewahrung, Sicherungen oder rechtlichen Ausnahmen nicht fest.',
      deletion_owner_title: 'Wenn das Konto ein Unternehmen besitzt',
      deletion_owner_body:
        'Die App zeigt eine eigene Warnung und verlangt eine ausdrückliche Zustimmung, bevor die Unternehmensbereinigung angefordert wird. Die Anmeldungen und privaten Notizen anderer Mitglieder gehören nicht zu dieser Anforderung. Diese Informationsseite behauptet nicht, dass die Bereinigung abgeschlossen ist.',
      deletion_access_title: 'Wenn Sie sich nicht anmelden können',
      deletion_access_body:
        'Verwenden Sie Passwort zurücksetzen auf dem EchoMeet-Anmeldebildschirm. Diese Seite fragt nie nach einer E-Mail-Adresse und zeigt nicht an, ob ein Konto existiert.',
      deletion_footer:
        'Diese öffentliche Seite zeigt allen dieselbe Anleitung und sucht nicht nach Konten.',
    }),
    sq: Object.freeze({
      language_label: 'Gjuha',
      open_app: 'Hap EchoMeet',
      privacy_link: 'Informacion mbi privatësinë',
      deletion_link: 'Udhëzimet për fshirjen e llogarisë',
      privacy_eyebrow: 'Publikimi i privatësisë',
      privacy_title: 'Informacion mbi privatësinë',
      privacy_status: 'Kërkohet miratimi i operatorit dhe ai ligjor',
      privacy_intro:
        'Ky version i kodit burimor nuk përmban hollësitë e miratuara nga operatori dhe ana ligjore që duhen për të publikuar një politikë privatësie. Kjo faqe teknike nuk është një politikë privatësie e miratuar.',
      privacy_source_title: 'Çfarë trajton kodi burimor i aplikacionit',
      privacy_source_body:
        'Kodi burimor i aplikacionit trajton emailin e hyrjes, emrin, datëlindjen, anëtarësimin dhe rolin në kompani, një fotografi profili opsionale, tokenin dhe gjuhën e njoftimeve, shënimet private, përgjigjet dhe rezultatet e anketave ose testeve, votat për takime dhe të dhënat e administrimit të kompanisë.',
      privacy_owner_title: 'Informacioni që ende nevojitet',
      privacy_owner_body:
        'Para publikimit, operatori duhet të miratojë identitetin dhe të dhënat e kontaktit, qëllimet dhe bazat ligjore të përdorimit të të dhënave, praktikat e ruajtjes dhe kopjeve rezervë, deklarimet për ofruesit e shërbimeve, të drejtat e përdoruesve dhe datën e hyrjes në fuqi të politikës.',
      privacy_deletion_title: 'Fshirja e llogarisë',
      privacy_deletion_body:
        'EchoMeet përfshin një kërkesë për fshirje brenda aplikacionit. Udhëzimet publike tregojnë si arrihet ajo pa kërkuar identifikues llogarie.',
      privacy_footer:
        'Gjendja e publikimit: kërkohen të dhënat e operatorit. Kjo faqe nuk nënkupton zotim ligjor.',
      deletion_eyebrow: 'Llogaria dhe të dhënat',
      deletion_title: 'Kërkoni fshirjen e një llogarie EchoMeet',
      deletion_intro:
        'Mund të kërkoni fshirjen e përhershme brenda EchoMeet. Pas konfirmimit të fjalëkalimit, EchoMeet nis pastrimin e besuar. Hyrja hiqet vetëm pasi ky pastrim raporton sukses.',
      deletion_steps_title: 'Hapat e fshirjes',
      deletion_step_1:
        'Hyni në llogari. Përdorni fillimisht Rivendos fjalëkalimin nëse nuk mund të hyni.',
      deletion_step_2:
        'Hapni Cilësimet dhe zgjidhni Fshi llogarinë në seksionin e rrezikut.',
      deletion_step_3:
        'Shkruani fjalëkalimin, lexoni paralajmërimin dhe dërgoni kërkesën për fshirje.',
      deletion_data_title: 'Çfarë synon procesi',
      deletion_data_body:
        'Procesi i besuar i fshirjes synon profilin privat, fotografinë e profilit, tokenët e njoftimeve, shënimet, pjesëmarrjen në anketa ose teste, votat për takime dhe referencat e bllokimit. Përmbajtja e përbashkët e kompanisë mund të mbetet me një shënim anonim të autorit. Kjo faqe nuk përcakton trajtimin e ruajtjes, kopjeve rezervë ose përjashtimeve ligjore.',
      deletion_owner_title: 'Nëse llogaria zotëron një kompani',
      deletion_owner_body:
        'Aplikacioni shfaq një paralajmërim të veçantë dhe kërkon miratim të qartë para se të kërkojë pastrimin e kompanisë. Hyrjet dhe shënimet private të anëtarëve të tjerë janë jashtë kësaj kërkese. Kjo faqe informative nuk pretendon se pastrimi ka përfunduar.',
      deletion_access_title: 'Nëse nuk mund të hyni',
      deletion_access_body:
        'Përdorni Rivendos fjalëkalimin në ekranin e hyrjes në EchoMeet. Kjo faqe nuk kërkon kurrë adresë emaili dhe nuk tregon nëse ekziston një llogari.',
      deletion_footer:
        'Kjo faqe publike u jep të gjithëve të njëjtat udhëzime dhe nuk kërkon llogari.',
    }),
  });

  global.EchoMeetLegalCopy = copy;

  const document = global.document;
  if (!document) return;

  const supported = Object.keys(copy);
  const requested = new URLSearchParams(global.location.search).get('lang');
  let saved;
  try {
    saved = global.localStorage.getItem('echomeet-legal-language');
  } catch (_) {
    saved = null;
  }
  const browserLanguage = (global.navigator.language || '').split('-')[0];
  const initial = [requested, saved, browserLanguage].find((language) =>
    supported.includes(language),
  );

  function render(language) {
    const locale = supported.includes(language) ? language : 'en';
    const values = copy[locale];
    document.documentElement.lang = locale;
    document.querySelectorAll('[data-i18n]').forEach((element) => {
      const value = values[element.dataset.i18n];
      if (value) element.textContent = value;
    });
    document.querySelectorAll('[data-i18n-aria-label]').forEach((element) => {
      const value = values[element.dataset.i18nAriaLabel];
      if (value) element.setAttribute('aria-label', value);
    });
    document.querySelectorAll('[data-language]').forEach((button) => {
      button.setAttribute(
        'aria-pressed',
        button.dataset.language === locale ? 'true' : 'false',
      );
    });
    const titleKey = document.body.dataset.titleKey;
    if (values[titleKey]) document.title = `${values[titleKey]} · EchoMeet`;
    try {
      global.localStorage.setItem('echomeet-legal-language', locale);
    } catch (_) {
      // The page remains usable when storage is unavailable.
    }
  }

  document.querySelectorAll('[data-language]').forEach((button) => {
    button.addEventListener('click', () => render(button.dataset.language));
  });
  render(initial || 'en');
})(typeof window === 'undefined' ? globalThis : window);
