-- repro.lua
-- Minimal reproduction script for ghost-text crash

-- Mock vim environment for headless run if needed (though nvim --headless has vim global)
if not vim then
  print("This script must be run with nvim --headless -u repro.lua")
  os.exit(1)
end

-- Setup dummy buffer
vim.cmd("new")
vim.api.nvim_buf_set_lines(0, 0, -1, false, {"hello world", "foo bar"})
vim.api.nvim_win_set_cursor(0, {1, 5}) -- Cursor at "hello|"

-- Mock SCRIPTS_DIR
vim.env.SCRIPTS_DIR = "/Users/mtalbergs/scripts"

-- Load modules
local ghost = dofile(vim.env.SCRIPTS_DIR .. "/neovim/ghost-text.lua")
local ollama_config = dofile(vim.env.SCRIPTS_DIR .. "/neovim/ghost-ollama.lua").get_config()

-- Setup
ghost.setup(vim.tbl_deep_extend("force", ollama_config, {
  debug = true,
  debounce_ms = 10,
}))

-- Trigger completion manually
print("Triggering completion...")
-- Use pcall to catch the error
local status, err = pcall(function()
  ghost.complete()
end)

if not status then
  print("CRASH DETECTED:")
  print(err)
else
  print("No immediate crash (async might crash later)")
end

-- Wait a bit for async (simulation)
vim.wait(100, function() return false end)

print("Done.")
vim.cmd("q!")
