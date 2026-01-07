-- ghost-text.lua
-- A generic, fully controllable ghost text completion engine for Neovim.

local M = {}

-- Default configuration
M.config = {
  -- Enable/disable debug logging
  debug = false,
  
  -- Debounce time in ms
  debounce_ms = 200,

  -- Highlight group for ghost text
  hl_group = "Comment",

  -- Trigger events
  events = { "TextChangedI", "CursorMovedI" },

  -- Should we trigger?
  -- @param bufnr number
  -- @return boolean
  should_enable = function(bufnr)
    return true
  end,

  -- Get context from the editor
  -- @return table Context object passed to fetcher
  get_context = function()
    local buf = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1], cursor[2]
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local line = lines[row] or ""
    
    -- Basic context: just the file info and cursor pos
    return {
      buf = buf,
      filetype = vim.bo[buf].filetype,
      filename = vim.fn.expand("%:t"),
      filepath = vim.fn.expand("%:p"),
      row = row,
      col = col,
      line_content = line,
      cursor_prefix = line:sub(1, col),
      cursor_suffix = line:sub(col + 1),
      full_content = table.concat(lines, "\n")
    }
  end,

  -- Fetch suggestion (Async)
  -- @param ctx table The context from get_context
  -- @param callback function(text: string|nil) Call this with the suggestion
  fetch = function(ctx, callback)
    -- Default implementation does nothing.
    -- Users must override this to call their LLM/Provider.
    callback(nil)
  end,

  -- Optional: Process response before display
  -- @param text string Raw text from fetcher
  -- @return string Cleaned text
  process_response = function(text)
    return text
  end
}

-- Internal State
local state = {
  ns_id = vim.api.nvim_create_namespace("GhostTextEngine"),
  job = nil,
  timer = nil,
  suggestion = nil, -- { text="", row=0, col=0, lines={} }
}

local function log(msg, ...)
  if M.config.debug then
    vim.notify(string.format("[Ghost] " .. msg, ...), vim.log.levels.DEBUG)
  end
end

-- Clear current ghost text and state
function M.clear()
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(buf, state.ns_id, 0, -1)
  state.suggestion = nil
end

-- Cancel any pending jobs or timers
function M.cancel()
  if state.timer then
    state.timer:stop()
    state.timer = nil
  end
  if state.job then
    -- Handle different job types if necessary, currently assumes vim.system object
    if state.job.kill then state.job:kill("sigterm") end
    state.job = nil
  end
  M.clear()
end

-- Display the suggestion
local function display(text, row, col)
  if not text or text == "" then return end
  M.clear() -- Clear previous before showing new

  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.split(text, "\n", { plain = true })
  
  -- Store state for acceptance
  state.suggestion = {
    text = text,
    row = row,
    col = col,
    lines = lines
  }

  local first_line = lines[1]
  local virt_lines = {}
  -- Create virtual lines for multi-line suggestions
  for i = 2, #lines do
    table.insert(virt_lines, { { lines[i], M.config.hl_group } })
  end

  -- Set extmark
  vim.api.nvim_buf_set_extmark(buf, state.ns_id, row - 1, col, {
    virt_text = { { first_line, M.config.hl_group } },
    virt_text_pos = "inline",
    virt_lines = #virt_lines > 0 and virt_lines or nil,
    hl_mode = "combine",
  })
end

-- Main completion logic
function M.complete()
  M.cancel() -- Cancel previous attempts

  local buf = vim.api.nvim_get_current_buf()
  if not M.config.should_enable(buf) then return end

  local ctx = M.config.get_context()
  
  -- Don't trigger on empty lines or very short prefixes if desired
  if ctx.cursor_prefix and ctx.cursor_prefix:match("^%s*$") then return end

  -- Store request position to verify validity on return
  local req_row, req_col = ctx.row, ctx.col

  -- Execute fetch
  state.job = M.config.fetch(ctx, function(text)
    state.job = nil -- Job done
    
    -- Schedule back to main loop
    vim.schedule(function()
      -- Verify we are still in Insert mode and at the same position
      local mode = vim.api.nvim_get_mode().mode
      if mode ~= "i" then return end

      local cursor = vim.api.nvim_win_get_cursor(0)
      if cursor[1] ~= req_row or cursor[2] ~= req_col then
        log("Cursor moved, discarding suggestion")
        return
      end

      if not text then return end
      
      local processed = M.config.process_response(text)
      display(processed, req_row, req_col)
    end)
  end)
end

-- Trigger with debounce
local function trigger()
  M.cancel()
  state.timer = vim.defer_fn(function()
    state.timer = nil
    M.complete()
  end, M.config.debounce_ms)
end

