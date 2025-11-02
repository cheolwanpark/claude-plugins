import { z } from 'zod';
import { runGemini } from '../utils/gemini.js';
import { runCodexReview } from '../utils/codex.js';
import { runClaudeReview } from '../utils/claude.js';
import { buildReviewPlanPrompt } from '../prompts/review_plan.js';

export const reviewPlanSchema = {
  plan: z.string().describe('The plan to review'),
  user_purpose: z.string().describe('The user\'s intended purpose or goal'),
  context: z.string().describe('Additional context for the review'),
  cwd: z.string().optional().describe('Working directory for running gemini-cli (optional)')
};

export interface ReviewPlanParams {
  plan: string;
  user_purpose: string;
  context: string;
  cwd?: string;
}

/**
 * Reviews a plan using gemini-cli, Codex, and Claude in parallel
 */
export async function reviewPlan(params: ReviewPlanParams) {
  const { plan, user_purpose, context, cwd } = params;

  // Construct the prompt
  const prompt = buildReviewPlanPrompt(user_purpose, plan, context);

  // Run all three reviews in parallel
  const [geminiResult, codexResult, claudeResult] = await Promise.allSettled([
    runGemini(prompt, cwd),
    runCodexReview(prompt, cwd),
    runClaudeReview(prompt, cwd)
  ]);

  // Process Gemini result
  let review_by_gemini: string;
  if (geminiResult.status === 'fulfilled') {
    const response = geminiResult.value;
    if (response.error) {
      review_by_gemini = `Error: ${response.error.message}`;
    } else {
      review_by_gemini = response.response;
    }
  } else {
    review_by_gemini = `Error: ${geminiResult.reason instanceof Error ? geminiResult.reason.message : String(geminiResult.reason)}`;
  }

  // Process Codex result
  let review_by_codex: string;
  if (codexResult.status === 'fulfilled') {
    review_by_codex = codexResult.value.review;
  } else {
    review_by_codex = `Error: ${codexResult.reason instanceof Error ? codexResult.reason.message : String(codexResult.reason)}`;
  }

  // Process Claude result
  let review_by_claude: string;
  if (claudeResult.status === 'fulfilled') {
    review_by_claude = claudeResult.value.review;
  } else {
    review_by_claude = `Error: ${claudeResult.reason instanceof Error ? claudeResult.reason.message : String(claudeResult.reason)}`;
  }

  // Build response
  const responseObj = {
    review_by_gemini,
    review_by_codex,
    review_by_claude
  };

  return {
    content: [{
      type: 'text' as const,
      text: JSON.stringify(responseObj, null, 2)
    }],
    structuredContent: responseObj
  };
}
