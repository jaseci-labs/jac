# jac editor (ninja) -- provenance & pins

The `jac ninja` editor is assembled from hash-pinned external trees plus the
first-party config layer in `jac/editor/ninja/`. Nothing editor-related is
vendored into this repo; every input is pinned in a `build.zig.zon`.

| input | repo | pin | consumed by |
|---|---|---|---|
| neovim (hard fork) | https://github.com/jaseci-labs/neovim (branch `jac`) | `f40bca00a` (forked from upstream `29db6ce84`, 2026-07-04) | `jac/build.zig.zon` -- built as a static library (`-Dlib`, upstream's `MAKE_LIB`) and linked into the launcher stub |
| tree-sitter-jac | https://github.com/jaseci-labs/tree-sitter-jac | `825e595d` | the neovim fork (compiles the parser in) + `jac/build.zig.zon` (queries/ftplugin/ftdetect into the ninja layer) |
| mini.nvim | https://github.com/nvim-mini/mini.nvim | v0.18.0 (`c5cdbade`) | `jac/build.zig.zon` -- staged into the payload's ninja layer |
| tree-sitter-python | https://github.com/tree-sitter/tree-sitter-python | v0.25.0 (`26855eab`) | the neovim fork -- bundled parser for jac's inline `::py::` injections |
| python queries | nvim-treesitter `main` (Apache-2.0) | snapshot 2026-07-04 | vendored at `jac/editor/ninja/queries/python/` |

The neovim fork is a **hard fork**, not a tracked upstream: it is maintained
on the `jac` branch of jaseci-labs/neovim, where non-jac infrastructure will
be culled over time and the editor migrated toward jac native. Upstream sync
is a deliberate cherry-pick event against the recorded fork point (the fork
keeps full upstream history, so `git cherry-pick` works directly).

The launcher dispatches `jac ninja` (and any `argv[0] == "nvim"` re-invocation
-- nvim's TUI re-execs its own binary as the `--embed` server) to the linked
`nvim_main()` before the Python runtime ever boots. The nvim runtime files,
tree-sitter parsers, and the ninja config layer ride in the jac payload under
`nvim/` (see `jac/launcher/README.md`).
