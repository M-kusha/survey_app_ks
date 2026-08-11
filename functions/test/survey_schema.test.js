const assert = require('node:assert/strict');
const test = require('node:test');
const {
  validateSurveyDefinition,
} = require('../lib/survey_publication');

function definition(overrides = {}) {
  return {
    surveyName: 'Safety test',
    surveyDescription: 'Canonical publication',
    deadlineMillis: 2_000_000_000_000,
    timeLimitPerQuestion: 30,
    surveyType: 1,
    questions: [
      {
        type: 'Single',
        question: 'Pick one',
        options: ['A', 'B'],
        correctAnswer: 1,
      },
      {
        type: 'Multiple',
        question: 'Pick two',
        options: ['A', 'B', 'C'],
        correctAnswers: [0, 2],
      },
      { type: 'Text', question: 'Explain' },
    ],
    ...overrides,
  };
}

test('splits one exact request into public questions and private grading keys', () => {
  const validated = validateSurveyDefinition(definition());
  assert.deepEqual(validated.publicDefinition.questions, [
    { type: 'Single', question: 'Pick one', options: ['A', 'B'] },
    { type: 'Multiple', question: 'Pick two', options: ['A', 'B', 'C'] },
    { type: 'Text', question: 'Explain' },
  ]);
  assert.deepEqual(validated.questionKeys, [
    { type: 'Single', correctAnswer: 1 },
    { type: 'Multiple', correctAnswers: [0, 2] },
    { type: 'Text' },
  ]);
  assert.equal(JSON.stringify(validated.publicDefinition).includes('correctAnswer'), false);
});

test('ordinary surveys accept no grading fields on either side', () => {
  const raw = definition({
    surveyType: 0,
    questions: [
      { type: 'Single', question: 'Choose', options: ['A', 'B'] },
      { type: 'Text', question: 'Comment' },
    ],
  });
  assert.deepEqual(validateSurveyDefinition(raw).questionKeys, [
    { type: 'Single' },
    { type: 'Text' },
  ]);
  raw.questions[0].correctAnswer = 0;
  assert.throws(() => validateSurveyDefinition(raw), /survey-definition-invalid/);
});

test('unknown, aliased, nested, missing, duplicate and out-of-range grading fails closed', () => {
  const mutations = [
    (raw) => { raw.questions[0].answerKey = 1; },
    (raw) => { raw.questions[0].grading = { correctAnswer: 1 }; },
    (raw) => { raw.questions[0].surprise = true; },
    (raw) => { delete raw.questions[0].correctAnswer; },
    (raw) => { raw.questions[0].correctAnswer = 2; },
    (raw) => { raw.questions[1].correctAnswers = [0, 0]; },
    (raw) => { raw.questions = [raw.questions[0]]; },
    (raw) => { raw.unknown = true; },
  ];
  for (const mutate of mutations) {
    const raw = definition();
    mutate(raw);
    assert.throws(() => validateSurveyDefinition(raw), /survey-definition-invalid/);
  }
});
