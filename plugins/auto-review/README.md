# Auto-Review Plugin

Automated triple-AI code review system for Claude Code that provides critical feedback on plans and implementations using Gemini, Codex, and Claude in parallel.

## Overview

The auto-review plugin integrates with Claude Code through hooks and an MCP (Model Context Protocol) server to automatically trigger comprehensive code reviews at strategic workflow points:
- **Before executing plans** - Critical review of feasibility, risks, and gaps
- **Before completing work** - Critical review of implementation quality and correctness

## Concept & Mechanism

The plugin intercepts Claude's workflow using hooks, which trigger triple-AI reviews via an MCP server:

```
User Action
    ↓
Hook Intercepts (bash scripts)
    ↓
MCP Server Receives Request (TypeScript)
    ↓
    ├─→ Gemini CLI Review (parallel)
    ├─→ Codex SDK Review (parallel)
    └─→ Claude Agent SDK Review (parallel)
    ↓
Aggregated Results
    ↓
Claude Analyzes & Acts on Feedback
```

### Workflow Details

1. **Plan Mode Entry**: `UserPromptSubmit` hook detects plan mode and sets review flag
2. **Plan Review Trigger**: `PreToolUse` hook blocks `ExitPlanMode`, prompts Claude to call `review_plan`
3. **Implementation Review**: `Stop` hook prompts Claude to self-evaluate and call `review_impl` if significant changes were made
4. **Triple-AI Processing**: MCP server runs Gemini, Codex, and Claude reviews in parallel
5. **Feedback Integration**: Claude receives critical feedback and may revise plan/code

## Hooks

The plugin uses 3 hooks to intercept workflow events:

### 1. UserPromptSubmit Hook
- **File**: `hooks/user_prompt_submit.sh`
- **Trigger**: When user submits a prompt
- **Action**: Detects plan mode entry and creates flag file `/tmp/<session_id>/.auto_review_required`
- **Purpose**: Mark that plan review is needed

### 2. PreToolUse Hook (ExitPlanMode)
- **File**: `hooks/pre_exit_plan_mode.sh`
- **Trigger**: Before Claude calls `ExitPlanMode` tool
- **Action**:
  - Checks for review flag file
  - If exists: Blocks with exit code 2, instructs Claude to call `review_plan`, deletes flag
  - If not: Allows ExitPlanMode to proceed
- **Purpose**: Ensure plans are reviewed before execution

### 3. Stop Hook
- **File**: `hooks/on_stop.sh`
- **Trigger**: When Claude is about to stop/finish
- **Action**: Outputs evaluation prompt for Claude to self-evaluate if significant implementation occurred
- **Output**: Returns JSON decision to block/approve with instructions to call `review_impl`
- **Purpose**: Ensure implementations are reviewed before completion

## MCP Server

Located in `mcp/` directory, provides 2 review tools via Model Context Protocol:

### review_plan

Reviews project plans for feasibility and potential issues using Gemini, Codex, and Claude.

**Parameters:**
- `plan` (string): The plan to review
- `user_purpose` (string): User's intended purpose or goal
- `context` (string): Additional context for the review
- `cwd` (string, optional): Working directory

**Returns:**
```json
{
  "review_by_gemini": "Critical analysis...",
  "review_by_codex": "Critical analysis...",
  "review_by_claude": "Critical analysis..."
}
```

**Focus Areas:**
- Feasibility issues (what won't work and why)
- Potential risks/problems (concrete issues)
- Missing considerations
- Actionable improvements

### review_impl

Reviews implementations against plans using Gemini, Codex, and Claude.

**Parameters:**
- `plan` (string): The original plan
- `impl_detail` (string): Implementation details to review
- `context` (string): Additional context
- `cwd` (string, optional): Working directory

**Returns:**
```json
{
  "review_by_gemini": "Critical analysis...",
  "review_by_codex": "Critical analysis...",
  "review_by_claude": "Critical analysis..."
}
```

**Focus Areas:**
- Plan deviations (how implementation differs)
- Correctness issues (bugs, errors, logic problems)
- Code quality problems (antipatterns, inefficiencies)
- Concrete improvement suggestions

## Prerequisites

Install these tools before using the plugin:

- **Node.js 18+** - For MCP server
- **[gemini-cli](https://github.com/google-gemini/gemini-cli)** - Gemini AI integration
- **[Codex SDK](https://openai.com/index/introducing-codex/)** - OpenAI Codex integration
- **Claude Code** - With active authentication (used by Claude Agent SDK)
- **jq** - JSON parsing in bash hooks

## Installation

### 1. Install MCP Server Dependencies

```bash
cd plugins/auto-review/mcp
npm install
npm run build
```

### 2. Configure MCP Server

Add to your `.mcp.json`:

```json
{
  "mcpServers": {
    "auto-review": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y",
        "/absolute/path/to/useful-claude-plugins/plugins/auto-review/mcp"
      ],
      "env": {}
    }
  }
}
```

**Alternative configurations:**

Using node directly:
```json
{
  "mcpServers": {
    "auto-review": {
      "type": "stdio",
      "command": "node",
      "args": [
        "/absolute/path/to/plugins/auto-review/mcp/dist/index.js"
      ],
      "env": {}
    }
  }
}
```

### 3. Enable Plugin

The hooks are automatically loaded from `hooks/hooks.json` when the plugin is installed.

## Example

When Claude creates a plan to add a new authentication feature:

1. **Plan Mode Entry**: User requests "Add OAuth authentication"
2. **Claude Creates Plan**: Outlines steps for OAuth integration
3. **Review Triggered**: PreToolUse hook blocks ExitPlanMode
4. **Triple Review Runs**:
   - **Gemini**: "Missing rate limiting, session management, CSRF protection..."
   - **Codex**: "No token refresh strategy, security headers not considered..."
   - **Claude**: "Lacks error handling for OAuth failures, missing state validation..."
5. **Claude Revises**: Incorporates feedback, adds missing security measures
6. **Execution Approved**: Plan proceeds with improvements

Similar workflow occurs for implementation reviews when work is completed.

## Project Structure

```
plugins/auto-review/
├── .claude-plugin/
│   └── plugin.json           # Plugin metadata
├── .mcp.json                  # MCP server configuration
├── hooks/
│   ├── hooks.json             # Hook definitions
│   ├── user_prompt_submit.sh # Plan mode detector
│   ├── pre_exit_plan_mode.sh # Plan review trigger
│   └── on_stop.sh             # Implementation review evaluator
└── mcp/                       # MCP server implementation
    ├── src/
    │   ├── server.ts          # MCP server & tool registration
    │   ├── tools/             # review_plan, review_impl
    │   ├── prompts/           # Review prompt builders
    │   └── utils/             # Gemini/Codex wrappers
    └── dist/                  # Compiled output
```

## Development

```bash
cd mcp

# Install dependencies
npm install

# Build
npm run build

# Watch mode (auto-rebuild)
npm run dev
```

## License

MIT
