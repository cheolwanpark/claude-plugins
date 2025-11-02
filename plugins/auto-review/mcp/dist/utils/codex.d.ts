export interface CodexReviewResult {
    review: string;
    usage?: {
        inputTokens?: number;
        outputTokens?: number;
    };
}
/**
 * Uses Codex SDK to run a review and return the response
 */
export declare function runCodexReview(prompt: string, cwd?: string): Promise<CodexReviewResult>;
//# sourceMappingURL=codex.d.ts.map