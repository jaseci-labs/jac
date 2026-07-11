-- ninja.theme -- the ninja look: the default mini.hues scheme.

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

return M
