#!/usr/bin/env bash
set -euo pipefail

# Test runner for go-lint plugin

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
TEMP_DIR=""

# Source common library
source "$PLUGIN_ROOT/scripts/go-lint-common.sh"

# Cleanup function
cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Setup temp directory
setup_temp() {
    TEMP_DIR=$(mktemp -d)
    cp -r "$FIXTURES_DIR"/* "$TEMP_DIR/"
}

# Test helper functions
print_test_header() {
    echo ""
    echo "========================================="
    echo "TEST: $1"
    echo "========================================="
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}✓${NC} $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        echo "  Haystack: $haystack"
        echo "  Needle: $needle"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $message: $file"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_json_decision() {
    local json="$1"
    local expected_decision="$2"
    local message="${3:-JSON decision should match}"

    TESTS_RUN=$((TESTS_RUN + 1))

    local actual_decision=$(echo "$json" | jq -r '.decision // empty' 2>/dev/null || echo "")

    if [[ "$actual_decision" == "$expected_decision" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        echo "  Expected decision: $expected_decision"
        echo "  Actual decision: $actual_decision"
        echo "  Full JSON: $json"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Unit tests for common library functions

test_parse_file_path() {
    print_test_header "Parse file path from JSON"

    local json='{"tool_input":{"file_path":"/path/to/file.go"}}'
    local result=$(_gol_parse_file_path "$json")

    assert_equals "/path/to/file.go" "$result" "Should extract file path"
}

test_check_required_tools() {
    print_test_header "Check required tools"

    # Test with existing tools
    if _gol_check_required_tools bash; then
        TESTS_RUN=$((TESTS_RUN + 1))
        echo -e "${GREEN}✓${NC} bash is available"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        TESTS_RUN=$((TESTS_RUN + 1))
        echo -e "${RED}✗${NC} bash should be available"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    # Test with non-existing tool
    if ! _gol_check_required_tools nonexistent_tool_xyz; then
        TESTS_RUN=$((TESTS_RUN + 1))
        echo -e "${GREEN}✓${NC} nonexistent tool correctly detected as missing"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        TESTS_RUN=$((TESTS_RUN + 1))
        echo -e "${RED}✗${NC} nonexistent tool should not be available"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_find_project_root() {
    print_test_header "Find project root"

    setup_temp

    local result=$(_gol_find_project_root "$TEMP_DIR")

    assert_equals "$TEMP_DIR" "$result" "Should find project root with go.mod"
}

test_json_response() {
    print_test_header "Generate JSON response"

    local json=$(_gol_json_response "block" "Test reason" "PostToolUse" "Test context")

    assert_json_decision "$json" "block" "Decision should be 'block'"
    assert_contains "$json" "Test reason" "Should contain reason"
    assert_contains "$json" "Test context" "Should contain context"
}

# Integration tests for hook script

test_hook_on_clean_file() {
    print_test_header "Hook on clean Go file"

    setup_temp

    # Skip if goimports not available
    if ! command -v goimports &>/dev/null; then
        echo -e "${YELLOW}⊘${NC} Skipped (goimports not installed)"
        return 0
    fi

    local test_file="$TEMP_DIR/clean.go"
    local input_json="{\"tool_input\":{\"file_path\":\"$test_file\"}}"

    # Run hook
    local output=$(echo "$input_json" | "$PLUGIN_ROOT/hooks/go-lint.sh" 2>&1 || true)

    # Clean file should exit silently (no output)
    if [[ -z "$output" ]]; then
        TESTS_RUN=$((TESTS_RUN + 1))
        echo -e "${GREEN}✓${NC} Hook exits silently on clean file"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        TESTS_RUN=$((TESTS_RUN + 1))
        echo -e "${RED}✗${NC} Hook should exit silently on clean file"
        echo "  Output: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_hook_on_non_go_file() {
    print_test_header "Hook on non-Go file"

    setup_temp

    local test_file="$TEMP_DIR/test.txt"
    echo "Not a Go file" > "$test_file"
    local input_json="{\"tool_input\":{\"file_path\":\"$test_file\"}}"

    # Run hook
    local output=$(echo "$input_json" | "$PLUGIN_ROOT/hooks/go-lint.sh" 2>&1 || true)

    # Non-Go file should exit silently
    if [[ -z "$output" ]]; then
        TESTS_RUN=$((TESTS_RUN + 1))
        echo -e "${GREEN}✓${NC} Hook exits silently on non-Go file"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        TESTS_RUN=$((TESTS_RUN + 1))
        echo -e "${RED}✗${NC} Hook should exit silently on non-Go file"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_hook_formats_file() {
    print_test_header "Hook formats badly formatted file"

    setup_temp

    # Skip if goimports not available
    if ! command -v goimports &>/dev/null; then
        echo -e "${YELLOW}⊘${NC} Skipped (goimports not installed)"
        return 0
    fi

    local test_file="$TEMP_DIR/format-needed.go"
    local input_json="{\"tool_input\":{\"file_path\":\"$test_file\"}}"

    # Save original content
    local original_content=$(cat "$test_file")

    # Run hook
    echo "$input_json" | "$PLUGIN_ROOT/hooks/go-lint.sh" &>/dev/null || true

    # Check if file was formatted
    local new_content=$(cat "$test_file")

    if [[ "$original_content" != "$new_content" ]]; then
        TESTS_RUN=$((TESTS_RUN + 1))
        echo -e "${GREEN}✓${NC} Hook formatted the file"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        TESTS_RUN=$((TESTS_RUN + 1))
        echo -e "${RED}✗${NC} Hook should format the file"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Integration tests for project script

test_project_script_missing_tools() {
    print_test_header "Project script with missing tools"

    setup_temp

    # Temporarily break PATH to simulate missing golangci-lint
    local output=$(PATH=/usr/bin:/bin "$PLUGIN_ROOT/scripts/go-lint-project.sh" "$TEMP_DIR" 2>&1 || true)

    assert_contains "$output" "Missing required tools" "Should report missing tools"
}

test_project_script_on_fixtures() {
    print_test_header "Project script on test fixtures"

    setup_temp

    # Skip if golangci-lint not available
    if ! command -v golangci-lint &>/dev/null; then
        echo -e "${YELLOW}⊘${NC} Skipped (golangci-lint not installed)"
        return 0
    fi

    local output=$("$PLUGIN_ROOT/scripts/go-lint-project.sh" "$TEMP_DIR" 2>&1 || true)

    assert_contains "$output" "Go Linting" "Should generate linting report"
}

# Run all tests
echo "======================================"
echo "  Go-Lint Plugin Test Suite"
echo "======================================"

# Unit tests
test_parse_file_path
test_check_required_tools
test_find_project_root
test_json_response

# Integration tests
test_hook_on_clean_file
test_hook_on_non_go_file
test_hook_formats_file
test_project_script_missing_tools
test_project_script_on_fixtures

# Print summary
echo ""
echo "======================================"
echo "  Test Summary"
echo "======================================"
echo -e "Tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
else
    echo -e "Failed: $TESTS_FAILED"
fi
echo "======================================"

# Exit with appropriate code
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
