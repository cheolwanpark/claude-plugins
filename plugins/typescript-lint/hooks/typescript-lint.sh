#!/usr/bin/env bash

# typescript-lint.sh - TypeScript/JavaScript linting hook
# Runs after Edit/Write operations to format and lint files

set -euo pipefail

# File size limit (1MB)
MAX_FILE_SIZE=1048576

# Supported file extensions
SUPPORTED_EXTS="\\.js$|\\.jsx$|\\.ts$|\\.tsx$|\\.mjs$|\\.cjs$"

# Helper function to generate JSON responses safely using jq
json_response() {
  local decision="$1"
  local reason="$2"
  local event_name="${3:-}"
  local context="${4:-}"

  if [[ -n "$event_name" && -n "$context" ]]; then
    jq -n \
      --arg decision "$decision" \
      --arg reason "$reason" \
      --arg event_name "$event_name" \
      --arg context "$context" \
      '{
        decision: $decision,
        reason: $reason,
        hookSpecificOutput: {
          hookEventName: $event_name,
          additionalContext: $context
        }
      }'
  else
    jq -n \
      --arg decision "$decision" \
      --arg reason "$reason" \
      '{
        decision: $decision,
        reason: $reason
      }'
  fi
}

# Read JSON input from stdin and parse safely
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")

# Validate file path
if [[ -z "$FILE_PATH" ]]; then
  json_response "allow" "No file path provided"
  exit 0
fi

# Check if file exists
if [[ ! -f "$FILE_PATH" ]]; then
  json_response "allow" "File does not exist"
  exit 0
fi

# Check file extension
if ! echo "$FILE_PATH" | grep -qE "$SUPPORTED_EXTS"; then
  EXT="${FILE_PATH##*.}"
  json_response "allow" "File extension .$EXT is not supported for linting"
  exit 0
fi

# Check file size
FILE_SIZE=$(wc -c < "$FILE_PATH" | tr -d ' ')
if [[ $FILE_SIZE -gt $MAX_FILE_SIZE ]]; then
  SIZE_MB=$(awk "BEGIN {printf \"%.2f\", $FILE_SIZE/1024/1024}")
  json_response "allow" "File is too large (${SIZE_MB}MB) to lint automatically"
  exit 0
fi

