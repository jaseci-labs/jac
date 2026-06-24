# `jac ai --tui` - Cross-Platform Porting

The native (`na`) TUI sidecar runs on **Linux, macOS, and Windows**. The
architecture is designed for portability: only the **terminal I/O layer** and
**control-plane spawn** are OS-specific. Everything above that seam is shared
Jac NA code.

Related docs:

- `PROTOCOL.md` - wire contract (platform-neutral)
- `BACKENDS.md` - spawn, binaries, env vars
- `../ai_tui_na/libc_tty.na.jac` - current Linux terminal backend

## Current platform support

| Environment              | Status | Notes                                      |
| ------------------------ | ------ | ------------------------------------------ |
| Linux (native terminal)  | **Yes** | `libc_tty.linux.na.jac` + glibc FFI       |
| WSL                      | **Yes** | Build and run inside WSL (Linux userspace) |
| macOS                    | **Yes** | `libc_tty.darwin.na.jac`; Phase 5 sign-off pending |
| Windows (native)         | **Yes** | `console.win32.na.jac`; in-process default; Phase 5 sign-off pending |

## Architecture (unchanged across platforms)

```
┌─────────────────────────────────────────────────────────┐
│  Control plane (Python/Jac)                             │
│  run_tui_session.impl.jac                               │
│    ui_stream() → frames on sidecar stdin                │
│    reads commands from sidecar stdout (saved IPC fd)    │
└───────────────────────┬─────────────────────────────────┘
                        │ PROTOCOL.md (frozen)
┌───────────────────────▼─────────────────────────────────┐
│  Sidecar (jac-na-tui) - shared on all platforms         │
│                                                         │
│  ipc / state / feed / screen / components / diff / input│
│  terminal.na.jac (ANSI escape helpers)                  │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Platform terminal backend (swap per OS)        │    │
│  │  Linux:   libc_tty.linux.na.jac  (shipped)       │    │
│  │  macOS:   libc_tty.darwin.na.jac  (shipped)     │    │
│  │  Windows: console.win32.na.jac    (shipped)     │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

The Linux sidecar uses a **stdio remap** so protocol pipes and the user's
terminal stay separate:

1. `stdout` is a **pipe** to the control plane → saved as **IPC fd** (fd 3).
2. `stderr` is inherited from the parent (the real terminal) → dup'd onto
   **fd 1** for ANSI rendering.
3. Keyboard input comes from a **separate TTY open** on the device path passed
   via `JAC_AI_TUI_TTY` (because `start_new_session=True` drops the controlling
   tty and `/dev/tty` no longer works).

Windows should mirror this pattern with console **handles** instead of POSIX fds.

### In-process transport removes the spawn-side port

The subprocess design has **two** OS-specific surfaces: the terminal I/O backend
*and* the spawn/session plumbing (`start_new_session`/`setsid`, `JAC_AI_TUI_TTY`,
the `dup2` stdio remap, the fd-3 IPC workaround, ConPTY/handle-passing on
Windows). The default in-process transport (`run_tui_in_process.impl.jac`;
`JAC_AI_TUI_BACKEND=subprocess` for the sidecar fallback) **deletes the second
surface entirely** - there is
no child to spawn, no IPC pipe, and no stdio remap; the renderer is loaded as
`libtui.so` and opens the tty directly. The macOS "Control plane (minor)" delta
and the Windows "Stdio remap" / ConPTY v1–v2 sections below then stop applying.

What does **not** get easier: the terminal-I/O backend (Darwin `termios`,
Windows Console API / `console.win32.na.jac`, key-sequence translation, CJK
width) - the plan never forks below the transport seam. The distribution shape
also flips: in-process ships a `dlopen`'d shared library per platform
(`libtui.so` / `libtui.dylib` / `tui.dll`) instead of a spawned executable, which
adds its own per-OS hazards (macOS `.dylib` code-signing, the Windows DLL search
path - `_ensure_tui_lib` already resolves an absolute path before `CDLL`). So if
cross-platform is near-term, sequencing the in-process swap **before** the
macOS/Windows ports means porting one surface instead of two. See
`../../../PLAN-tui-in-process.md` §16.

## Terminal backend API

`tui.na.jac` imports these symbols from the platform module. All three backends
must implement the same surface:

| Function | Role |
| -------- | ---- |
| `tty_open` / `tty_close` | Attach to the real terminal; enter/restore raw mode |
| `tty_init_stdio_remap` / `tty_restore_stdio` / `tty_ipc_fd` | Keep IPC pipe separate from display output |
| `tty_poll` / `tty_stdin_ready` / `tty_key_ready` | Multiplex IPC stdin and keyboard |
| `tty_read_key` | Read bytes; return escape sequences as strings (`"\x1b[A"`, etc.) |
| `tty_read_line` | Line-oriented read from IPC stdin (fd 0) |
| `tty_write` | Write bytes to a fd/handle |
| `tty_update_size` / `tty_rows` / `tty_cols` | Terminal dimensions |

`input.na.jac`, `screen.na.jac`, and the diff renderer depend only on this API
plus `terminal.na.jac` (pure ANSI strings).

## Recommended source layout

```
jaclang/cli/ai_tui_na/
  tty/
    libc_tty.linux.na.jac    # promote current libc_tty.na.jac
    libc_tty.darwin.na.jac   # macOS
    console.win32.na.jac     # Windows
  tui.na.jac                 # imports platform tty module
  terminal.na.jac            # unchanged (ANSI helpers)
  state.na.jac / feed.na.jac / screen.na.jac / …  # unchanged
