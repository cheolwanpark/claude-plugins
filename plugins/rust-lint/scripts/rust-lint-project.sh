#!/usr/bin/env bash
#
# Rust Lint Project Script
# Runs project-wide formatting check and comprehensive clippy linting
#
# This script:
# 1. Checks formatting with cargo fmt
# 2. Runs clippy on the entire workspace
# 3. Generates a markdown report
# 4. Exits with error code if issues found
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Source common library
# shellcheck disable=SC1091
source "$SCRIPT_DIR/rust-lint-common.sh"

# ============================================================================
# Configuration
# ============================================================================

# Get target directory from argument
TARGET_DIR="${1:-.}"
TARGET_DIR=$(_rl_get_absolute_path "$TARGET_DIR")

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "# Rust Lint Report"
    echo ""
    echo "## Error: Directory Not Found"
    echo ""
    echo "Directory \`$TARGET_DIR\` does not exist."
    exit 1
fi

# Check required tools
if ! _rl_check_required_tools cargo rustfmt jq; then
    TOOLS_LIST=$(IFS=", "; echo "${_RL_MISSING_TOOLS[*]}")
    echo "# Rust Lint Report"
    echo ""
    echo "## Error: Missing Required Tools"
    echo ""
    echo "Missing: **${TOOLS_LIST}**"
    echo ""
    echo "Install with:"
    echo '```bash'
    echo "rustup component add rustfmt clippy"
    echo '```'
    exit 1
fi

# Check if clippy is available
if ! cargo clippy --version &>/dev/null; then
    echo "# Rust Lint Report"
    echo ""
    echo "## Error: Clippy Not Installed"
    echo ""
    echo "Clippy is required for linting."
    echo ""
    echo "Install with:"
    echo '```bash'
    echo "rustup component add clippy"
    echo '```'
    exit 1
fi

# ============================================================================
# Find Project Root
# ============================================================================

# Try to find workspace root first
PROJECT_ROOT=""
cd "$TARGET_DIR"

if WORKSPACE_ROOT=$(_rl_get_workspace_root); then
    PROJECT_ROOT="$WORKSPACE_ROOT"
else
    # Fallback to manual search
    PROJECT_ROOT=$(_rl_find_project_root "$TARGET_DIR")
fi

if [[ ! -f "$PROJECT_ROOT/Cargo.toml" ]]; then
    echo "# Rust Lint Report"
    echo ""
    echo "## Error: Not a Rust Project"
    echo ""
    echo "No \`Cargo.toml\` found in \`$PROJECT_ROOT\` or parent directories."
    echo ""
    echo "Make sure you're running this command from within a Rust project."
    exit 1
fi

cd "$PROJECT_ROOT"

# ============================================================================
# Generate Cache Directory Path
# ============================================================================

# Create a unique cache directory based on project root path
# This isolates build artifacts from the actual project
PROJECT_HASH=$(echo -n "$PROJECT_ROOT" | shasum | cut -d' ' -f1 | head -c 8)
CACHE_DIR="/tmp/claude-rust-lint-cache-$PROJECT_HASH"

# ============================================================================
# Formatting Check
# ============================================================================

echo "Checking formatting..." >&2

FMT_NEEDED=""
FMT_OUTPUT=$(cargo fmt -- --check 2>&1) || FMT_NEEDED="true"

# ============================================================================
# Clippy Linting
# ============================================================================

echo "Running clippy..." >&2

# Run clippy with JSON output
# - --workspace: Check all workspace members
# - --all-targets: Check lib, bins, tests, benches, examples
# - --no-deps: Don't check dependencies (faster)
# - --message-format=json: Machine-readable output
# - --target-dir: Isolate build artifacts
CLIPPY_OUTPUT=$(cargo clippy \
    --workspace \
    --all-targets \
    --no-deps \
    --message-format=json \
    --target-dir="$CACHE_DIR" \
    2>&1 || true)

# Parse clippy output to extract compiler messages
# Keep as a JSON array for proper parsing
CLIPPY_MESSAGES=$(echo "$CLIPPY_OUTPUT" | \
    jq -s '[.[] | select(.reason == "compiler-message") | .message]' 2>/dev/null || echo "[]")

# Count errors and warnings
ERROR_COUNT=$(echo "$CLIPPY_MESSAGES" | \
    jq '[.[] | select(.level == "error")] | length' 2>/dev/null || echo "0")

WARNING_COUNT=$(echo "$CLIPPY_MESSAGES" | \
    jq '[.[] | select(.level == "warning")] | length' 2>/dev/null || echo "0")

# ============================================================================
# Generate Markdown Report
# ============================================================================

echo "# Rust Lint Report"
echo ""
echo "**Project:** \`$PROJECT_ROOT\`"
echo ""

# Summary section
echo "## Summary"
echo ""
if [[ -n "$FMT_NEEDED" ]]; then
    echo "- **Formatting:** ❌ Some files need formatting"
else
    echo "- **Formatting:** ✅ All files properly formatted"
fi
echo "- **Clippy Errors:** $ERROR_COUNT"
echo "- **Clippy Warnings:** $WARNING_COUNT"
echo ""

# Formatting issues
if [[ -n "$FMT_NEEDED" ]]; then
    echo "## Formatting Issues"
    echo ""
    echo "Some files are not properly formatted. Run the following command to fix:"
    echo '```bash'
    echo "cargo fmt"
    echo '```'
    echo ""
fi

# Clippy errors
if [[ "$ERROR_COUNT" -gt 0 ]]; then
    echo "## Clippy Errors"
    echo ""
    echo "$CLIPPY_MESSAGES" | jq -r '
        [.[] | select(.level == "error")] |
        .[0:20] |
        map("- **\(.spans[0].file_name):\(.spans[0].line_start):\(.spans[0].column_start)** - `\(.code.code // "error")` - \(.message)") |
        join("\n")
    ' 2>/dev/null || echo "- Failed to parse error messages"

    if [[ "$ERROR_COUNT" -gt 20 ]]; then
        REMAINING=$((ERROR_COUNT - 20))
        echo ""
        echo "_...and $REMAINING more error(s)_"
    fi
    echo ""
fi

# Clippy warnings
if [[ "$WARNING_COUNT" -gt 0 ]]; then
    echo "## Clippy Warnings"
    echo ""
    echo "$CLIPPY_MESSAGES" | jq -r '
        [.[] | select(.level == "warning")] |
        .[0:10] |
        map("- **\(.spans[0].file_name):\(.spans[0].line_start):\(.spans[0].column_start)** - `\(.code.code // "warning")` - \(.message)") |
        join("\n")
    ' 2>/dev/null || echo "- Failed to parse warning messages"

    if [[ "$WARNING_COUNT" -gt 10 ]]; then
        REMAINING=$((WARNING_COUNT - 10))
        echo ""
        echo "_...and $REMAINING more warning(s)_"
    fi
    echo ""
fi

# Success message
if [[ -z "$FMT_NEEDED" && "$ERROR_COUNT" -eq 0 && "$WARNING_COUNT" -eq 0 ]]; then
    echo "## ✅ All Checks Passed!"
    echo ""
    echo "Your Rust code is properly formatted and has no clippy warnings or errors."
    echo ""
fi

# ============================================================================
# Exit Code
# ============================================================================

# Exit with error if there are clippy errors or formatting issues
if [[ -n "$FMT_NEEDED" || "$ERROR_COUNT" -gt 0 ]]; then
    exit 1
fi

exit 0
