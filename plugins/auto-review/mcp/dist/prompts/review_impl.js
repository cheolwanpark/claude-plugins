/**
 * Builds the prompt for reviewing an implementation
 */
export function buildReviewImplPrompt(plan, impl_detail, context) {
    return `Review the following implementation critically:

Original Plan:
${plan}

Implementation Details:
${impl_detail}

Context:
${context}

Provide a critical review focusing on:
1. Plan deviations - describe specific ways the implementation diverges from the plan
2. Correctness issues - identify bugs, errors, or incorrect logic with specific examples
3. Code quality problems - point out specific antipatterns, inefficiencies, or poor practices
4. Improvement suggestions - provide concrete, actionable recommendations

Be direct and critical. If you find bugs or issues, describe them specifically with examples. Avoid generic statements - focus on identifying concrete problems in the implementation.

Keep your review concise but thorough.`;
}
//# sourceMappingURL=review_impl.js.map