-- ninja.check -- run `jac check` and populate both the quickfix list and an
-- output scratch buffer.
--
-- Parses `jac check` output (rust-like diagnostic format:
--   ✖ Error: error[CODE]: MESSAGE
--     --> FILE:LINE:COL
--   ⚠ warning[CODE]: MESSAGE
--     --> FILE:LINE:COL
-- ) into quickfix entries so you can jump to each location with :cnext/:cprev,
-- while the raw output buffer keeps the full context (inline code snippets with
-- ^^^ markers, `→ run 'jac guide …'` hints, per-file summary banner) visible.

local M = {}

-- Scratch buffer name for the most recent check run.
local OUTPUT_BUFNAME = "jac-check://output"
local output_buf = nil   -- buf handle for the scratch window

local function jac_bin()
  local bin = vim.env.JAC_BIN
  if not bin or bin == "" then bin = "jac" end
  return bin
end

-- ------------------------------------------------------------------ parser --

--- Parse `jac check` output lines into quickfix entries.
-- @param lines table of output lines (string[])
-- @return list of quickfix entries: {filename, lnum, col, text, type}
local function parse_output(lines)
  local entries = {}
  local pending_type    -- 'E' or 'W'
  local pending_text
  local pending_code

  for _, line in ipairs(lines) do
    -- Error header: ✖ Error: error[CODE]: MESSAGE
    local err_code, err_msg = line:match("^✖ Error: error%[([^%]]+)%]: (.+)")
    if err_code then
      pending_type = 'E'
      pending_code = err_code
      pending_text = err_msg
      goto continue
    end

    -- Warning header: ⚠ warning[CODE]: MESSAGE
    local warn_code, warn_msg = line:match("^⚠ warning%[([^%]]+)%]: (.+)")
    if warn_code then
      pending_type = 'W'
      pending_code = warn_code
      pending_text = warn_msg
      goto continue
    end

    -- Location line:   --> FILE:LINE:COL
    -- NOTE: hyphens must be escaped (%-) because - is a Lua pattern quantifier.
    if pending_type then
      local file, lnum_str, col_str = line:match("  %-%-%> ([^:]+):(%d+):(%d+)")
      if file and lnum_str and col_str then
        -- Resolve relative paths against the working directory.
        if not file:match("^/") then
          file = vim.fn.getcwd() .. "/" .. file
        end
        local lnum = tonumber(lnum_str) or 0
        local col  = tonumber(col_str) or 0

        table.insert(entries, {
          filename = file,
          lnum     = lnum,
          col      = col,
          text     = string.format("[%s] %s", pending_code, pending_text),
          type     = pending_type,
        })
      end
      -- Consume the pending diagnostic regardless (one location per header).
      pending_type = nil
      pending_text = nil
      pending_code = nil
    end

    ::continue::
  end

  return entries
end

-- --------------------------------------------------------------- scratch ---

--- Close the previous output scratch buffer (if still visible).
local function close_old_output()
  if output_buf and vim.api.nvim_buf_is_valid(output_buf) then
    -- Find any window showing this buffer and close it.
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == output_buf then
        vim.api.nvim_win_close(win, false)
        break
      end
    end
    -- Wipe the buffer so the next run starts fresh.
    pcall(vim.api.nvim_buf_delete, output_buf, { force = true })
  end
end

--- Show the raw check output in a scratch buffer at the bottom of the editor.
-- Returns the buffer number.
local function show_output(lines)
  close_old_output()

  -- Guard: nothing to show.
  if #lines == 0 then return nil end

  -- Create the scratch buffer.
  local buf = vim.api.nvim_create_buf(false, true) -- listed=false, scratch=true
  output_buf = buf

  -- Set a memorable name for `:ls` / buffer pickers.
  pcall(vim.api.nvim_buf_set_name, buf, OUTPUT_BUFNAME)

  -- Fill with output (strip trailing blank lines for compactness).
  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines)
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Options: read-only, no modline, no swap, no undo.
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  vim.bo[buf].swapfile = false
  vim.bo[buf].undofile  = false
  -- Simple syntax: highlight "✖ Error:" and "⚠ warning:" lines.
  vim.bo[buf].syntax = "jac-check-output"

  -- Open a horizontal split at the bottom, ~1/4 of the screen.
  local height = math.max(6, math.floor(vim.o.lines * 0.25))
  vim.cmd("botright " .. height .. "new")
  vim.api.nvim_win_set_buf(0, buf)
  vim.wo.winfixheight = true   -- prevent resize on :copen
  vim.cmd("wincmd p")          -- back to the original window

  return buf
