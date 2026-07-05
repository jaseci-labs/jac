-- ninja.easy -- VSCode-style input layer for people who don't speak vim.
--
-- Activation: `jac ninja --easy` (the launcher exports JAC_NINJA_EASY=1),
-- or `:NinjaEasy on`. The choice persists via a marker file in the state
-- dir (~/.local/state/jac-ninja/easy-mode), so easy mode sticks across
-- sessions until `:NinjaEasy off` / `jac ninja --no-easy`.
--
-- Philosophy: modal vim stays available (Esc works, clue hints still
-- teach), but the CUA muscle memory works everywhere: ctrl-s saves,
-- ctrl-z undoes, ctrl-c/x/v use the system clipboard, shift-arrows
-- select, file buffers open in insert mode. Documented tradeoff: ctrl-v
-- shadows visual-block (use ctrl-q for that per vim tradition? no --
-- ctrl-q quits; easy mode users don't block-select).

local M = {}

M.enabled = false
local maps = {} -- tracked for teardown: { {mode, lhs}, ... }
local saved = {} -- option values to restore on disable
local aug = nil

local function marker_path()
  return vim.fn.stdpath("state") .. "/easy-mode"
end

local function map(mode, lhs, rhs, opts)
  opts = opts or {}
  vim.keymap.set(mode, lhs, rhs, opts)
  local modes = type(mode) == "table" and mode or { mode }
  for _, m in ipairs(modes) do
    table.insert(maps, { m, lhs })
  end
end

local function set_opt(name, value)
  if saved[name] == nil then saved[name] = vim.o[name] end
  vim.o[name] = value
end

local function palette()
  require("mini.extra").pickers.commands()
end

function M.enable(persist)
  if M.enabled then return end
  M.enabled = true

  -- shift-arrow selection + typing-replaces-selection (select mode)
  set_opt("keymodel", "startsel,stopsel")
  set_opt("selectmode", "mouse,key")
  set_opt("mousemodel", "popup_setpos")

  -- file buffers open ready to type; Esc still drops to normal mode
  aug = vim.api.nvim_create_augroup("NinjaEasy", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = aug,
    callback = function(ev)
      if vim.bo[ev.buf].buftype == "" and vim.bo[ev.buf].modifiable
        and vim.fn.mode() == "n" then
        vim.cmd("startinsert")
      end
    end,
  })

  -- save / undo / redo
  map({ "n", "x" }, "<C-s>", "<Cmd>write<CR>", { desc = "Save" })
  map({ "i", "s" }, "<C-s>", "<C-o><Cmd>write<CR>", { desc = "Save" })
  map({ "n" }, "<C-z>", "u", { desc = "Undo" })
  map({ "i", "s" }, "<C-z>", "<C-o>u", { desc = "Undo" })
  map({ "n" }, "<C-y>", "<C-r>", { desc = "Redo" })
  map({ "i" }, "<C-y>", "<C-o><C-r>", { desc = "Redo" })

  -- system-clipboard copy / cut / paste / select-all
  map("x", "<C-c>", '"+y', { desc = "Copy" })
  map("n", "<C-c>", '"+yy', { desc = "Copy line" })
  map("x", "<C-x>", '"+d', { desc = "Cut" })
  map("n", "<C-x>", '"+dd', { desc = "Cut line" })
  map("n", "<C-v>", '"+p', { desc = "Paste" })
  map({ "i", "s" }, "<C-v>", '<C-r><C-o>+', { desc = "Paste" })
  map("c", "<C-v>", "<C-r>+", { desc = "Paste" })
  map("x", "<C-v>", '"+P', { desc = "Paste over selection" })
  map({ "n", "i", "x" }, "<C-a>", "<Esc>ggVG", { desc = "Select all" })

  -- find / replace
  map("n", "<C-f>", "/", { desc = "Find" })
  map({ "i", "s" }, "<C-f>", "<Esc>/", { desc = "Find" })
  map("n", "<C-h>", ":%s/", { desc = "Replace in file" })

  -- pickers: files / command palette (C-S-p needs a CSI-u terminal; F1
  -- is the universal fallback)
  map({ "n", "i" }, "<C-p>", "<Cmd>Pick files<CR>", { desc = "Go to file" })
  map({ "n", "i" }, "<C-S-p>", palette, { desc = "Command palette" })
  map({ "n", "i" }, "<F1>", palette, { desc = "Command palette" })

  -- comment toggle: terminals send C-/ as C-_ (map both)
  for _, key in ipairs({ "<C-/>", "<C-_>" }) do
    map("n", key, "gcc", { remap = true, desc = "Toggle comment" })
    map("x", key, "gc", { remap = true, desc = "Toggle comment" })
    map("i", key, "<C-o>gcc", { remap = true, desc = "Toggle comment" })
  end

  -- move line / selection with alt-arrows
  map("n", "<A-Down>", "<Cmd>move .+1<CR>==", { desc = "Move line down" })
  map("n", "<A-Up>", "<Cmd>move .-2<CR>==", { desc = "Move line up" })
  map("i", "<A-Down>", "<Esc><Cmd>move .+1<CR>==gi", { desc = "Move line down" })
  map("i", "<A-Up>", "<Esc><Cmd>move .-2<CR>==gi", { desc = "Move line up" })
  map("x", "<A-Down>", ":move '>+1<CR>gv=gv", { desc = "Move selection down" })
  map("x", "<A-Up>", ":move '<-2<CR>gv=gv", { desc = "Move selection up" })

  -- lsp function keys
  map({ "n", "i" }, "<F2>", vim.lsp.buf.rename, { desc = "Rename symbol" })
  map({ "n", "i" }, "<F12>", vim.lsp.buf.definition, { desc = "Go to definition" })

  -- buffers / windows / app
  map("n", "<C-w>", "<Cmd>confirm bdelete<CR>", { desc = "Close file" })
  map({ "n", "i" }, "<C-q>", "<Cmd>confirm qall<CR>", { desc = "Quit" })
  map({ "n", "i" }, "<C-PageDown>", "<Cmd>bnext<CR>", { desc = "Next file" })
  map({ "n", "i" }, "<C-PageUp>", "<Cmd>bprevious<CR>", { desc = "Previous file" })

  if persist then
    local f = io.open(marker_path(), "w")
    if f then f:write("1\n") ; f:close() end
  end
