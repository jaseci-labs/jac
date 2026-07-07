-- jac ninja -- the fused, jac-focused editor experience.
--
-- Sourced via `nvim -u <payload>/nvim/ninja/init.lua` by the jac launcher's
-- `jac ninja` dispatch (launcher/launcher.zig runNinja). Hermetic by
-- construction: the launcher sets NVIM_APPNAME=jac-ninja (state isolation),
-- VIMRUNTIME=<payload>/nvim/runtime (editor kernel + parsers), and
--   JAC_NINJA_DIR  this config layer (queries/, ftplugin/, mini.nvim, ...)
--   JAC_BIN        the running jac binary -- editor, parser and LSP server
--                  are one and the same file.
-- Everything here is core nvim 0.13 + mini.nvim; no network, no user config.

-- ---------------------------------------------------------------- bootstrap
local ninja_dir = vim.env.JAC_NINJA_DIR
if not ninja_dir or ninja_dir == "" then
  -- Fallback for running outside the launcher (dev loop): derive from this file.
  ninja_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
end
local jac_bin = vim.env.JAC_BIN
if not jac_bin or jac_bin == "" then jac_bin = "jac" end

-- jac.toml [dev] jaclang_source, mirroring _jac_finder's compiler override:
-- when this binary is NOT already linked (no baked marker -- the launcher
-- sets JAC_NINJA_BASE == JAC_NINJA_DIR in that case; the marker wins when
-- present, same precedence as the compiler) and the project's jac.toml dev-
-- links the source tree, serve the editor config from <source>/editor/ninja
-- too. JAC_NO_DEV_SOURCE=1 forces it off, like everywhere else.
local function toml_dev_ninja()
  if vim.env.JAC_NO_DEV_SOURCE == "1" then return nil end
  local base = vim.env.JAC_NINJA_BASE
  if base and base ~= "" and base ~= ninja_dir then return nil end -- marker already linked
  local dir = vim.fn.getcwd()
  for _ = 1, 64 do
    local f = io.open(dir .. "/jac.toml")
    if f then
      local txt = f:read("*a")
      f:close()
      local in_dev, src = false, nil
      for line in txt:gmatch("[^\n]*") do
        local sec = line:match("^%s*%[([^%]]+)%]")
        if sec then in_dev = (sec == "dev") end
        if in_dev then
          src = line:match('^%s*jaclang_source%s*=%s*"([^"]*)"') or src
        end
      end
      if not src then return nil end
      if not src:match("^[/~]") then src = dir .. "/" .. src end
      local candidate = vim.fn.fnamemodify(src, ":p"):gsub("/$", "") .. "/editor/ninja"
      if candidate ~= ninja_dir and vim.uv.fs_stat(candidate .. "/init.lua") then
        return candidate
      end
      return nil -- nearest jac.toml wins, like find_project_root
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then return nil end
    dir = parent
  end
end

local toml_ninja = toml_dev_ninja()
if toml_ninja then
  -- Chain-load the live source config; it sees itself as JAC_NINJA_DIR and
  -- the payload copy (via unchanged JAC_NINJA_BASE) keeps providing the
  -- build-staged pieces. The candidate ~= ninja_dir check above prevents
  -- recursion: the chained init resolves its own dir and stops.
  vim.env.JAC_NINJA_DIR = toml_ninja
  dofile(toml_ninja .. "/init.lua")
  return
end

-- This layer carries queries/, ftplugin/, ftdetect/ -- put it on the rtp; the
-- AFTER slot keeps $VIMRUNTIME first for core lua modules.
vim.opt.runtimepath:prepend(ninja_dir)
-- Linked-source dev builds (-Ddev): ninja_dir is the live source tree; the
-- payload's copy (JAC_NINJA_BASE) still provides the build-staged pieces --
-- mini.nvim and the jac queries -- so keep it on the rtp behind the dev dir.
local base_dir = vim.env.JAC_NINJA_BASE
if base_dir and base_dir ~= "" and base_dir ~= ninja_dir then
  vim.opt.runtimepath:append(base_dir)
end
-- mini.nvim is staged as a conventional start-package; rtp it directly so
-- require() works right here instead of after startup.
local mini_dir = ninja_dir .. "/pack/ninja/start/mini.nvim"
if not vim.uv.fs_stat(mini_dir) and base_dir and base_dir ~= "" then
  mini_dir = base_dir .. "/pack/ninja/start/mini.nvim"
end
if not vim.uv.fs_stat(mini_dir) then
  -- The require("mini.*") calls below would die one line later anyway;
  -- fail with an actionable message instead of a module-not-found trace.
  error("jac ninja: mini.nvim not found at " .. mini_dir .. " -- payload may be corrupt (try re-running `zig build`)")
end
vim.opt.runtimepath:append(mini_dir)

