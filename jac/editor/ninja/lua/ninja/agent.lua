-- ninja.agent -- orchestrate the jac binary's own coding agent (`jac ai`)
-- from inside the fused editor.
--
-- The agent lives in managed terminal splits, one per named session. Editor
-- actions send single-line requests into the live session's stdin; context
-- travels as REFERENCES (absolute path, line range, diagnostics text), never
-- pasted code -- `jac ai` has its own file tools and reads the code itself.
-- Everything runs through $JAC_BIN, so editor and agent are one binary.

local M = {}

local sessions = {} -- name -> { buf = bufnr, job = channel id }

local function jac_bin()
  -- JAC_NINJA_AGENT_BIN overrides for tests/dev; the launcher pins JAC_BIN.
  local bin = vim.env.JAC_NINJA_AGENT_BIN or vim.env.JAC_BIN
  if not bin or bin == "" then bin = "jac" end
  return bin
end

local function session_alive(s)
  return s and s.job and vim.api.nvim_buf_is_valid(s.buf)
    and vim.fn.jobwait({ s.job }, 0)[1] == -1
end

local function win_showing(buf)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(win) == buf then return win end
  end
  return nil
end

local function open_split(buf)
  vim.cmd("botright vsplit")
  vim.cmd("vertical resize " .. math.floor(vim.o.columns * 0.4))
  if buf then vim.api.nvim_win_set_buf(0, buf) end
end

--- Ensure the named session exists and is running; returns it.
local function ensure(name)
  name = name or "main"
  local s = sessions[name]
  if session_alive(s) then return s end

  local cmd = { jac_bin(), "ai" }
  local model = vim.g.ninja_agent_model
  if model and model ~= "" then
    table.insert(cmd, "-m")
    table.insert(cmd, model)
  end
  if vim.g.ninja_agent_safe then table.insert(cmd, "--safe") end

  local prev_win = vim.api.nvim_get_current_win()
  open_split(nil)
  vim.cmd("enew")
  local buf = vim.api.nvim_get_current_buf()
  local job = vim.fn.jobstart(cmd, {
    term = true,
    on_exit = vim.schedule_wrap(function()
      if sessions[name] and sessions[name].buf == buf then sessions[name] = nil end
    end),
  })
  vim.bo[buf].buflisted = false
  pcall(vim.api.nvim_buf_set_name, buf, "ninja-agent://" .. name)
  vim.api.nvim_set_current_win(prev_win)

  s = { buf = buf, job = job }
  sessions[name] = s
  return s
end

--- Show/hide the session's window (starting the agent on first use).
function M.toggle(name)
  name = name or "main"
  local s = sessions[name]
  if session_alive(s) then
    local win = win_showing(s.buf)
    if win then
      vim.api.nvim_win_close(win, false)
      return
    end
    open_split(s.buf)
    return
  end
  local created = ensure(name)
  local win = win_showing(created.buf)
  if win then vim.api.nvim_set_current_win(win) end
end

--- Send one request line into the live agent (starting it if needed).
function M.send(text, name)
  if not text or text == "" then return end
  -- Requests must stay single-line: the agent REPL submits per line.
  text = text:gsub("%s*\n%s*", " ")
  local s = ensure(name)
  vim.fn.chansend(s.job, text .. "\n")
  local win = win_showing(s.buf)
  if not win then open_split(s.buf) ; vim.cmd("wincmd p") end
end

-- ------------------------------------------------------- context builders --
local function buf_path()
  local p = vim.api.nvim_buf_get_name(0)
  return p ~= "" and vim.fn.fnamemodify(p, ":p") or nil
end

local function visual_range()
  local a = vim.fn.getpos("v")[2]
  local b = vim.fn.getpos(".")[2]
  return math.min(a, b), math.max(a, b)
end

local function diagnostics_text(lnum)
  local ds = vim.diagnostic.get(0, lnum and { lnum = lnum } or nil)
  if #ds == 0 then return nil end
  local parts = {}
  for _, d in ipairs(ds) do
    local sev = vim.diagnostic.severity[d.severity] or "?"
    table.insert(parts, string.format("line %d [%s] %s", d.lnum + 1, sev, d.message))
  end
  return table.concat(parts, "; ")
