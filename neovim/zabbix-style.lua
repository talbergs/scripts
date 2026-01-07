local M = {}

-- Define the diagnostics namespace
local ns_id = vim.api.nvim_create_namespace("ZabbixStyle")

-- Track enabled state
local enabled = false

-- The Tree-sitter query for Zabbix PHP rules
local php_query_str = [[
  ;; 1. Naming Conventions
  
  ;; Global variables forbidden
  (global_declaration) @violation.global_var
  (variable_name (name) @var_name (#eq? @var_name "GLOBALS")) @violation.global_var

  ;; Constants MUST be uppercase
  ;; const_element usually has a 'name' child
  (const_element (name) @const_name (#not-match? @const_name "^[A-Z][A-Z0-9_]*$")) @violation.const_naming
  
  ;; define('NAME', ...)
  (function_call_expression
    function: (name) @func_name (#eq? @func_name "define")
    (arguments 
      (argument 
        (string (string_content) @const_name (#not-match? @const_name "^[A-Z][A-Z0-9_]*$"))))) @violation.const_naming

  ;; Functions MUST be camelCase (start lower)
  (function_definition name: (name) @func_name (#not-match? @func_name "^[a-z][a-zA-Z0-9]*$")) @violation.func_naming

  ;; Methods MUST be camelCase (start lower), allowing magic methods starting with __
  (method_declaration name: (name) @method_name (#not-match? @method_name "^(__)?[a-z][a-zA-Z0-9]*$")) @violation.method_naming

  ;; Classes MUST start with 'C' (C + UpperCamelCase)
  (class_declaration name: (name) @class_name (#not-match? @class_name "^C[A-Z][a-zA-Z0-9]*$")) @violation.class_naming


  ;; 2. Control Structures & Forbidden Functions
  
  ;; count() call inside a for loop condition
  ;; Covers: for (; count($a) < 5; )
  (for_statement
    condition: (_ 
        (function_call_expression function: (name) @f_name (#eq? @f_name "count")))) @violation.count_in_loop

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
    (#eq? @var_name "_REQUEST")) @violation.superglobal

  ;; Variable variables $$var forbidden
  (dynamic_variable_name) @violation.variable_variable

  ;; No array() syntax - use [] shorthand instead
  (array_creation_expression "array") @violation.array_syntax


  ;; 3. Classes
  
  ;; Visibility 'var' keyword forbidden
  (property_declaration (var_modifier) @mod) @violation.var_keyword

  ;; Constructor property promotion forbidden
  (property_promotion_parameter) @violation.prop_promotion

  ;; Instantiation MUST have parentheses (filtered in Lua)
  (object_creation_expression) @check.new_parens


  ;; 5. Formatting
  
  ;; Else/Elseif must be on new line
  (else_clause) @check.else_newline
  (else_if_clause) @check.else_newline

  ;; 4. Comparisons

  ;; Warn on loose comparison == or != when string is involved (filtered in Lua)
  (binary_expression
    operator: ["==" "!="] @op) @check.loose_comparison
]]

-- Message map for violations
local messages = {
    ["violation.global_var"] = "Global variables MUST NOT be used.",
    ["violation.const_naming"] = "Constants MUST be UPPERCASE (e.g., CONST_NAME).",
    ["violation.func_naming"] = "Function names MUST be camelCase (start lower).",
    ["violation.method_naming"] = "Method names MUST be camelCase (start lower).",
    ["violation.class_naming"] = "Class names MUST start with 'C' (e.g., CClassName).",
    ["violation.count_in_loop"] = "Do NOT call count() in for loop condition. Calculate it once before.",
    ["violation.no_empty"] = "Function empty() is prohibited.",
    ["violation.no_is_null"] = "Function is_null() is prohibited. Use strict comparison (=== null).",
    ["violation.no_array_push"] = "array_push() is prohibited. Use $array[] = ...",
    ["violation.no_null_coalesce"] = "Null coalescing operator (??) is prohibited.",
    ["violation.superglobal"] = "Direct access to $_REQUEST is prohibited. Use hasInput()/getInput().",
    ["violation.variable_variable"] = "Variable variables ($$var) are prohibited.",
    ["violation.array_syntax"] = "Use [] shorthand instead of array().",
    ["violation.var_keyword"] = "Visibility 'var' is prohibited. Use public/protected/private.",
    ["violation.prop_promotion"] = "Constructor property promotion is prohibited.",
    ["violation.new_without_parens"] = "Instantiation MUST have parentheses (e.g., new Class()).",
    ["violation.strict_comparison"] = "Loose comparison (==, !=) found. Use strict comparison (===, !==).",
    ["violation.else_newline"] = "Keywords 'else' and 'elseif' MUST start on a new line.",
}

function M.check_buffer(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    
    if not enabled then return end
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    -- Only check PHP files
    if vim.bo[bufnr].filetype ~= "php" then
        return
    end

    local status_parser, parser = pcall(vim.treesitter.get_parser, bufnr, "php")
    if not status_parser or not parser then return end
    
    local tree = parser:parse()[1]
    local root = tree:root()
    
    -- Parse the query safely
    local status_query, query = pcall(vim.treesitter.query.parse, "php", php_query_str)
    
    if not status_query then
        if not M._has_logged_error then
            vim.notify("Zabbix Style: Query parse failed: " .. tostring(query), vim.log.levels.WARN)
            M._has_logged_error = true
        end
        return
    end
    
    local diagnostics = {}
    
    for id, node, metadata in query:iter_captures(root, bufnr, 0, -1) do
        local capture_name = query.captures[id]
        local range = { node:range() } -- row1, col1, row2, col2

        -- Special handling for new_parens check (filter in Lua)
        if capture_name == "check.new_parens" then
            local text = vim.treesitter.get_node_text(node, bufnr)
            if text:find("%(") then
                goto continue -- has parentheses, skip
            end
            capture_name = "violation.new_without_parens"
        end

        if capture_name == "check.else_newline" then
            local prev = node:prev_named_sibling()
            while prev and prev:type() == "comment" do
                prev = prev:prev_named_sibling()
            end

            if prev and prev:type() == "compound_statement" then
                local _, _, prev_end_row, _ = prev:range()
                local curr_start_row, _, _, _ = node:range()
                
                if prev_end_row == curr_start_row then
                    capture_name = "violation.else_newline"
                else
                    goto continue
                end
            else
                goto continue
            end
        end

        -- Special handling for loose comparison (only warn if string involved)
        if capture_name == "check.loose_comparison" then
            local has_string = false
            for child in node:iter_children() do
                local child_type = child:type()
                if child_type == "string" or child_type == "encapsed_string" then
                    has_string = true
                    break
                end
            end
            if not has_string then
                goto continue -- no string literal, allow loose comparison
            end
            capture_name = "violation.strict_comparison"
        end

        local msg = messages[capture_name]
        if not msg then
            goto continue -- not a violation capture
        end

        local severity = vim.diagnostic.severity.ERROR
        if capture_name == "violation.strict_comparison" then
            severity = vim.diagnostic.severity.WARN
        end

        table.insert(diagnostics, {
            lnum = range[1],
            col = range[2],
            end_lnum = range[3],
            end_col = range[4],
            severity = severity,
            source = "zbx-style",
            message = msg,
        })

        ::continue::
    end
    
    vim.diagnostic.set(ns_id, bufnr, diagnostics)
end

function M.toggle()
    enabled = not enabled
    if enabled then
        vim.notify("Zabbix Guideliner enabled", vim.log.levels.INFO)
        -- Run check on current buffer
        M.check_buffer(0)
    else
        vim.notify("Zabbix Guideliner disabled", vim.log.levels.INFO)
        -- Clear diagnostics when disabled
        vim.diagnostic.reset(ns_id)
    end
end

function M.setup()
    -- Create autocommand to run check on change
    local group = vim.api.nvim_create_augroup("ZabbixStyleChecker", { clear = true })
    vim.api.nvim_create_autocmd({ "TextChanged", "BufEnter", "InsertLeave" }, {
        group = group,
        pattern = "*.php",
        callback = function(ev)
            M.check_buffer(ev.buf)
        end,
    })
    
    -- Create toggle command
    vim.api.nvim_create_user_command("ZabbixGuidelinerToggle", M.toggle, {})
end

return M
