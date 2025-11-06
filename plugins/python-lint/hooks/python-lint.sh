#!/usr/bin/env bash
#
# Python Lint Hook
# Automatically lints, formats, and type-checks Python files after Claude edits or writes them
#
# This hook:
# 1. Auto-fixes linting violations with 'ruff check --fix'
# 2. Formats code with 'ruff format'
# 3. Reports unfixable linting issues from ruff
# 4. Type-checks with 'pyright' and reports type errors
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

# Check if required tools are installed
MISSING_TOOLS=()

if ! command -v ruff &> /dev/null; then
    MISSING_TOOLS+=("ruff")
fi

if ! command -v pyright &> /dev/null; then
    MISSING_TOOLS+=("pyright")
fi

if ! command -v jq &> /dev/null; then
    MISSING_TOOLS+=("jq")
fi

if ! command -v realpath &> /dev/null; then
    MISSING_TOOLS+=("realpath")
fi

# If any critical tools are missing, report and exit
if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    TOOLS_LIST=$(IFS=", "; echo "${MISSING_TOOLS[*]}")
    if command -v jq &> /dev/null; then
        jq -n --arg tools "$TOOLS_LIST" '{hookSpecificOutput: {additionalContext: {error: ("Missing required tools: " + $tools + ". Install with: brew install " + $tools)}}}'
    else
        echo "{\"hookSpecificOutput\": {\"additionalContext\": {\"error\": \"Missing required tools: $TOOLS_LIST\"}}}"
    fi
    exit 0
fi

# Initialize variables
FORMAT_FAILED=""
FORMAT_STDERR=""

# Run ruff check --fix and format
# Suppress output since we'll get diagnostics at the end
ruff check --fix --exit-zero "$FILE_PATH" > /dev/null 2>&1

# Run ruff format and capture stderr (note: 2>&1 must come before >/dev/null)
FORMAT_STDERR=$(ruff format "$FILE_PATH" 2>&1 1>/dev/null) || FORMAT_FAILED="true"

# Run final ruff check to capture any remaining unfixable issues in JSON format
RUFF_DIAGNOSTICS_JSON=$(ruff check "$FILE_PATH" --output-format=json --exit-zero 2>/dev/null)

# Validate that we got valid JSON from ruff
if ! echo "$RUFF_DIAGNOSTICS_JSON" | jq -e . >/dev/null 2>&1; then
    RUFF_DIAGNOSTICS_JSON="[]"
fi

# Find project root for pyright (look for pyproject.toml or pyrightconfig.json)
PROJECT_ROOT=""
CURRENT_DIR=$(dirname "$(realpath "$FILE_PATH")")

while [[ "$CURRENT_DIR" != "/" ]]; do
    if [[ -f "$CURRENT_DIR/pyproject.toml" ]] || [[ -f "$CURRENT_DIR/pyrightconfig.json" ]]; then
        PROJECT_ROOT="$CURRENT_DIR"
        break
    fi
    CURRENT_DIR=$(dirname "$CURRENT_DIR")
done

# If no project root found, use the file's directory (use realpath for consistency)
if [[ -z "$PROJECT_ROOT" ]]; then
    PROJECT_ROOT=$(dirname "$(realpath "$FILE_PATH")")
fi

# Get relative path from project root
RELATIVE_FILE_PATH=$(realpath --relative-to="$PROJECT_ROOT" "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")

# Run pyright from project root
PYRIGHT_JSON=""
PYRIGHT_FAILED=""
PYRIGHT_ERROR=""

# Change to project root and run pyright (capture stdout and stderr separately)
PYRIGHT_STDERR_FILE=$(mktemp)
PYRIGHT_OUTPUT=$(cd "$PROJECT_ROOT" && pyright "$RELATIVE_FILE_PATH" --outputjson 2>"$PYRIGHT_STDERR_FILE") || PYRIGHT_FAILED="true"
PYRIGHT_STDERR=$(cat "$PYRIGHT_STDERR_FILE")
rm -f "$PYRIGHT_STDERR_FILE"

# Try to parse pyright stdout as JSON
if echo "$PYRIGHT_OUTPUT" | jq -e . >/dev/null 2>&1; then
    PYRIGHT_JSON="$PYRIGHT_OUTPUT"
    # If there was stderr output but JSON is valid, append stderr as additional context
    if [[ -n "$PYRIGHT_STDERR" ]]; then
        PYRIGHT_ERROR="$PYRIGHT_STDERR"
    fi
else
    # If pyright didn't output valid JSON, capture the error
    PYRIGHT_ERROR="$PYRIGHT_OUTPUT"
    if [[ -n "$PYRIGHT_STDERR" ]]; then
        PYRIGHT_ERROR="$PYRIGHT_STDERR\n$PYRIGHT_OUTPUT"
    fi
    PYRIGHT_JSON='{"generalDiagnostics": [], "summary": {"errorCount": 0, "warningCount": 0}}'
fi

# Extract and filter pyright diagnostics for the edited file only
# Convert zero-based line/column numbers to one-based
# Filter by absolute path (pyright returns absolute paths in diagnostics)
# Also handle diagnostics that may not have ranges (skip them)
ABSOLUTE_FILE_PATH=$(realpath "$FILE_PATH")
PYRIGHT_DIAGNOSTICS=$(echo "$PYRIGHT_JSON" | jq --arg filepath "$ABSOLUTE_FILE_PATH" '
.generalDiagnostics
| map(select(.file == $filepath))
| map(
    if .range then
        {
            file: .file,
            severity: .severity,
            message: .message,
            rule: .rule,
            range: {
                start: {
                    line: (.range.start.line + 1),
                    character: (.range.start.character + 1)
                },
                end: {
                    line: (.range.end.line + 1),
                    character: (.range.end.character + 1)
                }
            }
        }
    else
        {
            file: .file,
            severity: .severity,
            message: .message,
            rule: .rule
        }
    end
)
' 2>/dev/null || echo "[]")

# Check if there are any issues to report
HAS_RUFF_ISSUES=$(echo "$RUFF_DIAGNOSTICS_JSON" | jq 'length > 0' 2>/dev/null || echo "false")
HAS_PYRIGHT_ISSUES=$(echo "$PYRIGHT_DIAGNOSTICS" | jq 'length > 0' 2>/dev/null || echo "false")

# Report issues to Claude if any diagnostics exist, formatting failed, or pyright had errors
if [[ "$HAS_RUFF_ISSUES" == "true" ]] || [[ "$HAS_PYRIGHT_ISSUES" == "true" ]] || [[ -n "$FORMAT_FAILED" ]] || [[ -n "$PYRIGHT_ERROR" ]]; then
    jq -n \
        --argjson lintingIssues "$RUFF_DIAGNOSTICS_JSON" \
        --argjson typeErrors "$PYRIGHT_DIAGNOSTICS" \
        --arg formatError "${FORMAT_STDERR:-}" \
        --arg pyrightError "${PYRIGHT_ERROR:-}" \
        '{
            hookSpecificOutput: {
                additionalContext: {
                    lintingIssues: $lintingIssues,
                    typeErrors: $typeErrors,
                    formatError: (if $formatError == "" then null else $formatError end),
                    pyrightError: (if $pyrightError == "" then null else $pyrightError end)
                }
            }
        }'
fi

# Always exit with 0 to allow the operation to proceed
# Issues are reported to Claude via JSON output above
exit 0
