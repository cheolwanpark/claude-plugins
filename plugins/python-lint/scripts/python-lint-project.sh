#!/usr/bin/env bash
#
# Python Lint Project Script
# Runs project-wide linting and type checking with ruff and pyright
#
# Usage: python-lint-project.sh [directory]
#   directory: Optional directory to scan (defaults to current directory)
#

set -euo pipefail

# Get the plugin root directory (parent of scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Source common library
# shellcheck disable=SC1091
source "$SCRIPT_DIR/python-lint-common.sh"

# Get target directory from argument or use current directory
TARGET_DIR="${1:-.}"

# Resolve to absolute path
TARGET_DIR=$(_pyl_get_absolute_path "$TARGET_DIR")

# Verify target directory exists
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: Directory '$TARGET_DIR' does not exist"
    exit 1
fi

# Check if required tools are installed (realpath is optional)
if ! _pyl_check_required_tools ruff pyright jq; then
    TOOLS_LIST=$(IFS=", "; echo "${_PYL_MISSING_TOOLS[*]}")
    echo "# Python Lint Report"
    echo ""
    echo "## Error: Missing Required Tools"
    echo ""
    echo "The following tools are required but not installed: **${TOOLS_LIST}**"
    echo ""
    echo "### Installation Instructions"
    echo ""
    echo "**macOS:**"
    echo '```bash'
    echo "brew install ${_PYL_MISSING_TOOLS[*]}"
    echo '```'
    echo ""
    echo "**Linux:**"
    echo '```bash'
    echo "pip install ${_PYL_MISSING_TOOLS[*]}"
    echo '```'
    exit 1
fi

# Find project root
PROJECT_ROOT=$(_pyl_find_project_root "$TARGET_DIR")

# Check for virtual environment and activate if found
_pyl_activate_venv "$PROJECT_ROOT"

# Change to project root for proper config detection
cd "$PROJECT_ROOT" || exit 1

# Calculate relative path from project root to target
RELATIVE_TARGET=$(_pyl_get_relative_path "$TARGET_DIR" "$PROJECT_ROOT")

# Initialize variables
RUFF_FAILED=false
PYRIGHT_FAILED=false

# Create temp files for outputs
RUFF_STDERR_FILE=$(mktemp)
PYRIGHT_STDERR_FILE=$(mktemp)

# Cleanup temp files on exit
trap 'rm -f "$RUFF_STDERR_FILE" "$PYRIGHT_STDERR_FILE"' EXIT

# Build ruff config arguments
_pyl_build_ruff_config_args "$PROJECT_ROOT" "$PLUGIN_ROOT"

# Run ruff with --fix to auto-correct issues first
echo "Running ruff auto-fix..." >&2
ruff check "$RELATIVE_TARGET" ${_PYL_RUFF_CONFIG_ARGS[@]+"${_PYL_RUFF_CONFIG_ARGS[@]}"} --fix --exit-zero > /dev/null 2>&1

# Run ruff check again to capture remaining unfixable issues (use command substitution instead of temp file)
RUFF_JSON=$(ruff check "$RELATIVE_TARGET" ${_PYL_RUFF_CONFIG_ARGS[@]+"${_PYL_RUFF_CONFIG_ARGS[@]}"} --output-format=json --exit-zero 2>"$RUFF_STDERR_FILE") || RUFF_FAILED=true

# Validate ruff JSON
if ! echo "$RUFF_JSON" | jq -e . >/dev/null 2>&1; then
    RUFF_JSON="[]"
fi

# Run pyright (use command substitution for stdout, temp file for stderr)
PYRIGHT_JSON=$(pyright "$RELATIVE_TARGET" --outputjson 2>"$PYRIGHT_STDERR_FILE") || PYRIGHT_FAILED=true

# Validate pyright JSON
if ! echo "$PYRIGHT_JSON" | jq -e . >/dev/null 2>&1; then
    PYRIGHT_JSON='{"generalDiagnostics": [], "summary": {"errorCount": 0, "warningCount": 0}}'
fi

