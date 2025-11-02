export interface GeminiResponse {
    response: string;
    stats?: {
        models?: Record<string, any>;
        tools?: Record<string, any>;
        files?: Record<string, any>;
    };
    error?: {
        type: string;
        message: string;
        code?: number;
    };
}
/**
 * Spawns gemini-cli in headless mode and returns the JSON response
 */
export declare function runGemini(prompt: string, cwd?: string): Promise<GeminiResponse>;
//# sourceMappingURL=gemini.d.ts.map