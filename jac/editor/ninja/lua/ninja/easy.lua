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

--- VSCode-style netrw sidebar (tree view, no banner, fixed width).
local function sidebar_setup()
  vim.g.netrw_banner = 0
  vim.g.netrw_liststyle = 3
  vim.g.netrw_browse_split = 4 -- open files in the previous (main) window
  vim.g.netrw_winsize = 22
  vim.g.netrw_altv = 1
end

-- Focus (or stay in) a real editor window -- not the sidebar, not the
-- panel. VSCode's panel-close and editor-split both land in the editor.
local function focus_editor_win()
  local function is_editor(b) return vim.bo[b].buftype == "" and vim.bo[b].filetype ~= "netrw" end
  if is_editor(vim.api.nvim_get_current_buf()) then return end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_editor(vim.api.nvim_win_get_buf(win)) then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
end

-- Hand-rolled toggle instead of :Lexplore: Lexplore silently opens an
-- empty, dead window when invoked while a special buffer (mini.starter's
-- ministarter://) is current, and its tab-global bookkeeping then wedges
-- the toggle. A plain split + :Explore <cwd> works from any context.
local function sidebar_toggle()
  sidebar_setup()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "netrw" then
      vim.api.nvim_win_close(win, true)
      focus_editor_win()
      return
    end
  end
  local prev = vim.api.nvim_get_current_win()
  vim.cmd("topleft vertical 24 new")
  vim.cmd("Explore " .. vim.fn.fnameescape(vim.fn.getcwd()))
  vim.wo.winfixwidth = true
  -- VSCode's ctrl+b keeps focus in the editor.
  if vim.api.nvim_win_is_valid(prev) then
    vim.api.nvim_set_current_win(prev)
  end
end

-- VSCode-style bottom panel: one persistent shell terminal per session,
-- toggled with ctrl+` (and ctrl+j); hiding the window keeps the job alive.
local panel = { buf = nil }

local function panel_toggle()
  -- visible? -> hide (job keeps running in the background buffer)
  if panel.buf and vim.api.nvim_buf_is_valid(panel.buf) then
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_buf(win) == panel.buf then
        vim.api.nvim_win_close(win, false)
        focus_editor_win()
        return
      end
    end
  end
  vim.cmd("botright 12split")
  if panel.buf and vim.api.nvim_buf_is_valid(panel.buf) then
    vim.api.nvim_win_set_buf(0, panel.buf)
  else
    vim.cmd("enew")
    panel.buf = vim.api.nvim_get_current_buf()
    vim.fn.jobstart({ vim.o.shell }, {
      term = true,
      on_exit = vim.schedule_wrap(function()
        if panel.buf and vim.api.nvim_buf_is_valid(panel.buf) then
          pcall(vim.api.nvim_buf_delete, panel.buf, { force = true })
        end
        panel.buf = nil
      end),
    })
    vim.bo[panel.buf].buflisted = false
    pcall(vim.api.nvim_buf_set_name, panel.buf, "ninja-panel://terminal")
  end
  vim.wo.winfixheight = true
  vim.cmd("startinsert")
end

local function panel_close()
  if panel.buf and vim.api.nvim_buf_is_valid(panel.buf) then
    pcall(vim.api.nvim_buf_delete, panel.buf, { force = true })
  end
  panel.buf = nil
end

function M.enable(persist)
  if M.enabled then return end
  M.enabled = true

  -- shift-arrow selection + typing-replaces-selection (select mode)
  set_opt("keymodel", "startsel,stopsel")
  set_opt("selectmode", "mouse,key")
  set_opt("mousemodel", "popup_setpos")
  -- absolute line numbers: relative jumps read as broken to non-vim users
  set_opt("relativenumber", false)

  -- the VSCode look: Dark+ colors, blue status bar, breadcrumbs winbar
  require("ninja.theme").vscode()
  require("ninja.crumbs").enable()

  -- file buffers open ready to type; Esc still drops to normal mode
  aug = vim.api.nvim_create_augroup("NinjaEasy", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = aug,
    callback = function(ev)
      -- Guard: BufEnter also fires when a buffer is placed into ANOTHER
      -- window by API (the welcome-tab swap) -- acting would then hit
      -- whatever buffer is actually current.
      if vim.api.nvim_get_current_buf() ~= ev.buf then return end
      local editorish = vim.bo[ev.buf].buftype == "" and vim.bo[ev.buf].modifiable
      if editorish and vim.fn.mode() == "n" then
        vim.cmd("startinsert")
      elseif not editorish and vim.bo[ev.buf].buftype ~= "terminal"
        and vim.fn.mode():find("i") then
        -- Insert-first must not LEAK into special buffers: insert mode
        -- carried into the netrw tree makes Enter try to edit the
        -- nomodifiable listing (E21) instead of opening the file.
        vim.cmd("stopinsert")
      end
    end,
  })

  -- Retire the welcome tab when the user enters the explorer (VSCode
  -- behavior): netrw cannot open files into the starter's nomodifiable
  -- window (silent E21), so hand it a normal empty buffer to land in.
  vim.api.nvim_create_autocmd("WinEnter", {
    group = aug,
    callback = function()
      if vim.bo.filetype ~= "netrw" then return end
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local b = vim.api.nvim_win_get_buf(win)
        if vim.bo[b].filetype == "ministarter" then
          vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(true, false))
        end
      end
    end,
  })

  -- Keep netrw aimed at the last editor window (the Lexplore mechanism,
  -- driven by hand since we hand-roll the sidebar): without it netrw's
  -- previous-window dance can land inside its own nomodifiable listing
  -- and die with a silent E21 instead of opening the file.
  vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
    group = aug,
    callback = function()
      if vim.bo.buftype == "" and vim.bo.filetype ~= "netrw" then
        vim.g.netrw_chgwin = vim.fn.winnr()
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

  -- explorer sidebar (netrw tree, VSCode's ctrl+b / ctrl+shift+e)
  map({ "n", "i" }, "<C-b>", sidebar_toggle, { desc = "Toggle explorer sidebar" })
  map({ "n", "i" }, "<C-S-e>", sidebar_toggle, { desc = "Toggle explorer sidebar" })

  -- bottom terminal panel (VSCode's ctrl+`; ctrl+j fallback for terminals
  -- that can't send ctrl+`) and editor split (ctrl+\)
  map({ "n", "i", "t" }, "<C-`>", panel_toggle, { desc = "Toggle terminal panel" })
  map({ "n", "i", "t" }, "<C-j>", panel_toggle, { desc = "Toggle terminal panel" })
  map({ "n", "i" }, "<C-\\>", function()
    focus_editor_win()
    vim.cmd("vsplit")
  end, { desc = "Split editor" })

  -- Interactive session bootstrap: open the sidebar and say hello once the
  -- UI attaches (headless runs and the --embed hop never trigger this).
  vim.api.nvim_create_autocmd("UIEnter", {
    group = aug,
    once = true,
    callback = vim.schedule_wrap(function()
      if not M.enabled or #vim.api.nvim_list_uis() == 0 then return end
      local main_win = vim.api.nvim_get_current_win()
      sidebar_toggle()
      pcall(vim.api.nvim_set_current_win, main_win)
      vim.notify("easy mode: ctrl+s save · ctrl+p files · F1 palette · ctrl+b explorer · ctrl+` terminal · :NinjaEasy off to leave")
    end),
  })

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
  -- re-register the stock window-nav maps easy shadowed (deleting the easy
  -- mapping removes the lhs entirely, not the map it replaced)
  vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Focus left window" })
  vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Focus lower window" })
  for name, value in pairs(saved) do
    vim.o[name] = value
  end
  saved = {}
  if aug then
    vim.api.nvim_del_augroup_by_id(aug)
    aug = nil
  end
  vim.g.netrw_chgwin = nil
  -- back to the stock ninja look; close the explorer sidebar + panel.
  -- All tabpages: a sidebar opened in another tab must not survive
  -- :NinjaEasy off (review feedback).
  require("ninja.crumbs").disable()
  require("ninja.theme").default()
  panel_close()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "netrw" then
      pcall(vim.api.nvim_win_close, win, true)
    end
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
