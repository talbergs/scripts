if not vim then
  print("Run with nvim --headless -l debug_php_ast_2.lua")
  os.exit(1)
end

vim.opt.rtp:append("/Users/mtalbergs/.local/share/nvim/site/pack/core/opt/nvim-treesitter")

local code = [[
<?php 
for ($i=0; $i<10; $i++) {}
$a = $b ?? $c;
$a == $b;
]]

local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(code, "\n"))
vim.bo[buf].filetype = "php"

local parser = vim.treesitter.get_parser(buf, "php")
local tree = parser:parse()[1]
local root = tree:root()

local function print_node(node, indent)
    indent = indent or ""
    print(indent .. node:type())
    for child in node:iter_children() do
        print_node(child, indent .. "  ")
    end
end

print_node(root)
vim.cmd("q!")
