-- ninja.theme -- the two ninja looks: the default mini.hues scheme and a
-- VSCode Dark+ scheme used by easy mode. Both are full re-applications, so
-- :NinjaEasy on/off can swap them live.

local M = {}

--- The stock ninja look (mini.hues, jaseci orange accent).
function M.default()
  require("mini.hues").setup({
    background = "#14161d",
    foreground = "#c9d1e3",
    accent = "orange",
    saturation = "medium",
  })
  vim.g.colors_name = "jac-ninja"
end

-- VSCode Dark+ palette
local p = {
  bg = "#1e1e1e",
  panel = "#252526",
  panel2 = "#2d2d30",
  cursorline = "#2a2d2e",
  selection = "#264f78",
  fg = "#d4d4d4",
  fg_dim = "#cccccc",
  comment = "#6a9955",
  string = "#ce9178",
  number = "#b5cea8",
  keyword = "#569cd6",
  control = "#c586c0",
  func = "#dcdcaa",
  type = "#4ec9b0",
  variable = "#9cdcfe",
  constant = "#4fc1ff",
  err = "#f44747",
  warn = "#cca700",
  info = "#3794ff",
  hint = "#b0b0b0",
  linenr = "#858585",
  linenr_cur = "#c6c6c6",
  border = "#454545",
  accent = "#007acc", -- the VSCode status-bar blue
  match = "#613214",
}

