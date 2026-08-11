const assert = require('node:assert/strict');
const { describe, it } = require('node:test');

const { scoreSurveySubmission } = require('../lib/scoring');

describe('trusted survey scoring', () => {
  it('matches single-choice and proportional multiple-choice grading', () => {
    const grade = scoreSurveySubmission(
      [
        { type: 'Single', options: ['A', 'B', 'C'] },
        { type: 'Multiple', options: ['A', 'B', 'C', 'D'] },
        { type: 'Text' },
      ],
      [
        { type: 'Single', correctAnswer: 2 },
        { type: 'Multiple', correctAnswers: [0, 1] },
        { type: 'Text' },
      ],
      {
        Q0: [2],
        // One hit and one wrong earns zero credit, matching the Flutter scorer.
        Q1: [0, 3],
        Q2: ['free text'],
      },
    );

    assert.deepEqual(grade, {
      score: 50,
      correctCount: 1,
      gradedCount: 2,
      hasPendingReview: true,
    });
  });

  it('deduplicates repeated selections and gives full credit only for an exact set', () => {
    const grade = scoreSurveySubmission(
      [{ type: 'Multiple', options: ['A', 'B', 'C'] }],
      [{ type: 'Multiple', correctAnswers: [0, 2] }],
      { Q0: [0, 0, 2] },
    );

    assert.deepEqual(grade, {
      score: 100,
      correctCount: 1,
      gradedCount: 1,
      hasPendingReview: false,
    });
  });

  it('fails closed for missing or mismatched private grading material', () => {
    assert.throws(
      () => scoreSurveySubmission(null, null, 'not-a-map'),
      /answer-key shape/,
    );
    assert.throws(
      () =>
        scoreSurveySubmission(
          [{ type: 'Single', options: ['A'] }],
          [{ type: 'Multiple', correctAnswers: [0, 1] }],
          { Q0: [0] },
        ),
      /type does not match/,
    );

    assert.deepEqual(
      scoreSurveySubmission(
        [{ type: 'Text' }],
        [{ type: 'Text' }],
        { Q0: ['answer'] },
      ),
      {
        score: 0,
        correctCount: 0,
        gradedCount: 0,
        hasPendingReview: true,
      },
    );
  });

  it('treats an unanswered timed text question as a final incorrect answer', () => {
    assert.deepEqual(
      scoreSurveySubmission(
        [{ type: 'Text' }],
        [{ type: 'Text' }],
        { Q0: [] },
      ),
      {
        score: 0,
        correctCount: 0,
        gradedCount: 1,
        hasPendingReview: false,
      },
    );
  });

  it('includes a reviewed text answer using the same survey-scoped key as Flutter', () => {
    const grade = scoreSurveySubmission(
      [
        { type: 'Single', options: ['A', 'B'] },
        { type: 'Text' },
      ],
      [
        { type: 'Single', correctAnswer: 1 },
        { type: 'Text' },
      ],
      { Q0: [1], Q1: ['because'] },
      { 'survey-42-Q1': false },
      'survey-42',
    );

    assert.deepEqual(grade, {
      score: 50,
      correctCount: 1,
      gradedCount: 2,
      hasPendingReview: false,
    });
  });

  it('malformed and unknown reviews remain pending without granting credit', () => {
    const score = () => scoreSurveySubmission(
      [{ type: 'Text' }],
      [{ type: 'Text' }],
      { Q0: ['answer'] },
      {
        'survey-42-Q0': 'true',
        'survey-42-Q99': true,
      },
      'survey-42',
    );

    const first = score();
    assert.deepEqual(first, {
      score: 0,
      correctCount: 0,
      gradedCount: 0,
      hasPendingReview: true,
    });
    assert.deepEqual(score(), first);
  });
});