end

function M.disable(persist)
  if not M.enabled then return end
  M.enabled = false
  for _, m in ipairs(maps) do
    pcall(vim.keymap.del, m[1], m[2])
  end
  maps = {}
  for name, value in pairs(saved) do
    vim.o[name] = value
  end
  saved = {}
  if aug then
    vim.api.nvim_del_augroup_by_id(aug)
    aug = nil
  end
  if persist then os.remove(marker_path()) end
end

--- Wire activation from env/marker and register :NinjaEasy.
function M.setup()
  local env = vim.env.JAC_NINJA_EASY
  local marked = vim.uv.fs_stat(marker_path()) ~= nil
  if env == "1" then
    M.enable(true) -- --easy: turn on AND make it stick
  elseif env == "0" then
    if marked then os.remove(marker_path()) end
  elseif marked then
    M.enable(false)
  end

  vim.api.nvim_create_user_command("NinjaEasy", function(o)
    local arg = o.args ~= "" and o.args or (M.enabled and "off" or "on")
    if arg == "on" then
      M.enable(true)
      vim.notify("easy mode ON (persists; :NinjaEasy off to leave)")
    elseif arg == "off" then
      M.disable(true)
      vim.notify("easy mode off (persisted)")
    end
  end, {
    nargs = "?",
    complete = function() return { "on", "off" } end,
    desc = "Toggle the VSCode-style easy input layer",
  })
end

return M
