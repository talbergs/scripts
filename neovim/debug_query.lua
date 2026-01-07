local query_str = [[
  ;; 1. Naming Conventions
  
  ;; Global variables forbidden
  (global_declaration) @violation.global_var
  (variable_name (name) @var_name (#eq? @var_name "$GLOBALS")) @violation.global_var

  ;; Constants MUST be uppercase
  (const_element name: (name) @const_name (#not-match? @const_name "^[A-Z][A-Z0-9_]*$")) @violation.const_naming
  (function_call_expression
    function: (name) @func_name (#eq? @func_name "define")
    arguments: (arguments (string (string_content) @const_name (#not-match? @const_name "^[A-Z][A-Z0-9_]*$")))) @violation.const_naming

  ;; Functions MUST be camelCase (start lower)
  (function_declaration name: (name) @func_name (#not-match? @func_name "^[a-z][a-zA-Z0-9]*$")) @violation.func_naming

  ;; Methods MUST be camelCase (start lower), allowing magic methods starting with __
  (method_declaration name: (name) @method_name (#not-match? @method_name "^(__)?[a-z][a-zA-Z0-9]*$")) @violation.method_naming

  ;; Classes MUST start with 'C' (CUpperCamelCase)
  (class_declaration name: (name) @class_name (#not-match? @class_name "^C[A-Z][a-zA-Z0-9]*$")) @violation.class_naming


  ;; 2. Control Structures & Forbidden Functions
  
  ;; count() call inside a for loop condition
  (for_statement
    condition: (expression_list
      (binary_expression
        right: (function_call_expression
          function: (name) @f_name (#eq? @f_name "count"))))) @violation.count_in_loop

  ;; empty() forbidden
  (function_call_expression
    function: (name) @func_name
    (#eq? @func_name "empty")) @violation.no_empty

  ;; is_null() forbidden
  (function_call_expression
    function: (name) @func_name
    (#eq? @func_name "is_null")) @violation.no_is_null

  ;; array_push() forbidden
  (function_call_expression
    function: (name) @func_name
    (#eq? @func_name "array_push")) @violation.no_array_push

  ;; Null coalescing ?? forbidden
  (binary_expression
    operator: "??" @op) @violation.no_null_coalesce

  ;; $_REQUEST forbidden
  (variable_name
    (name) @var_name
    (#eq? @var_name "$_REQUEST")) @violation.superglobal

  ;; Variable variables $$var forbidden
  (dynamic_variable_name) @violation.variable_variable


  ;; 3. Classes
  
  ;; Visibility 'var' keyword forbidden
  (property_declaration (var_modifier) @mod) @violation.var_keyword

  ;; Constructor property promotion forbidden
  (property_promotion_parameter) @violation.prop_promotion

  ;; Instantiation MUST have parentheses
  (object_creation_expression
    !arguments) @violation.new_without_parens


  ;; 4. Comparisons
  
  ;; Warn on loose comparison == or !=
  (binary_expression
    operator: ["==" "!="] @op) @violation.strict_comparison
]]

local status, err = pcall(vim.treesitter.query.parse, "php", query_str)
if not status then
    print("PARSE FAILED: " .. tostring(err))
    os.exit(1)
else
    print("PARSE SUCCESS")
end
