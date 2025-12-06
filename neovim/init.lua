if vim.fn.has('nvim-0.12') == 1 then
    dofile(vim.fn.getenv("SCRIPTS_DIR").."/neovim/init-v12.lua")
else
    error('not supported neovim runtime, expected one of 0.12.0 or greater')
end
