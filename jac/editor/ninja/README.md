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

## Layout of this directory

- `init.lua` -- the entire editor configuration (core nvim + mini.nvim only).
- `queries/python/` -- vendored nvim-treesitter python queries (Apache-2.0)
  so injected `::py::` blocks highlight; jac's own queries are staged at
  build time from the pinned tree-sitter-jac dependency.

At build time (`jac/build.zig`) this directory is composed with the neovim
runtime export and mini.nvim into the payload's `nvim/` tree; a release
binary reads nothing from the source tree at runtime.

## Dev loop

The editor config dev-links exactly like the compiler, through both of the
existing mechanisms:

- **Linked-source builds** (`zig build -Ddev` / `-Djaclang-dir`) bake a
  `nvim/ninja_linked_source` marker into the payload (the ninja analog of
  `site/jac_linked_source`); the launcher resolves it at boot.
- **`jac.toml [dev] jaclang_source`**: on a binary without the baked marker
  (e.g. a release binary run inside a source checkout), init.lua walks up
  from the cwd for a `jac.toml` dev stanza and chain-loads
  `<source>/editor/ninja/init.lua`, mirroring `_jac_finder`'s compiler
  override. The baked marker takes precedence, matching the compiler.

Either way the payload's copy stays on the runtimepath behind the source dir
for the build-staged pieces (mini.nvim, the jac queries), and
`JAC_NO_DEV_SOURCE=1` forces dev sourcing off, exactly as it does for the
compiler. So the loop for editor tweaks is just: edit `init.lua` or
`lua/ninja/*.lua`, relaunch `jac ninja` -- **no zig rebuild**. A rebuild is
only needed when the neovim fork, the parsers, or the pinned deps change.
