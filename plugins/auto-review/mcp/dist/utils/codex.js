import { Codex } from '@openai/codex-sdk';
/**
 * Uses Codex SDK to run a review and return the response
 */
export async function runCodexReview(prompt, cwd) {
    const codex = new Codex();
    const thread = codex.startThread({
        workingDirectory: cwd || process.cwd(),
        skipGitRepoCheck: true // Allow non-git directories
    });
    try {
        const turn = await thread.run(prompt);
        return {
            review: turn.finalResponse,
            usage: {
                inputTokens: turn.usage?.input_tokens,
                outputTokens: turn.usage?.output_tokens
            }
        };
    }
    catch (error) {
        throw new Error(`Codex review failed: ${error instanceof Error ? error.message : String(error)}`);
    }
}
//# sourceMappingURL=codex.js.map