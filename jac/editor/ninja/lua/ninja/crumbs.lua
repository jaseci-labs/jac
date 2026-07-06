-- ninja.crumbs -- VSCode-style winbar breadcrumbs: [EASY] path > Sym > Sym.
--
-- Symbol chain comes from textDocument/documentSymbol (cached per buffer,
-- refreshed when the buffer changes); path-only when no LSP is attached.

local M = {}

local aug = nil
local cache = {} -- bufnr -> { tick = changedtick, symbols = {...} }
local inflight = {} -- bufnr -> true while a request is pending
local retry_at = {} -- bufnr -> uv.now() floor for the next attempt
local debounce = nil -- uv timer coalescing cursor-move refreshes

local function sep()
  return vim.env.JAC_NINJA_ASCII == "1" and " > " or "  "
end

--- Depth-first: names of symbols whose range contains the cursor.
local function chain_at(symbols, row, col, out)
  for _, s in ipairs(symbols or {}) do
    local r = s.range or (s.location and s.location.range)
    if r and (row > r.start.line or (row == r.start.line and col >= r.start.character))
      and (row < r["end"].line or (row == r["end"].line and col <= r["end"].character)) then
      table.insert(out, s.name)
      chain_at(s.children, row, col, out)
      return
    end
  end
end

-- One in-flight request per buffer, coalesced behind a debounce timer, with
-- a hard backoff between attempts. Hammering documentSymbol on every cursor
-- move while the server warms up races its responses into
-- NO_RESULT_CALLBACK_FOUND errors -- which echo multi-line and park the TUI
-- at a hit-enter prompt.
local REFRESH_DEBOUNCE_MS = 250
local RETRY_BACKOFF_MS = 2000

local function request_symbols(buf)
  if not vim.api.nvim_buf_is_valid(buf) or inflight[buf] then return end
  if retry_at[buf] and vim.uv.now() < retry_at[buf] then return end
  local clients = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/documentSymbol" })
  if #clients == 0 then return end
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  if cache[buf] and cache[buf].tick == tick then return end
  inflight[buf] = true
  retry_at[buf] = vim.uv.now() + RETRY_BACKOFF_MS
  local params = { textDocument = vim.lsp.util.make_text_document_params(buf) }
  clients[1]:request("textDocument/documentSymbol", params, function(err, result)
    inflight[buf] = nil
    -- An empty result usually means the server is still indexing; leave the
    -- cache unset so a later (backed-off) attempt retries instead of
    -- pinning an empty chain.
    if not err and result and #result > 0 and vim.api.nvim_buf_is_valid(buf) then
      cache[buf] = { tick = tick, symbols = result }
    end
  end, buf)
end

local function refresh_symbols(buf)
  if debounce then debounce:stop() end
  debounce = debounce or vim.uv.new_timer()
  debounce:start(REFRESH_DEBOUNCE_MS, 0, vim.schedule_wrap(function()
    request_symbols(buf)
  end))
end

local function render(win)
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].buftype ~= "" then return end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then return end
  refresh_symbols(buf) -- async; the next render picks the result up

  local parts = { vim.fn.fnamemodify(name, ":~:.") }
  local entry = cache[buf]
  if entry then
    local cur = vim.api.nvim_win_get_cursor(win)
    local syms = {}
    chain_at(entry.symbols, cur[1] - 1, cur[2], syms)
    vim.list_extend(parts, syms)
  end
  local crumbs = table.concat(parts, sep()):gsub("%%", "%%%%")
  vim.wo[win].winbar = "%#WinBarEasy# EASY %#WinBar# " .. crumbs
end

function M.enable()
  if aug then return end
  aug = vim.api.nvim_create_augroup("NinjaCrumbs", { clear = true })
  vim.api.nvim_create_autocmd({ "LspAttach", "BufEnter", "TextChanged", "InsertLeave" }, {
    group = aug,
    callback = function(ev) refresh_symbols(ev.buf) end,
  })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufWinEnter" }, {
    group = aug,
    callback = function() render(vim.api.nvim_get_current_win()) end,
  })
  -- On attach, render every window SHOWING the attached buffer -- it may
  -- have attached in a background split, not the focused window.
  vim.api.nvim_create_autocmd("LspAttach", {
    group = aug,
    callback = function(ev)
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == ev.buf then render(win) end
      end
    end,
  })
  render(vim.api.nvim_get_current_win())
end

function M.disable()
  if not aug then return end
  vim.api.nvim_del_augroup_by_id(aug)
  aug = nil
  if debounce then
    debounce:stop()
    debounce:close()
    debounce = nil
  end
  cache = {}
  retry_at = {}
  -- Stale in-flight flags would suppress the first request after a quick
  -- re-enable (and forever, if the old callback never fires post-detach).
  inflight = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    vim.wo[win].winbar = ""
  end
end

return M
