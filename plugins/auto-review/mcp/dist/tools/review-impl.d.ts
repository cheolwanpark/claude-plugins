import { z } from 'zod';
export declare const reviewImplSchema: {
    plan: z.ZodString;
    impl_detail: z.ZodString;
    context: z.ZodString;
    cwd: z.ZodOptional<z.ZodString>;
};
export interface ReviewImplParams {
    plan: string;
    impl_detail: string;
    context: string;
    cwd?: string;
}
/**
 * Reviews an implementation using Codex SDK, gemini-cli, and Claude in parallel
 */
export declare function reviewImpl(params: ReviewImplParams): Promise<{
    content: {
        type: "text";
        text: string;
    }[];
    structuredContent: {
        review_by_gemini: string;
        review_by_codex: string;
        review_by_claude: string;
    };
}>;
//# sourceMappingURL=review-impl.d.ts.map