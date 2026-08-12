export type SurveyScore = {
  score: number;
  correctCount: number;
  gradedCount: number;
  hasPendingReview: boolean;
};

export function scoreSurveySubmission(
  rawQuestions: unknown,
  rawQuestionKeys: unknown,
  rawAnswers: unknown,
  rawTextReviews: unknown = {},
  surveyId = '',
): SurveyScore {
  const questions = Array.isArray(rawQuestions) ? rawQuestions : [];
  const questionKeys = Array.isArray(rawQuestionKeys) ? rawQuestionKeys : [];
  const answers = isRecord(rawAnswers) ? rawAnswers : {};
  const textReviews = isRecord(rawTextReviews) ? rawTextReviews : {};

  if (questions.length === 0 || questions.length !== questionKeys.length) {
    throw new Error('Survey answer-key shape does not match public questions.');
  }

  let credit = 0;
  let correctCount = 0;
  let gradedCount = 0;
  let hasPendingReview = false;

  questions.forEach((rawQuestion, index) => {
    const rawQuestionKey = questionKeys[index];
    if (!isRecord(rawQuestion) || !isRecord(rawQuestionKey)) {
      throw new Error(`Question ${index} or its private key is not a map.`);
    }
    if (rawQuestion.type !== rawQuestionKey.type) {
      throw new Error(`Question ${index} type does not match its private key.`);
    }

    const answerValue = answers[`Q${index}`];
    const answer = Array.isArray(answerValue) ? answerValue : [];

    switch (rawQuestion.type) {
      case 'Single': {
        const expected = rawQuestionKey.correctAnswer;
        const options = Array.isArray(rawQuestion.options)
          ? rawQuestion.options
          : [];
        if (
          !Number.isInteger(expected) ||
          (expected as number) < 0 ||
          (expected as number) >= options.length
        ) {
          throw new Error(`Question ${index} has an invalid private answer.`);
        }
        const correct =
          answer.length === 1 && answer[0] === expected;
        gradedCount += 1;
        if (correct) {
          credit += 1;
          correctCount += 1;
        }
        break;
      }

      case 'Multiple': {
        const options = Array.isArray(rawQuestion.options)
          ? rawQuestion.options
          : [];
        const rawExpected = rawQuestionKey.correctAnswers;
        if (
          !Array.isArray(rawExpected) ||
          rawExpected.length < 2 ||
          rawExpected.some(
            (value) =>
              !Number.isInteger(value) || value < 0 || value >= options.length,
          )
        ) {
          throw new Error(`Question ${index} has invalid private answers.`);
        }

        const expected = new Set(rawExpected);
        if (expected.size !== rawExpected.length) {
          throw new Error(`Question ${index} has duplicate private answers.`);
        }

        const chosen = new Set(answer);
        let hits = 0;
        let wrong = 0;

        for (const value of chosen) {
          if (expected.has(value)) hits += 1;
          else wrong += 1;
        }

        gradedCount += 1;
        credit += Math.max(0, Math.min(1, (hits - wrong) / expected.size));

        if (
          chosen.size === expected.size &&
          [...expected].every((value) => chosen.has(value))
        ) {
          correctCount += 1;
        }
        break;
      }

      case 'Text': {
        const hasWrittenAnswer = answer.some(
          (value) => String(value).trim().length > 0,
        );
        if (!hasWrittenAnswer) {
          gradedCount += 1;
          break;
        }

        const verdict = textReviews[`${surveyId}-Q${index}`];
        if (typeof verdict !== 'boolean') {
          hasPendingReview = true;
          break;
        }

        gradedCount += 1;
        if (verdict) {
          credit += 1;
          correctCount += 1;
        }
        break;
      }

      default:
        throw new Error(`Question ${index} has an unsupported type.`);
    }
  });

  return {
    score: gradedCount === 0 ? 0 : (credit / gradedCount) * 100,
    correctCount,
    gradedCount,
    hasPendingReview,
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