-- ------------------------------------------------------------------ options
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.o.number = true
vim.o.relativenumber = true
vim.o.signcolumn = "yes"
vim.o.cursorline = true
vim.o.termguicolors = true
vim.o.winborder = "rounded"
vim.o.laststatus = 3
vim.o.showmode = false
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.scrolloff = 6
vim.o.wrap = false
vim.o.undofile = true
vim.o.swapfile = false
vim.o.updatetime = 300
vim.o.timeoutlen = 400
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.inccommand = "split"
vim.o.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
vim.o.completeopt = "menuone,noinsert,fuzzy"
vim.o.pumheight = 12
vim.o.title = true
vim.o.titlestring = "jac ninja %t"
vim.o.mouse = "a"
vim.o.confirm = true

-- Folding: tree-sitter driven (folds.scm), open by default.
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.o.foldlevelstart = 99
vim.o.foldtext = ""

-- ----------------------------------------------------------------- filetype
vim.filetype.add({ extension = { jac = "jac" } })

-- ---------------------------------------------------------------- mini.nvim
local ascii = vim.env.JAC_NINJA_ASCII == "1"
require("mini.icons").setup(ascii and { style = "ascii" } or {})
-- Stock look; easy mode swaps in the VSCode Dark+ theme (ninja/theme.lua).
require("ninja.theme").default()

require("mini.statusline").setup()
require("mini.tabline").setup()
require("mini.notify").setup()
vim.notify = require("mini.notify").make_notify()

require("mini.pairs").setup()
require("mini.surround").setup()
require("mini.extra").setup()
local ai = require("mini.ai")
ai.setup({
  custom_textobjects = {
    -- tree-sitter textobjects (queries/jac/textobjects.scm)
    f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
    c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
    o = ai.gen_spec.treesitter({ a = "@block.outer", i = "@block.inner" }),
  },
})

require("mini.pick").setup()
require("mini.files").setup({ windows = { preview = true, width_preview = 45 } })
require("mini.completion").setup({})

-- Discoverable keymaps: clue window on <leader>/g/'/"/ctrl-w chords.
local clue = require("mini.clue")
clue.setup({
  triggers = {
    { mode = "n", keys = "<Leader>" },
    { mode = "x", keys = "<Leader>" },
    { mode = "n", keys = "g" },
    { mode = "n", keys = "'" },
    { mode = "n", keys = "`" },
    { mode = "n", keys = '"' },
    { mode = "n", keys = "<C-w>" },
    { mode = "n", keys = "[" },
    { mode = "n", keys = "]" },
  },
  clues = {
    clue.gen_clues.builtin_completion(),
    clue.gen_clues.g(),
    clue.gen_clues.marks(),
    clue.gen_clues.registers(),
    clue.gen_clues.windows(),
    { mode = "n", keys = "<Leader>a", desc = "+agent" },
    { mode = "n", keys = "<Leader>f", desc = "+find" },
    { mode = "n", keys = "<Leader>j", desc = "+jac" },
    { mode = "n", keys = "<Leader>l", desc = "+lsp" },
  },
  window = { delay = 300 },
})

-- Start screen.
local starter = require("mini.starter")
starter.setup({
  header = table.concat({
    "     ██╗ █████╗  ██████╗    ███╗   ██╗██╗███╗   ██╗     ██╗ █████╗ ",
    "     ██║██╔══██╗██╔════╝    ████╗  ██║██║████╗  ██║     ██║██╔══██╗",
    "     ██║███████║██║         ██╔██╗ ██║██║██╔██╗ ██║     ██║███████║",
    "██   ██║██╔══██║██║         ██║╚██╗██║██║██║╚██╗██║██   ██║██╔══██║",
    "╚█████╔╝██║  ██║╚██████╗    ██║ ╚████║██║██║ ╚████║╚█████╔╝██║  ██║",
    " ╚════╝ ╚═╝  ╚═╝ ╚═════╝    ╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚════╝ ╚═╝  ╚═╝",
    "",
    "        the jac editor -- one binary: editor + parser + lsp",
  }, "\n"),
  items = {
    starter.sections.recent_files(7, false),
    {
      { name = "Find file", action = "Pick files", section = "Actions" },
      { name = "Live grep", action = "Pick grep_live", section = "Actions" },
      { name = "Explore", action = "lua MiniFiles.open()", section = "Actions" },
      { name = "New jac file", action = "enew | setfiletype jac", section = "Actions" },
      { name = "Quit", action = "qall", section = "Actions" },
    },
  },
  footer = "space = leader  ·  space-f-f find  ·  space-a agent  ·  space-j jac tools",
})

-- -------------------------------------------------------------- tree-sitter
-- Parsers live in $VIMRUNTIME/parser (c, lua, vim, vimdoc, markdown, query,
-- python, jac); highlight what we ship queries for.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "jac", "python", "lua", "c", "markdown", "vim", "query" },
  callback = function(ev)
    pcall(vim.treesitter.start, ev.buf)
  end,
})

