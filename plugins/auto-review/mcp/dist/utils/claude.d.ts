export interface ClaudeReviewResult {
    review: string;
    usage?: {
        inputTokens?: number;
        outputTokens?: number;
    };
}
/**
 * Uses Claude Agent SDK to run a review and return the response
 */
export declare function runClaudeReview(prompt: string, cwd?: string): Promise<ClaudeReviewResult>;
//# sourceMappingURL=claude.d.ts.map