-- tests/run_style_check.lua
if not vim then
  print("Run with nvim --headless -c 'luafile tests/run_style_check.lua'")
  return
end

-- Add parser to rtp
vim.opt.rtp:append("/Users/mtalbergs/.local/share/nvim/site/pack/core/opt/nvim-treesitter")

-- Add scripts dir to path
local scripts_dir = vim.fn.getenv("SCRIPTS_DIR") or "/Users/mtalbergs/scripts"
-- Ensure we can load zabbix-style.lua which is in scripts_dir/neovim
package.path = package.path .. ";" .. scripts_dir .. "/neovim/?.lua"

local zabbix_style = require("zabbix-style")

-- Open the test file
local buf = vim.fn.bufadd("tests/zabbix_style_test.php")
vim.fn.bufload(buf)
vim.bo[buf].filetype = "php"

-- Run the check
print("Running check_buffer...")
local status, err = pcall(function()
  zabbix_style.check_buffer(buf)
end)

if status then
  print("Check completed successfully.")
  local diags = vim.diagnostic.get(buf)
  print("Diagnostics found: " .. #diags)
  
  local found_variable_variable = false
  for _, d in ipairs(diags) do
    print(string.format("Line %d: %s", d.lnum + 1, d.message))
    if d.message:match("Variable variables") then
      found_variable_variable = true
    end
  end
  
  if found_variable_variable then
     print("SUCCESS: Found variable variable violation.")
  else
     print("FAILURE: Did not find variable variable violation.")
     os.exit(1)
  end
else
  print("Check FAILED with error:")
  print(err)
  os.exit(1)
end

vim.cmd("q!")
