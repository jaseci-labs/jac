# `jac ai --tui` Renderer Backend

The TUI control plane spawns a single native renderer sidecar that speaks the
wire protocol in `PROTOCOL.md`.

Selection and spawning live in
`jac_super/ai_agent/impl/run_tui_session.impl.jac`:

- `_resolve_tui_command(pkg_root, initial) -> {ok, cmd_args, error, hint}` -
  validates that the NA binary is present and returns its spawn command.
- `_spawn_tui_backend(cmd_args) -> Popen` - spawns with line-buffered text pipes.

## Backend: `na` (native)

- Binary: `jac_super/ai_tui_na/bin/jac-na-tui`
- Built with `jac_super/ai_tui_na/build.sh` (`jac nacompile`).
- If the binary is missing, launch fails with a build hint; it is not
  auto-built.
- Sources: `state.na.jac`, `feed.na.jac`, `screen.na.jac`, `input.na.jac`,
  `ipc.na.jac`, `tui.na.jac`, and related modules under `ai_tui_na/`.
- Renders to `/dev/tty` (stdio remapped via `libc_tty.na.jac`) so process
  stdin/stdout stay the protocol pipes.
- **Platform:** Linux (and WSL) only today. macOS and Windows port plans are in
  `PORTING.md`.

## Environment passed to the sidecar

Set by the control plane before spawn (see `PROTOCOL.md` → Startup):

| Variable                  | Meaning                                   |
| ------------------------- | ----------------------------------------- |
| `JAC_AI_TUI_TTY`          | Parent terminal device path (e.g. `/dev/pts/5`); sidecar opens this for keyboard input after `setsid` |
| `JAC_AI_UI_PROJECT`       | Normalized working directory              |
| `JAC_AI_UI_MODEL`         | Model name override (may be empty)        |
| `JAC_AI_UI_NCTX`          | Context window override as int (`0`=unset)|
| `JAC_AI_UI_FILES`         | Newline-separated project file paths      |
| `JAC_AI_UI_MODEL_PRESETS` | Newline-separated quick-pick model names    |

Debugging: set `JAC_AI_TUI_DEBUG_LOG=<path>` to append a frame/command trace
from the control plane.

## Adding a new backend

1. Implement a sidecar that speaks `PROTOCOL.md` (read frames on stdin, write
   commands on stdout, render to its own terminal surface).
2. Add a branch to `_resolve_tui_command()` returning its `cmd_args` and a
   present/absent check with a helpful `hint`.
3. Cover the new branch in `jac-super/tests/test_ai_tui_bridge.jac`.
4. Document it here.
