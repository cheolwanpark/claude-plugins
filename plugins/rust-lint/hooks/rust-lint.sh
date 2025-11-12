#!/usr/bin/env bash
#
# Rust Lint Hook
# Automatically formats Rust files after Claude edits or writes them
#
# This hook:
# 1. Validates the file is a Rust source file (.rs)
# 2. Checks if rustfmt is available
# 3. Runs rustfmt to auto-format the file
# 4. Reports formatting status
#
# NOTE: This hook does NOT run clippy (too slow for per-file hooks).
#       Use the /rust-lint:lint-project command for comprehensive linting.
#

set -euo pipefail

# Get the plugin root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Source common library
# shellcheck disable=SC1091
source "$PLUGIN_ROOT/scripts/rust-lint-common.sh"

# File size limit (1MB)
MAX_FILE_SIZE=1048576

# ============================================================================
# Main Logic
# ============================================================================

# Read JSON input from stdin
INPUT=$(cat)

# Extract file path
FILE_PATH=$(_rl_parse_file_path "$INPUT")

# If no file path found, exit silently
if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Only process Rust files
if [[ ! "$FILE_PATH" =~ \.rs$ ]]; then
    exit 0
fi

# Check if file exists
if [[ ! -f "$FILE_PATH" ]]; then
    exit 0
fi

# Check file size
FILE_SIZE=$(wc -c < "$FILE_PATH" | tr -d ' ')
if [[ $FILE_SIZE -gt $MAX_FILE_SIZE ]]; then
    SIZE_MB=$(awk "BEGIN {printf \"%.2f\", $FILE_SIZE/1024/1024}")
    _rl_json_response "allow" "File is too large (${SIZE_MB}MB) to format automatically. Use 'cargo fmt' to format the entire project."
    exit 0
fi

# Check if required tools are installed
if ! _rl_check_required_tools rustfmt jq; then
    TOOLS_LIST=$(IFS=", "; echo "${_RL_MISSING_TOOLS[*]}")
    _rl_json_response "allow" "Missing required tools: $TOOLS_LIST. Install with: rustup component add rustfmt"
    exit 0
fi

# Find project root to use project-specific rustfmt configuration
FILE_DIR=$(dirname "$FILE_PATH")
PROJECT_ROOT=$(_rl_find_project_root "$FILE_DIR")

# Run rustfmt from project root to respect rustfmt.toml configuration
# Use a subshell to avoid changing the script's working directory
FORMAT_OUTPUT=$(
    if [[ -n "$PROJECT_ROOT" && -d "$PROJECT_ROOT" ]]; then
        cd "$PROJECT_ROOT" && rustfmt "$FILE_PATH" 2>&1
    else
        rustfmt "$FILE_PATH" 2>&1
    fi
)
FORMAT_EXIT=$?

# Check result
if [[ $FORMAT_EXIT -eq 0 ]]; then
    # Success - formatting applied (or file was already formatted)
    _rl_json_response "allow" "Formatting checked and applied with rustfmt"
    exit 0
else
    # Formatting failed (syntax error or other issue)
    ERROR_MSG="rustfmt failed (syntax error or incomplete code)"

    # Try to extract a helpful error message
    if echo "$FORMAT_OUTPUT" | grep -q "error:"; then
        ERROR_DETAIL=$(echo "$FORMAT_OUTPUT" | grep "error:" | head -3 | sed 's/^/  /')
        _rl_json_response "allow" "$ERROR_MSG" "PostToolUse" "$ERROR_DETAIL"
    else
        _rl_json_response "allow" "$ERROR_MSG"
    fi
    exit 0
fi