-- Accept the suggestion
function M.accept()
  if not state.suggestion then return false end

  local buf = vim.api.nvim_get_current_buf()
  local row, col = state.suggestion.row, state.suggestion.col
  local lines = state.suggestion.lines
  
  -- Verify cursor hasn't moved away wildly (though usually we clear on move)
  -- But user might have mapped accept in a way that doesn't trigger CursorMoved
  
  local current_line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
  local prefix = current_line:sub(1, col)
  local suffix = current_line:sub(col + 1)

  -- Construct new text
  local new_lines = {}
  -- First line combines prefix + suggestion[1]
  table.insert(new_lines, prefix .. lines[1])
  
  -- Middle lines are just suggestion lines
  for i = 2, #lines - 1 do
    table.insert(new_lines, lines[i])
  end
  
  -- Last line combines suggestion[last] + suffix
  if #lines > 1 then
    table.insert(new_lines, lines[#lines] .. suffix)
  else
    new_lines[1] = new_lines[1] .. suffix
  end

  -- Apply changes
  vim.api.nvim_buf_set_lines(buf, row - 1, row, false, new_lines)

  -- Move cursor to end of inserted text
  local new_row = row + #lines - 1
  local new_col
  if #lines == 1 then
    new_col = col + #lines[1]
  else
    new_col = #lines[#lines]
  end
  vim.api.nvim_win_set_cursor(0, { new_row, new_col })

  M.clear()
  return true
end

-- Open suggestion in editable popup
function M.edit_popup()
  if not state.suggestion then
    log("No suggestion to edit")
    return false
  end

  local suggestion = state.suggestion
  local original_buf = vim.api.nvim_get_current_buf()
  local original_win = vim.api.nvim_get_current_win()
  local insert_row, insert_col = suggestion.row, suggestion.col

  -- Create a scratch buffer for editing
  local edit_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(edit_buf, 0, -1, false, suggestion.lines)
  vim.bo[edit_buf].buftype = "nofile"
  vim.bo[edit_buf].bufhidden = "wipe"
  vim.bo[edit_buf].filetype = vim.bo[original_buf].filetype

  -- Calculate popup dimensions
  local width = math.max(40, math.min(80, vim.o.columns - 10))
  local height = math.max(3, math.min(20, #suggestion.lines + 2))

  -- Center the popup
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Open floating window
  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Edit Suggestion (q/Esc to cancel, <CR> to accept) ",
    title_pos = "center",
  }
  local popup_win = vim.api.nvim_open_win(edit_buf, true, win_opts)

  -- Set window options
  vim.wo[popup_win].wrap = true
  vim.wo[popup_win].cursorline = true

  -- Clear the ghost text display since we're editing it
  M.clear()

  -- Function to accept edited content
  local function accept_edit()
    local edited_lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)
    local edited_text = table.concat(edited_lines, "\n")

    -- Close popup
    if vim.api.nvim_win_is_valid(popup_win) then
      vim.api.nvim_win_close(popup_win, true)
    end

    -- Return to original window/buffer
    if vim.api.nvim_win_is_valid(original_win) then
      vim.api.nvim_set_current_win(original_win)
    end

    -- Insert the edited text
    if edited_text and edited_text ~= "" then
      local current_line = vim.api.nvim_buf_get_lines(original_buf, insert_row - 1, insert_row, false)[1] or ""
      local prefix = current_line:sub(1, insert_col)
      local suffix = current_line:sub(insert_col + 1)

      local new_lines = {}
      table.insert(new_lines, prefix .. edited_lines[1])
      for i = 2, #edited_lines - 1 do
        table.insert(new_lines, edited_lines[i])
      end
      if #edited_lines > 1 then
        table.insert(new_lines, edited_lines[#edited_lines] .. suffix)
      else
        new_lines[1] = new_lines[1] .. suffix
      end

      vim.api.nvim_buf_set_lines(original_buf, insert_row - 1, insert_row, false, new_lines)

      -- Move cursor to end of inserted text
      local new_row = insert_row + #edited_lines - 1
      local new_col
      if #edited_lines == 1 then
        new_col = insert_col + #edited_lines[1]
      else
        new_col = #edited_lines[#edited_lines]
      end
      vim.api.nvim_win_set_cursor(original_win, { new_row, new_col })
    end

    -- Re-enter insert mode
    vim.cmd("startinsert")
  end

  -- Function to cancel
  local function cancel_edit()
    if vim.api.nvim_win_is_valid(popup_win) then
      vim.api.nvim_win_close(popup_win, true)
    end
    if vim.api.nvim_win_is_valid(original_win) then
      vim.api.nvim_set_current_win(original_win)
    end
    vim.cmd("startinsert")
  end

  -- Keymaps for the popup buffer
  local opts = { buffer = edit_buf, noremap = true, silent = true }
  vim.keymap.set("n", "<CR>", accept_edit, opts)
  vim.keymap.set("n", "<C-CR>", accept_edit, opts)
  vim.keymap.set("i", "<C-CR>", accept_edit, opts)
  vim.keymap.set("n", "q", cancel_edit, opts)
  vim.keymap.set("n", "<Esc>", cancel_edit, opts)
  vim.keymap.set("n", "<C-c>", cancel_edit, opts)

  return true
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Highlight group
  vim.api.nvim_set_hl(0, "GhostText", { link = M.config.hl_group, default = true })

  -- Autocommands
  local group = vim.api.nvim_create_augroup("GhostTextGroup", { clear = true })
  
  vim.api.nvim_create_autocmd(M.config.events, {
    group = group,
    callback = function()
        M.clear()
        trigger()
    end,
  })

  vim.api.nvim_create_autocmd({"InsertLeave", "BufLeave"}, {
    group = group,
    callback = M.cancel
  })

  -- User commands for testing/manual trigger
  vim.api.nvim_create_user_command("GhostComplete", M.complete, {})
  vim.api.nvim_create_user_command("GhostAccept", M.accept, {})
  vim.api.nvim_create_user_command("GhostCancel", M.cancel, {})
end

return M