end

--- Toggle the last check output buffer.
function M.toggle_output()
  if output_buf and vim.api.nvim_buf_is_valid(output_buf) then
    -- Find a window showing it.
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == output_buf then
        vim.api.nvim_win_close(win, false)
        return
      end
    end
    -- Buffer exists but isn't shown; re-open it.
    local height = math.max(6, math.floor(vim.o.lines * 0.25))
    vim.cmd("botright " .. height .. "new")
    vim.api.nvim_win_set_buf(0, output_buf)
    vim.wo.winfixheight = true
    vim.cmd("wincmd p")
    return
  end
  vim.notify("jac check: no previous output", vim.log.levels.INFO)
end

-- --------------------------------------------------------------- actions --

--- Run `jac check` on the given paths, populate quickfix + output buffer.
-- @param paths  list of file/directory paths
-- @param opts   optional table: { silent = true } suppresses the "checking…" message
function M.check(paths, opts)
  paths = paths or {}
  opts  = opts or {}

  if #paths == 0 then
    local p = vim.api.nvim_buf_get_name(0)
    if p == "" then
      vim.notify("jac check: no file to check", vim.log.levels.WARN)
      return
    end
    paths = { p }
  end

  if not opts.silent then
    vim.notify("jac check: checking " .. #paths .. " file(s)…", vim.log.levels.INFO)
  end

  local cmd = vim.list_extend({ jac_bin(), "check", "--no-nowarn" }, paths)
  local output_lines = {}

  local function on_done()
    -- 1. Show raw output in a scratch buffer (always, even on success — the
    --    notification alone feels hollow; this way you see the "PASSED" banner).
    local buf = show_output(output_lines)

    -- 2. Parse and populate quickfix list silently (no auto-open).
    --    User can open it with :copen or navigate with :cnext/:cprev.
    local entries = parse_output(output_lines)

    if #entries > 0 then
      vim.fn.setqflist({}, 'r', { items = entries })
    else
      vim.fn.setqflist({}, 'r')
    end

    -- 3. Summary notification.
    local err_c, warn_c = 0, 0
    for _, e in ipairs(entries) do
      if e.type == 'E' then err_c = err_c + 1
      elseif e.type == 'W' then warn_c = warn_c + 1 end
    end

    if err_c == 0 and warn_c == 0 then
      vim.notify("jac check: passed", vim.log.levels.INFO)
    else
      local summary = string.format("jac check: %d error(s), %d warning(s)", err_c, warn_c)
      vim.notify(summary, err_c > 0 and vim.log.levels.WARN or vim.log.levels.INFO)
    end
  end

  -- Async job: merge stdout and stderr (jac sends diagnostics to both).
  local job = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        table.insert(output_lines, line)
      end
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data) do
        table.insert(output_lines, line)
      end
    end,
    on_exit = vim.schedule_wrap(function()
      on_done()
    end),
  })

  if job <= 0 then
    vim.notify("jac check: failed to start process", vim.log.levels.ERROR)
  end
end

--- Check the current buffer's file.
function M.check_current()
  local p = vim.api.nvim_buf_get_name(0)
  if p == "" then
    vim.notify("jac check: buffer has no file", vim.log.levels.WARN)
    return
  end
  M.check({ p })
end

--- Check the whole project (current working directory).
function M.check_project()
  M.check({ vim.fn.getcwd() })
end

-- ------------------------------------------------------------------ setup --
function M.setup()
  vim.api.nvim_create_user_command("JacCheckOutput", function()
    M.toggle_output()
  end, { desc = "Toggle jac check output buffer" })
end

return M
