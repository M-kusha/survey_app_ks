import { scoreSurveySubmission, SurveyScore } from './scoring';

export type TrustedSurveyGrade = SurveyScore & {
  gradingStatus: 'pending_review' | 'final';
};

export function scoreTrustedSurvey(args: {
  surveyId: string;
  survey: Record<string, unknown>;
  answerKey: Record<string, unknown> | undefined;
  response: Record<string, unknown>;
}): TrustedSurveyGrade {
  const { surveyId, survey, answerKey, response } = args;

  if (
    !answerKey ||
    answerKey.schemaVersion !== 1 ||
    answerKey.surveyId !== surveyId ||
    answerKey.companyId !== survey.companyId
  ) {
    throw new Error('Private survey answer key is missing or mismatched.');
  }

  if (survey.surveyType !== 1) {
    return {
      score: 0,
      correctCount: 0,
      gradedCount: 0,
      hasPendingReview: false,
      gradingStatus: 'final',
    };
  }

  const grade = scoreSurveySubmission(
    survey.questions,
    answerKey.questionKeys,
    response.answers,
    response.textAnswersReviewed,
    surveyId,
  );

  return {
    ...grade,
    gradingStatus: grade.hasPendingReview ? 'pending_review' : 'final',
  };
}
