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

# Read JSON input from stdin with timeout to prevent indefinite hangs
# Use timeout if available (GNU coreutils), otherwise fallback to cat
if command -v timeout &>/dev/null; then
    INPUT=$(timeout 5s cat 2>/dev/null || true)
else
    INPUT=$(cat)
fi

# If no file path found or input is empty/timeout, exit silently
if [[ -z "$INPUT" ]]; then
    exit 0
fi

# Extract file path (don't fail on parse errors due to set -e)
FILE_PATH=$(_rl_parse_file_path "$INPUT" || echo "")

if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Only process Rust files - exit silently for non-Rust files
if [[ ! "$FILE_PATH" =~ \.rs$ ]]; then
    exit 0
fi

# Check if file exists - exit silently if it doesn't
if [[ ! -f "$FILE_PATH" ]]; then
    exit 0
fi

# Check file size - exit silently for large files
FILE_SIZE=$(wc -c < "$FILE_PATH" | tr -d ' ')
if [[ $FILE_SIZE -gt $MAX_FILE_SIZE ]]; then
    # Large files are skipped without notification to reduce noise
    # Users can run 'cargo fmt' manually for the entire project
    exit 0
fi

# Check if required tools are installed - exit silently if missing
if ! _rl_check_required_tools rustfmt jq; then
    # If tools are missing, silently skip formatting
    # User will see error when running the /rust-lint:lint-project command
    exit 0
fi

# Find project root to use project-specific rustfmt configuration
FILE_DIR=$(dirname "$FILE_PATH")
PROJECT_ROOT=$(_rl_find_project_root "$FILE_DIR")

# Run rustfmt from project root to respect rustfmt.toml configuration
# Use a subshell to avoid changing the script's working directory
# Capture stderr separately to prevent it from corrupting JSON output
# rustfmt modifies files in-place, we only need to capture stderr and exit code
FORMAT_EXIT=0
FORMAT_STDERR=$(
    if [[ -n "$PROJECT_ROOT" && -d "$PROJECT_ROOT" ]]; then
        (cd "$PROJECT_ROOT" && rustfmt "$FILE_PATH") 2>&1 >/dev/null
    else
        rustfmt "$FILE_PATH" 2>&1 >/dev/null
    fi
) || FORMAT_EXIT=$?

# Check result
if [[ $FORMAT_EXIT -eq 0 ]]; then
    # Success - formatting applied (or file was already formatted)
    # Exit silently - no need to notify Claude about successful formatting
    exit 0
else
    # Formatting failed (syntax error or other issue)
    # Report the error but allow the operation to proceed (exit 0)
    # This ensures the hook never blocks Claude's file operations
    exit 0
fi
