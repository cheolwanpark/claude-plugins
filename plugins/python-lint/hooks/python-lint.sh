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

# Get the plugin root directory (parent of hooks directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Source common library
# shellcheck disable=SC1091
source "$PLUGIN_ROOT/scripts/python-lint-common.sh"

# Read JSON input from stdin
INPUT=$(cat)

# Extract file path from the hook input
FILE_PATH=$(_pyl_parse_file_path "$INPUT")

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

# Check if required tools are installed (realpath is optional now)
if ! _pyl_check_required_tools ruff pyright jq; then
    TOOLS_LIST=$(IFS=", "; echo "${_PYL_MISSING_TOOLS[*]}")
    _pyl_json_response "allow" "Missing required tools: $TOOLS_LIST. Install with: brew install $TOOLS_LIST"
    exit 0
fi

# Find project root from file's directory
FILE_DIR=$(dirname "$FILE_PATH")
PROJECT_ROOT=$(_pyl_find_project_root "$FILE_DIR")

# Activate virtual environment if present
_pyl_activate_venv "$PROJECT_ROOT"

# Build ruff config arguments
_pyl_build_ruff_config_args "$PROJECT_ROOT" "$PLUGIN_ROOT"

# Initialize variables
FORMAT_FAILED=""
FORMAT_STDERR=""

# Run ruff check --fix and format
# Suppress output since we'll get diagnostics at the end
ruff check --fix ${_PYL_RUFF_CONFIG_ARGS[@]+"${_PYL_RUFF_CONFIG_ARGS[@]}"} --exit-zero "$FILE_PATH" > /dev/null 2>&1

# Run ruff format with same config and capture stderr
FORMAT_STDERR=$(ruff format ${_PYL_RUFF_CONFIG_ARGS[@]+"${_PYL_RUFF_CONFIG_ARGS[@]}"} "$FILE_PATH" 2>&1 1>/dev/null) || FORMAT_FAILED="true"

# Run final ruff check to capture any remaining unfixable issues in JSON format
RUFF_DIAGNOSTICS_JSON=$(ruff check "$FILE_PATH" ${_PYL_RUFF_CONFIG_ARGS[@]+"${_PYL_RUFF_CONFIG_ARGS[@]}"} --output-format=json --exit-zero 2>/dev/null)

# Validate that we got valid JSON from ruff
if ! echo "$RUFF_DIAGNOSTICS_JSON" | jq -e . >/dev/null 2>&1; then
    RUFF_DIAGNOSTICS_JSON="[]"
fi

# Get relative path from project root for pyright
RELATIVE_FILE_PATH=$(_pyl_get_relative_path "$FILE_PATH" "$PROJECT_ROOT")

# Run pyright from project root
PYRIGHT_JSON=""
PYRIGHT_FAILED=""
PYRIGHT_ERROR=""

# Create temp files for pyright output with proper cleanup
PYRIGHT_STDERR_FILE=$(mktemp)
trap 'rm -f "$PYRIGHT_STDERR_FILE"' EXIT

# Change to project root and run pyright (capture stdout and stderr separately)
PYRIGHT_OUTPUT=$(cd "$PROJECT_ROOT" && pyright "$RELATIVE_FILE_PATH" --outputjson 2>"$PYRIGHT_STDERR_FILE") || PYRIGHT_FAILED="true"
PYRIGHT_STDERR=$(cat "$PYRIGHT_STDERR_FILE")

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
ABSOLUTE_FILE_PATH=$(_pyl_get_absolute_path "$FILE_PATH")
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
    # Count issues for summary
    RUFF_COUNT=$(echo "$RUFF_DIAGNOSTICS_JSON" | jq 'length' 2>/dev/null || echo "0")
    PYRIGHT_COUNT=$(echo "$PYRIGHT_DIAGNOSTICS" | jq 'length' 2>/dev/null || echo "0")

    # Build reason message
    REASON_PARTS=()
    if [[ "$RUFF_COUNT" -gt 0 ]]; then
        REASON_PARTS+=("$RUFF_COUNT linting issue(s)")
    fi
    if [[ "$PYRIGHT_COUNT" -gt 0 ]]; then
        REASON_PARTS+=("$PYRIGHT_COUNT type error(s)")
    fi
    if [[ -n "$FORMAT_FAILED" ]]; then
        REASON_PARTS+=("formatting failed")
    fi
    if [[ -n "$PYRIGHT_ERROR" ]]; then
        REASON_PARTS+=("pyright error")
    fi

    # Join reason parts with commas
    REASON=$(IFS=", "; echo "${REASON_PARTS[*]}")

    # Format ruff diagnostics as concise text (limit to 10)
    RUFF_TEXT=""
    if [[ "$RUFF_COUNT" -gt 0 ]]; then
        RUFF_TEXT=$(echo "$RUFF_DIAGNOSTICS_JSON" | jq -r '
            .[0:10] | map(
                "  - line \(.location.row):\(.location.column) [\(.code)] \(.message)"
            ) | join("\n")
        ' 2>/dev/null || echo "")

        if [[ "$RUFF_COUNT" -gt 10 ]]; then
            REMAINING=$((RUFF_COUNT - 10))
            RUFF_TEXT="$RUFF_TEXT\n  ... and $REMAINING more"
        fi
    fi

    # Format pyright diagnostics as concise text (limit to 10)
    PYRIGHT_TEXT=""
    if [[ "$PYRIGHT_COUNT" -gt 0 ]]; then
        PYRIGHT_TEXT=$(echo "$PYRIGHT_DIAGNOSTICS" | jq -r '
            .[0:10] | map(
                if .range then
                    "  - line \(.range.start.line):\(.range.start.character) [\(.severity)] \(.message)"
                else
                    "  - [\(.severity)] \(.message)"
                end
            ) | join("\n")
        ' 2>/dev/null || echo "")

        if [[ "$PYRIGHT_COUNT" -gt 10 ]]; then
            REMAINING=$((PYRIGHT_COUNT - 10))
            PYRIGHT_TEXT="$PYRIGHT_TEXT\n  ... and $REMAINING more"
        fi
    fi

    # Build formatted context message
    CONTEXT_MESSAGE=""

    if [[ -n "$RUFF_TEXT" ]]; then
        CONTEXT_MESSAGE="${CONTEXT_MESSAGE}Linting Issues ($RUFF_COUNT):\n$RUFF_TEXT\n\n"
    fi

    if [[ -n "$PYRIGHT_TEXT" ]]; then
        CONTEXT_MESSAGE="${CONTEXT_MESSAGE}Type Errors ($PYRIGHT_COUNT):\n$PYRIGHT_TEXT\n\n"
    fi

    if [[ -n "$FORMAT_FAILED" ]]; then
        CONTEXT_MESSAGE="${CONTEXT_MESSAGE}Formatting Error:\n  $FORMAT_STDERR\n\n"
    fi

    if [[ -n "$PYRIGHT_ERROR" ]]; then
        CONTEXT_MESSAGE="${CONTEXT_MESSAGE}Pyright Error:\n  $PYRIGHT_ERROR\n\n"
    fi

    # Remove trailing newlines
    CONTEXT_MESSAGE=$(echo -e "$CONTEXT_MESSAGE" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')

    _pyl_json_response "block" "Python linting/type checking found issues: $REASON" "PostToolUse" "$CONTEXT_MESSAGE"
fi

# Always exit with 0 to allow the operation to proceed
# The "decision": "block" in JSON output above will prompt Claude about the issues
exit 0
