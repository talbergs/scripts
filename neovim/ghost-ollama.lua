-- ghost-ollama.lua
-- Example configuration for ghost-text.lua using local Ollama
local M = {}

M.agent_script = vim.fn.getenv("SCRIPTS_DIR") .. "/ayay/agent.sh"
M.model = "deepseek-coder:6.7b"

function M.get_config()
  return {
    -- Custom context builder
    get_context = function()
      local buf = vim.api.nvim_get_current_buf()
      local cursor = vim.api.nvim_win_get_cursor(0)
      local row, col = cursor[1], cursor[2]
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      
      -- Get 50 lines before and 10 after
      local start_line = math.max(1, row - 50)
      local end_line = math.min(#lines, row + 10)
      
      local prefix_lines = {}
      for i = start_line, row do
        table.insert(prefix_lines, lines[i] or "")
      end
      -- Adjust current line to cursor pos
      local current_line = lines[row] or ""
      local c_prefix = current_line:sub(1, col)
      prefix_lines[#prefix_lines] = c_prefix
      
      local suffix_lines = {}
      for i = row + 1, end_line do
        table.insert(suffix_lines, lines[i] or "")
      end

      return {
        prefix = table.concat(prefix_lines, "\n"),
        suffix = table.concat(suffix_lines, "\n"),
        filename = vim.fn.expand("%:t"),
        filetype = vim.bo[buf].filetype,
        row = row,
        col = col,
        cursor_prefix = c_prefix -- Exposed for ghost-text engine checks
      }
    end,

    -- The Fetcher: This is where the magic happens.
    -- You have full control over how to call the external process.
    fetch = function(ctx, callback)
      if ctx.prefix:match("^%s*$") then
        callback(nil)
        return nil
      end

      -- Build the prompt
      local prompt = string.format(
        [[Complete the following %s code. Only output the completion code.
File: %s

%s<CURSOR>%s

Complete from <CURSOR>:]],
        ctx.filetype,
        ctx.filename,
        ctx.prefix,
        ctx.suffix
      )

      -- Async system call
      return vim.system(
        { M.agent_script, "prompt", prompt },
        { text = true, env = { MODEL = M.model, TEMPERATURE = "0.2" } },
        function(obj)
          if obj.code == 0 and obj.stdout then
            local text = obj.stdout:gsub("^%s+", ""):gsub("%s+$", "")
            callback(text)
          else
            callback(nil)
          end
        end
      )
    end
  }
end

return M
