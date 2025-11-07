#!/usr/bin/env bash
#
# TypeScript-Lint Test Suite
# Comprehensive tests with auto-setup and auto-cleanup
#

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ==============================================================================
# Setup and Cleanup
# ==============================================================================

setup_test_env() {
    echo "Setting up test environment..."

    # Create unique temp directory
    TEST_DIR=$(mktemp -d -t ts-lint-test.XXXXXX)

    # Copy fixtures to temp directory
    cp -r "$SCRIPT_DIR/fixtures" "$TEST_DIR/test-project"

    # Install dependencies
    echo "Installing dependencies (this may take a moment)..."
    cd "$TEST_DIR/test-project"
    npm install --silent --no-audit --no-fund > /dev/null 2>&1 || {
        echo -e "${RED}Failed to install dependencies${NC}"
        exit 1
    }

    echo "Test environment ready at: $TEST_DIR/test-project"
    echo ""
}

cleanup() {
    if [[ -n "${TEST_DIR:-}" ]] && [[ -d "$TEST_DIR" ]]; then
        echo ""
        echo "Cleaning up test environment..."
        rm -rf "$TEST_DIR"
    fi
}

# Register cleanup on exit
trap cleanup EXIT

# ==============================================================================
# Test Helpers
# ==============================================================================

run_test() {
    local test_name="$1"
    shift

    echo -n "Testing: $test_name... "
    TESTS_RUN=$((TESTS_RUN + 1))

    set +e
    "$@"
    local result=$?
    set -e

    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_json_decision() {
    local output="$1"
    local expected_decision="$2"

    # Check if output is valid JSON
    if ! echo "$output" | jq -e . >/dev/null 2>&1; then
        echo "Invalid JSON output" >&2
        return 1
    fi

    # Extract decision
    local actual_decision
    actual_decision=$(echo "$output" | jq -r '.decision')

    if [[ "$actual_decision" == "$expected_decision" ]]; then
        return 0
    else
        echo "Expected decision: $expected_decision, got: $actual_decision" >&2
        return 1
    fi
}

# ==============================================================================
# Hook Tests
# ==============================================================================

test_hook_clean_file() {
    local file_path="$TEST_DIR/test-project/clean.ts"
    local input_json=$(cat <<EOF
{
  "tool_input": {
    "file_path": "$file_path"
  }
}
EOF
)

    local output
    output=$(echo "$input_json" | "$PLUGIN_ROOT/hooks/typescript-lint.sh" 2>&1)

    assert_json_decision "$output" "allow"
}

test_hook_eslint_errors() {
    local file_path="$TEST_DIR/test-project/eslint-errors.ts"
    local input_json=$(cat <<EOF
{
  "tool_input": {
    "file_path": "$file_path"
  }
}
EOF
)

    local output
    output=$(echo "$input_json" | "$PLUGIN_ROOT/hooks/typescript-lint.sh" 2>&1)

    # Should block due to ESLint errors
    assert_json_decision "$output" "block"
}

test_hook_invalid_json() {
    local output
    output=$(echo "not valid json" | "$PLUGIN_ROOT/hooks/typescript-lint.sh" 2>&1)

    # Should handle gracefully and allow
    assert_json_decision "$output" "allow"
}

test_hook_non_ts_file() {
    # Create a non-TypeScript file
    local non_ts_file="$TEST_DIR/test-project/test.txt"
    echo "test content" > "$non_ts_file"

    local input_json=$(cat <<EOF
{
  "tool_input": {
    "file_path": "$non_ts_file"
  }
}
EOF
)

    local output
    output=$(echo "$input_json" | "$PLUGIN_ROOT/hooks/typescript-lint.sh" 2>&1)

    # Should allow (ignore non-TS files)
    assert_json_decision "$output" "allow"
}

test_hook_prettier_autofix() {
    local file_path="$TEST_DIR/test-project/prettier-errors.ts"

    # Save original content
    local original_content
    original_content=$(cat "$file_path")

    local input_json=$(cat <<EOF
{
  "tool_input": {
    "file_path": "$file_path"
  }
}
EOF
)

    # Run hook
    echo "$input_json" | "$PLUGIN_ROOT/hooks/typescript-lint.sh" > /dev/null 2>&1

    # Get new content
    local new_content
    new_content=$(cat "$file_path")

    # Content should be different (fixed)
    if [[ "$original_content" != "$new_content" ]]; then
        return 0
    else
        echo "File was not auto-fixed by Prettier" >&2
        return 1
    fi
}

# ==============================================================================
# Project Script Tests
# ==============================================================================

test_project_scan_succeeds() {
    cd "$TEST_DIR/test-project"

    # Should complete successfully even with errors (exit 0 for warnings, 1 for errors)
    "$PLUGIN_ROOT/scripts/typescript-lint-project.sh" . > /dev/null 2>&1
    local exit_code=$?

    # Accept both 0 and 1 (1 means errors found, which is expected)
    if [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 1 ]]; then
        return 0
    else
        echo "Unexpected exit code: $exit_code" >&2
        return 1
    fi
}

test_project_markdown_output() {
    cd "$TEST_DIR/test-project"

    local output
    output=$("$PLUGIN_ROOT/scripts/typescript-lint-project.sh" . 2>&1)

    # Should contain markdown header
    if echo "$output" | grep -q "# TypeScript/JavaScript Linting Report"; then
        return 0
    else
        echo "Missing markdown header in output" >&2
        return 1
    fi
}

test_project_detects_errors() {
    cd "$TEST_DIR/test-project"

    local output
    output=$("$PLUGIN_ROOT/scripts/typescript-lint-project.sh" . 2>&1)

    # Should detect the errors in eslint-errors.ts
    if echo "$output" | grep -q "ESLint Errors"; then
        return 0
    else
        echo "Did not detect ESLint errors" >&2
        return 1
    fi
}

# ==============================================================================
# Main Test Execution
# ==============================================================================

main() {
    echo "========================================"
    echo "TypeScript-Lint Test Suite"
    echo "========================================"
    echo ""

    # Setup
    setup_test_env

    # Run hook tests
    echo "--- Hook Tests ---"
    run_test "Hook: Clean file" test_hook_clean_file
    run_test "Hook: ESLint errors" test_hook_eslint_errors
    run_test "Hook: Invalid JSON" test_hook_invalid_json
    run_test "Hook: Non-TS file" test_hook_non_ts_file
    run_test "Hook: Prettier auto-fix" test_hook_prettier_autofix

    echo ""

    # Run project script tests
    echo "--- Project Script Tests ---"
    run_test "Project: Scan succeeds" test_project_scan_succeeds
    run_test "Project: Markdown output" test_project_markdown_output
    run_test "Project: Detects errors" test_project_detects_errors

    # Summary
    echo ""
    echo "========================================"
    echo "Test Summary"
    echo "========================================"
    echo "Total: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}Failed: $TESTS_FAILED${NC}"
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

# Run main
main
