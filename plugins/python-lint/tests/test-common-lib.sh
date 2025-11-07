#!/usr/bin/env bash
#
# Unit tests for python-lint-common.sh
#

set -euo pipefail

# Get script directory and source the common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Source the common library
# shellcheck disable=SC1091
source "$PLUGIN_ROOT/scripts/python-lint-common.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper
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

echo "========================================"
echo "Python Lint Common Library Tests"
echo "========================================"
echo ""

# ============================================================================
# JSON Response Tests
# ============================================================================
echo "--- JSON Response Tests ---"

# Test basic allow response
RESULT=$(_pyl_json_response "allow" "test reason")
assert_equals "allow" "$(echo "$RESULT" | jq -r '.decision')" "JSON response: allow decision"
assert_equals "test reason" "$(echo "$RESULT" | jq -r '.reason')" "JSON response: reason"

# Test block response with context
RESULT=$(_pyl_json_response "block" "error found" "PostToolUse" "error details")
assert_equals "block" "$(echo "$RESULT" | jq -r '.decision')" "JSON response: block decision"
assert_equals "PostToolUse" "$(echo "$RESULT" | jq -r '.hookSpecificOutput.hookEventName')" "JSON response: event name"
assert_equals "error details" "$(echo "$RESULT" | jq -r '.hookSpecificOutput.additionalContext')" "JSON response: context"

echo ""

# ============================================================================
# Input Parsing Tests
# ============================================================================
echo "--- Input Parsing Tests ---"

# Test valid JSON input
JSON_INPUT='{"tool_input": {"file_path": "/test/path.py"}}'
RESULT=$(_pyl_parse_file_path "$JSON_INPUT")
assert_equals "/test/path.py" "$RESULT" "Parse file path: valid JSON"

# Test empty JSON
JSON_INPUT='{}'
RESULT=$(_pyl_parse_file_path "$JSON_INPUT")
assert_equals "" "$RESULT" "Parse file path: empty JSON"

# Test invalid JSON (should handle gracefully)
JSON_INPUT='not valid json'
RESULT=$(_pyl_parse_file_path "$JSON_INPUT")
assert_equals "" "$RESULT" "Parse file path: invalid JSON"

echo ""

# ============================================================================
# Tool Checking Tests
# ============================================================================
echo "--- Tool Checking Tests ---"

# Test with available tools
assert_success "Check tools: bash exists" _pyl_check_required_tools bash

# Test with missing tool
assert_failure "Check tools: fake tool missing" _pyl_check_required_tools bash fake-tool-that-does-not-exist

# Test that _PYL_MISSING_TOOLS is set correctly
_pyl_check_required_tools bash fake-tool jq || true
if [[ ${#_PYL_MISSING_TOOLS[@]} -gt 0 ]] && [[ "${_PYL_MISSING_TOOLS[0]}" == "fake-tool" ]]; then
    echo -n "Testing: Check tools: missing tools array... "
    echo -e "${GREEN}PASS${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

echo ""

# ============================================================================
# Project Root Detection Tests
# ============================================================================
echo "--- Project Root Detection Tests ---"

# Test finding git root (our plugin is in a git repo, should find parent .git)
RESULT=$(_pyl_find_project_root "$PLUGIN_ROOT")
# Result should be a directory with .git or ruff.toml
if [[ -d "$RESULT/.git" ]] || [[ -f "$RESULT/ruff.toml" ]]; then
    echo -n "Testing: Find project root: from plugin dir... "
    echo -e "${GREEN}PASS${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -n "Testing: Find project root: from plugin dir... "
    echo -e "${RED}FAIL${NC}"
    echo "  Result has no .git or config: $RESULT"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test from test-project (has pyproject.toml)
RESULT=$(_pyl_find_project_root "$SCRIPT_DIR/test-project")
assert_equals "$SCRIPT_DIR/test-project" "$RESULT" "Find project root: from test-project"

echo ""

# ============================================================================
# Config Detection Tests
# ============================================================================
echo "--- Config Detection Tests ---"

# Test with test-project (has pyproject.toml with [tool.ruff])
assert_success "Detect ruff config: test-project" _pyl_detect_ruff_config "$SCRIPT_DIR/test-project"

# Test with plugin root (has ruff.toml)
assert_success "Detect ruff config: plugin root" _pyl_detect_ruff_config "$PLUGIN_ROOT"

# Test with /tmp (no config)
assert_failure "Detect ruff config: /tmp (no config)" _pyl_detect_ruff_config "/tmp"

# Test build config args
_pyl_build_ruff_config_args "$SCRIPT_DIR/test-project" "$PLUGIN_ROOT"
if [[ ${#_PYL_RUFF_CONFIG_ARGS[@]} -eq 0 ]]; then
    echo -n "Testing: Build config args: user config exists... "
    echo -e "${GREEN}PASS${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -n "Testing: Build config args: user config exists... "
    echo -e "${RED}FAIL${NC}"
    echo "  Expected empty array, got: ${_PYL_RUFF_CONFIG_ARGS[*]}"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

_pyl_build_ruff_config_args "/tmp" "$PLUGIN_ROOT"
if [[ ${#_PYL_RUFF_CONFIG_ARGS[@]} -eq 2 ]] && [[ "${_PYL_RUFF_CONFIG_ARGS[0]}" == "--config" ]]; then
    echo -n "Testing: Build config args: plugin config fallback... "
    echo -e "${GREEN}PASS${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -n "Testing: Build config args: plugin config fallback... "
    echo -e "${RED}FAIL${NC}"
    echo "  Expected --config arg, got: ${_PYL_RUFF_CONFIG_ARGS[*]}"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""

# ============================================================================
# Path Utilities Tests
# ============================================================================
echo "--- Path Utilities Tests ---"

# Test absolute path
RESULT=$(_pyl_get_absolute_path "$PLUGIN_ROOT")
if [[ "$RESULT" == /* ]]; then
    echo -n "Testing: Get absolute path: plugin root... "
    echo -e "${GREEN}PASS${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -n "Testing: Get absolute path: plugin root... "
    echo -e "${RED}FAIL${NC}"
    echo "  Result not absolute: $RESULT"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test relative path
ABS_PATH="$PLUGIN_ROOT/tests/test-project/clean_file.py"
REL_PATH=$(_pyl_get_relative_path "$ABS_PATH" "$PLUGIN_ROOT")
assert_equals "tests/test-project/clean_file.py" "$REL_PATH" "Get relative path: clean_file.py"

echo ""

# ============================================================================
# Summary
# ============================================================================
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
