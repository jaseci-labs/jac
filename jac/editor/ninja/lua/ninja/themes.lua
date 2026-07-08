-- ninja.themes -- base16 color schemes for the fused jac editor.
--
-- Ten curated schemes covering the full spectrum of popular moods:
-- warm/cool, high/low contrast, light/dark. Each palette is the official
-- base16 definition from <https://github.com/tinted-theming/schemes>.
--
-- Usage:
--   :Theme <name>      -- switch theme (tab-completes)
--   <Leader>t          -- pick theme from a fuzzy list
--
-- All themes go through mini.base16 (already in the payload), so LSP
-- diagnostics, tree-sitter, mini.nvim chrome, and ~40 plugin integrations
-- are handled automatically.

local M = {}

-- ------------------------------------------------------------------ palettes
-- Each entry is a full base16 palette (base00–base0F) as consumed by
-- mini.base16.setup({ palette = ... }). Comments show the official scheme
-- name and author.

local themes = {
  ["catppuccin-mocha"] = {
    base00 = "#1e1e2e", base01 = "#181825", base02 = "#313244",
    base03 = "#45475a", base04 = "#585b70", base05 = "#cdd6f4",
    base06 = "#f5e0dc", base07 = "#b4befe", base08 = "#f38ba8",
    base09 = "#fab387", base0A = "#f9e2af", base0B = "#a6e3a1",
    base0C = "#94e2d5", base0D = "#89b4fa", base0E = "#cba6f7",
    base0F = "#f2cdcd",
    -- author: https://github.com/catppuccin/catppuccin
    -- dark · purple/warm · medium contrast
  },

  ["dracula"] = {
    base00 = "#282a36", base01 = "#21222c", base02 = "#44475a",
    base03 = "#6272a4", base04 = "#9ea8c7", base05 = "#f8f8f2",
    base06 = "#f8f8f2", base07 = "#ffffff", base08 = "#ff5555",
    base09 = "#ffb86c", base0A = "#f1fa8c", base0B = "#50fa7b",
    base0C = "#8be9fd", base0D = "#bd93f9", base0E = "#ff79c6",
    base0F = "#993333",
    -- author: clach04 / https://draculatheme.com
    -- dark · purple/green · high contrast
  },

  ["gruvbox-dark-medium"] = {
    base00 = "#282828", base01 = "#3c3836", base02 = "#504945",
    base03 = "#665c54", base04 = "#bdae93", base05 = "#d5c4a1",
    base06 = "#ebdbb2", base07 = "#fbf1c7", base08 = "#fb4934",
    base09 = "#fe8019", base0A = "#fabd2f", base0B = "#b8bb26",
    base0C = "#8ec07c", base0D = "#83a598", base0E = "#d3869b",
    base0F = "#d65d0e",
    -- author: Dawid Kurek / morhetz
    -- dark · warm/retro orange · medium contrast
  },

  ["everforest-dark-medium"] = {
    base00 = "#2d353b", base01 = "#343f44", base02 = "#3d484d",
    base03 = "#475258", base04 = "#7a8478", base05 = "#859289",
    base06 = "#9da9a0", base07 = "#d3c6aa", base08 = "#e67e80",
    base09 = "#e69875", base0A = "#dbbc7f", base0B = "#a7c080",
    base0C = "#83c092", base0D = "#7fbbb3", base0E = "#d699b6",
    base0F = "#514045",
    -- author: Sainnhe Park
    -- dark · earthy green · soft/low contrast
  },

  ["nord"] = {
    base00 = "#2e3440", base01 = "#3b4252", base02 = "#434c5e",
    base03 = "#4c566a", base04 = "#d8dee9", base05 = "#e5e9f0",
    base06 = "#eceff4", base07 = "#8fbcbb", base08 = "#bf616a",
    base09 = "#d08770", base0A = "#ebcb8b", base0B = "#a3be8c",
    base0C = "#88c0d0", base0D = "#81a1c1", base0E = "#b48ead",
    base0F = "#5e81ac",
    -- author: arcticicestudio
    -- dark · arctic blue · medium-low contrast
  },

  ["tokyo-night-storm"] = {
    base00 = "#24283b", base01 = "#16161e", base02 = "#343a52",
    base03 = "#444b6a", base04 = "#787c99", base05 = "#a9b1d6",
    base06 = "#cbccd1", base07 = "#d5d6db", base08 = "#c0caf5",
    base09 = "#a9b1d6", base0A = "#0db9d7", base0B = "#9ece6a",
    base0C = "#b4f9f8", base0D = "#2ac3de", base0E = "#bb9af7",
    base0F = "#f7768e",
    -- author: Michaël Ball
    -- dark · deep blue/purple · medium contrast
  },

  ["monokai"] = {
    base00 = "#272822", base01 = "#383830", base02 = "#49483e",
    base03 = "#75715e", base04 = "#a59f85", base05 = "#f8f8f2",
    base06 = "#f5f4f1", base07 = "#f9f8f5", base08 = "#f92672",
    base09 = "#fd971f", base0A = "#f4bf75", base0B = "#a6e22e",
    base0C = "#a1efe4", base0D = "#66d9ef", base0E = "#ae81ff",
    base0F = "#cc6633",
    -- author: Wimer Hazenberg
    -- dark · high contrast · punchy
  },

  ["catppuccin-latte"] = {
    base00 = "#eff1f5", base01 = "#e6e9ef", base02 = "#ccd0da",
    base03 = "#bcc0cc", base04 = "#acb0be", base05 = "#4c4f69",
    base06 = "#dc8a78", base07 = "#7287fd", base08 = "#d20f39",
    base09 = "#fe640b", base0A = "#df8e1d", base0B = "#40a02b",
    base0C = "#179299", base0D = "#1e66f5", base0E = "#8839ef",
    base0F = "#dd7878",
    -- author: https://github.com/catppuccin/catppuccin
    -- light · warm/soft · medium contrast
  },

  ["one-light"] = {
    base00 = "#fafafa", base01 = "#f0f0f1", base02 = "#e5e5e6",
    base03 = "#a0a1a7", base04 = "#696c77", base05 = "#383a42",
    base06 = "#202227", base07 = "#090a0b", base08 = "#ca1243",
    base09 = "#d75f00", base0A = "#c18401", base0B = "#50a14f",
    base0C = "#0184bc", base0D = "#4078f2", base0E = "#a626a4",
    base0F = "#986801",
    -- author: Daniel Pfeifer
    -- light · clean/crisp · medium contrast
  },

  ["solarized-light"] = {
    base00 = "#fdf6e3", base01 = "#eee8d5", base02 = "#93a1a1",
    base03 = "#839496", base04 = "#657b83", base05 = "#586e75",
    base06 = "#073642", base07 = "#002b36", base08 = "#dc322f",
    base09 = "#cb4b16", base0A = "#b58900", base0B = "#859900",
    base0C = "#2aa198", base0D = "#268bd2", base0E = "#6c71c4",
    base0F = "#d33682",
    -- author: Ethan Schoonover
    -- light · sepia/warm · medium contrast
  },
}

-- ---------------------------------------------------------------- public api
function M.get_palette(name)
  return themes[name]
end

function M.list()
  local names = {}
  for k, _ in pairs(themes) do
    table.insert(names, k)
  end
  table.sort(names)
  return names
end

function M.apply(name)
  local palette = themes[name]
  if not palette then
    vim.notify("ninja: theme '" .. name .. "' not found", vim.log.levels.ERROR)
    return
  end
  require("mini.base16").setup({ palette = palette })
  vim.g.colors_name = name
  vim.notify("Theme: " .. name)
end

-- -------------------------------------------------------------------- setup
function M.setup()
  -- :Theme <name> — switch with tab completion.
  vim.api.nvim_create_user_command("Theme", function(opts)
    M.apply(opts.args)
  end, {
    nargs = 1,
    complete = function() return M.list() end,
    desc = "Switch jac ninja base16 theme",
  })

  -- <Leader>t — pick a theme from a fuzzy list.
  vim.keymap.set("n", "<Leader>t", function()
    require("mini.pick").start({
      source = {
        items = M.list(),
        choose = function(choice)
          if choice then M.apply(choice) end
        end,
      },
    })
  end, { desc = "Theme: pick" })
end

return M
