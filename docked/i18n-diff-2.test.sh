#!/bin/bash
#
# Test suite for i18n-diff-2
#
# This script creates test scenarios and validates that i18n-diff-2
# correctly extracts and compares translation strings.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="/tmp/i18n-diff-2-test-$$"
PYTHON_SCRIPT="${SCRIPT_DIR}/i18n-diff-2.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

setup() {
    echo "Setting up test environment..."
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
}

teardown() {
    echo "Cleaning up..."
    cd /
    rm -rf "$TEST_DIR"
}

assert_contains() {
    local output="$1"
    local expected="$2"
    local test_name="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if echo "$output" | grep -qF "$expected"; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected to find: $expected"
        echo "  In output:"
        echo "$output" | sed 's/^/    /'
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_not_contains() {
    local output="$1"
    local unexpected="$2"
    local test_name="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if echo "$output" | grep -qF "$unexpected"; then
        echo -e "${RED}✗${NC} $test_name"
        echo "  Did not expect to find: $unexpected"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    else
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    fi
}

test_case_1_simple_strings() {
    echo "Test Case 1: Simple string extraction"

    cat > file1.php <<'EOF'
<?php
_s("Hello World");
_s("Goodbye World");
EOF

    git add file1.php
    git commit -m "Initial commit"
    local commit1=$(git rev-parse HEAD)

    cat > file1.php <<'EOF'
<?php
_s("Hello World");
_s("Welcome User");
EOF

    git add file1.php
    git commit -m "Change strings"
    local commit2=$(git rev-parse HEAD)

    output=$(python3 "$PYTHON_SCRIPT" "$commit1" "$commit2" 2>&1)

    assert_contains "$output" "Welcome User" "Should detect added string"
    assert_contains "$output" "Goodbye World" "Should detect removed string"
    assert_not_contains "$output" "Hello World" "Should not show unchanged string"
}

test_case_2_concatenated_strings() {
    echo "Test Case 2: Concatenated strings"

    cat > file2.php <<'EOF'
<?php
_s("Hello " . "World");
_s("Multi" . "ple" . "Parts");
EOF

    git add file2.php
    git commit -m "Add concatenated"
    local commit1=$(git rev-parse HEAD)

    cat > file2.php <<'EOF'
<?php
_s("Hello World");
_s("MultipleParts");
EOF

    git add file2.php
    git commit -m "Make literal"
    local commit2=$(git rev-parse HEAD)

    output=$(python3 "$PYTHON_SCRIPT" "$commit1" "$commit2" 2>&1)

    # Both versions should be treated as identical
    assert_not_contains "$output" "Hello World" "Concatenated should equal literal"
    assert_not_contains "$output" "MultipleParts" "Multi-part concatenation should work"
}

test_case_3_multiline_strings() {
    echo "Test Case 3: Multiline strings"

    cat > file3.php <<'EOF'
<?php
_s("This is a
multiline
string");
EOF

    git add file3.php
    git commit -m "Add multiline"
    local commit1=$(git rev-parse HEAD)

    cat > file3.php <<'EOF'
<?php
_s("Different string");
EOF

    git add file3.php
    git commit -m "Change to single line"
    local commit2=$(git rev-parse HEAD)

    output=$(python3 "$PYTHON_SCRIPT" "$commit1" "$commit2" 2>&1)

    assert_contains "$output" "This is a" "Should handle multiline strings"
    assert_contains "$output" "Different string" "Should detect new string"
}

test_case_4_context_strings() {
    echo "Test Case 4: Context strings (_x, _xs)"

    cat > file4.php <<'EOF'
<?php
_x("Save", "button");
_xs("Save", "menu");
EOF

    git add file4.php
    git commit -m "Add context strings"
    local commit1=$(git rev-parse HEAD)

    cat > file4.php <<'EOF'
<?php
_x("Save", "button");
_xs("Store", "menu");
EOF

    git add file4.php
    git commit -m "Change context string"
    local commit2=$(git rev-parse HEAD)

    output=$(python3 "$PYTHON_SCRIPT" "$commit1" "$commit2" 2>&1)

    assert_contains "$output" "context" "Should show context information"
    assert_contains "$output" "Store" "Should detect new context string"
    assert_contains "$output" "Save" "Should detect removed context string (different context)"
}

test_case_5_plural_strings() {
    echo "Test Case 5: Plural strings (_n)"

    cat > file5.php <<'EOF'
<?php
_n("One item", "Many items");
EOF

    git add file5.php
    git commit -m "Add plural"
    local commit1=$(git rev-parse HEAD)

    cat > file5.php <<'EOF'
<?php
_n("One thing", "Many things");
EOF

    git add file5.php
    git commit -m "Change plural"
    local commit2=$(git rev-parse HEAD)

    output=$(python3 "$PYTHON_SCRIPT" "$commit1" "$commit2" 2>&1)

    assert_contains "$output" "One item" "Should detect old plural"
    assert_contains "$output" "One thing" "Should detect new plural"
}

test_case_6_json_output() {
    echo "Test Case 6: JSON output format"

    cat > file6.php <<'EOF'
<?php
_s("Test String");
EOF

    git add file6.php
    git commit -m "Add test string"
    local commit1=$(git rev-parse HEAD)

    cat > file6.php <<'EOF'
<?php
_s("Test String");
_s("New String");
EOF

    git add file6.php
    git commit -m "Add new string"
    local commit2=$(git rev-parse HEAD)

    output=$(python3 "$PYTHON_SCRIPT" --json "$commit1" "$commit2" 2>&1)

    assert_contains "$output" '"added"' "JSON should have added field"
    assert_contains "$output" '"removed"' "JSON should have removed field"
    assert_contains "$output" '"New String"' "JSON should contain new string"
}

test_case_7_escaped_quotes() {
    echo "Test Case 7: Escaped quotes in strings"

    cat > file7.php <<'EOF'
<?php
_s("He said \"Hello\"");
_s('She said \'Hi\'');
EOF

    git add file7.php
    git commit -m "Add escaped quotes"
    local commit1=$(git rev-parse HEAD)

    cat > file7.php <<'EOF'
<?php
_s("Different text");
EOF

    git add file7.php
    git commit -m "Remove escaped"
    local commit2=$(git rev-parse HEAD)

    output=$(python3 "$PYTHON_SCRIPT" "$commit1" "$commit2" 2>&1)

    assert_contains "$output" "Hello" "Should handle double quote escapes"
    assert_contains "$output" "Hi" "Should handle single quote escapes"
}

test_case_8_empty_change() {
    echo "Test Case 8: No changes"

    cat > file8.php <<'EOF'
<?php
_s("Same String");
EOF

    git add file8.php
    git commit -m "Add string"
    local commit1=$(git rev-parse HEAD)

    # Make a commit with no string changes
    cat > other.txt <<'EOF'
Some other content
EOF

    git add other.txt
    git commit -m "Non-PHP change"
    local commit2=$(git rev-parse HEAD)

    output=$(python3 "$PYTHON_SCRIPT" "$commit1" "$commit2" 2>&1)

    assert_not_contains "$output" "Same String" "Should not show unchanged strings"
}

test_case_9_mixed_quotes() {
    echo "Test Case 9: Mixed quote styles"

    cat > file9.php <<'EOF'
<?php
_s("Double quotes");
_s('Single quotes');
_s("Concat " . 'with mixed' . " quotes");
EOF

    git add file9.php
    git commit -m "Mixed quotes"
    local commit1=$(git rev-parse HEAD)

    cat > file9.php <<'EOF'
<?php
_s("New string");
EOF

    git add file9.php
    git commit -m "Replace all"
    local commit2=$(git rev-parse HEAD)

    output=$(python3 "$PYTHON_SCRIPT" "$commit1" "$commit2" 2>&1)

    assert_contains "$output" "Double quotes" "Should handle double quotes"
    assert_contains "$output" "Single quotes" "Should handle single quotes"
    assert_contains "$output" "Concat with mixed quotes" "Should handle mixed concatenation"
}

test_case_10_xn_function() {
    echo "Test Case 10: Context + plural (_xn)"

    cat > file10.php <<'EOF'
<?php
_xn("One file", "Many files", $count, "filesystem");
EOF

    git add file10.php
    git commit -m "Add _xn"
    local commit1=$(git rev-parse HEAD)

    cat > file10.php <<'EOF'
<?php
_xn("One document", "Many documents", $count, "filesystem");
EOF

    git add file10.php
    git commit -m "Change _xn"
    local commit2=$(git rev-parse HEAD)

    output=$(python3 "$PYTHON_SCRIPT" "$commit1" "$commit2" 2>&1)

    assert_contains "$output" "One file" "Should detect old _xn string"
    assert_contains "$output" "One document" "Should detect new _xn string"
    assert_contains "$output" "context" "Should show context for _xn"
}

# Main test runner
main() {
    echo "================================"
    echo "i18n-diff-2 Test Suite"
    echo "================================"
    echo ""

    setup

    # Run all test cases
    test_case_1_simple_strings
    test_case_2_concatenated_strings
    test_case_3_multiline_strings
    test_case_4_context_strings
    test_case_5_plural_strings
    test_case_6_json_output
    test_case_7_escaped_quotes
    test_case_8_empty_change
    test_case_9_mixed_quotes
    test_case_10_xn_function

    teardown

    echo ""
    echo "================================"
    echo "Test Results"
    echo "================================"
    echo "Total tests run: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "${RED}Failed: $TESTS_FAILED${NC}"
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

main "$@"
