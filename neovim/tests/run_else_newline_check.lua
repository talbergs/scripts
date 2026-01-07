if not vim then
  print("Run with nvim --headless -c 'luafile tests/run_else_newline_check.lua'")
  return
end

vim.opt.rtp:append("/Users/mtalbergs/.local/share/nvim/site/pack/core/opt/nvim-treesitter")

local scripts_dir = vim.fn.getenv("SCRIPTS_DIR") or "/Users/mtalbergs/scripts"
package.path = package.path .. ";" .. scripts_dir .. "/neovim/?.lua"

local zabbix_style = require("zabbix-style")

local buf = vim.fn.bufadd("tests/test_else_newline.php")
vim.fn.bufload(buf)
vim.bo[buf].filetype = "php"

local status, err = pcall(function()
  zabbix_style.check_buffer(buf)
end)

if status then
  local diags = vim.diagnostic.get(buf)
  print("Diagnostics found: " .. #diags)
  
  local found_violation_1 = false
  local found_violation_2 = false

  for _, d in ipairs(diags) do
    print(string.format("Line %d: %s", d.lnum + 1, d.message))
    if d.message:find("Keywords 'else' and 'elseif' MUST start on a new line") then
        if d.lnum + 1 == 4 then found_violation_1 = true end
        if d.lnum + 1 == 8 then found_violation_2 = true end
    end
  end
  
  if found_violation_1 and found_violation_2 then
     print("SUCCESS: Found expected violations.")
  else
     print("FAILURE: Did not find all expected violations.")
     os.exit(1)
  end
else
  print("Check FAILED with error:")
  print(err)
  os.exit(1)
end

vim.cmd("q!")
