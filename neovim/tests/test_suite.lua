-- tests/test_suite.lua
-- Comprehensive test suite for Zabbix PHP Style Checker
--
-- Usage: nvim --headless -c 'luafile tests/test_suite.lua'

if not vim then
  print("ERROR: Run with nvim --headless -c 'luafile tests/test_suite.lua'")
  os.exit(1)
end

-- ============================================================================
-- Configuration
-- ============================================================================

local TESTS_PASSED = 0
local TESTS_FAILED = 0
local TESTS_SKIPPED = 0

-- Add parser to runtime path
vim.opt.rtp:append("/Users/mtalbergs/.local/share/nvim/site/pack/core/opt/nvim-treesitter")

-- Add scripts dir to path
local scripts_dir = vim.fn.getenv("SCRIPTS_DIR") or "/Users/mtalbergs/scripts"
package.path = package.path .. ";" .. scripts_dir .. "/neovim/?.lua"

-- Load the style checker
local zabbix_style = require("zabbix-style")

-- Get diagnostic namespace
local ns_id = vim.api.nvim_create_namespace("zbx-test-suite")

-- ============================================================================
-- Test Case Definitions
-- ============================================================================

local test_cases = {
  {
    name = "Array syntax: array() shorthand",
    code = [[<?php
$a = array(1, 2, 3);
]],
    expected_msg = "Use [] shorthand instead of array()",
    rule = "array_syntax"
  },

  {
    name = "Empty() function usage",
    code = [[<?php
if (empty($var)) {
    return true;
}
]],
    expected_msg = "empty() is prohibited",
    rule = "no_empty"
  },

  {
    name = "is_null() function usage",
    code = [[<?php
if (is_null($var)) {
    return true;
}
]],
    expected_msg = "is_null()",
    rule = "no_is_null"
  },

  {
    name = "Null coalescing operator ??",
    code = [[<?php
$result = $value ?? 'default';
]],
    expected_msg = "Null coalescing operator",
    rule = "no_null_coalesce"
  },

  {
    name = "$_REQUEST superglobal usage",
    code = [[<?php
$input = $_REQUEST['param'];
]],
    expected_msg = "$_REQUEST",
    rule = "superglobal"
  },

  {
    name = "array_push() function usage",
    code = [[<?php
array_push($array, $value);
]],
    expected_msg = "array_push()",
    rule = "no_array_push"
  },

  {
    name = "Class naming: must start with C",
    code = [[<?php
class InvalidName {}
]],
    expected_msg = "start with 'C'",
    rule = "class_naming"
  },

  {
    name = "Class naming: valid (should not trigger)",
    code = [[<?php
class CValidName {}
]],
    expected_msg = nil,
    rule = "class_naming_valid",
    should_fail = false
  },

  {
    name = "Variable variables ($$var)",
    code = [[<?php
$foo = 'bar';
$$foo = 'baz';
]],
    expected_msg = "Variable variables",
    rule = "variable_variable"
  },

  {
    name = "Strict comparison: == instead of ===",
    code = [[<?php
if ($a == $b) {
    return true;
}
]],
    expected_msg = "Strict comparison",
    rule = "strict_comparison"
  },

  {
    name = "Strict comparison: != instead of !==",
    code = [[<?php
if ($a != $b) {
    return true;
}
]],
    expected_msg = "Strict comparison",
    rule = "strict_comparison_not_equals"
  },

  {
    name = "Method naming: must start with lowercase",
    code = [[<?php
class CTest {
    public function InvalidMethod() {}
}
]],
    expected_msg = "camelCase",
    rule = "method_naming"
  },

  {
    name = "Method naming: valid camelCase (should not trigger)",
    code = [[<?php
class CTest {
    public function validMethod() {}
}
]],
    expected_msg = nil,
    rule = "method_naming_valid",
    should_fail = false
  },

  -- ==========================================================================
  -- Tests for rules that SHOULD be implemented but currently aren't
  -- These will be marked as SKIPPED
  -- ==========================================================================

  {
    name = "Global variables: global keyword",
    code = [[<?php
global $config;
]],
    expected_msg = "Global variables",
    rule = "global_variables",
    not_implemented = true
  },

  {
    name = "Constants: not uppercase",
    code = [[<?php
const bad_CONST = 1;
]],
    expected_msg = "uppercase",
    rule = "constants_uppercase",
    not_implemented = true
  },

  {
    name = "Function naming: not camelCase",
    code = [[<?php
function Bad_Function_Name() {}
]],
    expected_msg = "camelCase",
    rule = "function_naming",
    not_implemented = true
  },

  {
    name = "Constructor property promotion",
    code = [[<?php
class CTest {
    public function __construct(public $prop) {}
}
]],
    expected_msg = "Property promotion",
    rule = "constructor_property_promotion",
    not_implemented = true
  },

  {
    name = "For loop: count() in condition",
    code = [[<?php
for ($i = 0; $i < count($array); $i++) {}
]],
    expected_msg = "count()",
    rule = "for_count_condition",
    not_implemented = true
  },

  {
    name = "Instance creation: missing parentheses",
    code = [[<?php
class CTest {}
$obj = new CTest;
]],
    expected_msg = "Parentheses",
    rule = "instantiation_parentheses",
    not_implemented = true
  },

  {
    name = "Class: var keyword used",
    code = [[<?php
class CTest {
    var $old_style;
}
]],
    expected_msg = "var",
    rule = "var_keyword",
    not_implemented = true
  },

  {
    name = "Class: missing visibility modifier",
    code = [[<?php
class CTest {
    function noVisibility() {}
}
]],
    expected_msg = "Visibility",
    rule = "visibility_required",
    not_implemented = true
  },

  {
    name = "Multiple classes in one file",
    code = [[<?php
class CFirst {}
class CSecond {}
]],
    expected_msg = "one class per file",
    rule = "one_class_per_file",
    not_implemented = true
  },

  {
    name = "Parameter: trailing comma",
    code = [[<?php
function test($a, $b,) {}
]],
    expected_msg = "Trailing comma",
    rule = "no_trailing_comma_params",
    not_implemented = true
  },

  {
    name = "Nullable type: space between ? and type",
    code = [[<?php
function test(? string $a) {}
]],
    expected_msg = "space",
    rule = "nullable_type_spacing",
    not_implemented = true
  },

  {
    name = "Array merge: using array_merge() instead of +",
    code = [[<?php
$result = array_merge($a, $b);
]],
    expected_msg = "array_merge",
    rule = "array_merge",
    not_implemented = true
  },

  {
    name = "Array uniqueness: using array_unique()",
    code = [[<?php
$result = array_unique($array);
]],
    expected_msg = "array_unique",
    rule = "array_uniqueness",
    not_implemented = true
  },

  {
    name = "Array key check: using isset()",
    code = [[<?php
if (isset($array['key'])) {}
]],
    expected_msg = "array_key_exists",
    rule = "array_key_check",
    not_implemented = true
  },

  {
    name = "Argument unpacking: ... operator",
    code = [[<?php
function test(...$args) {}
]],
    expected_msg = "Unpacking",
    rule = "argument_unpacking",
    not_implemented = true
  },

  {
    name = "Null-safe operator ?->",
    code = [[<?php
$result = $obj?->method();
]],
    expected_msg = "?->",
    rule = "null_safe_operator",
    not_implemented = true
  },

  {
    name = "Ternary operator ?: (non-array usage)",
    code = [[<?php
$result = $value ?: 'default';
]],
    expected_msg = "ternary",
    rule = "ternary_non_array",
    not_implemented = true
  },

  {
    name = "Translation: string not wrapped",
    code = [[<?php
echo "Not translated";
]],
    expected_msg = "translation",
    rule = "translation_wrapping",
    not_implemented = true
  },
}

