# `jac ai --tui` Renderer Backend

See `ARCHITECTURE.md` for the process model, module stack, and data flow.

The TUI control plane drives a single native renderer that speaks the wire
protocol in `PROTOCOL.md`, over one of two transports.

## Transport selection (`JAC_AI_TUI_BACKEND`)

`jaclang/jac0core/impl/runtime.impl.jac` (`JacCmd.run_ai_agent`) selects a
backend when `req.tui` is set, based on the `JAC_AI_TUI_BACKEND` env var:

| Value | Backend | Driver |
| ----- | ------- | ------ |
| unset / `inprocess` (`in-process`, `in_process`) (default) | `dlopen` `bin/libtui.so` via ctypes | `run_tui_in_process.impl.jac` |
| `subprocess` | spawn `bin/jac-na-tui` over pipes | `run_tui_session.impl.jac` |

The default is the in-process shared library; `JAC_AI_TUI_BACKEND=subprocess`
opts into the crash-isolated sidecar fallback. Both share `_frame_blob` /
`_dispatch_cmd` / `_list_project_files` / `_require_tty` from
`jaclang/cli/ai_tui/tui_shared.jac`, so they can never drift on the protocol.

## Backend: subprocess sidecar (fallback)

Selection and spawning live in
`jaclang/cli/ai_tui/impl/run_tui_session.impl.jac`:

- `_resolve_tui_command(pkg_root, initial) -> {ok, cmd_args, error, hint}` -
  validates that the NA binary is present and returns its spawn command.
- `_spawn_tui_backend(cmd_args) -> Popen` - spawns with line-buffered text pipes.

## Backend: `na` (native)

- Binary: `jaclang/cli/ai_tui_na/bin/jac-na-tui`
- Built with `jaclang/cli/ai_tui_na/build.sh` (`jac nacompile`).
- If the binary is missing but NA sources are present (dev checkout),
  `run_tui_session` runs `build.sh --quick` once before spawn. Installed
  packages without sources still need a prebuilt binary or a manual build.
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

## Backend: in-process shared library (default)

- Library: `jaclang/cli/ai_tui_na/bin/libtui.so`
- Built by the same `build.sh` (`jac nacompile host.na.jac --shared -o
  bin/libtui.so`). If missing on a dev checkout, `run_tui_in_process` builds it
  once via `build.sh --quick` (`_ensure_tui_lib`); `JAC_AI_TUI_REBUILD=1` forces
  a recompile. Installed packages ship a prebuilt `.so` (no LLVM at runtime).
- Bound by `jaclang/cli/ai_tui/tui_host.jac` (`TuiHost`): `ctypes.CDLL` +
  `restype`/`argtypes` for the eight seam exports (`tui_init`, `tui_apply_frame`,
  `tui_wait_key`, `tui_handle_key`, `tui_next_command`, `tui_quit_requested`,
  `tui_render`, `tui_shutdown`). The wrapper for `tui_init` is named `start`
  because Jac reserves `def init` as the obj constructor.
- Renders to the controlling tty the native side opens itself (`tui_init`'s
  `tty_dev`); the driver redirects the agent's real stdout/stderr to `/dev/null`
  for the session so stray output can't corrupt the alt-screen.
- **Platform:** Linux (and WSL) only today, same as the sidecar.

## Adding a new backend

1. Implement a sidecar that speaks `PROTOCOL.md` (read frames on stdin, write
   commands on stdout, render to its own terminal surface).
2. Add a branch to `_resolve_tui_command()` returning its `cmd_args` and a
   present/absent check with a helpful `hint`.
3. Cover the new branch in `jac/tests/cli/test_ai_tui_bridge.jac`.
4. Document it here.
