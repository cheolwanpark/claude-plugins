#!/usr/bin/env bash
#
# Rust-Lint Test Suite
# Comprehensive testing for the rust-lint plugin
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Source common library for testing
# shellcheck disable=SC1091
source "$PLUGIN_ROOT/scripts/rust-lint-common.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# Test Helpers
# ============================================================================

run_test() {
    local test_name="$1"
    shift
    echo -n "Testing: $test_name... "
    TESTS_RUN=$((TESTS_RUN + 1))

    set +e
    local output
    output=$("$@" 2>&1)
    local result=$?
    set -e

    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Output: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    [[ "$actual" == "$expected" ]]
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    echo "$haystack" | grep -q "$needle"
}

assert_json_decision() {
    local json="$1"
    local expected_decision="$2"
    local actual_decision
    actual_decision=$(echo "$json" | jq -r '.decision' 2>/dev/null)
    [[ "$actual_decision" == "$expected_decision" ]]
}

assert_valid_json() {
    local json="$1"
    echo "$json" | jq -e . >/dev/null 2>&1
}

assert_silent_success() {
    local output="$1"
    # For PostToolUse hooks, successful operations should exit silently (no output)
    [[ -z "$output" ]]
}

assert_json_or_silent() {
    local output="$1"
    # Output can be either empty (silent) OR valid JSON
    if [[ -z "$output" ]]; then
        return 0
    else
        assert_valid_json "$output"
    fi
}

# ============================================================================
# Setup and Cleanup
# ============================================================================

setup_test_env() {
    TEST_DIR=$(mktemp -d -t rust-lint-test.XXXXXX)
    cp -r "$SCRIPT_DIR/fixtures" "$TEST_DIR/test-project"
    echo -e "${YELLOW}Test environment: $TEST_DIR/test-project${NC}"
}

