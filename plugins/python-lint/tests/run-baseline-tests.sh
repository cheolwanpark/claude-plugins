#!/usr/bin/env bash
#
# Baseline test script to validate python-lint behavior
# Run this before and after refactoring to ensure consistency
#

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "Python Lint Baseline Tests"
echo "========================================"
echo ""

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"

    echo -n "Testing: $test_name... "
    TESTS_RUN=$((TESTS_RUN + 1))

    # Run the test and capture output and exit code
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

# Test 1: Hook on clean file (should allow)
echo "--- Hook Tests ---"
run_test "Hook: Clean file" \
    "cat '$SCRIPT_DIR/hook-input-clean.json' | '$PLUGIN_ROOT/hooks/python-lint.sh'" \
    0

# Test 2: Hook on file with ruff errors (should exit 0 but output block decision)
run_test "Hook: Ruff errors" \
    "cat '$SCRIPT_DIR/hook-input-ruff-error.json' | '$PLUGIN_ROOT/hooks/python-lint.sh' | jq -r '.decision' | grep -q 'block'" \
    0

# Test 3: Hook on file with type errors (should exit 0 but output block decision)
run_test "Hook: Type errors" \
    "cat '$SCRIPT_DIR/hook-input-type-error.json' | '$PLUGIN_ROOT/hooks/python-lint.sh' | jq -r '.decision' | grep -q 'block'" \
    0

# Test 4: Hook with invalid JSON input (should handle gracefully)
run_test "Hook: Invalid JSON" \
    "echo 'invalid json' | '$PLUGIN_ROOT/hooks/python-lint.sh'" \
    0

# Test 5: Project script on test directory
echo ""
echo "--- Project Script Tests ---"
run_test "Project: Scan test directory" \
    "'$PLUGIN_ROOT/scripts/python-lint-project.sh' '$SCRIPT_DIR/test-project' > /dev/null" \
    0

# Test 6: Project script generates markdown (capture output first to avoid SIGPIPE)
run_test "Project: Markdown output" \
    "OUTPUT=\$('$PLUGIN_ROOT/scripts/python-lint-project.sh' '$SCRIPT_DIR/test-project' 2>/dev/null); echo \"\$OUTPUT\" | grep -q '# Python Lint Report'" \
    0

# Test 7: Project script detects errors (capture output first to avoid SIGPIPE)
run_test "Project: Detects errors" \
    "OUTPUT=\$('$PLUGIN_ROOT/scripts/python-lint-project.sh' '$SCRIPT_DIR/test-project' 2>/dev/null); echo \"\$OUTPUT\" | grep -q 'Linting issues:'" \
    0

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
