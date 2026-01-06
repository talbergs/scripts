-- todo-agent.lua - Periodic TODO scanner with AI suggestions
-- Scans buffer for TODO markers and invokes agent.sh for improvement suggestions

local M = {}

M.config = {
  agent_script = vim.fn.expand("~/scripts/ayay/agent.sh"),
  scan_interval_ms = 5000,
  context_lines = 15, -- lines before/after TODO for context
  todo_pattern = "TODO", -- pattern to match
  cache_file = vim.fn.expand("~/.cache/nvim/todo-agent-cache.json"),
  icons = {
    pending = "○",
    loading = "◐",
    ready = "●",
    error = "✗",
  },
  debug = false,
}

-- Persistent cache for TODO responses
local response_cache = {}

-- State
local ns_id = vim.api.nvim_create_namespace("TodoAgent")
local scan_timer = nil
local todo_states = {} -- { [bufnr] = { [line] = { status, response, job } } }

local function dbg(msg, ...)
  if M.config.debug then
    vim.notify(string.format("[TodoAgent] " .. msg, ...), vim.log.levels.DEBUG)
  end
end

-- Strip ANSI escape sequences from text
local function strip_ansi(str)
  if not str then return "" end
  -- Remove ANSI escape codes: ESC[ ... m (colors), ESC[ ... K (erase), etc.
  str = str:gsub("\027%[[%d;]*m", "")     -- Colors/styles
  str = str:gsub("\027%[[%d;]*[A-Za-z]", "") -- Other escape sequences
  str = str:gsub("\027%]%d*;[^\027]*\027\\", "") -- OSC sequences
  str = str:gsub("\r", "")                 -- Carriage returns
  return str
end

-- Simple hash function for cache keys
local function hash_string(str)
  local hash = 5381
  for i = 1, #str do
    hash = ((hash * 33) + string.byte(str, i)) % 0x7FFFFFFF
  end
  return string.format("%08x", hash)
end

-- Generate cache key from filename, line number, and TODO content
local function get_cache_key(filename, line_num, todo_text)
  local key_str = filename .. ":" .. line_num .. ":" .. todo_text
  return hash_string(key_str)
end

-- Load cache from disk
local function load_cache()
  local file = io.open(M.config.cache_file, "r")
  if not file then
    return
  end
  local content = file:read("*a")
  file:close()
  if content and content ~= "" then
    local ok, data = pcall(vim.json.decode, content)
    if ok and type(data) == "table" then
      response_cache = data
      dbg("Loaded %d cached responses", vim.tbl_count(response_cache))
    end
  end
end

-- Save cache to disk
local function save_cache()
  local cache_dir = vim.fn.fnamemodify(M.config.cache_file, ":h")
  vim.fn.mkdir(cache_dir, "p")
  local file = io.open(M.config.cache_file, "w")
  if file then
    local ok, json = pcall(vim.json.encode, response_cache)
    if ok then
      file:write(json)
    end
    file:close()
  end
end

-- Get cached response for a TODO
local function get_cached_response(filename, line_num, todo_text)
  local key = get_cache_key(filename, line_num, todo_text)
  return response_cache[key]
end

-- Save response to cache
local function set_cached_response(filename, line_num, todo_text, response)
  local key = get_cache_key(filename, line_num, todo_text)
  response_cache[key] = {
    response = response,
    timestamp = os.time(),
  }
  save_cache()
end

-- Get context around a TODO line
local function get_todo_context(bufnr, line)
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local start_line = math.max(0, line - M.config.context_lines)
  local end_line = math.min(total_lines, line + M.config.context_lines + 1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
  local filetype = vim.bo[bufnr].filetype
  local filename = vim.api.nvim_buf_get_name(bufnr)
  filename = vim.fn.fnamemodify(filename, ":t")

  local todo_line = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ""

  return {
    context = table.concat(lines, "\n"),
    todo_line = todo_line,
    filetype = filetype,
    filename = filename,
    line_num = line + 1, -- 1-indexed for display
  }
end

-- Build prompt for TODO analysis
local function build_prompt(ctx)
  return string.format(
    [[Analyze this TODO comment and provide a concise improvement suggestion.

File: %s (type: %s)
TODO at line %d: %s

Context:
```
%s
```

Provide a brief, actionable suggestion (2-3 sentences max) for implementing or improving this TODO. Focus on concrete steps.]],
    ctx.filename,
    ctx.filetype ~= "" and ctx.filetype or "unknown",
    ctx.line_num,
    ctx.todo_line:match("TODO:?%s*(.*)") or ctx.todo_line,
    ctx.context
  )
end

-- Update extmark for a TODO
local function update_extmark(bufnr, line, status, response)
  -- Clear existing extmark at this line
  local existing = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, {line, 0}, {line, -1}, {})
  for _, mark in ipairs(existing) do
    vim.api.nvim_buf_del_extmark(bufnr, ns_id, mark[1])
  end

  local icon = M.config.icons[status] or M.config.icons.pending
  local hl = "Comment"
  if status == "loading" then
    hl = "WarningMsg"
  elseif status == "ready" then
    hl = "String"
  elseif status == "error" then
    hl = "ErrorMsg"
  end

  vim.api.nvim_buf_set_extmark(bufnr, ns_id, line, 0, {
    sign_text = icon,
    sign_hl_group = hl,
    priority = 100,
  })
end

-- Initialize buffer state
local function init_buf_state(bufnr)
  if not todo_states[bufnr] then
    todo_states[bufnr] = {}
  end
end

-- Call agent.sh for a TODO
local function process_todo(bufnr, line)
  init_buf_state(bufnr)

  local state = todo_states[bufnr][line]
  if state and (state.status == "loading" or state.status == "ready") then
    return -- Already processing or done
  end

  local ctx = get_todo_context(bufnr, line)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local todo_text = ctx.todo_line

  -- Check cache first
  local cached = get_cached_response(filename, line + 1, todo_text)
  if cached and cached.response then
    dbg("Using cached response for TODO at line %d", line + 1)
    todo_states[bufnr][line] = { status = "ready", response = cached.response, job = nil }
    update_extmark(bufnr, line, "ready", cached.response)
    return
  end

  local prompt = build_prompt(ctx)

  todo_states[bufnr][line] = { status = "loading", response = nil, job = nil }
  update_extmark(bufnr, line, "loading", nil)

  dbg("Processing TODO at line %d", line + 1)

  local job = vim.system(
    { M.config.agent_script, "prompt", prompt },
    { text = true },
    function(obj)
      vim.schedule(function()
        if not todo_states[bufnr] or not todo_states[bufnr][line] then
          return
        end

        if obj.code == 0 and obj.stdout then
          local response = obj.stdout:gsub("^%s+", ""):gsub("%s+$", "")
          todo_states[bufnr][line] = { status = "ready", response = response, job = nil }
          update_extmark(bufnr, line, "ready", response)
          -- Save to cache
          set_cached_response(filename, line + 1, todo_text, response)
          dbg("TODO at line %d ready: %s", line + 1, response:sub(1, 50))
        else
          todo_states[bufnr][line] = { status = "error", response = obj.stderr or "Failed", job = nil }
          update_extmark(bufnr, line, "error", nil)
          dbg("TODO at line %d failed: %s", line + 1, obj.stderr or "unknown")
        end
      end)
    end
  )

  todo_states[bufnr][line].job = job
end

-- Scan buffer for TODOs
local function scan_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  init_buf_state(bufnr)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local found_lines = {}

  for i, line_text in ipairs(lines) do
    if line_text:match(M.config.todo_pattern) then
      local line = i - 1 -- 0-indexed
      found_lines[line] = true
      process_todo(bufnr, line)
    end
  end

  -- Clean up stale entries (TODOs that no longer exist)
  for line, _ in pairs(todo_states[bufnr]) do
    if not found_lines[line] then
      local state = todo_states[bufnr][line]
      if state.job then
        state.job:kill("sigterm")
      end
      todo_states[bufnr][line] = nil
      -- Remove extmark
      local existing = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, {line, 0}, {line, -1}, {})
      for _, mark in ipairs(existing) do
        vim.api.nvim_buf_del_extmark(bufnr, ns_id, mark[1])
      end
    end
  end
end

-- Show TODO response in a floating window
function M.show_hover()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1 -- 0-indexed

  init_buf_state(bufnr)

  local state = todo_states[bufnr][line]
  if not state then
    -- Check if there's a TODO on this line
    local line_text = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ""
    if not line_text:match(M.config.todo_pattern) then
      return false -- Not a TODO line, let default K work
    end
    -- TODO exists but not processed yet
    state = { status = "pending", response = nil }
  end

  local lines = {}
  local todo_line = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ""
  local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
  local todo_text = todo_line:match("TODO:?%s*(.*)") or todo_line

  -- Build content lines
  table.insert(lines, "TODO Agent")
  table.insert(lines, string.rep("─", 40))

  if state.status == "loading" then
    table.insert(lines, "")
    table.insert(lines, "⏳ Loading...")
  elseif state.status == "ready" and state.response then
    table.insert(lines, "")
    table.insert(lines, "📍 " .. filename .. ":" .. (line + 1))
    table.insert(lines, "📝 " .. todo_text)
    table.insert(lines, "")
    table.insert(lines, string.rep("─", 40))
    table.insert(lines, "")
    -- Strip ANSI codes and split response into lines
    local clean_response = strip_ansi(state.response)
    for resp_line in clean_response:gmatch("[^\n]+") do
      table.insert(lines, resp_line)
    end
  elseif state.status == "error" then
    table.insert(lines, "")
    table.insert(lines, "❌ Error")
    table.insert(lines, "")
    local err_msg = strip_ansi(state.response or "Unknown error")
    for err_line in err_msg:gmatch("[^\n]+") do
      table.insert(lines, err_line)
    end
  else
    table.insert(lines, "")
    table.insert(lines, "⏸  Pending...")
  end

  -- Calculate window size
  local max_width = 60
  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  width = math.min(width + 2, max_width)
  local height = math.min(#lines, 20)

  -- Create floating window using LSP util for consistent styling
  local float_bufnr, win_id = vim.lsp.util.open_floating_preview(lines, "markdown", {
    border = "rounded",
    max_width = max_width,
    max_height = 20,
    focus_id = "todo_agent_hover",
  })

  -- Set buffer options for better display
  if float_bufnr then
    vim.bo[float_bufnr].modifiable = false
  end

  return true
end

-- Start periodic scanning for current buffer
local function start_scan_timer()
  if scan_timer then
    scan_timer:stop()
  end

  scan_timer = vim.uv.new_timer()
  scan_timer:start(0, M.config.scan_interval_ms, vim.schedule_wrap(function()
    local bufnr = vim.api.nvim_get_current_buf()
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" then
      scan_buffer(bufnr)
    end
  end))
end

-- Stop scanning
function M.stop()
  if scan_timer then
    scan_timer:stop()
    scan_timer = nil
  end
end

-- Manual scan trigger
function M.scan()
  local bufnr = vim.api.nvim_get_current_buf()
  scan_buffer(bufnr)
end

-- Clear all TODO states and extmarks for buffer
function M.clear(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if todo_states[bufnr] then
    for _, state in pairs(todo_states[bufnr]) do
      if state.job then
        state.job:kill("sigterm")
      end
    end
    todo_states[bufnr] = {}
  end

  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

-- Clear the entire persistent cache
function M.clear_cache()
  response_cache = {}
  save_cache()
  vim.notify("[TodoAgent] Cache cleared", vim.log.levels.INFO)
end

-- Refresh a specific TODO (force re-process, invalidate cache)
function M.refresh()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1

  init_buf_state(bufnr)

  -- Kill existing job if any
  local state = todo_states[bufnr][line]
  if state and state.job then
    state.job:kill("sigterm")
  end

  -- Invalidate cache for this TODO
  local line_text = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ""
  if line_text:match(M.config.todo_pattern) then
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local key = get_cache_key(filename, line + 1, line_text)
    if response_cache[key] then
      response_cache[key] = nil
      save_cache()
      dbg("Invalidated cache for TODO at line %d", line + 1)
    end
  end

  -- Reset state
  todo_states[bufnr][line] = nil

  -- Re-process
  if line_text:match(M.config.todo_pattern) then
    process_todo(bufnr, line)
  end
end

-- Setup function
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Load persistent cache
  load_cache()

  -- Define sign column highlight
  vim.fn.sign_define("TodoAgentPending", { text = M.config.icons.pending, texthl = "Comment" })
  vim.fn.sign_define("TodoAgentLoading", { text = M.config.icons.loading, texthl = "WarningMsg" })
  vim.fn.sign_define("TodoAgentReady", { text = M.config.icons.ready, texthl = "String" })
  vim.fn.sign_define("TodoAgentError", { text = M.config.icons.error, texthl = "ErrorMsg" })

  -- Override K to show TODO hover when on TODO line, otherwise default behavior
  vim.keymap.set("n", "K", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1] - 1
    local line_text = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ""

    if line_text:match(M.config.todo_pattern) then
      M.show_hover()
    else
      -- Default K behavior (LSP hover)
      vim.lsp.buf.hover()
    end
  end, { desc = "TODO Agent: Hover / LSP Hover" })

  -- Additional keymaps
  vim.keymap.set("n", "<leader>Ts", M.scan, { desc = "TODO Agent: Scan buffer" })
  vim.keymap.set("n", "<leader>Tr", M.refresh, { desc = "TODO Agent: Refresh current TODO" })
  vim.keymap.set("n", "<leader>Tc", function() M.clear() end, { desc = "TODO Agent: Clear buffer" })
  vim.keymap.set("n", "<leader>TC", M.clear_cache, { desc = "TODO Agent: Clear persistent cache" })
  vim.keymap.set("n", "<leader>Tt", function()
    if scan_timer then
      M.stop()
      vim.notify("[TodoAgent] Stopped", vim.log.levels.INFO)
    else
      start_scan_timer()
      vim.notify("[TodoAgent] Started", vim.log.levels.INFO)
    end
  end, { desc = "TODO Agent: Toggle scanning" })

  -- Start scanning on buffer enter
  local group = vim.api.nvim_create_augroup("TodoAgent", { clear = true })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      if vim.bo[bufnr].buftype == "" then
        start_scan_timer()
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(args)
      M.clear(args.buf)
      todo_states[args.buf] = nil
    end,
  })

  -- Initial scan
  start_scan_timer()

  dbg("TodoAgent setup complete")
end

return M