end

-- ---------------------------------------------------------------- actions --
local function prompted(prompt_label, fn)
  vim.ui.input({ prompt = prompt_label }, function(input)
    if input and input ~= "" then fn(input) end
  end)
end

function M.ask()
  prompted("agent> ", function(req) M.send(req) end)
end

function M.ask_file()
  local p = buf_path()
  if not p then return vim.notify("no file in this buffer", vim.log.levels.WARN) end
  prompted("agent (this file)> ", function(req)
    M.send(string.format("In %s: %s", p, req))
  end)
end

function M.ask_range()
  local p = buf_path()
  if not p then return vim.notify("no file in this buffer", vim.log.levels.WARN) end
  local first, last = visual_range()
  prompted(string.format("agent (L%d-L%d)> ", first, last), function(req)
    M.send(string.format("In %s, lines %d-%d: %s", p, first, last, req))
  end)
end

function M.explain_range()
  local p = buf_path()
  if not p then return end
  local first, last = visual_range()
  M.send(string.format(
    "Read %s and explain lines %d-%d: what they do and how they fit the module.",
    p, first, last))
end

function M.fix_diagnostics()
  local p = buf_path()
  if not p then return end
  local diag = diagnostics_text()
  if not diag then return vim.notify("no diagnostics in this buffer", vim.log.levels.INFO) end
  M.send(string.format("Fix these issues in %s: %s", p, diag))
end

function M.new_session()
  prompted("new agent session name> ", function(name) M.toggle(name) end)
end

function M.pick_session()
  local names = {}
  for name, s in pairs(sessions) do
    if session_alive(s) then table.insert(names, name) end
  end
  table.sort(names)
  if #names == 0 then return vim.notify("no live agent sessions", vim.log.levels.INFO) end
  vim.ui.select(names, { prompt = "agent sessions" }, function(choice)
    if choice then M.toggle(choice) end
  end)
end

function M.set_model()
  prompted("agent model (empty = jac.toml default)> ", function(m)
    vim.g.ninja_agent_model = m
    vim.notify("new agent sessions will use: " .. (m ~= "" and m or "(default)"))
  end)
end

function M.toggle_safe()
  vim.g.ninja_agent_safe = not vim.g.ninja_agent_safe
  vim.notify("agent --safe " .. (vim.g.ninja_agent_safe and "ON" or "off") .. " (new sessions)")
end

-- ------------------------------------------------------------------ setup --
function M.setup()
  local map = vim.keymap.set
  map("n", "<Leader>aa", function() M.toggle() end, { desc = "Agent: toggle session" })
  map("n", "<Leader>aq", M.ask, { desc = "Agent: ask" })
  map("n", "<Leader>af", M.ask_file, { desc = "Agent: ask about this file" })
  map("n", "<Leader>ad", M.fix_diagnostics, { desc = "Agent: fix diagnostics" })
  map("x", "<Leader>as", M.ask_range, { desc = "Agent: ask about selection" })
  map("x", "<Leader>ae", M.explain_range, { desc = "Agent: explain selection" })
  map("n", "<Leader>an", M.new_session, { desc = "Agent: new named session" })
  map("n", "<Leader>al", M.pick_session, { desc = "Agent: pick session" })
  map("n", "<Leader>am", M.set_model, { desc = "Agent: set model" })
  map("n", "<Leader>ax", M.toggle_safe, { desc = "Agent: toggle --safe" })

  vim.api.nvim_create_user_command("NinjaAgent", function(o)
    if o.args ~= "" then M.toggle(o.args) else M.toggle() end
  end, { nargs = "?", desc = "Toggle a jac ai agent session" })
  vim.api.nvim_create_user_command("NinjaAgentSend", function(o)
    M.send(o.args)
  end, { nargs = "+", desc = "Send a request to the jac ai agent" })
end

-- test seam: expose internals for headless verification
M._sessions = sessions
M._ensure = ensure

return M