# Find project root by walking up from file's directory
find_project_root() {
  local dir="$(cd "$(dirname "$FILE_PATH")" && pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/package.json" ]] || [[ -f "$dir/tsconfig.json" ]] || [[ -d "$dir/.git" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  # Default to file's directory
  echo "$(cd "$(dirname "$FILE_PATH")" && pwd)"
}

PROJECT_ROOT=$(find_project_root)
cd "$PROJECT_ROOT"

# Check if required tools are installed
MISSING_TOOLS=()

if ! command -v npx >/dev/null 2>&1; then
  MISSING_TOOLS+=("npx")
fi

if ! command -v jq >/dev/null 2>&1; then
  MISSING_TOOLS+=("jq")
fi

# If any critical tools are missing, report and exit
if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
  TOOLS_LIST=$(IFS=", "; echo "${MISSING_TOOLS[*]}")
  json_response "allow" "Missing required tools: $TOOLS_LIST. Install with: brew install $TOOLS_LIST"
  exit 0
fi

MISSING_DEPS=()
if ! npx prettier --version >/dev/null 2>&1; then
  MISSING_DEPS+=("prettier")
fi

if ! npx eslint --version >/dev/null 2>&1; then
  MISSING_DEPS+=("eslint")
fi

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
  DEPS_STR="${MISSING_DEPS[*]}"
  json_response "allow" "Missing dependencies: $DEPS_STR. Install with: npm install --save-dev $DEPS_STR"
  exit 0
fi

# Format with Prettier
PRETTIER_EXIT=0
PRETTIER_OUTPUT=$(npx prettier --write "$FILE_PATH" 2>&1) || PRETTIER_EXIT=$?

# Check if prettier failed
if [[ $PRETTIER_EXIT -ne 0 ]]; then
  # Extract first line of error
  ERROR_LINE=$(echo "$PRETTIER_OUTPUT" | head -1)
  json_response "allow" "Prettier formatting failed: $ERROR_LINE"
  exit 0
fi

# Lint with ESLint
ESLINT_EXIT=0
ESLINT_OUTPUT=$(npx eslint --fix --format json "$FILE_PATH" 2>&1) || ESLINT_EXIT=$?

# Extract JSON array from output (in case there are warnings on stderr)
# Find the first line starting with '[' and take everything from there
ESLINT_JSON=$(echo "$ESLINT_OUTPUT" | sed -n '/^\[/,$p')

# Check if we got valid JSON
if [[ -z "$ESLINT_JSON" ]] || ! echo "$ESLINT_JSON" | jq -e . >/dev/null 2>&1; then
  # No valid JSON - check if it's a configuration error
  if echo "$ESLINT_OUTPUT" | grep -qi "no eslint configuration\|could not find.*config\|error.*config"; then
    ERROR_LINE=$(echo "$ESLINT_OUTPUT" | grep -i "config" | head -1)
    json_response "allow" "ESLint config error: $ERROR_LINE"
    exit 0
  fi
  # Treat as empty result
  ESLINT_JSON="[]"
fi

# Parse ESLint JSON output to count errors and warnings
# ESLint JSON format: array of results, each with messages array
# Each message has severity: 1 (warning) or 2 (error)
ERROR_COUNT=$(echo "$ESLINT_JSON" | jq '[.[].messages[] | select(.severity == 2)] | length' 2>/dev/null || echo "0")
WARNING_COUNT=$(echo "$ESLINT_JSON" | jq '[.[].messages[] | select(.severity == 1)] | length' 2>/dev/null || echo "0")

# Extract error and warning messages (limit to 10 each)
ERRORS=$(echo "$ESLINT_JSON" | jq -r '
  [.[].messages[] | select(.severity == 2)]
  | .[0:10]
  | map("  - line \(.line):\(.column) [\(.ruleId // "unknown")] \(.message)")
  | join("\n")
' 2>/dev/null || echo "")

WARNINGS=$(echo "$ESLINT_JSON" | jq -r '
  [.[].messages[] | select(.severity == 1)]
  | .[0:10]
  | map("  - line \(.line):\(.column) [\(.ruleId // "unknown")] \(.message)")
  | join("\n")
' 2>/dev/null || echo "")

# If there are errors, block with detailed message
if [[ ${ERROR_COUNT:-0} -gt 0 ]]; then
  ERROR_MSG="TypeScript/JavaScript linting found $ERROR_COUNT error(s) that require manual fixes"

  # Build context with errors
  ERROR_DETAIL="ESLint Errors ($ERROR_COUNT):"
  if [[ -n "$ERRORS" ]]; then
    ERROR_DETAIL="$ERROR_DETAIL"$'\n'"$ERRORS"
  fi

  if [[ $ERROR_COUNT -gt 10 ]]; then
    REMAINING=$((ERROR_COUNT - 10))
    ERROR_DETAIL="$ERROR_DETAIL"$'\n'"... and $REMAINING more"
  fi

  json_response "block" "$ERROR_MSG" "PostToolUse" "$ERROR_DETAIL"
  exit 0
fi

# If there are warnings, allow but report them
if [[ ${WARNING_COUNT:-0} -gt 0 ]]; then
  WARNING_MSG="Linting complete. $WARNING_COUNT warning(s) found."

  # Build context with warnings
  WARNING_DETAIL="ESLint Warnings ($WARNING_COUNT):"
  if [[ -n "$WARNINGS" ]]; then
    WARNING_DETAIL="$WARNING_DETAIL"$'\n'"$WARNINGS"
  fi

  if [[ $WARNING_COUNT -gt 10 ]]; then
    REMAINING=$((WARNING_COUNT - 10))
    WARNING_DETAIL="$WARNING_DETAIL"$'\n'"... and $REMAINING more"
  fi

  json_response "allow" "$WARNING_MSG" "PostToolUse" "$WARNING_DETAIL"
  exit 0
fi

# Success - file was formatted and/or linted with no issues
json_response "allow" "Linting complete. File was formatted and auto-fixed."
exit 0
