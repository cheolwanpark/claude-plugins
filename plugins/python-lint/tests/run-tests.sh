#!/usr/bin/env bash
#
# Python-Lint Test Suite
# Comprehensive tests: Unit tests for common library + integration tests for hooks/scripts
# Auto-setup with temp directory and auto-cleanup
#

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Source common library for unit tests
# shellcheck disable=SC1091
source "$PLUGIN_ROOT/scripts/python-lint-common.sh"

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
# Test Helpers
# ==============================================================================

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Testing: $test_name... "

    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_success() {
    local test_name="$1"
    shift
    local exit_code=0

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Testing: $test_name... "

    "$@" &>/dev/null || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC} (exit code: $exit_code)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_failure() {
    local test_name="$1"
    shift
    local exit_code=0

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Testing: $test_name... "

    "$@" &>/dev/null || exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC} (expected failure, got success)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"

    echo -n "Testing: $test_name... "
    TESTS_RUN=$((TESTS_RUN + 1))

    set +e
    TEST_OUTPUT=$(eval "$test_command" 2>&1)
    TEST_EXIT=$?
    set -e

    if [[ $TEST_EXIT -eq $expected_exit_code ]]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC} (exit code: $TEST_EXIT, expected: $expected_exit_code)"
        echo "Output: $TEST_OUTPUT"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# ==============================================================================
# Unit Tests: Common Library Functions
# ==============================================================================

test_unit_json_response() {
    # Test basic allow response
    RESULT=$(_pyl_json_response "allow" "test reason")
    assert_equals "allow" "$(echo "$RESULT" | jq -r '.decision')" "JSON response: allow decision"
    assert_equals "test reason" "$(echo "$RESULT" | jq -r '.reason')" "JSON response: reason"

    # Test block response with context
    RESULT=$(_pyl_json_response "block" "error found" "PostToolUse" "error details")
    assert_equals "block" "$(echo "$RESULT" | jq -r '.decision')" "JSON response: block decision"
    assert_equals "PostToolUse" "$(echo "$RESULT" | jq -r '.hookSpecificOutput.hookEventName')" "JSON response: event name"
    assert_equals "error details" "$(echo "$RESULT" | jq -r '.hookSpecificOutput.additionalContext')" "JSON response: context"
}

test_unit_input_parsing() {
    # Test valid JSON input
    JSON_INPUT='{"tool_input": {"file_path": "/test/path.py"}}'
    RESULT=$(_pyl_parse_file_path "$JSON_INPUT")
    assert_equals "/test/path.py" "$RESULT" "Parse file path: valid JSON"

    # Test empty JSON
    JSON_INPUT='{}'
    RESULT=$(_pyl_parse_file_path "$JSON_INPUT")
    assert_equals "" "$RESULT" "Parse file path: empty JSON"

    # Test invalid JSON
    JSON_INPUT='not valid json'
    RESULT=$(_pyl_parse_file_path "$JSON_INPUT")
    assert_equals "" "$RESULT" "Parse file path: invalid JSON"
}

test_unit_tool_checking() {
    assert_success "Check tools: bash exists" _pyl_check_required_tools bash
    assert_failure "Check tools: fake tool missing" _pyl_check_required_tools bash fake-tool-that-does-not-exist
}

test_unit_config_detection() {
    # Test from fixtures (has pyproject.toml with [tool.ruff])
    assert_success "Detect ruff config: fixtures" _pyl_detect_ruff_config "$SCRIPT_DIR/fixtures"
    # Test with plugin root (has ruff.toml)
    assert_success "Detect ruff config: plugin root" _pyl_detect_ruff_config "$PLUGIN_ROOT"
    # Test with /tmp (no config)
    assert_failure "Detect ruff config: /tmp (no config)" _pyl_detect_ruff_config "/tmp"
}

# ==============================================================================
# Setup and Cleanup for Integration Tests
# ==============================================================================

setup_test_env() {
    echo "Setting up test environment..."

    # Create unique temp directory
    TEST_DIR=$(mktemp -d -t py-lint-test.XXXXXX)

    # Copy fixtures to temp directory
    cp -r "$SCRIPT_DIR/fixtures" "$TEST_DIR/test-project"

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
# Integration Tests: Hook Script
# ==============================================================================

test_integration_hook() {
    local file_path="$TEST_DIR/test-project/clean.py"
    local input_json=$(cat <<EOF
{
  "tool_input": {
    "file_path": "$file_path"
  }
}
EOF
)

    # Test 1: Clean file (should allow)
    run_test "Hook: Clean file" \
        "echo '$input_json' | '$PLUGIN_ROOT/hooks/python-lint.sh'" \
        0

    # Test 2: Ruff errors (should block)
    file_path="$TEST_DIR/test-project/ruff-errors.py"
    input_json=$(cat <<EOF
{
  "tool_input": {
    "file_path": "$file_path"
  }
}
EOF
)
    run_test "Hook: Ruff errors" \
        "echo '$input_json' | '$PLUGIN_ROOT/hooks/python-lint.sh' | jq -r '.decision' | grep -q 'block'" \
        0

    # Test 3: Type errors (should block)
    file_path="$TEST_DIR/test-project/type-errors.py"
    input_json=$(cat <<EOF
{
  "tool_input": {
    "file_path": "$file_path"
  }
}
EOF
)
    run_test "Hook: Type errors" \
        "echo '$input_json' | '$PLUGIN_ROOT/hooks/python-lint.sh' | jq -r '.decision' | grep -q 'block'" \
        0

    # Test 4: Invalid JSON (should handle gracefully)
    run_test "Hook: Invalid JSON" \
        "echo 'invalid json' | '$PLUGIN_ROOT/hooks/python-lint.sh'" \
        0
}

# ==============================================================================
# Integration Tests: Project Script
# ==============================================================================

test_integration_project() {
    # Test 1: Scan test directory
    run_test "Project: Scan test directory" \
        "'$PLUGIN_ROOT/scripts/python-lint-project.sh' '$TEST_DIR/test-project' > /dev/null" \
        0

    # Test 2: Generate markdown
    run_test "Project: Markdown output" \
        "OUTPUT=\$('$PLUGIN_ROOT/scripts/python-lint-project.sh' '$TEST_DIR/test-project' 2>/dev/null); echo \"\$OUTPUT\" | grep -q '# Python Lint Report'" \
        0

    # Test 3: Detect errors
    run_test "Project: Detects errors" \
        "OUTPUT=\$('$PLUGIN_ROOT/scripts/python-lint-project.sh' '$TEST_DIR/test-project' 2>/dev/null); echo \"\$OUTPUT\" | grep -q 'Linting issues:'" \
        0
}

# ==============================================================================
# Main Test Execution
# ==============================================================================

main() {
    echo "========================================"
    echo "Python-Lint Test Suite"
    echo "========================================"
    echo ""

    # Run unit tests
    echo "--- Unit Tests: Common Library ---"
    test_unit_json_response
    test_unit_input_parsing
    test_unit_tool_checking
    test_unit_config_detection

    echo ""

    # Setup for integration tests
    setup_test_env

    # Run integration tests
    echo "--- Integration Tests: Hook Script ---"
    test_integration_hook

    echo ""
    echo "--- Integration Tests: Project Script ---"
    test_integration_project

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
