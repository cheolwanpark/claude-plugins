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

# Get target directory from argument or use current directory
TARGET_DIR="${1:-.}"

# Resolve to absolute path
if ! command -v realpath &> /dev/null; then
    echo "Error: realpath command not found. Install coreutils: brew install coreutils"
    exit 1
fi

TARGET_DIR=$(realpath "$TARGET_DIR" 2>/dev/null || echo "$TARGET_DIR")

# Verify target directory exists
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: Directory '$TARGET_DIR' does not exist"
    exit 1
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

# If any tools are missing, report and exit
if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    TOOLS_LIST=$(IFS=", "; echo "${MISSING_TOOLS[*]}")
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
    echo "brew install ${MISSING_TOOLS[*]}"
    echo '```'
    echo ""
    echo "**Linux:**"
    echo '```bash'
    echo "pip install ${MISSING_TOOLS[*]}"
    echo '```'
    exit 1
fi

# Find project root by searching upward
# Priority: .git > pyproject.toml > pyrightconfig.json
GIT_ROOT=""
TOML_ROOT=""
PYRIGHT_ROOT=""
CURRENT_DIR="$TARGET_DIR"
SEARCH_DEPTH=0
MAX_DEPTH=10

while [[ "$CURRENT_DIR" != "/" ]] && [[ $SEARCH_DEPTH -lt $MAX_DEPTH ]]; do
    # Collect candidates (keep first occurrence of each)
    if [[ -d "$CURRENT_DIR/.git" ]] && [[ -z "$GIT_ROOT" ]]; then
        GIT_ROOT="$CURRENT_DIR"
    fi
    if [[ -f "$CURRENT_DIR/pyproject.toml" ]] && [[ -z "$TOML_ROOT" ]]; then
        TOML_ROOT="$CURRENT_DIR"
    fi
    if [[ -f "$CURRENT_DIR/pyrightconfig.json" ]] && [[ -z "$PYRIGHT_ROOT" ]]; then
        PYRIGHT_ROOT="$CURRENT_DIR"
    fi
    CURRENT_DIR=$(dirname "$CURRENT_DIR")
    ((SEARCH_DEPTH++))
done

# Apply priority: .git > pyproject.toml > pyrightconfig.json > target directory
PROJECT_ROOT="${GIT_ROOT:-${TOML_ROOT:-${PYRIGHT_ROOT:-$TARGET_DIR}}}"

# Check for virtual environment and activate if found
VENV_ACTIVATED=false
for VENV_PATH in "$PROJECT_ROOT/.venv" "$PROJECT_ROOT/venv"; do
    if [[ -f "$VENV_PATH/bin/activate" ]]; then
        # shellcheck disable=SC1091
        source "$VENV_PATH/bin/activate" 2>/dev/null && VENV_ACTIVATED=true || true
        break
    fi
done

# Change to project root for proper config detection
cd "$PROJECT_ROOT" || exit 1

# Calculate relative path from project root to target
RELATIVE_TARGET=$(realpath --relative-to="$PROJECT_ROOT" "$TARGET_DIR" 2>/dev/null || echo "$TARGET_DIR")

# Initialize variables
RUFF_FAILED=false
PYRIGHT_FAILED=false

# Create temp files for outputs
RUFF_OUTPUT_FILE=$(mktemp)
RUFF_STDERR_FILE=$(mktemp)
PYRIGHT_OUTPUT_FILE=$(mktemp)
PYRIGHT_STDERR_FILE=$(mktemp)

# Cleanup temp files on exit
trap 'rm -f "$RUFF_OUTPUT_FILE" "$RUFF_STDERR_FILE" "$PYRIGHT_OUTPUT_FILE" "$PYRIGHT_STDERR_FILE"' EXIT

# Determine which Ruff config to use
# If user has a project-level config, respect it; otherwise use plugin's default
HAS_RUFF_CONFIG=false

# Check for dedicated ruff config files
if [[ -f "$PROJECT_ROOT/ruff.toml" ]] || [[ -f "$PROJECT_ROOT/.ruff.toml" ]]; then
    HAS_RUFF_CONFIG=true
# Check if pyproject.toml contains [tool.ruff] section
elif [[ -f "$PROJECT_ROOT/pyproject.toml" ]]; then
    if grep -q '^\[tool\.ruff' "$PROJECT_ROOT/pyproject.toml" 2>/dev/null; then
        HAS_RUFF_CONFIG=true
    fi
fi

# Build config args as array to handle paths with spaces
RUFF_CONFIG_ARGS=()
if [[ "$HAS_RUFF_CONFIG" == "false" ]]; then
    # Use plugin's default config for comprehensive whitespace checking
    RUFF_CONFIG_ARGS=(--config "$PLUGIN_ROOT/ruff.toml")
fi

# Run ruff with --fix to auto-correct issues first
echo "Running ruff auto-fix..." >&2
ruff check "$RELATIVE_TARGET" ${RUFF_CONFIG_ARGS[@]+"${RUFF_CONFIG_ARGS[@]}"} --fix --exit-zero > /dev/null 2>&1

# Run ruff check again to capture remaining unfixable issues
if ruff check "$RELATIVE_TARGET" ${RUFF_CONFIG_ARGS[@]+"${RUFF_CONFIG_ARGS[@]}"} --output-format=json --exit-zero > "$RUFF_OUTPUT_FILE" 2> "$RUFF_STDERR_FILE"; then
    :
else
    RUFF_FAILED=true
fi

# Run pyright
if pyright "$RELATIVE_TARGET" --outputjson > "$PYRIGHT_OUTPUT_FILE" 2> "$PYRIGHT_STDERR_FILE"; then
    :
else
    PYRIGHT_FAILED=true
fi

# Parse ruff output
RUFF_JSON=$(cat "$RUFF_OUTPUT_FILE")
if ! echo "$RUFF_JSON" | jq -e . >/dev/null 2>&1; then
    RUFF_JSON="[]"
fi

# Parse pyright output
PYRIGHT_JSON=$(cat "$PYRIGHT_OUTPUT_FILE")
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
if [[ "$VENV_ACTIVATED" == "true" ]]; then
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
            | "- `\(.file):\(.range.start.line):\(.range.start.character)` - \(.message)"
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
        | "- `\(.file):\(.range.start.line):\(.range.start.character)` - \(.message)"
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
