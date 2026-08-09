const assert = require('node:assert/strict');
const { describe, it } = require('node:test');

const { scoreTrustedSurvey } = require('../lib/trusted_scoring');

const survey = {
  companyId: 'company-1',
  createdBy: 'author-1',
  questions: [
    { type: 'Single', question: 'Pick', options: ['A', 'B'] },
    { type: 'Text', question: 'Explain' },
  ],
  surveyType: 1,
};

const answerKey = {
  schemaVersion: 1,
  surveyId: 'survey-1',
  companyId: 'company-1',
  questionKeys: [
    { type: 'Single', correctAnswer: 1 },
    { type: 'Text' },
  ],
};

describe('trusted answer-key envelope', () => {
  it('returns a pending authoritative score without exposing the key', () => {
    assert.deepEqual(
      scoreTrustedSurvey({
        surveyId: 'survey-1',
        survey,
        answerKey,
        response: {
          answers: { Q0: [1], Q1: ['Because'] },
          textAnswersReviewed: {},
        },
      }),
      {
        score: 100,
        correctCount: 1,
        gradedCount: 1,
        hasPendingReview: true,
        gradingStatus: 'pending_review',
      },
    );
  });

  it('rejects a key copied from another tenant or survey', () => {
    assert.throws(
      () =>
        scoreTrustedSurvey({
          surveyId: 'survey-1',
          survey,
          answerKey: { ...answerKey, companyId: 'company-2' },
          response: { answers: { Q0: [1] } },
        }),
      /missing or mismatched/,
    );
  });

  it('does not grade ordinary survey responses', () => {
    assert.deepEqual(
      scoreTrustedSurvey({
        surveyId: 'survey-1',
        survey: { ...survey, surveyType: 0 },
        answerKey,
        response: { answers: { Q0: [1] } },
      }),
      {
        score: 0,
        correctCount: 0,
        gradedCount: 0,
        hasPendingReview: false,
        gradingStatus: 'final',
      },
    );
  });
});
