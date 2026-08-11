(function exposeLegalCopy(global) {
  'use strict';

  // The one place the operator's identity is written. Both the privacy page and
  // the deletion page interpolate these, so there is nothing to keep in sync.
  const OPERATOR = 'Kushtrim Mulliqi';
  const CONTACT = 'kushtrim.mulliqi@outlook.com';

  const copy = Object.freeze({
    en: Object.freeze({
      language_label: 'Language',
      open_app: 'Open EchoMeet',
      privacy_link: 'Privacy policy',
      deletion_link: 'Account-deletion instructions',
      privacy_eyebrow: 'Privacy policy',
      privacy_title: 'Privacy policy',
      privacy_effective: 'In effect from 12 August 2026',
      privacy_intro:
        'EchoMeet lets a company run surveys and tests, agree on meeting times, and keep private notes. It is a personal project published to demonstrate the software rather than a commercial service, and this policy describes exactly what it does with your data — nothing is collected for advertising, analytics or resale.',
      privacy_operator_title: 'Who is responsible',
      privacy_operator_body: `EchoMeet is operated by ${OPERATOR}, acting as an individual and as the controller of the data described here. For any question about your data, or to exercise any of the rights below, write to ${CONTACT}. Messages are answered by the same person who wrote the software.`,
      privacy_collect_title: 'What is collected',
      privacy_collect_body:
        'To create an account: your email address, your name, and your date of birth. Your password is never stored by EchoMeet — Firebase Authentication holds it and only ever confirms whether a sign-in attempt matches. While you use the app: which company you belong to, your role and approval state there, an optional profile photo, a notification token for each device you allow notifications on, your preferred notification language, your private notes, your answers and scores in surveys and tests, and which meeting times you said you can attend. Administrative actions inside a company — approvals, role changes, removals, bans — are recorded with who did them and when.',
      privacy_not_collected_title: 'What is never collected',
      privacy_not_collected_body:
        'No location, no contacts, no advertising identifier, no browsing or usage history. EchoMeet contains no analytics SDK, no crash-reporting SDK and no advertising SDK — you can verify this in the dependency list of the published source. Your data is never sold, rented, or shared for anyone else’s marketing, and no profile is built about you.',
      privacy_purpose_title: 'Why, and on what legal basis',
      privacy_purpose_body:
        'Your email, name and company membership exist to provide the account and the shared workspace you asked for — that is performance of a contract (GDPR Article 6(1)(b)). Your date of birth is collected at registration as part of that profile. Security measures — verifying the app itself, enforcing per-document access rules, honouring bans — rest on legitimate interests (Article 6(1)(f)): without them one member could read another company’s answers. Push notifications are sent only after you allow them on your device, and you can withdraw that at any time in your device settings or in EchoMeet’s own notification preferences.',
      privacy_visibility_title: 'Who can see what',
      privacy_visibility_body:
        'Your notes are private to you; no administrator and no other member can read them. Your name and profile photo are visible to the members of your company, because a survey result or a meeting vote is meaningless without knowing whose it is. Your answers to a survey or test, and your score, are visible to the administrators and moderators of that company. Your meeting votes are visible to members of that company. Nothing you do is visible to members of any other company, and none of it is public.',
      privacy_scoring_title: 'Automatic scoring',
      privacy_scoring_body:
        'Answers to a test are compared against the answer key on the server, and a score is calculated automatically. Written answers are marked by a person — an administrator or moderator of your company — not by the software. No automated decision is made about you beyond that score, and the score has no effect outside the app.',
      privacy_processors_title: 'Who processes it',
      privacy_processors_body:
        'EchoMeet runs on Google’s Firebase platform and Google is its only processor. Sign-in uses Firebase Authentication; the database is Cloud Firestore, located in Google’s multi-region for Europe; profile photos are in Cloud Storage; server logic runs as Cloud Functions in the Netherlands (europe-west4); notifications go through Firebase Cloud Messaging and your device’s own push service; the website is on Firebase Hosting. Firebase App Check confirms that requests come from the genuine app, using reCAPTCHA in the browser and Play Integrity on Android, which means Google receives signals about the browser or device making the request. Google may process data outside the European Economic Area under the safeguards set out in its own terms.',
      privacy_security_title: 'How it is protected',
      privacy_security_body:
        'Every connection is encrypted in transit. Access is decided by rules evaluated on Google’s servers, per document, not by the app on your phone — so a modified client cannot read what it is not entitled to. An email address must be verified before it can join a company. Grading material for tests is stored apart from the questions members can read, and scores are computed on the server so an answer key never reaches a participant’s device.',
      privacy_retention_title: 'How long it is kept',
      privacy_retention_body:
        'Your data is kept while your account exists. When you request deletion, EchoMeet removes your sign-in, your profile, your photo, your notification tokens, your notes, your survey and test participation, your meeting votes, and any ban records naming you; surveys and meetings you created for a company can remain for that company with your authorship marker removed. Closing a company schedules it for deletion seven days later, at which point its surveys, tests, answers and meetings are deleted — its members are released, not deleted, and keep their accounts and notes. Deletion removes these records from the live database; copies held inside Google’s infrastructure for operational resilience expire on Google’s own schedule.',
      privacy_rights_title: 'Your rights',
      privacy_rights_body: `You may ask for a copy of your data, correct it, have it erased, restrict or object to its processing, and receive it in a portable form. Your name, birth date and notification settings are editable in the app, results can be exported as PDF, and deletion can be requested from Settings without asking anyone. For anything else, write to ${CONTACT}. If you are in the European Economic Area or the United Kingdom you may also complain to your national data-protection authority.`,
      privacy_children_title: 'Children',
      privacy_children_body:
        'EchoMeet is not intended for children under 16 and is not directed at them. If you are under 16, please do not create an account. If you believe a child has registered, write to the address above and the account will be deleted.',
      privacy_changes_title: 'Changes to this policy',
      privacy_changes_body:
        'The text published on this page is always the current one, and the date at the top changes whenever it does. There is no earlier version that still applies.',
      privacy_footer: `Privacy policy for EchoMeet · ${OPERATOR} · ${CONTACT}`,
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
        'The trusted deletion process targets the private profile, profile photo, notification tokens, notes, survey or test participation, meeting votes, and ban references. Shared company content can remain with an anonymous author marker. Copies held inside Google’s infrastructure for operational resilience expire on Google’s own schedule.',
      deletion_owner_title: 'If the account owns a company',
      deletion_owner_body:
        'The app shows a separate warning and requires explicit approval before requesting company cleanup. Other members’ sign-ins and private notes are outside that company-cleanup request. This information page does not claim that cleanup is complete.',
      deletion_access_title: 'If you cannot sign in',
      deletion_access_body:
        'Use Reset password on the EchoMeet sign-in screen. This page never asks for an email address and does not reveal whether an account exists.',
      deletion_footer: `This public page gives the same instructions to everyone and does not look up accounts. Questions: ${CONTACT}`,
    }),
    de: Object.freeze({
      language_label: 'Sprache',
      open_app: 'EchoMeet öffnen',
      privacy_link: 'Datenschutzerklärung',
      deletion_link: 'Anleitung zur Kontolöschung',
      privacy_eyebrow: 'Datenschutzerklärung',
      privacy_title: 'Datenschutzerklärung',
      privacy_effective: 'Gültig ab 12. August 2026',
      privacy_intro:
        'Mit EchoMeet kann ein Unternehmen Umfragen und Tests durchführen, Termine abstimmen und private Notizen führen. Es ist ein persönliches Projekt, das die Software vorführen soll, und kein kommerzieller Dienst. Diese Erklärung beschreibt genau, was mit Ihren Daten geschieht – nichts wird für Werbung, Analyse oder Weiterverkauf erhoben.',
      privacy_operator_title: 'Wer verantwortlich ist',
      privacy_operator_body: `EchoMeet wird von ${OPERATOR} als Privatperson betrieben, der auch Verantwortlicher für die hier beschriebenen Daten ist. Bei Fragen zu Ihren Daten oder zur Ausübung der unten genannten Rechte schreiben Sie an ${CONTACT}. Antworten kommen von derselben Person, die die Software geschrieben hat.`,
      privacy_collect_title: 'Was erhoben wird',
      privacy_collect_body:
        'Für ein Konto: Ihre E-Mail-Adresse, Ihr Name und Ihr Geburtsdatum. Ihr Passwort speichert EchoMeet nie – Firebase Authentication verwahrt es und bestätigt lediglich, ob ein Anmeldeversuch dazu passt. Während der Nutzung: Ihre Unternehmenszugehörigkeit, Ihre Rolle und Ihr Freigabestatus dort, ein optionales Profilbild, ein Benachrichtigungstoken für jedes Gerät, auf dem Sie Benachrichtigungen erlauben, Ihre bevorzugte Benachrichtigungssprache, Ihre privaten Notizen, Ihre Antworten und Ergebnisse in Umfragen und Tests sowie die Termine, zu denen Sie zugesagt haben. Administrative Vorgänge innerhalb eines Unternehmens – Freigaben, Rollenwechsel, Entfernungen, Sperren – werden mit Urheber und Zeitpunkt festgehalten.',
      privacy_not_collected_title: 'Was nie erhoben wird',
      privacy_not_collected_body:
        'Kein Standort, keine Kontakte, keine Werbekennung, kein Browser- oder Nutzungsverlauf. EchoMeet enthält kein Analyse-SDK, kein Crash-Reporting-SDK und kein Werbe-SDK – das lässt sich in der Abhängigkeitsliste des veröffentlichten Quellcodes nachprüfen. Ihre Daten werden nicht verkauft, nicht vermietet und nicht für die Werbung Dritter weitergegeben; es wird kein Profil über Sie gebildet.',
      privacy_purpose_title: 'Wozu und auf welcher Rechtsgrundlage',
      privacy_purpose_body:
        'E-Mail-Adresse, Name und Unternehmenszugehörigkeit dienen dazu, das Konto und den gemeinsamen Arbeitsbereich bereitzustellen, um den Sie gebeten haben – das ist die Erfüllung eines Vertrags (Art. 6 Abs. 1 lit. b DSGVO). Das Geburtsdatum wird bei der Registrierung als Teil dieses Profils erhoben. Sicherheitsmaßnahmen – die Prüfung der App selbst, die Durchsetzung dokumentgenauer Zugriffsregeln, die Beachtung von Sperren – stützen sich auf berechtigte Interessen (Art. 6 Abs. 1 lit. f DSGVO): ohne sie könnte ein Mitglied die Antworten eines anderen Unternehmens lesen. Push-Benachrichtigungen werden erst gesendet, wenn Sie sie auf Ihrem Gerät erlauben; das können Sie jederzeit in den Geräteeinstellungen oder in den Benachrichtigungseinstellungen von EchoMeet zurücknehmen.',
      privacy_visibility_title: 'Wer was sehen kann',
      privacy_visibility_body:
        'Ihre Notizen sind privat; weder Administratoren noch andere Mitglieder können sie lesen. Ihr Name und Ihr Profilbild sind für die Mitglieder Ihres Unternehmens sichtbar, denn ein Umfrageergebnis oder eine Terminabstimmung ist ohne Zuordnung sinnlos. Ihre Antworten in einer Umfrage oder einem Test und Ihr Ergebnis sind für Administratoren und Moderatoren dieses Unternehmens sichtbar. Ihre Terminabstimmungen sind für die Mitglieder dieses Unternehmens sichtbar. Für Mitglieder anderer Unternehmen ist nichts davon sichtbar, und öffentlich ist nichts davon.',
      privacy_scoring_title: 'Automatische Bewertung',
      privacy_scoring_body:
        'Antworten in einem Test werden auf dem Server mit dem Lösungsschlüssel verglichen und ein Ergebnis wird automatisch berechnet. Freitextantworten bewertet ein Mensch – ein Administrator oder Moderator Ihres Unternehmens – nicht die Software. Darüber hinaus wird keine automatisierte Entscheidung über Sie getroffen, und das Ergebnis hat außerhalb der App keine Wirkung.',
      privacy_processors_title: 'Wer die Daten verarbeitet',
      privacy_processors_body:
        'EchoMeet läuft auf der Firebase-Plattform von Google, und Google ist der einzige Auftragsverarbeiter. Die Anmeldung nutzt Firebase Authentication; die Datenbank ist Cloud Firestore in der europäischen Multi-Region von Google; Profilbilder liegen in Cloud Storage; die Serverlogik läuft als Cloud Functions in den Niederlanden (europe-west4); Benachrichtigungen laufen über Firebase Cloud Messaging und den Push-Dienst Ihres Geräts; die Website liegt auf Firebase Hosting. Firebase App Check bestätigt, dass Anfragen aus der echten App stammen, über reCAPTCHA im Browser und Play Integrity auf Android – dabei erhält Google Signale über den anfragenden Browser oder das anfragende Gerät. Google kann Daten außerhalb des Europäischen Wirtschaftsraums verarbeiten, unter den in seinen eigenen Bedingungen festgelegten Garantien.',
      privacy_security_title: 'Wie die Daten geschützt sind',
      privacy_security_body:
        'Jede Verbindung ist bei der Übertragung verschlüsselt. Über Zugriffe entscheiden Regeln, die auf den Servern von Google für jedes Dokument einzeln ausgewertet werden, nicht die App auf Ihrem Gerät – ein manipulierter Client kann daher nicht lesen, wozu er nicht berechtigt ist. Eine E-Mail-Adresse muss bestätigt sein, bevor sie einem Unternehmen beitreten kann. Bewertungsschlüssel für Tests liegen getrennt von den Fragen, die Mitglieder lesen können, und Ergebnisse werden auf dem Server berechnet, damit ein Lösungsschlüssel nie auf das Gerät eines Teilnehmers gelangt.',
      privacy_retention_title: 'Wie lange die Daten bleiben',
      privacy_retention_body:
        'Ihre Daten bleiben, solange Ihr Konto besteht. Auf Ihre Löschanforderung entfernt EchoMeet Ihre Anmeldung, Ihr Profil, Ihr Bild, Ihre Benachrichtigungstokens, Ihre Notizen, Ihre Teilnahme an Umfragen und Tests, Ihre Terminabstimmungen sowie Sperrvermerke, die Sie nennen; von Ihnen für ein Unternehmen erstellte Umfragen und Termine können diesem Unternehmen erhalten bleiben, ohne Ihre Autorenkennzeichnung. Das Schließen eines Unternehmens plant seine Löschung in sieben Tagen; danach werden seine Umfragen, Tests, Antworten und Termine gelöscht – seine Mitglieder werden freigegeben, nicht gelöscht, und behalten Konto und Notizen. Die Löschung entfernt diese Datensätze aus der laufenden Datenbank; Kopien innerhalb der Infrastruktur von Google zur Betriebssicherheit verfallen nach dem Zeitplan von Google.',
      privacy_rights_title: 'Ihre Rechte',
      privacy_rights_body: `Sie können eine Kopie Ihrer Daten verlangen, sie berichtigen, löschen, deren Verarbeitung einschränken oder ihr widersprechen und sie in einem übertragbaren Format erhalten. Name, Geburtsdatum und Benachrichtigungseinstellungen können Sie in der App ändern, Ergebnisse lassen sich als PDF ausgeben, und die Löschung können Sie in den Einstellungen selbst anfordern, ohne jemanden zu fragen. Für alles Weitere schreiben Sie an ${CONTACT}. Wenn Sie im Europäischen Wirtschaftsraum oder im Vereinigten Königreich sind, können Sie sich außerdem bei Ihrer nationalen Datenschutzbehörde beschweren.`,
      privacy_children_title: 'Kinder',
      privacy_children_body:
        'EchoMeet ist nicht für Kinder unter 16 Jahren gedacht und richtet sich nicht an sie. Wenn Sie unter 16 sind, erstellen Sie bitte kein Konto. Wenn Sie glauben, dass ein Kind sich registriert hat, schreiben Sie an die oben genannte Adresse; das Konto wird dann gelöscht.',
      privacy_changes_title: 'Änderungen dieser Erklärung',
      privacy_changes_body:
        'Der auf dieser Seite veröffentlichte Text ist stets der aktuelle, und das Datum oben ändert sich mit ihm. Es gibt keine frühere Fassung, die weiterhin gilt.',
      privacy_footer: `Datenschutzerklärung für EchoMeet · ${OPERATOR} · ${CONTACT}`,
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
        'Der vertrauenswürdige Löschprozess erfasst privates Profil, Profilbild, Benachrichtigungstokens, Notizen, die Teilnahme an Umfragen oder Tests, Terminabstimmungen und Sperrverweise. Gemeinsam genutzte Unternehmensinhalte können mit einer anonymen Autorenmarkierung bestehen bleiben. Kopien innerhalb der Infrastruktur von Google zur Betriebssicherheit verfallen nach dem Zeitplan von Google.',
      deletion_owner_title: 'Wenn das Konto ein Unternehmen besitzt',
      deletion_owner_body:
        'Die App zeigt eine eigene Warnung und verlangt eine ausdrückliche Zustimmung, bevor die Unternehmensbereinigung angefordert wird. Die Anmeldungen und privaten Notizen anderer Mitglieder gehören nicht zu dieser Anforderung. Diese Informationsseite behauptet nicht, dass die Bereinigung abgeschlossen ist.',
      deletion_access_title: 'Wenn Sie sich nicht anmelden können',
      deletion_access_body:
        'Verwenden Sie Passwort zurücksetzen auf dem EchoMeet-Anmeldebildschirm. Diese Seite fragt nie nach einer E-Mail-Adresse und zeigt nicht an, ob ein Konto existiert.',
      deletion_footer: `Diese öffentliche Seite zeigt allen dieselbe Anleitung und sucht nicht nach Konten. Fragen: ${CONTACT}`,
    }),
    sq: Object.freeze({
      language_label: 'Gjuha',
      open_app: 'Hap EchoMeet',
      privacy_link: 'Politika e privatësisë',
      deletion_link: 'Udhëzimet për fshirjen e llogarisë',
      privacy_eyebrow: 'Politika e privatësisë',
      privacy_title: 'Politika e privatësisë',
      privacy_effective: 'Në fuqi nga 12 gusht 2026',
      privacy_intro:
        'EchoMeet i lejon një kompanie të zhvillojë anketa dhe teste, të bjerë në një orar takimi dhe të mbajë shënime private. Është një projekt personal i botuar për të demonstruar programin, jo një shërbim tregtar. Kjo politikë përshkruan saktësisht çfarë bëhet me të dhënat tuaja – asgjë nuk mblidhet për reklama, analitikë ose rishitje.',
      privacy_operator_title: 'Kush është përgjegjës',
      privacy_operator_body: `EchoMeet operohet nga ${OPERATOR}, si individ dhe si kontrollues i të dhënave të përshkruara këtu. Për çdo pyetje mbi të dhënat tuaja, ose për të ushtruar ndonjë të drejtë më poshtë, shkruani në ${CONTACT}. Përgjigjet vijnë nga i njëjti person që shkroi programin.`,
      privacy_collect_title: 'Çfarë mblidhet',
      privacy_collect_body:
        'Për të krijuar një llogari: adresa e emailit, emri dhe datëlindja. Fjalëkalimin EchoMeet nuk e ruan kurrë – Firebase Authentication e mban dhe vetëm konfirmon nëse një përpjekje hyrjeje përputhet. Gjatë përdorimit: kompania të cilës i bëheni anëtar, roli dhe gjendja e miratimit tuaj atje, një fotografi profili opsionale, një token njoftimi për çdo pajisje ku lejoni njoftimet, gjuha e preferuar e njoftimeve, shënimet private, përgjigjet dhe rezultatet në anketa e teste, dhe oraret e takimeve për të cilat thoni se mund të vini. Veprimet administrative brenda një kompanie – miratime, ndryshime roli, heqje, bllokime – regjistrohen bashkë me atë që i bëri dhe kohën.',
      privacy_not_collected_title: 'Çfarë nuk mblidhet kurrë',
      privacy_not_collected_body:
        'Pa vendndodhje, pa kontakte, pa identifikues reklamash, pa histori shfletimi ose përdorimi. EchoMeet nuk përmban SDK analitike, SDK raportimi të gabimeve dhe SDK reklamash – kjo mund të verifikohet në listën e varësive të kodit të botuar. Të dhënat tuaja nuk shiten, nuk jepen me qira dhe nuk ndahen për marketingun e të tjerëve; për ju nuk krijohet asnjë profil.',
      privacy_purpose_title: 'Pse, dhe në çfarë bazë ligjore',
      privacy_purpose_body:
        'Emaili, emri dhe anëtarësimi në kompani ekzistojnë për të ofruar llogarinë dhe hapësirën e përbashkët që kërkuat – kjo është përmbushje e një kontrate (neni 6(1)(b) i GDPR). Datëlindja mblidhet gjatë regjistrimit si pjesë e këtij profili. Masat e sigurisë – verifikimi i aplikacionit, zbatimi i rregullave të qasjes dokument për dokument, respektimi i bllokimeve – bazohen në interesa legjitime (neni 6(1)(f)): pa ato një anëtar mund të lexonte përgjigjet e një kompanie tjetër. Njoftimet dërgohen vetëm pasi ju t’i lejoni në pajisjen tuaj, dhe mund t’i tërhiqni kurdo në cilësimet e pajisjes ose në cilësimet e njoftimeve të EchoMeet.',
      privacy_visibility_title: 'Kush mund të shohë çfarë',
      privacy_visibility_body:
        'Shënimet janë private për ju; nuk i lexon as administratori, as anëtarët e tjerë. Emri dhe fotografia e profilit shihen nga anëtarët e kompanisë tuaj, sepse një rezultat anketë ose një votë takimi nuk ka kuptim pa e ditur të kujt është. Përgjigjet tuaja në një anketë ose test, dhe rezultati, shihen nga administratorët dhe moderatorët e kësaj kompanie. Votat për takime shihen nga anëtarët e kësaj kompanie. Asgjë prej këtyre nuk shihet nga anëtarët e një kompanie tjetër, dhe asgjë nuk është publike.',
      privacy_scoring_title: 'Vlerësimi automatik',
      privacy_scoring_body:
        'Përgjigjet në një test krahasohen në server me çelësin e përgjigjeve dhe rezultati llogaritet automatikisht. Përgjigjet me shkrim vlerësohen nga një njeri – një administrator ose moderator i kompanisë tuaj – jo nga programi. Përveç këtij rezultati, për ju nuk merret asnjë vendim automatik, dhe rezultati nuk ka efekt jashtë aplikacionit.',
      privacy_processors_title: 'Kush i përpunon',
      privacy_processors_body:
        'EchoMeet punon mbi platformën Firebase të Google, dhe Google është përpunuesi i vetëm. Hyrja përdor Firebase Authentication; baza e të dhënave është Cloud Firestore, në multi-regjionin europian të Google; fotografitë e profilit ndodhen në Cloud Storage; logjika e serverit punon si Cloud Functions në Holandë (europe-west4); njoftimet kalojnë përmes Firebase Cloud Messaging dhe shërbimit të njoftimeve të pajisjes tuaj; faqja është në Firebase Hosting. Firebase App Check konfirmon që kërkesat vijnë nga aplikacioni i vërtetë, me reCAPTCHA në shfletues dhe Play Integrity në Android – kjo do të thotë se Google merr sinjale për shfletuesin ose pajisjen që bën kërkesën. Google mund t’i përpunojë të dhënat jashtë Zonës Ekonomike Europiane, nën garancitë e përcaktuara në kushtet e vetë Google.',
      privacy_security_title: 'Si mbrohen',
      privacy_security_body:
        'Çdo lidhje është e enkriptuar gjatë transmetimit. Qasjen e vendosin rregulla që vlerësohen në serverat e Google, dokument për dokument, dhe jo aplikacioni në telefonin tuaj – kështu një klient i modifikuar nuk mund të lexojë atë që nuk i takon. Një adresë emaili duhet të verifikohet para se të bashkohet me një kompani. Materiali i vlerësimit për testet ruhet veçmas nga pyetjet që anëtarët lexojnë, dhe rezultatet llogariten në server, kështu që çelësi i përgjigjeve nuk arrin kurrë në pajisjen e një pjesëmarrësi.',
      privacy_retention_title: 'Sa gjatë ruhen',
      privacy_retention_body:
        'Të dhënat ruhen sa kohë ekziston llogaria juaj. Kur kërkoni fshirjen, EchoMeet heq hyrjen, profilin, fotografinë, tokenët e njoftimeve, shënimet, pjesëmarrjen në anketa e teste, votat për takime dhe shënimet e bllokimit që përmendin ju; anketat dhe takimet që krijuat për një kompani mund të mbeten për atë kompani, pa shenjën e autorësisë tuaj. Mbyllja e një kompanie planifikon fshirjen e saj shtatë ditë më vonë; pas kësaj fshihen anketat, testet, përgjigjet dhe takimet e saj – anëtarët lirohen, nuk fshihen, dhe ruajnë llogarinë e shënimet. Fshirja i heq këto të dhëna nga baza e të dhënave aktive; kopjet brenda infrastrukturës së Google për vazhdimësi operative skadojnë sipas afateve të Google.',
      privacy_rights_title: 'Të drejtat tuaja',
      privacy_rights_body: `Mund të kërkoni një kopje të të dhënave tuaja, t’i korrigjoni, t’i fshini, të kufizoni ose kundërshtoni përpunimin e tyre, dhe t’i marrni në një formë të transportueshme. Emri, datëlindja dhe cilësimet e njoftimeve redaktohen në aplikacion, rezultatet mund të eksportohen si PDF, dhe fshirjen mund t’a kërkoni vetë te Cilësimet, pa pyetur njeri. Për çdo gjë tjetër shkruani në ${CONTACT}. Nëse ndodheni në Zonën Ekonomike Europiane ose në Mbretërinë e Bashkuar, mund të ankoheni edhe në autoritetin kombëtar për mbrojtjen e të dhënave.`,
      privacy_children_title: 'Fëmijët',
      privacy_children_body:
        'EchoMeet nuk është menduar për fëmijë nën 16 vjeç dhe nuk u drejtohet atyre. Nëse jeni nën 16, ju lutemi mos krijoni llogari. Nëse mendoni se një fëmijë është regjistruar, shkruani në adresën më sipër dhe llogaria do të fshihet.',
      privacy_changes_title: 'Ndryshimet e kësaj politike',
      privacy_changes_body:
        'Teksti i botuar në këtë faqe është gjithmonë ai aktual, dhe data lart ndryshon bashkë me të. Nuk ka version të mëparshëm që vazhdon të zbatohet.',
      privacy_footer: `Politika e privatësisë për EchoMeet · ${OPERATOR} · ${CONTACT}`,
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
        'Procesi i besuar i fshirjes synon profilin privat, fotografinë e profilit, tokenët e njoftimeve, shënimet, pjesëmarrjen në anketa ose teste, votat për takime dhe referencat e bllokimit. Përmbajtja e përbashkët e kompanisë mund të mbetet me një shënim anonim të autorit. Kopjet brenda infrastrukturës së Google për vazhdimësi operative skadojnë sipas afateve të Google.',
      deletion_owner_title: 'Nëse llogaria zotëron një kompani',
      deletion_owner_body:
        'Aplikacioni shfaq një paralajmërim të veçantë dhe kërkon miratim të qartë para se të kërkojë pastrimin e kompanisë. Hyrjet dhe shënimet private të anëtarëve të tjerë janë jashtë kësaj kërkese. Kjo faqe informative nuk pretendon se pastrimi ka përfunduar.',
      deletion_access_title: 'Nëse nuk mund të hyni',
      deletion_access_body:
        'Përdorni Rivendos fjalëkalimin në ekranin e hyrjes në EchoMeet. Kjo faqe nuk kërkon kurrë adresë emaili dhe nuk tregon nëse ekziston një llogari.',
      deletion_footer: `Kjo faqe publike u jep të gjithëve të njëjtat udhëzime dhe nuk kërkon llogari. Pyetje: ${CONTACT}`,
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
