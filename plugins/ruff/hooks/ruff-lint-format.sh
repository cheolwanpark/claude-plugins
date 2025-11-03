#!/usr/bin/env bash
#
# Ruff Lint and Format Hook
# Automatically lints and formats Python files after Claude edits or writes them
#
# This hook:
# 1. Auto-fixes linting violations with 'ruff check --fix'
# 2. Formats code with 'ruff format'
# 3. Reports unfixable linting issues back to Claude
#

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

# Extract file path from the hook input
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('tool_input', {}).get('file_path', ''))" 2>/dev/null || echo "")

# If no file path found, exit silently
if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Only process Python files
if [[ ! "$FILE_PATH" =~ \.py$ ]]; then
    exit 0
fi

# Check if file exists (it should, since we just wrote/edited it)
if [[ ! -f "$FILE_PATH" ]]; then
    exit 0
fi

# Check if ruff is installed
if ! command -v ruff &> /dev/null; then
    # Report missing ruff as JSON context, don't block the operation
    if command -v jq &> /dev/null; then
        jq -n '{hookSpecificOutput: {additionalContext: {error: "ruff is not installed. Install it with: uv add --dev ruff"}}}'
    else
        echo '{"hookSpecificOutput": {"additionalContext": {"error": "ruff is not installed"}}}'
    fi
    exit 0
fi

# Initialize variables
FORMAT_FAILED=""
FORMAT_STDERR=""

# Run ruff check --fix and format
# Suppress output since we'll get diagnostics at the end
ruff check --fix --exit-zero "$FILE_PATH" > /dev/null 2>&1

# Run ruff format and capture stderr (not stdout which just lists formatted files)
FORMAT_STDERR=$(ruff format "$FILE_PATH" 2>&1 >/dev/null) || FORMAT_FAILED="true"

# Run final check once to capture any remaining unfixable issues in JSON format
# Separate stdout and stderr - only stdout should contain JSON
DIAGNOSTICS_JSON=$(ruff check "$FILE_PATH" --output-format=json --exit-zero 2>/dev/null)

# Validate that we got valid JSON from ruff
if ! echo "$DIAGNOSTICS_JSON" | jq -e . >/dev/null 2>&1; then
    # ruff check failed or output invalid JSON
    DIAGNOSTICS_JSON="[]"
fi

# Check if there are any issues to report
# Use jq to properly check if diagnostics array is empty
HAS_DIAGNOSTICS=$(echo "$DIAGNOSTICS_JSON" | jq 'length > 0' 2>/dev/null || echo "false")

# Report issues to Claude if any diagnostics exist or formatting failed
if [[ "$HAS_DIAGNOSTICS" == "true" ]] || [[ -n "$FORMAT_FAILED" ]]; then
    # Check if jq is available for proper JSON generation
    if command -v jq &> /dev/null; then
        # Always use consistent object schema
        jq -n \
            --argjson lintingIssues "$DIAGNOSTICS_JSON" \
            --arg formatError "${FORMAT_STDERR:-}" \
            '{
                hookSpecificOutput: {
                    additionalContext: {
                        lintingIssues: $lintingIssues,
                        formatError: (if $formatError == "" then null else $formatError end)
                    }
                }
            }'
    elif command -v python3 &> /dev/null; then
        # Fallback to python3 if jq is not available
        # Use proper argument passing to avoid injection
        python3 -c '
import json
import sys

diagnostics_json = sys.argv[1]
format_error = sys.argv[2] if len(sys.argv) > 2 else ""

try:
    diagnostics = json.loads(diagnostics_json)
except json.JSONDecodeError:
    diagnostics = []

context = {
    "lintingIssues": diagnostics,
    "formatError": format_error if format_error else None
}

output = {
    "hookSpecificOutput": {
        "additionalContext": context
    }
}
print(json.dumps(output))
' "$DIAGNOSTICS_JSON" "${FORMAT_STDERR:-}"
    else
        # No JSON tools available, output minimal valid JSON
        echo '{"hookSpecificOutput": {"additionalContext": {"error": "jq and python3 not available"}}}'
    fi
fi

# Always exit with 0 to allow the operation to proceed
# Issues are reported to Claude via JSON output above
exit 0
