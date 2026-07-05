# jac ninja -- the fused jac editor

`jac ninja [file ...]` opens the editor that is **built into the jac binary**:
the hard-forked Neovim (jaseci-labs/neovim, branch `jac`, hash-pinned in
`jac/build.zig.zon`) is statically linked into the launcher stub, so the
editor boots in milliseconds without starting Python. Python starts only when
the editor spawns `jac lsp` -- the same binary -- as its language server.
Editor, parser, and LSP are one file on disk.

## How it boots

```
jac ninja …
  └─ launcher (Zig): materialize payload → set VIMRUNTIME/JAC_NINJA_DIR/JAC_BIN
     └─ nvim_main("nvim", "-u", <payload>/nvim/ninja/init.lua, …)   [TUI client]
        └─ re-exec of this binary with argv[0]="nvim" --embed        [server]
           └─ init.lua: treesitter jac + LSP({JAC_BIN, "lsp"}) + mini.nvim
```

Hermetic by construction: `-u` bypasses user configs and `NVIM_APPNAME=jac-ninja`
isolates all state under `~/.local/{share,state}/jac-ninja`. A user's own
Neovim setup is never read and can never break the jac experience.

## What's in the box

- **Syntax**: the tree-sitter jac grammar (jaseci-labs/tree-sitter-jac,
  pinned) compiled in, with highlights/folds/textobjects from the grammar
  repo's queries; python parser bundled for inline `::py::` blocks.
- **LSP**: completion, hover, go-to-definition, references, rename,
  code actions, diagnostics -- served by `jac lsp` from the same binary.
- **UX**: mini.nvim (pinned) -- fuzzy pick, live grep, file explorer,
  statusline, autopairs, surround, treesitter textobjects, clue hints.
- **Agent**: `jac ai` -- the binary's own coding agent -- orchestrated in
  managed splits (`lua/ninja/agent.lua`): named sessions, ask/explain/fix
  actions that send path + line-range + diagnostics references into the live
  session (the agent reads code with its own file tools; nothing is pasted).

## Keymaps (leader = space)

| keys | action |
|---|---|
| `space f f / f g / f b / f h` | find files / live grep / buffers / help |
| `space e` or `-` | file explorer (at file / at cwd) |
| `g d`, `g r r`, `g r n`, `g r a`, `K` | definition, references, rename, code action, hover |
| `space l f / l s / l w` | format, document symbols, workspace symbols |
| `space j r / j t / j c` | jac run / test / check the current file |
| `space d`, `[d` / `]d` | line diagnostics, prev/next diagnostic |
| `space a a` | toggle the coding agent (`jac ai` -- the same binary) |
| `space a q / a f / a d` | ask agent / ask about this file / fix diagnostics |
| `space a s / a e` (visual) | ask about / explain the selected lines |
| `space a n / a l / a m / a x` | new named session / pick session / set model / toggle `--safe` |

`JAC_NINJA_ASCII=1` switches icons/signs to plain ASCII for glyph-less
terminals.

## Easy mode (for people who don't speak vim)

`jac ninja --easy` (or `:NinjaEasy on`) enables a VSCode-style input layer,
and the choice persists across sessions (`--no-easy` / `:NinjaEasy off` to
leave). Modal vim stays underneath -- Esc still works and the clue hints keep
teaching -- but the CUA muscle memory just works:

| keys | action |
|---|---|
| `ctrl+s / ctrl+z / ctrl+y` | save / undo / redo (any mode) |
| `ctrl+c / ctrl+x / ctrl+v / ctrl+a` | system-clipboard copy / cut / paste, select all |
| `shift+arrows` | select text; typing replaces the selection |
| `ctrl+p`, `ctrl+shift+p` or `F1` | go to file, command palette |
| `ctrl+f / ctrl+h` | find / replace in file |
| `ctrl+/`, `alt+up/down` | toggle comment, move line or selection |
| `F2 / F12` | rename symbol / go to definition |
| `` ctrl+` `` or `ctrl+j` | toggle the bottom terminal panel (persistent shell) |
| `ctrl+\` | split the editor |
| `ctrl+w`, `ctrl+pgup/pgdn`, `ctrl+q` | close file, switch file, quit |

File buffers open in insert mode, ready to type. Tradeoff: `ctrl+v` shadows
visual-block mode while easy mode is on.

## Layout of this directory

- `init.lua` -- the entire editor configuration (core nvim + mini.nvim only).
- `queries/python/` -- vendored nvim-treesitter python queries (Apache-2.0)
  so injected `::py::` blocks highlight; jac's own queries are staged at
  build time from the pinned tree-sitter-jac dependency.

At build time (`jac/build.zig`) this directory is composed with the neovim
runtime export and mini.nvim into the payload's `nvim/` tree; nothing here is
read from the source tree at runtime.
