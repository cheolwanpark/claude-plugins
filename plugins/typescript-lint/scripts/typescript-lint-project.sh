#!/usr/bin/env bash

# typescript-lint-project.sh - Project-wide TypeScript/JavaScript linting script
# Runs Prettier and ESLint on all TypeScript/JavaScript files in the project

set -euo pipefail

# Get the target directory (default to current directory)
TARGET_DIR="${1:-.}"

# Find project root by walking up from target directory
find_project_root() {
  local dir="$(cd "$TARGET_DIR" && pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/package.json" ]]; then
      echo "$dir"
      return 0
    fi
    if [[ -d "$dir/.git" ]]; then
      echo "$dir"
      return 0
    fi
    if [[ -f "$dir/tsconfig.json" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  # Default to target directory
  echo "$(cd "$TARGET_DIR" && pwd)"
}

PROJECT_ROOT=$(find_project_root)

echo "📁 Project root: $PROJECT_ROOT"
echo

# Change to project root
cd "$PROJECT_ROOT"

# Check if required tools are installed
if ! command -v npx >/dev/null 2>&1; then
  echo "❌ Error: npx not found"
  echo "Please install Node.js and npm."
  echo "Visit: https://nodejs.org/"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "❌ Error: jq not found"
  echo "Please install jq for JSON parsing."
  echo "Visit: https://stedolan.github.io/jq/"
  exit 1
fi

# Check if dependencies are installed
MISSING_DEPS=()

if ! npx prettier --version >/dev/null 2>&1; then
  MISSING_DEPS+=("prettier")
fi

if ! npx eslint --version >/dev/null 2>&1; then
  MISSING_DEPS+=("eslint")
fi

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
  echo "❌ Missing dependencies: ${MISSING_DEPS[*]}"
  echo
  echo "Please install them with:"
  echo "  npm install --save-dev ${MISSING_DEPS[*]}"
  echo
  echo "Or using yarn:"
  echo "  yarn add --dev ${MISSING_DEPS[*]}"
  exit 1
fi

echo "✅ All dependencies found"
echo

# Run Prettier
echo "🎨 Running Prettier..."
if npx prettier --write "**/*.{js,jsx,ts,tsx,mjs,cjs}" 2>&1; then
  echo "   ✓ Prettier completed"
else
  echo "   ⚠️  Prettier encountered some issues"
fi
echo

# Run ESLint with --fix
echo "🔍 Running ESLint..."
ESLINT_EXIT_CODE=0
npx eslint --fix "**/*.{js,jsx,ts,tsx,mjs,cjs}" 2>&1 || ESLINT_EXIT_CODE=$?

if [[ $ESLINT_EXIT_CODE -eq 0 ]]; then
  echo "   ✓ ESLint completed with no errors"
else
  echo "   ⚠️  ESLint found issues (exit code: $ESLINT_EXIT_CODE)"
fi
echo

# Generate report by running ESLint again to get JSON output
echo "# TypeScript/JavaScript Linting Report"
echo
echo "## Summary"
echo

# Get ESLint report
ESLINT_JSON=$(npx eslint --format json "**/*.{js,jsx,ts,tsx,mjs,cjs}" 2>/dev/null || true)

# Validate JSON
if ! echo "$ESLINT_JSON" | jq -e . >/dev/null 2>&1; then
  ESLINT_JSON="[]"
fi

if [[ -n "$ESLINT_JSON" ]] && [[ "$ESLINT_JSON" != "[]" ]]; then
  # Count total files, errors, and warnings using jq
  TOTAL_FILES=$(echo "$ESLINT_JSON" | jq 'length' 2>/dev/null || echo "0")
  TOTAL_ERRORS=$(echo "$ESLINT_JSON" | jq '[.[].errorCount] | add // 0' 2>/dev/null || echo "0")
  TOTAL_WARNINGS=$(echo "$ESLINT_JSON" | jq '[.[].warningCount] | add // 0' 2>/dev/null || echo "0")

  echo "- **ESLint**: $TOTAL_FILES file(s) checked"
  echo "  - Errors: ${TOTAL_ERRORS:-0}"
  echo "  - Warnings: ${TOTAL_WARNINGS:-0}"
  echo

  # Show errors if any (limit to 20)
  if [[ ${TOTAL_ERRORS:-0} -gt 0 ]]; then
    echo "## ESLint Errors"
    echo
    # Extract and display errors using jq
    echo "$ESLINT_JSON" | jq -r '
      [.[].messages[] | select(.severity == 2)]
      | .[0:20]
      | map("- \(.message) [\(.ruleId // "unknown")]")
      | join("\n")
    ' 2>/dev/null || echo "Error parsing ESLint output"
    echo
  fi

  # Show warnings if any (limit to 10)
  if [[ ${TOTAL_WARNINGS:-0} -gt 0 ]]; then
    echo "## ESLint Warnings"
    echo
    echo "$ESLINT_JSON" | jq -r '
      [.[].messages[] | select(.severity == 1)]
      | .[0:10]
      | map("- \(.message) [\(.ruleId // "unknown")]")
      | join("\n")
    ' 2>/dev/null || echo "Error parsing ESLint output"

    if [[ ${TOTAL_WARNINGS:-0} -gt 10 ]]; then
      REMAINING=$((TOTAL_WARNINGS - 10))
      echo
      echo "_...and $REMAINING more warnings_"
    fi
    echo
  fi

  # Success message
  if [[ ${TOTAL_ERRORS:-0} -eq 0 ]] && [[ ${TOTAL_WARNINGS:-0} -eq 0 ]]; then
    echo "## ✅ All checks passed!"
    echo
    echo "Your project has no linting or formatting issues."
  fi
else
  echo "- **ESLint**: No output or configuration error"
  echo
fi

# Exit with appropriate code
if [[ ${TOTAL_ERRORS:-0} -gt 0 ]]; then
  exit 1
fi

exit 0
