# `jac ai --tui` Renderer Backends

The TUI control plane is backend-agnostic. Which renderer sidecar it spawns is
chosen at launch by environment, and the choice is the only thing that varies -
every backend speaks the same wire protocol (`PROTOCOL.md`).

Selection and spawning live in
`jac_super/ai_agent/impl/run_tui_session.impl.jac`:

- `_resolve_tui_backend() -> str` - reads `JAC_AI_TUI_BACKEND`, trims +
  lowercases it, defaults to `js`.
- `_resolve_tui_command(backend, pkg_root, initial) -> {ok, cmd_args, error, hint}`
  - maps a backend name to a spawn command and validates that the backend is
  actually present on disk.
- `_spawn_tui_backend(cmd_args) -> Popen` - spawns with line-buffered text pipes.

## Selecting a backend

```
JAC_AI_TUI_BACKEND=js    # OpenTUI renderer authored in Jac (default)
JAC_AI_TUI_BACKEND=na    # native nacompile'd OpenTUI renderer (fallback)
```

Unset/empty → `js`. An unknown value is rejected with a clear error rather than
silently falling back.

**Implicit fallback to `na`.** When the env is unset (js is the implicit default)
but js isn't launchable - `bun` is missing or `ai_tui_js/dist/` hasn't been built

- the launcher prints a one-line notice and transparently retries `na`, so the
cutover never hard-breaks an environment that hasn't built the js sidecar. This
fallback applies **only** to the implicit default: if you set
`JAC_AI_TUI_BACKEND=js` explicitly, a launch failure is surfaced as-is (with its
build hint) instead of being papered over - set it explicitly when you want to
see why js won't start.

## Backends

### `js` - OpenTUI renderer authored in Jac (default)

- Sources: `jac_super/ai_tui_js/*.cl.jac` (`main`, `state`, `protocol`, `input`,
  `render`), compiled to JS via `ai_tui_js/build.py` (`EsastGenPass` + `es_to_js`,
  the programmatic ecmascript path - not Vite). Drives `@opentui/core`
  imperatively; no Solid/React.
- Entry: `jac_super/ai_tui_js/dist/main.js` (built artifact).
- **Prerequisite: `bun`** must be on `PATH` (the default runtime). Build the
  sidecar once with `cd jac_super/ai_tui_js && bun install && python build.py`.
- Runtime: `bun` by default; override with `JAC_AI_TUI_JS_RUNTIME` (e.g. `node`).
  Spawned as `<runtime> run <entry> [seed-prompt]`.
- Until built (or if `bun` is absent), the implicit default falls back to `na`;
  an explicit `JAC_AI_TUI_BACKEND=js` instead fails with a build hint.
- Renders to `/dev/tty` (passed as explicit `stdin`/`stdout` streams to
  `createCliRenderer`) so the process stdin/stdout stay the protocol pipes.
- Logic (`state`/`protocol`/`input`) is I/O-free and unit-tested for parity
  against the NA semantics (`bun test ./dist/`); the real spawn + frame/command
  round-trip is covered by `ai_tui_js/smoke_bridge.py`.

### `na` - native renderer (fallback)

- Binary: `jac_super/ai_tui_na/bin/jac-na-tui`
- Built with `jac_super/ai_tui_na/build.sh` (nacompile + OpenTUI shim).
- If the binary is missing, launch fails with a build hint; it is not
  auto-built.
- Sources: `state.na.jac`, `feed.na.jac`, `render.na.jac`, `input.na.jac`,
  `ipc.na.jac`, `tui.na.jac`.
- Retained as the rollback target while the js backend matures; select it with
  `JAC_AI_TUI_BACKEND=na`.

## Environment passed to every backend

Set by the control plane before spawn (see `PROTOCOL.md` → Startup):

| Variable            | Meaning                                   |
| ------------------- | ----------------------------------------- |
| `JAC_AI_UI_PROJECT` | Normalized working directory              |
| `JAC_AI_UI_MODEL`   | Model name override (may be empty)        |
| `JAC_AI_UI_NCTX`    | Context window override as int (`0`=unset)|

Debugging: set `JAC_AI_TUI_DEBUG_LOG=<path>` to append a frame/command trace
from the control plane.

## Adding a new backend

1. Implement a sidecar that speaks `PROTOCOL.md` (read frames on stdin, write
   commands on stdout, render to its own terminal surface).
2. Add a branch to `_resolve_tui_command()` returning its `cmd_args` and a
   present/absent check with a helpful `hint`.
3. Cover the new branch in `jac-super/tests/test_ai_tui_bridge.jac`.
4. Document it here.
