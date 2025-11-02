import { query } from '@anthropic-ai/claude-agent-sdk';
/**
 * Uses Claude Agent SDK to run a review and return the response
 */
export async function runClaudeReview(prompt, cwd) {
    try {
        const result = query({
            prompt,
            options: {
                cwd: cwd || process.cwd(),
                allowedTools: ['Read', 'Grep', 'Glob'], // Read-only tools for safety
                permissionMode: 'bypassPermissions', // Avoid permission prompts in automated review
                systemPrompt: 'You are a critical code reviewer. Provide direct, specific feedback focusing on issues, risks, and improvements. Be concise but thorough.'
            }
        });
        // Iterate through messages to get the final result
        for await (const message of result) {
            if (message.type === 'result') {
                // Check if the review completed successfully
                if (message.subtype === 'success') {
                    return {
                        review: message.result || 'No response from Claude',
                        usage: {
                            inputTokens: message.usage?.input_tokens ?? 0,
                            outputTokens: message.usage?.output_tokens ?? 0
                        }
                    };
                }
                else {
                    // Handle error cases (error_max_turns, error_during_execution)
                    throw new Error(`Claude review failed with subtype: ${message.subtype}`);
                }
            }
        }
        // If we exit the loop without a result message
        throw new Error('Claude review did not complete - no result message received');
    }
    catch (error) {
        throw new Error(`Claude review failed: ${error instanceof Error ? error.message : String(error)}`);
    }
}
//# sourceMappingURL=claude.js.map