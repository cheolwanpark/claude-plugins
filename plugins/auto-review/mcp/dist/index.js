#!/usr/bin/env node
import { startServer } from './server.js';
/**
 * Main entry point
 */
async function main() {
    try {
        // Start the MCP server
        await startServer();
    }
    catch (error) {
        console.error('Failed to start auto-review MCP server:', error);
        process.exit(1);
    }
}
main();
//# sourceMappingURL=index.js.map