-- ============================================================================
-- Helper Functions
-- ============================================================================

--- Create a temporary buffer with given content
--- @param content string The PHP code to put in the buffer
--- @return number bufnr The buffer number
local function create_temp_buffer(content)
  local bufnr = vim.fn.bufadd("")
  vim.fn.bufload(bufnr)
  vim.bo[bufnr].filetype = "php"
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))
  return bufnr
end

--- Find if a diagnostic with given message exists
--- @param diagnostics table List of diagnostics
--- @param expected_msg string Substring to search for
--- @return boolean found Whether the diagnostic was found
local function find_diagnostic(diagnostics, expected_msg)
  if not expected_msg then
    -- If no message expected, check if there are NO diagnostics
    return #diagnostics == 0
  end

  for _, diag in ipairs(diagnostics) do
    if string.find(diag.message:lower(), expected_msg:lower(), 1, true) then
      return true
    end
  end
  return false
end

--- Run a single test case
--- @param test_case table Test case definition
--- @return boolean success Whether the test passed
local function run_test_case(test_case)
  local should_fail = test_case.should_fail ~= false -- Default: expect failure

  -- Skip tests for rules not yet implemented
  if test_case.not_implemented then
    print(string.format("SKIP: %s (%s - not implemented)", test_case.name, test_case.rule))
    TESTS_SKIPPED = TESTS_SKIPPED + 1
    return true
  end

  -- Create temporary buffer
  local bufnr = create_temp_buffer(test_case.code)

  -- Run the style checker
  local status, err = pcall(function()
    zabbix_style.check_buffer(bufnr)
  end)

  if not status then
    print(string.format("FAIL: %s", test_case.name))
    print(string.format("  Error: %s", err))
    TESTS_FAILED = TESTS_FAILED + 1
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return false
  end

  -- Get diagnostics
  local diagnostics = vim.diagnostic.get(bufnr)

  -- Check if expected diagnostic exists
  local found = find_diagnostic(diagnostics, test_case.expected_msg)

  -- Determine success
  local success
  if should_fail then
    success = found
  else
    success = not found
  end

  -- Report result
  if success then
    print(string.format("PASS: %s (%s)", test_case.name, test_case.rule))
    TESTS_PASSED = TESTS_PASSED + 1
  else
    print(string.format("FAIL: %s (%s)", test_case.name, test_case.rule))
    print(string.format("  Expected message containing: %s", test_case.expected_msg or "none"))
    print(string.format("  Diagnostics found: %d", #diagnostics))
    for i, diag in ipairs(diagnostics) do
      print(string.format("    [%d] Line %d: %s", i, diag.lnum + 1, diag.message))
    end
    TESTS_FAILED = TESTS_FAILED + 1
  end

  -- Clean up
  vim.api.nvim_buf_delete(bufnr, { force = true })

  return success
end

-- ============================================================================
-- Main Test Runner
-- ============================================================================

print("=============================================================================")
print("Zabbix PHP Style Checker - Test Suite")
print("=============================================================================")
print("")

for _, test_case in ipairs(test_cases) do
  run_test_case(test_case)
end

-- ============================================================================
-- Summary
-- ============================================================================

print("")
print("=============================================================================")
print("Test Summary")
print("=============================================================================")
print(string.format("Total tests:  %d", TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
print(string.format("Passed:        %d", TESTS_PASSED))
print(string.format("Failed:        %d", TESTS_FAILED))
print(string.format("Skipped:       %d (not implemented)", TESTS_SKIPPED))
print("=============================================================================")

-- Exit with appropriate code
if TESTS_FAILED > 0 then
  print("ERROR: Some tests failed!")
  os.exit(1)
else
  print("SUCCESS: All implemented tests passed!")
  os.exit(0)
end
