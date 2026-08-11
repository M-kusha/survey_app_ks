const assert = require('node:assert/strict');
const test = require('node:test');

const {
  appointmentConfirmedCopy,
  appointmentCreatedCopy,
  appointmentReminderCopy,
  companyClosedCopy,
  joinRequestCopy,
  surveyCreatedCopy,
  surveyReminderCopy,
} = require('../lib/notification_copy');

test('every notification has non-empty copy in every supported language', () => {
  for (const locale of ['en', 'de', 'sq']) {
    const messages = [
      joinRequestCopy(locale, 'Ada'),
      surveyCreatedCopy(locale, 'Pulse', false),
      surveyCreatedCopy(locale, 'Safety', true),
      appointmentCreatedCopy(locale, 'Planning'),
      appointmentConfirmedCopy(
        locale,
        'Planning',
        new Date('2026-08-10T09:00:00.000Z'),
        'Europe/Berlin',
      ),
      surveyReminderCopy(locale, 'Pulse'),
      appointmentReminderCopy(locale, 'Planning'),
      companyClosedCopy(locale, 'Acme'),
    ];

    for (const message of messages) {
      assert.ok(message.title.trim());
      assert.ok(message.body.trim());
    }
  }
});

test('missing names use a localized fallback instead of an empty subject', () => {
  assert.match(surveyReminderCopy('en', '').body, /A survey/);
  assert.match(surveyReminderCopy('de', null).body, /Eine Umfrage/);
  assert.match(surveyReminderCopy('sq', undefined).body, /Një anketë/);
});

test('confirmed appointment time uses recipient locale in the creator IANA zone', () => {
  const instant = new Date('2026-08-10T09:00:00.000Z');
  const english = appointmentConfirmedCopy('en', 'Planning', instant, 'Europe/Berlin');
  const german = appointmentConfirmedCopy('de', 'Planning', instant, 'Europe/Berlin');
  const albanian = appointmentConfirmedCopy('sq', 'Planning', instant, 'Europe/Berlin');

  for (const message of [english, german, albanian]) {
    assert.match(message.body, /11:00/);
    assert.doesNotMatch(message.body, /Mon, 10 Aug 2026 09:00:00 GMT/);
  }
  assert.notEqual(english.body, german.body);
  assert.notEqual(german.body, albanian.body);
});

test('invalid notification time metadata falls back to localized generic copy', () => {
  assert.equal(
    appointmentConfirmedCopy(
      'de', 'Planung', new Date('2026-08-10T09:00:00.000Z'), 'Mars/Olympus',
    ).body,
    'Planung hat jetzt einen bestätigten Termin.',
  );
});
