import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { reviewPlan, reviewPlanSchema } from './tools/review-plan.js';
import { reviewImpl, reviewImplSchema } from './tools/review-impl.js';
/**
 * Creates and configures the MCP server with review tools
 */
export function createServer() {
    const server = new McpServer({
        name: 'auto-review-server',
        version: '1.0.0'
    });
    // Register review_plan tool
    server.registerTool('review_plan', {
        title: 'Review Plan',
        description: 'Review a plan using gemini-cli to provide feedback on feasibility and potential issues',
        inputSchema: reviewPlanSchema
    }, async (params) => {
        return reviewPlan(params);
    });
    // Register review_impl tool
    server.registerTool('review_impl', {
        title: 'Review Implementation',
        description: 'Review an implementation using Codex to verify it matches the plan and suggest improvements',
        inputSchema: reviewImplSchema
    }, async (params) => {
        return reviewImpl(params);
    });
    return server;
}
/**
 * Starts the MCP server with stdio transport
 */
export async function startServer() {
    const server = createServer();
    const transport = new StdioServerTransport();
    await server.connect(transport);
    // Log to stderr (stdout is used for MCP communication)
    console.error('Auto-review MCP server started');
}
//# sourceMappingURL=server.js.map