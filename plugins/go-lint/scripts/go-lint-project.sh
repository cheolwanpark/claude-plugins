#!/usr/bin/env bash
set -euo pipefail

# Project-wide Go linting script using golangci-lint
# Usage: go-lint-project.sh [directory]

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Source common library
source "$PLUGIN_ROOT/scripts/go-lint-common.sh"

# Parse target directory argument
TARGET_DIR="${1:-.}"
TARGET_DIR=$(_gol_get_absolute_path "$TARGET_DIR")

# Check if target exists
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "## Go Linting Failed"
    echo ""
    echo "Target directory does not exist: $TARGET_DIR"
    exit 1
fi

# Check for required tools
if ! _gol_check_required_tools golangci-lint jq; then
    MISSING_TOOLS="${_gol_MISSING_TOOLS[*]}"
    echo "## Go Linting Failed"
    echo ""
    echo "Missing required tools: $MISSING_TOOLS"
    echo ""
    echo "### Installation"
    echo ""
    echo "Install golangci-lint:"
    echo '```bash'
    echo "go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
    echo '```'
    exit 1
fi

# Find project root
PROJECT_ROOT=$(_gol_find_project_root "$TARGET_DIR")

if [[ -z "$PROJECT_ROOT" ]]; then
    echo "## Go Linting Failed"
    echo ""
    echo "Could not find Go project root (no go.mod, go.work, or .git found)"
    echo "Searched from: $TARGET_DIR"
    exit 1
fi

# Get relative target path from project root
REL_TARGET=$(_gol_get_relative_path "$PROJECT_ROOT" "$TARGET_DIR")
if [[ "$REL_TARGET" == "." || "$REL_TARGET" == "$TARGET_DIR" ]]; then
    LINT_TARGET="./..."
else
    LINT_TARGET="./$REL_TARGET/..."
fi

# Detect golangci-lint config
CONFIG_ARGS=$(_gol_build_golangci_config_args "$PROJECT_ROOT")

# Run golangci-lint with JSON output
# Use subshell to preserve working directory
# NOTE: Don't capture stderr (no 2>&1) to avoid mixing error messages with JSON
GOLANGCI_EXIT=0
GOLANGCI_JSON=$(
    cd "$PROJECT_ROOT" && golangci-lint run $CONFIG_ARGS --out-format=json --fix "$LINT_TARGET"
) || GOLANGCI_EXIT=$?

# Handle empty output (no issues found)
if [[ -z "$GOLANGCI_JSON" ]]; then
    echo "## Go Linting Succeeded"
    echo ""
    echo "No issues found!"
    echo ""
    echo "**Target:** $LINT_TARGET"
    echo "**Project root:** $PROJECT_ROOT"
    exit 0
fi

# Parse JSON output - take the full JSON, not just first line
# golangci-lint JSON is multi-line, so we need to parse it properly
if [[ $GOLANGCI_EXIT -ne 0 ]]; then
    # Validate JSON before attempting to parse
    if ! echo "$GOLANGCI_JSON" | jq empty 2>/dev/null; then
        # Not valid JSON - tool failed completely
        echo "## Go Linting Failed"
        echo ""
        echo "golangci-lint exited with code $GOLANGCI_EXIT and produced invalid output:"
        echo '```'
        echo "$GOLANGCI_JSON"
        echo '```'
        exit 1
    fi
fi

REPORT_JSON="$GOLANGCI_JSON"

# Validate JSON structure before parsing
if ! echo "$REPORT_JSON" | jq empty 2>/dev/null; then
    echo "## Go Linting Failed"
    echo ""
    echo "golangci-lint produced invalid JSON output:"
    echo '```'
    echo "$REPORT_JSON"
    echo '```'
    exit 1
fi

# Extract issues
ISSUES_JSON=$(echo "$REPORT_JSON" | jq -r '.Issues // []')
ISSUE_COUNT=$(echo "$ISSUES_JSON" | jq 'length')

# Check if there are any issues
if [[ "$ISSUE_COUNT" -eq 0 ]]; then
    echo "## Go Linting Succeeded"
    echo ""
    echo "No issues found!"
    echo ""
    echo "**Target:** $LINT_TARGET"
    echo "**Project root:** $PROJECT_ROOT"
    exit 0
fi

# Separate errors and warnings
# golangci-lint doesn't distinguish severity in JSON, so we treat all as errors
ERRORS_JSON="$ISSUES_JSON"
ERROR_COUNT="$ISSUE_COUNT"
WARNINGS_JSON="[]"
WARNING_COUNT=0

# Generate markdown report
echo "## Go Linting Report"
echo ""
echo "**Target:** $LINT_TARGET"
echo "**Project root:** $PROJECT_ROOT"
if [[ -n "$CONFIG_ARGS" ]]; then
    CONFIG_FILE=$(echo "$CONFIG_ARGS" | sed 's/--config=//')
    echo "**Config:** $CONFIG_FILE"
fi
echo ""
echo "### Summary"
echo ""
echo "- **Errors:** $ERROR_COUNT"
echo "- **Warnings:** $WARNING_COUNT"
echo ""

# Display top 20 errors
if [[ $ERROR_COUNT -gt 0 ]]; then
    echo "### Errors"
    echo ""

    # Format and limit to 20 errors
    ERROR_TEXT=$(echo "$ERRORS_JSON" | jq -r '
        .[0:20] | map(
            "- **\(.Pos.Filename):\(.Pos.Line):\(.Pos.Column)** [\(.FromLinter)] \(.Text)"
        ) | join("\n")
    ')

    echo "$ERROR_TEXT"
    echo ""

    if [[ $ERROR_COUNT -gt 20 ]]; then
        REMAINING=$((ERROR_COUNT - 20))
        echo "_...and $REMAINING more errors_"
        echo ""
    fi
fi

# Display top 10 warnings (if any)
if [[ $WARNING_COUNT -gt 0 ]]; then
    echo "### Warnings"
    echo ""

    WARNING_TEXT=$(echo "$WARNINGS_JSON" | jq -r '
        .[0:10] | map(
            "- **\(.Pos.Filename):\(.Pos.Line):\(.Pos.Column)** [\(.FromLinter)] \(.Text)"
        ) | join("\n")
    ')

    echo "$WARNING_TEXT"
    echo ""

    if [[ $WARNING_COUNT -gt 10 ]]; then
        REMAINING=$((WARNING_COUNT - 10))
        echo "_...and $REMAINING more warnings_"
        echo ""
    fi
fi

# Exit with appropriate code
# Exit 1 for errors, 0 for warnings only
if [[ $ERROR_COUNT -gt 0 ]]; then
    exit 1
else
    exit 0
fi
