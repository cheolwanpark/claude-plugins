#!/usr/bin/env bash
set -euo pipefail

# Hook script for go-lint plugin
# Runs goimports, golangci-lint (if available), and go vet on edited Go files

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Source common library
source "$PLUGIN_ROOT/scripts/go-lint-common.sh"

# Global error trap to ensure JSON output on unexpected failures
trap '_gol_safe_exit "allow" "Unexpected error in go-lint hook" "PostToolUse" "Error code: $?"' ERR

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
    # Just run goimports and report any errors
    GOIMPORTS_EXIT=0
    GOIMPORTS_OUTPUT=$(goimports -w "$FILE_PATH" 2>&1) || GOIMPORTS_EXIT=$?

    if [[ $GOIMPORTS_EXIT -ne 0 ]]; then
        _gol_safe_exit "allow" \
            "goimports formatting failed (no project root found)" \
            "PostToolUse" \
            "goimports error: $GOIMPORTS_OUTPUT"
    fi

    # Success - formatted without project context
    exit 0
fi

# Run goimports to format and fix imports (modifies file in-place)
GOIMPORTS_EXIT=0
GOIMPORTS_OUTPUT=$(goimports -w "$FILE_PATH" 2>&1) || GOIMPORTS_EXIT=$?

# If goimports failed, report error but allow operation to proceed
if [[ $GOIMPORTS_EXIT -ne 0 ]]; then
    _gol_safe_exit "allow" \
        "goimports formatting failed" \
        "PostToolUse" \
        "goimports error: $GOIMPORTS_OUTPUT"
fi

# Try to run golangci-lint if available and configured
if command -v golangci-lint &>/dev/null; then
    # Build config arguments
    CONFIG_ARG=$(_gol_build_golangci_config_args "$PROJECT_ROOT")

    # Run golangci-lint with JSON output (stdout only, discard stderr warnings)
    # golangci-lint exits: 0=clean, 1=issues found, >1=error
    GOLANGCI_EXIT=0
    if [[ -n "$CONFIG_ARG" ]]; then
        GOLANGCI_OUTPUT=$(cd "$PROJECT_ROOT" && golangci-lint run \
            --out-format json \
            "$CONFIG_ARG" \
            "$FILE_ABS" 2>/dev/null) || GOLANGCI_EXIT=$?
    else
        GOLANGCI_OUTPUT=$(cd "$PROJECT_ROOT" && golangci-lint run \
            --out-format json \
            "$FILE_ABS" 2>/dev/null) || GOLANGCI_EXIT=$?
    fi

    # Check if output is valid JSON and parse issues
    if [[ -n "$GOLANGCI_OUTPUT" ]] && echo "$GOLANGCI_OUTPUT" | jq -e '.Issues' &>/dev/null; then
        # Valid JSON output - check for issues
        ISSUE_COUNT=$(echo "$GOLANGCI_OUTPUT" | jq -r '.Issues | length' 2>/dev/null || echo "0")

        if [[ "$ISSUE_COUNT" =~ ^[0-9]+$ ]] && [[ "$ISSUE_COUNT" -gt 0 ]]; then
            # Format issues for display
            FORMATTED_ISSUES=$(echo "$GOLANGCI_OUTPUT" | jq -r '
                .Issues[] |
                "\(.Pos.Filename):\(.Pos.Line):\(.Pos.Column): \(.Text) (\(.FromLinter))"
            ' 2>/dev/null || echo "$GOLANGCI_OUTPUT")

            _gol_safe_exit "block" \
                "golangci-lint found $ISSUE_COUNT issue(s) in file" \
                "PostToolUse" \
                "$FORMATTED_ISSUES"
        fi
    elif [[ $GOLANGCI_EXIT -gt 1 ]]; then
        # Runtime error (exit code >1 indicates tool failure, not linting issues)
        _gol_safe_exit "allow" \
            "golangci-lint encountered an error" \
            "PostToolUse" \
            "Tool exited with code $GOLANGCI_EXIT"
    fi
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

# Parse go vet output for errors related to the edited file
if [[ $GO_VET_EXIT -ne 0 ]] && [[ -n "$GO_VET_OUTPUT" ]]; then
    # Use relative path from project root for accurate matching
    # grep -F for literal string matching (no regex interpretation)
    # Pattern: "./$REL_PATH:" to match go vet output format
    FILTERED_OUTPUT=$(echo "$GO_VET_OUTPUT" | grep -F "./$REL_PATH:" || echo "")

    # If there are errors in the edited file, report them
    if [[ -n "$FILTERED_OUTPUT" ]]; then
        # Count the number of issues (non-empty lines)
        ISSUE_COUNT=$(echo "$FILTERED_OUTPUT" | grep -c "^" || echo "0")

        _gol_safe_exit "block" \
            "go vet found $ISSUE_COUNT issue(s) in file" \
            "PostToolUse" \
            "$FILTERED_OUTPUT"
    fi
fi

# All checks passed or no issues found in edited file - exit silently (success)
exit 0
