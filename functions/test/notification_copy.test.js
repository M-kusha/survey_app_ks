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
      appointmentConfirmedCopy(locale, 'Planning', 'Mon, 10 Aug 2026 09:00:00 GMT'),
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
