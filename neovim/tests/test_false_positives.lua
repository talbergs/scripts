if not vim then
  print("Run with nvim --headless -l tests/test_false_positives.lua")
  os.exit(1)
end

vim.opt.rtp:append("/Users/mtalbergs/.local/share/nvim/site/pack/core/opt/nvim-treesitter")
local scripts_dir = vim.fn.getenv("SCRIPTS_DIR") or "/Users/mtalbergs/scripts"
package.path = "./?.lua;" .. package.path

local zabbix_style = require("zabbix-style")

local function run_check(code, name, should_have_errors)
    local buf = vim.fn.bufadd("")
    vim.fn.bufload(buf)
    vim.bo[buf].filetype = "php"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(code, "\n"))
    
    zabbix_style.check_buffer(buf)
    
    local diags = vim.diagnostic.get(buf)
    local has_errors = #diags > 0
    
    if has_errors == should_have_errors then
        print(string.format("PASS: %s", name))
    else
        print(string.format("FAIL: %s", name))
        print(string.format("  Code: %s", code))
        print(string.format("  Expected errors: %s, Found: %d", tostring(should_have_errors), #diags))
        for _, d in ipairs(diags) do
            print("    - " .. d.message)
        end
    end
    
    vim.api.nvim_buf_delete(buf, { force = true })
end

print("--- Checking for False Positives ---")

-- Array Syntax
run_check("<?php $a = [1, 2];", "Valid Array Short Syntax []", false)
run_check("<?php $a = array(1, 2);", "Invalid Array Syntax array()", true)

-- Class Instantiation
run_check("<?php $a = new Foo();", "Valid Instantiation with ()", false)
run_check("<?php $a = new Foo;", "Invalid Instantiation without ()", true)

-- Loose Comparison
run_check("<?php if ($a == 1) {}", "Loose comparison int==int (allowed)", false)
run_check("<?php if ($a != $b) {}", "Loose comparison var==var (allowed)", false)
run_check("<?php if ($a == 'foo') {}", "Loose comparison with string (error)", true)
run_check('<?php if ($a != "bar") {}', "Loose comparison with double-quoted string (error)", true)

print("------------------------------------")
vim.cmd("q!")
