import { z } from 'zod';
export declare const reviewPlanSchema: {
    plan: z.ZodString;
    user_purpose: z.ZodString;
    context: z.ZodString;
    cwd: z.ZodOptional<z.ZodString>;
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
export declare function reviewPlan(params: ReviewPlanParams): Promise<{
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
//# sourceMappingURL=review-plan.d.ts.map