-- ollama-ghost.lua - Local Ollama-powered ghost text completions
-- Uses ayay/agent.sh for Ollama setup and prompts

local M = {}

M.config = {
  agent_script = vim.fn.getenv("SCRIPTS_DIR") .. "/ayay/agent.sh",
  model = "deepseek-coder:6.7b",
  debounce_ms = 500,
  max_context_lines = 50,
  ghost_hl = "Comment",
  trigger_on_insert = true,
  debug = true,
}

local ensured = false

local function dbg(msg, ...)
  if M.config.debug then
    vim.notify(string.format("[OllamaGhost] " .. msg, ...), vim.log.levels.DEBUG)
  end
end

-- State
local ns_id = vim.api.nvim_create_namespace("OllamaGhost")
local current_suggestion = nil
local pending_job = nil
local debounce_timer = nil

-- Get file context around cursor
local function get_context()
  local buf = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local filetype = vim.bo[buf].filetype

  local start_line = math.max(1, row - M.config.max_context_lines)
  local prefix_lines = {}
  for i = start_line, row do
    table.insert(prefix_lines, lines[i] or "")
  end

  local current_line = lines[row] or ""
  local prefix = current_line:sub(1, col)
  prefix_lines[#prefix_lines] = prefix

  local suffix_lines = {}
  local end_line = math.min(#lines, row + 10)
  for i = row + 1, end_line do
    table.insert(suffix_lines, lines[i] or "")
  end

  return {
    prefix = table.concat(prefix_lines, "\n"),
    suffix = table.concat(suffix_lines, "\n"),
    filetype = filetype,
    filename = vim.fn.expand("%:t"),
    row = row,
    col = col,
  }
end

-- Build the prompt for code completion
local function build_prompt(ctx)
  local lang = ctx.filetype ~= "" and ctx.filetype or "code"
  return string.format(
    [[Complete the following %s code. Only output the completion, no explanation.
File: %s

%s<CURSOR>%s

Complete from <CURSOR>:]],
    lang,
    ctx.filename,
    ctx.prefix,
    ctx.suffix ~= "" and ("\n" .. ctx.suffix) or ""
  )
end

-- Clear current ghost text
function M.clear()
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
  current_suggestion = nil
end

-- Display ghost text at cursor
local function display_ghost(text, row, col)
  if not text or text == "" then return end

  M.clear()
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.split(text, "\n", { plain = true })

  if #lines == 0 then return end

  current_suggestion = {
    text = text,
    row = row,
    col = col,
    lines = lines,
  }

  local first_line = lines[1]
  local virt_lines = {}
  for i = 2, #lines do
    table.insert(virt_lines, { { lines[i], M.config.ghost_hl } })
  end

  vim.api.nvim_buf_set_extmark(buf, ns_id, row - 1, col, {
    virt_text = { { first_line, M.config.ghost_hl } },
    virt_text_pos = "inline",
    virt_lines = #virt_lines > 0 and virt_lines or nil,
    hl_mode = "combine",
  })
end

-- Accept the current suggestion
function M.accept()
  if not current_suggestion then return false end

  local buf = vim.api.nvim_get_current_buf()
  local row, col = current_suggestion.row, current_suggestion.col

  M.clear()

  local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
  local before = line:sub(1, col)
  local after = line:sub(col + 1)

  local insert_lines = current_suggestion.lines
  insert_lines[1] = before .. insert_lines[1]
  insert_lines[#insert_lines] = insert_lines[#insert_lines] .. after

  vim.api.nvim_buf_set_lines(buf, row - 1, row, false, insert_lines)

  local new_row = row + #insert_lines - 1
  local new_col = #insert_lines[#insert_lines] - #after
  vim.api.nvim_win_set_cursor(0, { new_row, new_col })

  return true
end

-- Ensure ollama is ready (runs once)
local function ensure_ollama(callback)
  if ensured then
    dbg("already ensured")
    callback(true)
    return
  end
  dbg("running: %s check", M.config.agent_script)
  vim.system(
    { M.config.agent_script, "check" },
    { text = true, env = { MODEL = M.config.model } },
    function(obj)
      vim.schedule(function()
        ensured = obj.code == 0
        dbg("check exit=%d stdout=%s stderr=%s", obj.code, obj.stdout or "", obj.stderr or "")
        if not ensured then
          vim.notify("[OllamaGhost] Ollama setup failed: " .. (obj.stderr or ""), vim.log.levels.ERROR)
        end
        callback(ensured)
      end)
    end
  )
end

-- Call agent.sh prompt command
local function call_agent(prompt, callback)
  dbg("call_agent started")
  ensure_ollama(function(ready)
    if not ready then
      dbg("ensure_ollama not ready")
      return
    end

    dbg("running: %s prompt <prompt>", M.config.agent_script)
    pending_job = vim.system(
      { M.config.agent_script, "prompt", prompt },
      { text = true, env = { MODEL = M.config.model, TEMPERATURE = "0.2" } },
      function(obj)
        pending_job = nil
        vim.schedule(function()
          dbg("prompt exit=%d stdout_len=%d stderr=%s", obj.code, #(obj.stdout or ""), obj.stderr or "")
          if obj.code == 0 and obj.stdout then
            local completion = obj.stdout:gsub("^%s+", ""):gsub("%s+$", "")
            dbg("completion: %s", completion:sub(1, 100))
            callback(completion)
          else
            dbg("no completion returned")
          end
        end)
      end
    )
  end)
end

-- Cancel pending request
function M.cancel()
  if debounce_timer then
    debounce_timer:stop()
    debounce_timer = nil
  end
  if pending_job then
    pending_job:kill("sigterm")
    pending_job = nil
  end
  M.clear()
end

-- Request a completion
function M.complete()
  dbg("M.complete() called")
  M.cancel()

  local ctx = get_context()
  dbg("prefix_len=%d suffix_len=%d row=%d col=%d", #ctx.prefix, #ctx.suffix, ctx.row, ctx.col)
  if ctx.prefix:match("^%s*$") then
    dbg("prefix is whitespace only, aborting")
    return
  end

  local prompt = build_prompt(ctx)
  local row, col = ctx.row, ctx.col

  call_agent(prompt, function(completion)
    local mode = vim.api.nvim_get_mode().mode
    dbg("callback: mode=%s", mode)
    if mode ~= "i" then
      dbg("not in insert mode, skipping")
      return
    end
    local cursor = vim.api.nvim_win_get_cursor(0)
    dbg("cursor now: row=%d col=%d (expected row=%d col=%d)", cursor[1], cursor[2], row, col)
    if cursor[1] == row and cursor[2] == col then
      dbg("displaying ghost text")
      display_ghost(completion, row, col)
    else
      dbg("cursor moved, skipping display")
    end
  end)
end

-- Debounced completion trigger
local function trigger_completion()
  M.cancel()
  debounce_timer = vim.defer_fn(function()
    debounce_timer = nil
    M.complete()
  end, M.config.debounce_ms)
end

-- Setup function
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  vim.api.nvim_set_hl(0, "OllamaGhost", { link = M.config.ghost_hl })

  vim.keymap.set("i", "<C-g>", function()
    if current_suggestion then
      M.accept()
    else
      M.complete()
    end
  end, { desc = "Ollama: Accept/Trigger completion" })

  vim.keymap.set("i", "<C-]>", M.cancel, { desc = "Ollama: Cancel completion" })

  vim.keymap.set("n", "<leader>og", M.complete, { desc = "Ollama: Ghost complete" })
  vim.keymap.set("n", "<leader>oc", M.cancel, { desc = "Ollama: Cancel" })

  local group = vim.api.nvim_create_augroup("OllamaGhost", { clear = true })

  if M.config.trigger_on_insert then
    vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
      group = group,
      callback = function()
        M.clear()
        trigger_completion()
      end,
    })
  end

  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = M.cancel,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = M.cancel,
  })
end

return M