--- The easy-mode look: VSCode Dark+ colors, blue status bar included.
function M.vscode()
  vim.cmd("highlight clear")
  vim.o.background = "dark"
  local hi = function(group, spec) vim.api.nvim_set_hl(0, group, spec) end

  -- UI chrome
  hi("Normal", { fg = p.fg, bg = p.bg })
  hi("NormalFloat", { fg = p.fg, bg = p.panel })
  hi("FloatBorder", { fg = p.border, bg = p.panel })
  hi("FloatTitle", { fg = p.fg, bg = p.panel, bold = true })
  hi("CursorLine", { bg = p.cursorline })
  hi("CursorLineNr", { fg = p.linenr_cur })
  hi("LineNr", { fg = p.linenr })
  hi("SignColumn", { bg = p.bg })
  hi("Visual", { bg = p.selection })
  hi("Search", { bg = p.match })
  hi("IncSearch", { bg = p.selection })
  hi("CurSearch", { bg = p.selection })
  hi("Pmenu", { fg = p.fg, bg = p.panel })
  hi("PmenuSel", { bg = "#04395e" })
  hi("PmenuSbar", { bg = p.panel2 })
  hi("PmenuThumb", { bg = p.border })
  hi("WinSeparator", { fg = p.border })
  hi("StatusLine", { fg = "#ffffff", bg = p.accent })
  hi("StatusLineNC", { fg = p.fg_dim, bg = p.panel })
  hi("TabLine", { fg = p.hint, bg = p.panel })
  hi("TabLineSel", { fg = p.fg, bg = p.bg })
  hi("TabLineFill", { bg = p.panel })
  hi("WinBar", { fg = p.fg_dim, bg = p.bg })
  hi("WinBarNC", { fg = p.linenr, bg = p.bg })
  hi("WinBarEasy", { fg = "#ffffff", bg = p.accent, bold = true })
  hi("Directory", { fg = p.variable })
  hi("Title", { fg = p.keyword, bold = true })
  hi("MatchParen", { bg = p.panel2, underline = true })
  hi("NonText", { fg = "#3b3b3b" })
  hi("Whitespace", { fg = "#3b3b3b" })
  hi("EndOfBuffer", { fg = p.bg })
  hi("ColorColumn", { bg = p.panel })
  hi("QuickFixLine", { bg = p.selection })
  hi("Folded", { fg = p.hint, bg = p.panel })

  -- mini.nvim chrome follows the blue bar
  hi("MiniStatuslineModeNormal", { fg = "#ffffff", bg = p.accent, bold = true })
  hi("MiniStatuslineModeInsert", { fg = "#1e1e1e", bg = p.func, bold = true })
  hi("MiniStatuslineModeVisual", { fg = "#ffffff", bg = p.control, bold = true })
  hi("MiniStatuslineModeReplace", { fg = "#ffffff", bg = p.err, bold = true })
  hi("MiniStatuslineModeCommand", { fg = "#1e1e1e", bg = p.warn, bold = true })
  hi("MiniStatuslineDevinfo", { fg = "#ffffff", bg = p.accent })
  hi("MiniStatuslineFilename", { fg = "#ffffff", bg = p.accent })
  hi("MiniStatuslineFileinfo", { fg = "#ffffff", bg = p.accent })
  hi("MiniStatuslineInactive", { fg = p.fg_dim, bg = p.panel })
  hi("MiniTablineCurrent", { fg = p.fg, bg = p.bg })
  hi("MiniTablineVisible", { fg = p.hint, bg = p.panel })
  hi("MiniTablineHidden", { fg = p.hint, bg = p.panel })
  hi("MiniTablineModifiedCurrent", { fg = p.warn, bg = p.bg })
  hi("MiniTablineModifiedVisible", { fg = p.warn, bg = p.panel })
  hi("MiniTablineModifiedHidden", { fg = p.warn, bg = p.panel })
  hi("MiniTablineFill", { bg = p.panel })
  hi("MiniPickMatchCurrent", { bg = "#04395e" })
  hi("MiniPickPrompt", { fg = p.info, bg = p.panel })

  -- syntax (vim core groups)
  hi("Comment", { fg = p.comment, italic = true })
  hi("String", { fg = p.string })
  hi("Character", { fg = p.string })
  hi("Number", { fg = p.number })
  hi("Float", { fg = p.number })
  hi("Boolean", { fg = p.keyword })
  hi("Constant", { fg = p.constant })
  hi("Identifier", { fg = p.variable })
  hi("Function", { fg = p.func })
  hi("Statement", { fg = p.control })
  hi("Conditional", { fg = p.control })
  hi("Repeat", { fg = p.control })
  hi("Keyword", { fg = p.keyword })
  hi("Operator", { fg = p.fg })
  hi("Exception", { fg = p.control })
  hi("PreProc", { fg = p.control })
  hi("Include", { fg = p.control })
  hi("Type", { fg = p.type })
  hi("Special", { fg = p.constant })
  hi("Delimiter", { fg = p.fg })
  hi("Error", { fg = p.err })
  hi("Todo", { fg = p.bg, bg = p.warn, bold = true })

  -- treesitter captures (the jac grammar's queries land on these)
  hi("@comment", { link = "Comment" })
  hi("@string", { link = "String" })
  hi("@number", { link = "Number" })
  hi("@number.float", { link = "Float" })
  hi("@boolean", { link = "Boolean" })
  hi("@constant", { link = "Constant" })
  hi("@constant.builtin", { fg = p.keyword })
  hi("@keyword", { link = "Keyword" })
  hi("@keyword.import", { fg = p.control })
  hi("@keyword.conditional", { fg = p.control })
  hi("@keyword.repeat", { fg = p.control })
  hi("@keyword.return", { fg = p.control })
  hi("@keyword.exception", { fg = p.control })
  hi("@keyword.operator", { fg = p.keyword })
  hi("@function", { link = "Function" })
  hi("@function.call", { link = "Function" })
  hi("@function.method", { link = "Function" })
  hi("@function.builtin", { link = "Function" })
  hi("@type", { link = "Type" })
  hi("@type.builtin", { link = "Type" })
  hi("@variable", { fg = p.variable })
  hi("@variable.builtin", { fg = p.keyword })
  hi("@variable.parameter", { fg = p.variable })
  hi("@variable.member", { fg = p.variable })
  hi("@property", { fg = p.variable })
  hi("@operator", { link = "Operator" })
  hi("@punctuation.bracket", { fg = p.fg })
  hi("@punctuation.delimiter", { fg = p.fg })
  hi("@punctuation.special", { fg = p.keyword })
  hi("@module", { fg = p.type })
  hi("@attribute", { fg = p.func })

  -- diagnostics
  hi("DiagnosticError", { fg = p.err })
  hi("DiagnosticWarn", { fg = p.warn })
  hi("DiagnosticInfo", { fg = p.info })
  hi("DiagnosticHint", { fg = p.hint })
  hi("DiagnosticUnderlineError", { undercurl = true, sp = p.err })
  hi("DiagnosticUnderlineWarn", { undercurl = true, sp = p.warn })
  hi("DiagnosticUnderlineInfo", { undercurl = true, sp = p.info })
  hi("DiagnosticUnderlineHint", { undercurl = true, sp = p.hint })

  vim.g.colors_name = "jac-ninja-dark"
end

return M
