#!/usr/bin/env bash
set -euo pipefail

# Hook script for go-lint plugin
# Runs goimports and go vet on edited Go files

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Source common library
source "$PLUGIN_ROOT/scripts/go-lint-common.sh"

# Constants
MAX_FILE_SIZE=1048576  # 1MB

# Read stdin input
INPUT=$(cat)

# Parse file path from JSON input
FILE_PATH=$(_gol_parse_file_path "$INPUT")

# Exit silently if no file path found
if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Exit silently if file doesn't exist
if [[ ! -f "$FILE_PATH" ]]; then
    exit 0
fi

# Exit silently if not a Go file
if [[ ! "$FILE_PATH" =~ \.go$ ]]; then
    exit 0
fi

# Check file size (skip files > 1MB)
FILE_SIZE=$(wc -c < "$FILE_PATH" | tr -d ' ')
if [[ $FILE_SIZE -gt $MAX_FILE_SIZE ]]; then
    exit 0
fi

# Check for required tools
if ! _gol_check_required_tools goimports go jq; then
    MISSING_TOOLS="${_gol_MISSING_TOOLS[*]}"
    _gol_safe_exit "allow" \
        "Go linting skipped: missing tools" \
        "PostToolUse" \
        "Missing required tools: $MISSING_TOOLS. Install with: go install golang.org/x/tools/cmd/goimports@latest"
fi

# Get file directory and find project root
FILE_DIR=$(dirname "$FILE_PATH")
FILE_ABS=$(_gol_get_absolute_path "$FILE_PATH")
PROJECT_ROOT=$(_gol_find_project_root "$FILE_DIR")

# If no project root found, still try to format but skip go vet
if [[ -z "$PROJECT_ROOT" ]]; then
    # Just run goimports
    GOIMPORTS_OUTPUT=$(goimports -w "$FILE_PATH" 2>&1) || true
    exit 0
fi

# Run goimports to format and fix imports (modifies file in-place)
GOIMPORTS_EXIT=0
GOIMPORTS_OUTPUT=$(goimports -w "$FILE_PATH" 2>&1) || GOIMPORTS_EXIT=$?

# If goimports failed, exit silently (following rust-lint pattern)
if [[ $GOIMPORTS_EXIT -ne 0 ]]; then
    exit 0
fi

# Run go vet on just the package containing the edited file
# This is much faster than running on entire project
FILE_PKG_DIR=$(dirname "$FILE_ABS")
REL_PATH=$(_gol_get_relative_path "$PROJECT_ROOT" "$FILE_ABS")
REL_PKG_DIR=$(dirname "$REL_PATH")

# Use subshell to preserve working directory
GO_VET_EXIT=0
GO_VET_OUTPUT=$(
    cd "$PROJECT_ROOT" && go vet "./$REL_PKG_DIR" 2>&1
) || GO_VET_EXIT=$?

# Always exit silently (following rust-lint pattern - never block)
# Even if go vet found issues, we exit 0 to not disrupt workflow
exit 0
