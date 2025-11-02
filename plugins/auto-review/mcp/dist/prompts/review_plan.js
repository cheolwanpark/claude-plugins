/**
 * Builds the prompt for reviewing a plan
 */
export function buildReviewPlanPrompt(user_purpose, plan, context) {
    return `Review the following plan critically:

User Purpose:
${user_purpose}

Plan:
${plan}

Context:
${context}

Provide a critical review focusing on:
1. Feasibility issues - be specific about what won't work and why
2. Potential risks or problems - describe concrete issues you foresee
3. Missing considerations - point out what the plan overlooks
4. Suggestions for improvement - provide actionable alternatives

Be direct and critical. If you find issues, describe them in detail rather than being vague. Avoid generic praise - focus on identifying problems and gaps.

Keep your review concise but thorough.`;
}
//# sourceMappingURL=review_plan.js.map