# Extract counts and file lists in a single jq call for efficiency
read -r RUFF_ERRORS RUFF_FILES_LIST < <(echo "$RUFF_JSON" | jq -r '
    [length, ([.[].filename] | unique | join(" "))] | @tsv
' 2>/dev/null || echo "0 ")

read -r PYRIGHT_ERRORS PYRIGHT_WARNINGS PYRIGHT_FILES_LIST < <(echo "$PYRIGHT_JSON" | jq -r '
    [
        (.summary.errorCount // 0),
        (.summary.warningCount // 0),
        ([.generalDiagnostics[].file] | unique | join(" "))
    ] | @tsv
' 2>/dev/null || echo "0 0 ")

# Calculate total unique files (union of ruff and pyright files)
TOTAL_FILES=$(echo "$RUFF_FILES_LIST $PYRIGHT_FILES_LIST" | tr ' ' '\n' | sort -u | grep -c . || true)

# Start markdown output
echo "# Python Lint Report"
echo ""
echo "**Project:** \`$PROJECT_ROOT\`"
echo "**Scanned:** \`$RELATIVE_TARGET\`"
if [[ "$_PYL_VENV_ACTIVATED" == "true" ]]; then
    echo "**Virtual Environment:** Active"
fi
echo ""

# Summary section
echo "## Summary"
echo ""
echo "- **Linting issues:** $RUFF_ERRORS"
echo "- **Type errors:** $PYRIGHT_ERRORS"
echo "- **Type warnings:** $PYRIGHT_WARNINGS"
echo "- **Files with issues:** $TOTAL_FILES"
echo ""

# Show errors if any
if [[ $RUFF_ERRORS -gt 0 ]] || [[ $PYRIGHT_ERRORS -gt 0 ]]; then
    echo "## Errors"
    echo ""

    # Ruff issues (all ruff violations are treated as issues)
    if [[ $RUFF_ERRORS -gt 0 ]]; then
        echo "### Linting Issues ($RUFF_ERRORS)"
        echo ""
        echo "$RUFF_JSON" | jq -r '
            .[]
            | "- `\(.filename):\(.location.row):\(.location.column)` **\(.code)** - \(.message)"
        ' 2>/dev/null || echo "- _(Error parsing ruff output)_"
        echo ""
    fi

    # Pyright errors
    if [[ $PYRIGHT_ERRORS -gt 0 ]]; then
        echo "### Type Errors ($PYRIGHT_ERRORS)"
        echo ""
        echo "$PYRIGHT_JSON" | jq -r '
            [.generalDiagnostics[] | select(.severity == "error")]
            | .[]
            | "- `\(.file):\(.range.start.line + 1):\(.range.start.character + 1)` - \(.message)"
        ' 2>/dev/null || echo "- _(Error parsing pyright output)_"
        echo ""
    fi
fi

# Show warnings (pyright warnings only, up to 10)
if [[ $PYRIGHT_WARNINGS -gt 0 ]]; then
    echo "## Warnings"
    echo ""
    if [[ $PYRIGHT_WARNINGS -gt 10 ]]; then
        echo "_(Showing 10 of $PYRIGHT_WARNINGS type warnings)_"
        echo ""
    fi

    echo "$PYRIGHT_JSON" | jq -r '
        [.generalDiagnostics[] | select(.severity == "warning")]
        | .[0:10]
        | .[]
        | "- `\(.file):\(.range.start.line + 1):\(.range.start.character + 1)` - \(.message)"
    ' 2>/dev/null || echo "- _(Error parsing pyright output)_"
    echo ""
fi

# Show tool errors if any (only if there's actual stderr content)
RUFF_STDERR_CONTENT=$(cat "$RUFF_STDERR_FILE")
PYRIGHT_STDERR_CONTENT=$(cat "$PYRIGHT_STDERR_FILE")

if [[ "$RUFF_FAILED" == "true" && -n "$RUFF_STDERR_CONTENT" ]] || [[ "$PYRIGHT_FAILED" == "true" && -n "$PYRIGHT_STDERR_CONTENT" ]]; then
    echo "## Tool Errors"
    echo ""

    if [[ "$RUFF_FAILED" == "true" && -n "$RUFF_STDERR_CONTENT" ]]; then
        echo "### Ruff Error"
        echo '```'
        echo "$RUFF_STDERR_CONTENT"
        echo '```'
        echo ""
    fi

    if [[ "$PYRIGHT_FAILED" == "true" && -n "$PYRIGHT_STDERR_CONTENT" ]]; then
        echo "### Pyright Error"
        echo '```'
        echo "$PYRIGHT_STDERR_CONTENT"
        echo '```'
        echo ""
    fi
fi

# Success message if no issues
if [[ $RUFF_ERRORS -eq 0 ]] && [[ $PYRIGHT_ERRORS -eq 0 ]] && [[ $PYRIGHT_WARNINGS -eq 0 ]]; then
    echo "## ✅ No Issues Found"
    echo ""
    echo "All Python files are properly linted and type-checked!"
fi