-- ---------------------------------------------------------------------- lsp
-- The language server is the very binary that launched the editor.
vim.lsp.config("jac", {
  cmd = { jac_bin, "lsp" },
  filetypes = { "jac" },
  root_markers = { "jac.toml", ".git" },
})
vim.lsp.enable("jac")

vim.diagnostic.config({
  severity_sort = true,
  virtual_text = { spacing = 2 },
  float = { source = true },
  signs = {
    text = ascii and { "E", "W", "I", "H" } or nil,
  },
})

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local map = function(lhs, rhs, desc, mode)
      vim.keymap.set(mode or "n", lhs, rhs, { buffer = ev.buf, desc = desc })
    end
    -- Core already maps grn/gra/grr/gri/gO/K/<C-s>; add the classics on top.
    map("gd", vim.lsp.buf.definition, "Goto definition")
    map("gD", vim.lsp.buf.declaration, "Goto declaration")
    map("<Leader>lr", vim.lsp.buf.rename, "Rename symbol")
    map("<Leader>la", vim.lsp.buf.code_action, "Code action")
    map("<Leader>lf", function() vim.lsp.buf.format({ async = true }) end, "Format buffer")
    map("<Leader>ls", function() require("mini.extra").pickers.lsp({ scope = "document_symbol" }) end, "Document symbols")
    map("<Leader>lw", function() require("mini.extra").pickers.lsp({ scope = "workspace_symbol" }) end, "Workspace symbols")
  end,
})

-- ------------------------------------------------------------------ keymaps
local map = vim.keymap.set

map("n", "<Esc>", "<Cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
map("n", "<C-h>", "<C-w>h", { desc = "Focus left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Focus lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Focus upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Focus right window" })
map("n", "<Leader>q", "<Cmd>confirm qall<CR>", { desc = "Quit" })
map("n", "<Leader>w", "<Cmd>write<CR>", { desc = "Write" })

-- find/pick
map("n", "<Leader>ff", "<Cmd>Pick files<CR>", { desc = "Find files" })
map("n", "<Leader>fg", "<Cmd>Pick grep_live<CR>", { desc = "Live grep" })
map("n", "<Leader>fb", "<Cmd>Pick buffers<CR>", { desc = "Buffers" })
map("n", "<Leader>fh", "<Cmd>Pick help<CR>", { desc = "Help tags" })
map("n", "<Leader>fr", "<Cmd>Pick resume<CR>", { desc = "Resume last pick" })
map("n", "<Leader>fd", "<Cmd>Pick diagnostic<CR>", { desc = "Diagnostics" })
map("n", "<Leader>e", function()
  local path = vim.api.nvim_buf_get_name(0)
  require("mini.files").open(path ~= "" and path or nil)
end, { desc = "Explore files" })
map("n", "-", function() require("mini.files").open() end, { desc = "Explore cwd" })

-- diagnostics
map("n", "<Leader>d", vim.diagnostic.open_float, { desc = "Line diagnostics" })

-- jac tools: run the current file with the SAME binary in a terminal split.
local function jac_term(args)
  vim.cmd("botright 14new")
  vim.fn.jobstart(vim.list_extend({ jac_bin }, args), { term = true })
  vim.cmd("startinsert")
end
-- Guarded on a real .jac file so `space-j-r` from the sidebar/starter says
-- so instead of spawning a split that dies with a raw CLI error.
local function jac_file_cmd(subcmd)
  return function()
    local f = vim.api.nvim_buf_get_name(0)
    if not f:match("%.jac$") then
      return vim.notify("jac " .. subcmd .. ": focus a .jac file first", vim.log.levels.WARN)
    end
    jac_term({ subcmd, f })
  end
end
map("n", "<Leader>jr", jac_file_cmd("run"), { desc = "jac run file" })
map("n", "<Leader>jt", jac_file_cmd("test"), { desc = "jac test file" })
map("n", "<Leader>jc", jac_file_cmd("check"), { desc = "jac check file" })
map("n", "<Leader>jd", jac_file_cmd("dot"), { desc = "jac dot graph" })

-- -------------------------------------------------------------------- agent
-- The binary's own coding agent (`jac ai`), orchestrated in managed splits:
-- space-a-a session, space-a-q ask, space-a-d fix diagnostics, ...
require("ninja.agent").setup()

-- ---------------------------------------------------------------- easy mode
-- VSCode-style input layer (`jac ninja --easy` or :NinjaEasy on): CUA keys,
-- shift-arrow selection, insert-first buffers. Persists via a state marker.
require("ninja.easy").setup()

-- ------------------------------------------------------------- autocommands
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank() end,
})

-- Jump back to the last cursor position when reopening a file.
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local lines = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= lines then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})
