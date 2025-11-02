#!/usr/bin/env bash
#
# Ruff Lint and Format Hook
# Automatically lints and formats Python files after Claude edits or writes them
#
# This hook:
# 1. Auto-fixes linting violations with 'ruff check --fix'
# 2. Formats code with 'ruff format'
# 3. Reports unfixable linting issues back to Claude
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

# Check if ruff is installed
if ! command -v ruff &> /dev/null; then
    echo "Warning: ruff is not installed. Install it with: `uv add --dev ruff`" >&2
    exit 1
fi

# Temporary file to capture ruff output
TEMP_OUTPUT=$(mktemp)
trap 'rm -f "$TEMP_OUTPUT"' EXIT

# Run ruff check --fix to auto-fix linting issues
# Capture output and exit code
set +e
ruff check --fix "$FILE_PATH" > "$TEMP_OUTPUT" 2>&1
CHECK_EXIT=$?
set -e

# Run ruff format to format the code
# This should always succeed for valid Python syntax
set +e
ruff format "$FILE_PATH" >> "$TEMP_OUTPUT" 2>&1
FORMAT_EXIT=$?
set -e

# If there were unfixable linting errors, report them to Claude
# ruff check exits with:
# - 0 if no violations found
# - 1 if violations found (some may have been fixed)
# - 2 for fatal errors
if [[ $CHECK_EXIT -ne 0 ]]; then
    # Check if there are still violations after fixing
    set +e
    ruff check "$FILE_PATH" --output-format=text > "$TEMP_OUTPUT" 2>&1
    RECHECK_EXIT=$?
    set -e

    if [[ $RECHECK_EXIT -ne 0 ]]; then
        # There are unfixable violations - report to Claude
        echo "Ruff found unfixable linting issues in $FILE_PATH:" >&2
        cat "$TEMP_OUTPUT" >&2
        exit 2  # Exit code 2 blocks and shows error to Claude
    fi
fi

# Check if formatting failed
if [[ $FORMAT_EXIT -ne 0 ]]; then
    echo "Ruff formatting failed for $FILE_PATH:" >&2
    cat "$TEMP_OUTPUT" >&2
    exit 2
fi

# Success - file was linted and formatted
exit 0