```

The compiler resolves `import from "libSystem.dylib"` / `kernel32.dll` per
target triple (`nacompile --target …`). See
`jaclang/compiler/passes/native/na_ir_gen_pass.impl/core.impl.jac`
(`_resolve_clib_lib_name`).

## Binary layout and resolution

Ship one binary per platform (and optionally per arch):

```
ai_tui_na/bin/
  jac-na-tui              # Linux (ELF)
  jac-na-tui-darwin       # macOS (Mach-O), or a universal binary
  jac-na-tui.exe          # Windows (PE)
```

`_resolve_tui_command()` in `run_tui_session.impl.jac` selects the binary from
`sys.platform` and returns a build hint when the expected artifact is missing.

`build.sh` should accept a target (or detect the host) and invoke
`jac nacompile tui.na.jac -o <out> --target <triple>`.

## macOS port

macOS is the natural second target. Same sidecar model, same `/dev/tty` paths,
same `os.ttyname()` in the control plane.

### Terminal backend (`libc_tty.darwin.na.jac`)

| Linux today (`libc_tty.na.jac`) | macOS change |
| ------------------------------- | ------------ |
| `import from "/usr/lib/libc.so.6"` | `import from "libSystem.dylib"` |
| `TERMIOS_SZ = 60` (glibc layout) | Re-derive - Darwin `termios` is larger with a different `c_cc` layout |
| `TIOCGWINSZ = 0x5413` | Same on Darwin |
| `poll()` | Available; keep or switch to `kqueue` later |
| `/dev/tty`, `/dev/pts/N` | Same device namespace |
| Raw-mode flag masks | Mostly POSIX; verify `IEXTEN`, `VMIN`/`VTIME` offsets |

Main risk: **termios struct size and field offsets**. The Linux backend avoids
passing structs by value and uses calloc'd byte buffers - keep that pattern on
Darwin but with the correct size and offsets for macOS.

### Control plane (minor)

- `_sidecar_tty_device()` - already uses `os.ttyname()`; works on macOS.
- `_spawn_tui_backend()` - `start_new_session=True` (setsid) works on macOS.
- Keep passing `JAC_AI_TUI_TTY` (e.g. `/dev/ttys003` or `/dev/pts/N`).

### Keyboard follow-ups (phase 2)

Optional, per `PLAN.md`:

- Option/Alt modifier sequences
- Terminal-specific fn-key CSI variants

Extend `tty_read_key` on Darwin; `input.na.jac` stays unchanged.

### macOS validation

- Re-run libc smoke tests under a real terminal (Terminal.app, iTerm2, Warp).
- `proto/no_c_*.na.jac` scenarios adapted for Darwin termios size.
- CI: `macos-latest` build + pseudo-tty smoke (`script` or equivalent).

### Rough effort

~1–2 weeks with Mac hardware for interactive testing.

## Windows port

Windows has no `/dev/tty`, `termios`, or `os.ttyname()`. The **protocol and UI
layers are unchanged**; the terminal backend is a **Console API** (or ConPTY)
module, not a libc tty tweak.

### Stdio remap on Windows

Mirror the Linux fd layout with handles:

| Linux | Windows equivalent |
| ----- | ------------------ |
| `stdout` = pipe → save as IPC fd 3 | `stdout` = pipe → save `WRITE` handle for IPC |
| `stderr` = terminal → dup to fd 1 for render | `stderr` = console → use for ANSI output |
| `tty_open(JAC_AI_TUI_TTY)` for keyboard | `ReadConsoleInput` / ConPTY read end |

Enable VT mode for ANSI (`ENABLE_VIRTUAL_TERMINAL_PROCESSING`). Document
requirement: **Windows Terminal** or a VT-aware console (standard for a modern
CLI).

### Terminal backend (`console.win32.na.jac`)

FFI against system DLLs (Jac NA resolves `.dll` per target triple):

| API | Purpose |
| --- | ------- |
| `GetStdHandle` / `SetStdHandle` | Stdio remap |
| `GetConsoleMode` / `SetConsoleMode` | Raw input, VT output |
| `ReadConsoleInput` or `ReadFile` on ConPTY | Keys → escape strings for `input.na.jac` |
| `WriteFile` | ANSI render |
| `GetConsoleScreenBufferInfo` | Rows/cols |
| `WaitForMultipleObjects` (or Win32 `poll`) | Multiplex IPC pipe + keyboard |

**v1 - parent console (simpler):** sidecar attaches to the parent's console
(`ATTACH_PARENT_PROCESS`). User runs `jac ai --tui` from Windows Terminal,
PowerShell, or cmd. No `/dev` paths.

**v2 - ConPTY (more robust):** control plane creates a pseudo-console and
passes inherited pipe handles to the sidecar. Closer to Linux session
isolation; more spawn plumbing.

### Control plane (required changes)

| Linux | Windows |
| ----- | ------- |
| `os.ttyname()` → `JAC_AI_TUI_TTY` | No `ttyname` - pass `JAC_AI_TUI_USE_PARENT_CONSOLE=1`, inherited handle integers, or ConPTY pipe handles via env |
| `start_new_session=True` | `CREATE_NEW_PROCESS_GROUP` or ConPTY; **do not** detach from console when using parent-console v1 |
| `bin/jac-na-tui` | `bin/jac-na-tui.exe` |

Add a Windows branch to `_sidecar_tty_device()` that does not call `ttyname`.

### Windows-specific gotchas

- **ANSI** - require VT mode; fail with a clear message on legacy conhost without VT.
- **Width** - console Unicode width may differ from Linux `width.na.jac` assumptions; test CJK.
- **Key translation** - `INPUT_RECORD` → same string format as Linux `tty_read_key` (`"\x1b"`, arrows, etc.) so `input.na.jac` needs no fork.
- **Artifacts** - ship x64 (and optionally ARM64) `.exe` per release.

### Rough effort

~3–6 weeks for v1 in Windows Terminal; ConPTY adds time but improves long-term
isolation.

## Control-plane env vars (platform-related)

| Variable | Linux / macOS | Windows |
| -------- | ------------- | ------- |
| `JAC_AI_TUI_TTY` | Device path from `os.ttyname()` (e.g. `/dev/pts/5`) | `""` (empty sentinel; `tty_open_dev` attaches parent console) |
| `JAC_AI_UI_*` | Unchanged | Unchanged |

All `JAC_AI_UI_*` startup vars in `PROTOCOL.md` stay the same on every OS.

## Testing strategy

| Layer | Linux | macOS | Windows |
| ----- | ----- | ----- | ------- |
| Protocol / bridge (subprocess) | `test_ai_tui_bridge.jac` | Same | Same |
| In-process host (ctypes) | `test_host.py` | Same | Same (`tui.dll`) |
| TTY / console smoke | `proto/no_c_*.na.jac` | `test_tty_darwin.py` (PTY harness) | `test_console_win32.py` (constant probe + VT gate) |
| Headless UI | `test_pickers.na.jac` | Same | Same |
| CI | `blacksmith-4vcpu-ubuntu-2404` | cross-compile + `macos-latest` | cross-compile (PE/COFF assert) + `windows-latest` |
| Integration | `jac ai --tui` under real TTY | Phase 5 sign-off pending | Phase 5 sign-off pending |

## Implementation order

1. **macOS** - POSIX variant of `libc_tty`; smallest diff from Linux.
2. **Windows** - new `console.win32.na.jac` + spawn/handle plumbing.
3. **CI matrix** - build artifacts per OS; publish alongside the jaclang core wheel.

## What not to port per platform

Keep platform-neutral (do not fork):

- `PROTOCOL.md` frame/command format
- `state`, `feed`, `screen`, `components`, `diff`, `input`, `ipc`
- `terminal.na.jac` ANSI sequences (VT-capable terminals on all targets)
- Control-plane file list / model presets (`JAC_AI_UI_FILES`, etc.)

Only fork when the OS API forces it: termios vs Console API, device paths vs
handles, and spawn/session flags.