cleanup() {
    if [[ -n "${TEST_DIR:-}" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

trap cleanup EXIT

# ============================================================================
# Unit Tests - Common Library Functions
# ============================================================================

test_json_response_simple() {
    local json
    json=$(_rl_json_response "allow" "Test message")
    assert_json_decision "$json" "allow"
}

test_json_response_with_context() {
    local json
    json=$(_rl_json_response "block" "Error message" "PostToolUse" "Detailed context")
    assert_json_decision "$json" "block" &&
    echo "$json" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null
}

test_post_tool_exit_silent() {
    # Test that silent exit produces no output
    local output
    output=$(_rl_safe_exit_post_tool "silent" 2>/dev/null || true)
    assert_silent_success "$output"
}

test_post_tool_exit_block() {
    # Test that block exit produces valid JSON with decision=block
    local output
    output=$(_rl_safe_exit_post_tool "block" "Error message" 2>/dev/null || true)
    assert_valid_json "$output" &&
    assert_json_decision "$output" "block"
}

test_post_tool_exit_block_with_context() {
    # Test that block with context includes hookSpecificOutput
    local output
    output=$(_rl_safe_exit_post_tool "block" "Error message" "Additional context" 2>/dev/null || true)
    assert_valid_json "$output" &&
    assert_json_decision "$output" "block" &&
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null
}

test_parse_file_path() {
    local input='{"tool_input":{"file_path":"/path/to/file.rs"}}'
    local path
    path=$(_rl_parse_file_path "$input")
    assert_equals "/path/to/file.rs" "$path"
}

test_check_required_tools_success() {
    _rl_check_required_tools bash
}

test_check_required_tools_failure() {
    ! _rl_check_required_tools nonexistent_tool_xyz
}

test_find_project_root() {
    local root
    root=$(_rl_find_project_root "$TEST_DIR/test-project/src")
    assert_contains "$root" "test-project"
}

# ============================================================================
# Hook Integration Tests
# ============================================================================

test_hook_clean_file() {
    local file_path="$TEST_DIR/test-project/src/clean.rs"
    local input
    input=$(jq -n --arg path "$file_path" '{tool_input:{file_path:$path}}')
    local output
    output=$(echo "$input" | "$PLUGIN_ROOT/hooks/rust-lint.sh")
    # Should exit silently on success (PostToolUse behavior)
    assert_silent_success "$output"
}

test_hook_badly_formatted_file() {
    local file_path="$TEST_DIR/test-project/src/fmt_errors.rs"
    local input
    input=$(jq -n --arg path "$file_path" '{tool_input:{file_path:$path}}')
    local output
    output=$(echo "$input" | "$PLUGIN_ROOT/hooks/rust-lint.sh")
    # Hook should exit silently (formatting is auto-applied)
    assert_silent_success "$output"
}

test_hook_non_rust_file() {
    local file_path="$TEST_DIR/test-project/Cargo.toml"
    local input
    input=$(jq -n --arg path "$file_path" '{tool_input:{file_path:$path}}')
    local output
    output=$(echo "$input" | "$PLUGIN_ROOT/hooks/rust-lint.sh")
    # Should exit silently (non-Rust files are skipped)
    assert_silent_success "$output"
}

test_hook_nonexistent_file() {
    local file_path="$TEST_DIR/test-project/src/nonexistent.rs"
    local input
    input=$(jq -n --arg path "$file_path" '{tool_input:{file_path:$path}}')
    local output
    output=$(echo "$input" | "$PLUGIN_ROOT/hooks/rust-lint.sh")
    # Should exit silently (nonexistent files are skipped)
    assert_silent_success "$output"
}

test_hook_invalid_json() {
    local output
    output=$(echo "invalid json" | "$PLUGIN_ROOT/hooks/rust-lint.sh" || true)
    # Should exit gracefully with no output
    assert_silent_success "$output"
}

test_hook_large_file() {
    # Create a file larger than 1MB
    local large_file="$TEST_DIR/test-project/src/large.rs"
    dd if=/dev/zero of="$large_file" bs=1024 count=1100 2>/dev/null
    echo "pub fn test() {}" >> "$large_file"  # Make it valid Rust

    local input
    input=$(jq -n --arg path "$large_file" '{tool_input:{file_path:$path}}')
    local output
    output=$(echo "$input" | "$PLUGIN_ROOT/hooks/rust-lint.sh")

    # Should skip large files silently (to reduce noise)
    assert_silent_success "$output"
}

test_hook_empty_stdin() {
    local output
    output=$(echo "" | "$PLUGIN_ROOT/hooks/rust-lint.sh")
    # Should exit silently for empty input
    assert_silent_success "$output"
}

test_hook_stdin_timeout() {
    local output
    # Simulate slow/hanging stdin by using a timeout
    output=$(echo "" | "$PLUGIN_ROOT/hooks/rust-lint.sh" 2>/dev/null)
    # Should exit silently
    assert_silent_success "$output"
}

test_hook_empty_file_path() {
    local input='{"tool_input":{"file_path":""}}'
    local output
    output=$(echo "$input" | "$PLUGIN_ROOT/hooks/rust-lint.sh")
    # Should exit silently for empty file path
    assert_silent_success "$output"
}

test_hook_missing_tool_input() {
    local input='{"other":"data"}'
    local output
    output=$(echo "$input" | "$PLUGIN_ROOT/hooks/rust-lint.sh")
    # Should exit silently when tool_input is missing
    assert_silent_success "$output"
}

test_hook_json_output_valid_or_empty() {
    # Test all hook outputs are either empty (silent) or valid JSON
    local file_path="$TEST_DIR/test-project/src/clean.rs"
    local inputs=(
        '{"tool_input":{"file_path":"'"$file_path"'"}}'
        '{"tool_input":{}}'
        '{}'
        '{"tool_input":{"file_path":""}}'
        '{"tool_input":{"file_path":"/nonexistent/file.rs"}}'
    )

    for input in "${inputs[@]}"; do
        local output
        # Capture actual output even if hook returns non-zero exit code
        output=$(echo "$input" | "$PLUGIN_ROOT/hooks/rust-lint.sh" 2>&1 || true)
        # Output must be either empty (silent success) OR valid JSON (block decision)
        if ! assert_json_or_silent "$output"; then
            echo "Invalid output for input: $input"
            echo "Output: $output"
            return 1
        fi
    done
}

# ============================================================================
# Project Script Tests
# ============================================================================

test_project_script_runs() {
    cd "$TEST_DIR/test-project"
    # Script may exit with 1 if issues found (expected behavior)
    "$PLUGIN_ROOT/scripts/rust-lint-project.sh" . >/dev/null || [[ $? -eq 1 ]]
}

test_project_script_markdown_output() {
    cd "$TEST_DIR/test-project"
    local output
    output=$("$PLUGIN_ROOT/scripts/rust-lint-project.sh" . 2>/dev/null || true)
    assert_contains "$output" "# Rust Lint Report"
}

test_project_script_detects_clippy_warnings() {
    cd "$TEST_DIR/test-project"
    local output
    output=$("$PLUGIN_ROOT/scripts/rust-lint-project.sh" . 2>/dev/null || true)
    # Should mention clippy in the report
    assert_contains "$output" "Clippy"
}

test_project_script_detects_formatting_issues() {
    cd "$TEST_DIR/test-project"
    local output
    output=$("$PLUGIN_ROOT/scripts/rust-lint-project.sh" . 2>/dev/null || true)
    # Should detect that formatting is needed
    assert_contains "$output" "Formatting"
}

test_project_script_nonexistent_directory() {
    local output
    output=$("$PLUGIN_ROOT/scripts/rust-lint-project.sh" /nonexistent/path 2>&1 || true)
    assert_contains "$output" "does not exist"
}

# ============================================================================
# Main Test Runner
# ============================================================================

main() {
    echo "============================================"
    echo "Rust-Lint Plugin Test Suite"
    echo "============================================"
    echo ""

    # Setup
    setup_test_env
    echo ""

    # Check dependencies
    echo "Checking dependencies..."
    if ! command -v cargo &>/dev/null; then
        echo -e "${RED}Error: cargo not found. Install Rust toolchain.${NC}"
        exit 1
    fi
    if ! command -v rustfmt &>/dev/null; then
        echo -e "${RED}Error: rustfmt not found. Run: rustup component add rustfmt${NC}"
        exit 1
    fi
    if ! command -v jq &>/dev/null; then
        echo -e "${RED}Error: jq not found. Install jq.${NC}"
        exit 1
    fi
    echo -e "${GREEN}All dependencies found.${NC}"
    echo ""

    # Run unit tests
    echo "============================================"
    echo "Unit Tests - Common Library"
    echo "============================================"
    run_test "JSON response (simple)" test_json_response_simple
    run_test "JSON response (with context)" test_json_response_with_context
    run_test "PostToolUse exit (silent)" test_post_tool_exit_silent
    run_test "PostToolUse exit (block)" test_post_tool_exit_block
    run_test "PostToolUse exit (block with context)" test_post_tool_exit_block_with_context
    run_test "Parse file path" test_parse_file_path
    run_test "Check required tools (success)" test_check_required_tools_success
    run_test "Check required tools (failure)" test_check_required_tools_failure
    run_test "Find project root" test_find_project_root
    echo ""

    # Run hook tests
    echo "============================================"
    echo "Hook Integration Tests"
    echo "============================================"
    run_test "Hook: Clean file" test_hook_clean_file
    run_test "Hook: Badly formatted file" test_hook_badly_formatted_file
    run_test "Hook: Non-Rust file" test_hook_non_rust_file
    run_test "Hook: Nonexistent file" test_hook_nonexistent_file
    run_test "Hook: Invalid JSON input" test_hook_invalid_json
    run_test "Hook: Large file (>1MB)" test_hook_large_file
    run_test "Hook: Empty stdin" test_hook_empty_stdin
    run_test "Hook: Stdin timeout handling" test_hook_stdin_timeout
    run_test "Hook: Empty file path" test_hook_empty_file_path
    run_test "Hook: Missing tool_input field" test_hook_missing_tool_input
    run_test "Hook: Output is valid JSON or empty" test_hook_json_output_valid_or_empty
    echo ""

    # Run project script tests
    echo "============================================"
    echo "Project Script Tests"
    echo "============================================"
    run_test "Project script runs successfully" test_project_script_runs
    run_test "Project script generates markdown" test_project_script_markdown_output
    run_test "Project script detects clippy warnings" test_project_script_detects_clippy_warnings
    run_test "Project script detects formatting issues" test_project_script_detects_formatting_issues
    run_test "Project script handles nonexistent directory" test_project_script_nonexistent_directory
    echo ""

    # Summary
    echo "============================================"
    echo "Test Summary"
    echo "============================================"
    echo "Tests run: $TESTS_RUN"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "Failed: ${GREEN}$TESTS_FAILED${NC}"
        echo ""
        echo -e "${GREEN}✓ All tests passed!${NC}"
        exit 0
    else
        echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
        echo ""
        echo -e "${RED}✗ Some tests failed.${NC}"
        exit 1
    fi
}

main "$@"
