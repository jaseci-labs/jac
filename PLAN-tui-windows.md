# Windows Port - `jac ai --tui` native backend

Status: **v1 implemented** (parent-console, in-process default). Phases 0–3
landed; Phase 4 CI and Phase 5 human sign-off remain open. Branches off the
in-process default (`PLAN-tui-in-process.md`); reuses macOS `tty/` staging
(`PLAN-tui-macos.md`).

> **v1 ships parent-console mode only.** User runs `jac ai --tui` from
> Windows Terminal, PowerShell, or a VT-enabled cmd. No ConPTY pseudo-console.
> The in-process default (`ctypes` → `tui.dll`) is the supported path;
> subprocess (`jac-na-tui.exe`) compiles and spawns but IPC stdio-remap stubs
> in `console.win32.na.jac` are not wired - treat subprocess on Windows as
> **experimental** until Phase 6.

Related:

- `jac-super/jac_super/ai_tui/PORTING.md` - platform-support matrix and
  high-level per-OS notes (this plan is the concrete Windows breakdown).
- `PLAN-tui-macos.md` - the POSIX cousin port; reuse its `tty/` staging
  pattern and `_tui_lib_path` branching, but **do not** copy its termios work.
- `PLAN-tui-in-process.md` §16 - Windows DLL search-path footgun (absolute
  path before `CDLL`; already handled in `tui_host.jac`).
- `reference/pi` (`packages/tui/src/terminal.ts`) - `ENABLE_VIRTUAL_TERMINAL_INPUT`
  on Windows; pi externalizes `koffi` rather than bundling 74 MB of `.node`
  files - we use Jac NA FFI against `kernel32.dll` directly instead.

## TL;DR

The Windows port is a **new terminal backend**, not a constant-table tweak.
macOS is a one-module swap (`termios` flags + struct size on POSIX). Windows
has no `/dev/tty`, no `termios`, no `poll(2)`, and no `os.ttyname()`. The
entire Linux-specific surface in `libc_tty.*.na.jac` must be replaced by
`tty/console.win32.na.jac` - Console API FFI, handle-based I/O, and
`ReadConsoleInput` → escape-sequence translation so `input.na.jac` stays
unchanged.

Everything above the tty seam (`width`, `tui_core`, `state`, `feed`,
`screen`, `components`, `diff`, `input`, `ipc`, `terminal`, `host.na.jac`
`:pub` exports) is shared. The default **in-process** backend does not need
Linux-style fd-3 IPC remap for the happy path.

**Still open:** `windows-latest` CI job, `PORTING.md` status table update,
Phase 5 interactive sign-off (`SIGNOFF-win32.md`). ConPTY + full subprocess
IPC remain follow-up work.

## Delivered (v1 - 2026-06-18)

| Area | Artifact | Notes |
| ---- | -------- | ----- |
| Win32 tty backend | `ai_tui_na/tty/console.win32.na.jac` | `kernel32` + `msvcrt` FFI; parent-console attach; `ReadConsoleInputW` → escape strings |
| Native build | `ai_tui_na/build.ps1` | Stages win32 module; `tui.dll` + `jac-na-tui.exe`; runs host + console gates |
| Cross-compile | `ai_tui_na/build.sh` | `JAC_AI_TUI_TARGET=win32`, MSYS/MINGW host; skips run-on-Linux tests |
| Lib path | `tui_host.jac` | `tui.dll` on `sys.platform == "win32"` |
| TTY resolution | `tui_shared.jac` `_sidecar_tty_device` | Returns `""` sentinel; `isatty()` gate in drivers |
| Auto-build | `tui_shared.jac` `_ensure_na_artifact` | `powershell -File build.ps1 -Quick` on win32 |
| In-process driver | `run_tui_in_process.impl.jac` | win32 `isatty()` check; `nul` redirect |
| Subprocess driver | `run_tui_session.impl.jac` | `jac-na-tui.exe`; `CREATE_NEW_PROCESS_GROUP` spawn |
| Compiler | `nacompile.impl.jac` | Default `--target windows` when `sys.platform == "win32"` |
| Tests | `test_console_win32.py`, `test_host.py` | Constant probe + VT gate; platform lib name |

### Implementation notes (differs from early plan draft)

- **`ENABLE_VIRTUAL_TERMINAL_INPUT` is not set** for the `ReadConsoleInputW`
  path - VT input mode affects `ReadFile(stdin)`, not low-level console
  input records. Shift+Tab is handled via `VK_TAB` + `SHIFT_PRESSED` →
  `\x1b[Z` in `tty_read_key`, not via VT input mode.
- **`ENABLE_PROCESSED_INPUT` is cleared** so Ctrl+C arrives as
  `UnicodeChar=0x03` (mirrors Linux raw mode clearing `ISIG`).
- **Subprocess IPC exports exist but stub** (`tty_init_stdio_remap` → `-1`,
  `tty_read_line` → `""`) - enough to link `tui.na.jac`; not enough to run
  the sidecar backend end-to-end on Windows.

## macOS vs Windows - scope comparison

| Area | macOS (`PLAN-tui-macos.md`) | Windows (this plan) |
| ---- | --------------------------- | ------------------- |
| TTY module | `libc_tty.darwin.na.jac` - copy Linux, fix flags | **New** `console.win32.na.jac` |
| Shared UI | `state`, `feed`, `screen`, `input`, `diff`, `host` | **Unchanged** |
| Control plane | `_sidecar_tty_device()` via `os.ttyname()` | **Must branch** - no `ttyname` |
| In-process init | `tui_init(..., "/dev/pts/N")` | `tui_init(..., "")` → parent console |
| Subprocess fallback | Minor spawn tweaks | `jac-na-tui.exe`; no console detach in v1 |
| Build | `build.sh` → `libtui.dylib` | **`build.ps1`** → `tui.dll` / `.exe` |
| Compiler | `nacompile --target darwin` | `nacompile --target windows` (PE/COFF) |

Windows is **3–4× the macOS tty work**, not a flag-table diff.

## The real crux is key translation, not ANSI output

Everyone (including `PORTING.md`) lists "enable VT mode" first. That part is
well-trodden (`ENABLE_VIRTUAL_TERMINAL_PROCESSING` on the output handle;
`ENABLE_VIRTUAL_TERMINAL_INPUT` on the input handle - pi documents why the
latter matters for Shift+Tab). The dangerous work is **`tty_read_key`**: Linux
reads a byte stream from a raw tty fd; Windows delivers **`INPUT_RECORD`**
structs from `ReadConsoleInputW`. Every arrow key, function key, modifier
combo, and Unicode code point must be translated into the **same escape
strings** `input.na.jac` already expects (`"\x1b[A"`, `"\r"`, `"\x03"`,
bracketed paste, CSI mouse sequences if enabled). A single wrong mapping
yields a TUI that "runs" but feels broken - keys do nothing, Shift+Tab inserts
a tab, Ctrl+C doesn't route to quit.

Derived from pi's Windows notes and the existing Linux `tty_read_key` contract:

| Input | Linux (byte stream) | Windows must emit |
| ----- | ------------------- | ----------------- |
| Up/Down/Left/Right | `\x1b[A` / `[B` / `[C` / `[D` | same (from `VK_*` + `KEY_EVENT`) |
| Home/End/PgUp/PgDn | CSI `~` sequences | same |
| Enter | `\r` | `\r` (not `\n` from console) |
| Backspace | `\x7f` or `\b` | match Linux (`input.na.jac` assumption) |
| Tab / Shift+Tab | `\t` / `\x1b[Z` | `VK_TAB` + `SHIFT_PRESSED` → `\x1b[Z` (not VT input mode) |
| Ctrl+C | `\x03` | `\x03` or `VK_CANCEL` path |
| Unicode typing | UTF-8 bytes | `KEY_EVENT` wchar → UTF-8 `str` |
| Escape / CSI | raw bytes | synthesize or pass through VT parser |

**This table is the single most useful artifact in the port** - same role the
glibc-vs-xnu termios table plays on macOS.

### Console mode flags (the easy part)

On init, after opening the console handles:

| Mode | Value | Handle | Purpose |
| ---- | ----- | ------ | ------- |
| `ENABLE_VIRTUAL_TERMINAL_PROCESSING` | `0x0004` | stdout | ANSI diff renderer (**required**) |
| Disable `ENABLE_PROCESSED_INPUT` | `0x0001` | stdin | Ctrl+C as `\x03`, not break event |
| Disable `ENABLE_LINE_INPUT` | `0x0002` | stdin | raw-ish input (no line buffering) |
| Disable `ENABLE_ECHO_INPUT` | `0x0004` | stdin | no local echo |

`ENABLE_VIRTUAL_TERMINAL_INPUT` (`0x0200`) is **not** used - see §Delivered.

Fail fast with a clear error if VT output cannot be enabled - legacy conhost
without VT is unsupported in v1. Document requirement: **Windows Terminal**
or any VT-aware console (standard for a modern CLI).

## Source layout

Follow the macOS `tty/` staging pattern (`PLAN-tui-macos.md` § Source layout).
Windows adds a third module; it is staged into the same transient import path
so `tui.na.jac` / `host.na.jac` keep static `import from .libc_tty {…}`:

```
jac_super/ai_tui_na/
  tty/
    libc_tty.linux.na.jac     # POSIX / glibc
    libc_tty.darwin.na.jac    # POSIX / xnu (macOS branch)
    console.win32.na.jac      # kernel32 Console API (DONE)
  libc_tty.na.jac             # gitignored; staged by build.sh / build.ps1
  tui.na.jac                  # unchanged: import from .libc_tty { ... }
  host.na.jac                 # unchanged: same priming import of .libc_tty
  build.sh                    # linux | darwin | win32 (+ cross-compile via env)
  build.ps1                   # win32 native entrypoint (DONE)
  (everything else unchanged)
```

`console.win32.na.jac` exports the **same symbol surface** as
`libc_tty.linux.na.jac` (see `PORTING.md` § Terminal backend API). Internally
it stores `HANDLE`s in `TtyCtx`, not POSIX fds - but `tty_fd()` must remain
callable because `host.na.jac` / `tui_core` pass it into `tui_enter_screen`.

Jac AOT imports are static; the platform module is selected at **build time**
by copying the right file to `libc_tty.na.jac`, not by a compiler
`--target` source switch (AGENTS.md: one thing per branch).

## Terminal backend API (frozen contract)

All three backends must implement this surface (`PORTING.md`):

| Function | Role |
| -------- | ---- |
| `tty_open` / `tty_close` | Attach to the real terminal; enter/restore console modes |
| `tty_open_dev(dev)` | v1: ignore `dev` on Win32; attach parent console |
| `tty_init_stdio_remap` / `tty_restore_stdio` / `tty_ipc_fd` | Subprocess only; v1 in-process may stub |
| `tty_poll` / `tty_stdin_ready` / `tty_key_ready` | Multiplex IPC + keyboard |
| `tty_read_key` | Keys → escape strings for `input.na.jac` |
| `tty_read_line` | Line-oriented read from IPC stdin (subprocess) |
| `tty_write` | Write bytes to console output handle |
| `tty_update_size` / `tty_rows` / `tty_cols` | `GetConsoleScreenBufferInfo` |
| `tty_fd` | Sentinel / handle token for shared `tui_core` call sites |

## Build & selection mechanism

### `build.ps1` (native Windows)

`build.sh` cannot be the only entrypoint - `_ensure_na_artifact` today runs
`["bash", build_sh, "--quick"]`, which fails on a stock Windows install
without Git Bash. Add a PowerShell twin:

```powershell
# Conceptual - mirror build.sh structure
$TTY = "win32"
$LIBNAME = "tui.dll"
$BINNAME = "jac-na-tui.exe"
Copy-Item "tty/console.win32.na.jac" "libc_tty.na.jac"
try {
    jac nacompile tui.na.jac -o "bin/$BINNAME"
    jac nacompile host.na.jac --shared -o "bin/$LIBNAME"
} finally {
    Remove-Item "libc_tty.na.jac" -ErrorAction SilentlyContinue
}
```

### `build.sh` extension (Git Bash / cross-compile)

Add a `MINGW*` / `MSYS*` host case or `JAC_AI_TUI_TARGET=win32` override
(already patterned for `darwin`):

```bash
case "$(uname -s)" in
  Linux*)   HOST_TTY=linux  ;;
  Darwin*)  HOST_TTY=darwin ;;
  MINGW*|MSYS*) HOST_TTY=win32 ;;
  *) echo "unsupported host"; exit 1 ;;
esac
# ...
case "$TTY" in
  linux)  LIBNAME=libtui.so;     STAGE=tty/libc_tty.linux.na.jac ;;
  darwin) LIBNAME=libtui.dylib;  STAGE=tty/libc_tty.darwin.na.jac ;;
  win32)  LIBNAME=tui.dll;       STAGE=tty/console.win32.na.jac ;;
esac
cp "$STAGE" libc_tty.na.jac
```

Cross-compile from Linux CI: `JAC_AI_TUI_TARGET=win32` +
`nacompile --target windows` (compiler already emits PE/COFF `.exe` / `.dll` -
`nacompile.impl.jac` `is_windows` path). Assert PE headers with `file` /
`llvm-objdump`; do not attempt to run a Windows binary on Linux.

### Artifact naming

| Platform | Shared lib (in-process) | Subprocess binary |
| -------- | ----------------------- | ----------------- |
| Linux | `bin/libtui.so` | `bin/jac-na-tui` |
| macOS | `bin/libtui.dylib` | `bin/jac-na-tui` |
| Windows | `bin/tui.dll` | `bin/jac-na-tui.exe` |

`nacompile --shared` on Windows uses `.dll` (not `libtui.so`).

## Phase 0 - prerequisites - **DONE**

Landed with macOS plumbing:

1. **`tty/` layout + staging** - `cp` + `trap` / `finally` cleanup.
2. **`_tui_lib_path`** - `tui.dll` on `win32`.
3. **`test_host.py`** - platform-aware lib name.
4. **`TuiHost.load`** - absolute path before `CDLL`.

## Phase 1 - `console.win32.na.jac` - **DONE**

### 1.1 FFI surface

```jac
import from "kernel32.dll" {
    def GetStdHandle(std: i32) -> i64;
    def SetStdHandle(std: i32, handle: i64) -> i32;
    def GetConsoleMode(handle: i64, mode: str) -> i32;
    def SetConsoleMode(handle: i64, mode: i32) -> i32;
    def ReadConsoleInputW(handle: i64, buf: str, count: i32, read: str) -> i32;
    def WriteFile(handle: i64, buf: str, n: i32, written: str, overlapped: i64) -> i32;
    def PeekConsoleInput(handle: i64, buf: str, count: i32, read: str) -> i32;
    def GetConsoleScreenBufferInfo(handle: i64, info: str) -> i32;
    def WaitForSingleObject(handle: i64, ms: i32) -> i32;
    def AttachConsole(pid: i32) -> i32;
    def AllocConsole() -> i32;
    def FreeConsole() -> i32;
    # calloc/memset/memcpy from msvcrt or kernel32 as needed for RECORD buffers
}
```

Exact signatures must be validated against the NA FFI marshaller on PE -
same early gate as macOS Mach-O: compile a tiny smoke before building the
full module.

### 1.2 `TtyCtx` on Windows

Keep `obj TtyCtx` and `glob g_tty` so the rest of the module graph is
unchanged. Store:

- `in_handle: i64`, `out_handle: i64` (from `GetStdHandle` / `CONIN$` / `CONOUT$`)
- `saved_in_mode: i32`, `saved_out_mode: i32`
- `rows`, `cols`, `stdin_ready`, `key_ready` (same semantics as Linux)
- `fd_saved` → rename intent to `stdio_remapped: int` (subprocess only)

`tty_fd()` returns a non-negative sentinel when the console is open (e.g. `0`);
`tty_write(fd, text)` writes to `out_handle` regardless of `fd`.

### 1.3 Lifecycle

**`tty_open_dev(dev)` (v1 - parent console):**

1. If not attached, `AttachConsole(ATTACH_PARENT_PROCESS)` (`-1`).
2. `in_handle = GetStdHandle(STD_INPUT_HANDLE)` (`-10`).
3. `out_handle = GetStdHandle(STD_OUTPUT_HANDLE)` (`-11`).
4. Save modes; enable VT output + VT input; disable line input and echo.
5. `tty_update_size()`.

If `AttachConsole` fails and no console exists, return `-1` (same as Linux
`open("/dev/tty")` failure).

**`tty_close`:** restore saved modes; `FreeConsole()` only if this module
called `AllocConsole`.

### 1.4 `tty_poll` / readiness

Linux uses `poll(2)` on tty fd + optional pipe fd. Windows v1 in-process has
**no IPC pipe** (`host_state.ipc_fd = -1`). `tty_poll` can:

- `WaitForSingleObject` on the console input event (or peek with timeout), or
- `PeekConsoleInput` in a tight loop with `Sleep` for the timeout ms.

Subprocess fallback (phase 6) adds a pipe handle to the wait set.

### 1.5 `tty_read_key` (the crux)

Read one or more `INPUT_RECORD` structs; for `KEY_EVENT` with `bKeyDown`:

- Map `wVirtualKeyCode` + `dwControlKeyState` → the Linux escape string.
- For Unicode `KEY_EVENT` with no VT sequence, emit UTF-8 via the wchar.
- Coalesce `ESC` + CSI runs the same way Linux coalesces byte-at-a-time.

Cap malformed runs (Linux caps CSI at 32 bytes). Unit-test this table in
isolation before wiring the full TUI.

### 1.6 Subprocess-only stubs - **stubbed (Phase 6)**

`tty_init_stdio_remap`, `tty_restore_stdio`, `tty_ipc_fd`, `tty_read_line`:
symbols exist so `tui.na.jac` links; all return failure/empty. Subprocess
backend on Windows is **not** end-to-end until Phase 6 wires handle-based
stdio remap.

### Validation gates

| Gate | Status | Where |
| ---- | ------ | ----- |
| PE cross-compile (`JAC_AI_TUI_TARGET=win32`) | **DONE** | `build.sh` skips run-on-Linux |
| `test_console_win32.py` (constants + VT) | **DONE** | `build.ps1` full build |
| `test_host.py` (ctypes + headless render) | **DONE** | `build.ps1` full build |
| `windows-latest` CI | **open** | not in `.github/workflows` yet |
| Interactive `jac ai --tui` | **open** | Phase 5 human sign-off |

## Phase 2 - control-plane branches - **DONE**

### `_sidecar_tty_device()` (`tui_shared.jac`)

Today: `os.ttyname(stream.fileno())` on the first `isatty()` stream.

Windows:

```python
if sys.platform == "win32":
    for stream in (sys.stderr, sys.stdin, sys.stdout):
        try:
            if stream.isatty():
                return ""   # sentinel: parent console (no /dev path)
        except Exception:
            pass
    return ""
```

`host.na.jac` `tui_init(..., tty_dev)` receives `""`; `tty_open_dev` attaches
the parent console. **Never pass a fabricated path** across the ABI.

### `_tui_lib_path` (`tui_host.jac`)

```python
def _tui_lib_name() -> str:
    if sys.platform == "darwin":
        return "libtui.dylib";
    if sys.platform == "win32":
        return "tui.dll";
    return "libtui.so";
```

### `run_tui_in_process.impl.jac`

- No change to the threading / render-lock model.
- **Fd redirect:** today uses `os.open(os.devnull)` + `dup2`. On Windows,
  `os.devnull` is `nul` - verify on Python 3.12–3.14 early; same stray-output
  guard intent as Linux.
- **TTY gate:** keep `if not tty_dev` only when no `isatty()` - on Windows
  `tty_dev == ""` is **success**, not failure. Branch:

```python
if sys.platform != "win32" and not tty_dev:
    console.error("needs an interactive terminal ...");
    return 1;
if sys.platform == "win32" and not (sys.stdin.isatty() or sys.stderr.isatty()):
    console.error("needs an interactive terminal ...");
    return 1;
```

### `_ensure_na_artifact` (`tui_shared.jac`) - **DONE**

Dispatches `powershell -ExecutionPolicy Bypass -File build.ps1 -Quick` on
win32; `bash build.sh --quick` elsewhere.

## Phase 3 - v1 vs v2 strategy - **v1 DONE**

### v1 - parent console - **shipped**

- User runs `jac ai --tui` from Windows Terminal / PowerShell / VT cmd.
- In-process: `AttachConsole(ATTACH_PARENT_PROCESS)` or inherited handles.
- No ConPTY creation, no pseudo-terminal allocation.
- Matches pi's v1 model (parent console + VT modes).
- **Limitation:** Python stray `print()` competes with the TUI unless fd
  redirect works on Win32 (same class of bug as in-process Linux).

### v2 - ConPTY (**follow-up branch**)

- Control plane creates a pseudo-console; passes pipe handles via env.
- Closer to Linux sidecar isolation; needed for clean subprocess IPC/stderr
  split on Windows.
- Significant spawn plumbing - **not a v1 merge blocker**.

### Subprocess fallback on Windows - **partial (Phase 6)**

| Linux | Windows (today) |
| ----- | --------------- |
| `start_new_session=True` | `CREATE_NEW_PROCESS_GROUP` (spawn only) |
| `JAC_AI_TUI_TTY=/dev/pts/N` | `""` parent console |
| `bin/jac-na-tui` | `bin/jac-na-tui.exe` compiles |
| IPC stdio remap | **stubbed** in `console.win32.na.jac` |

Default is in-process; use `JAC_AI_TUI_BACKEND=subprocess` on Windows at
your own risk until Phase 6.

## Phase 4 - CI - **open**

Add to the jac-super NA artifact workflow:

**Linux job (cross-compile gate):**

1. `JAC_AI_TUI_TARGET=win32 ./build.sh` → `nacompile --target windows
   host.na.jac --shared -o bin/tui.dll`.
2. Assert PE/COFF (`file`, `llvm-objdump -p`). Do **not** run it.

**windows-latest job (native):**

1. `powershell ./build.ps1 -Quick` → `bin/tui.dll` + `bin/jac-na-tui.exe`.
2. `python test_host.py` (headless ctypes + frame round-trip).
3. `bin/test_pickers` (unchanged).
4. `python test_console_win32.py` (new) - VT enable + one key round-trip.
5. Optional integration: `jac ai --tui` smoke in Windows Terminal (manual or
   scripted `script` equivalent).

`test_tty_darwin.py` stays macOS-only. Libc `proto/no_c_*` smokes stay
POSIX-only.

**CI green is necessary but not sufficient** - Phase 5 human sign-off on a
real Windows desktop still gates confidence in interactive UX.

## Phase 5 - human Windows sign-off - **open**

Checklist for interactive validation (capture in `ai_tui/SIGNOFF-win32.md`):

- **Windows Terminal** (primary), PowerShell, cmd with VT enabled.
- Resize: console buffer/window change → `tty_update_size` / layout refresh.
- Key sequences: arrows, Home/End, PgUp/PgDn, Ctrl+C, Shift+Tab, Enter,
  Backspace, paste (bracketed if enabled).
- CJK / wide chars: spot-check `width.na.jac` assumptions.
- Confirm failure mode on legacy conhost without VT is a **clear error**, not a
  garbled screen.

## Sequencing

| Phase | Work | Status |
| ----- | ---- | ------ |
| 0 | Platform helpers (`_tui_lib_path`, build dispatch, `_sidecar_tty_device`) | **DONE** |
| 1 | `console.win32.na.jac` (Console API + `tty_read_key` translation) | **DONE** |
| 2 | `build.ps1`, `build.sh` win32, `_ensure_na_artifact` | **DONE** |
| 3 | `run_tui_in_process` TTY gate + `nul` redirect | **DONE** |
| 4 | Linux cross-compile gate + `windows-latest` CI | **open** (local gates only) |
| 5 | Human Windows sign-off (`SIGNOFF-win32.md`) | **open** |
| 6 | Subprocess IPC + stdio remap on Win | **open** |
| 7 | ConPTY v2 | **out of scope** |

## Risks & open questions

1. **`tty_read_key` is the crux** (see §crux). Mitigation: pi as reference;
   isolated translation tests before full TUI; table in this doc kept current.
2. **PE FFI parity with ELF/Mach-O** is less exercised for calloc'd
   `INPUT_RECORD` buffers and `ReadConsoleInputW`. Validate early (Phase 1
   cross-compile gate); fork to a separate compiler branch if one appears
   (AGENTS.md).
3. **`width.na.jac` CJK** may differ on Windows console Unicode width -
   spot-fix, not a full fork; track in sign-off.
4. **`bash build.sh` on Windows** - `_ensure_na_artifact` must call
   `build.ps1` natively; documenting Git Bash as optional, not required.
5. **MSVC runtime / DLL load** - if `tui.dll` fails to load, check PE
   dependencies; document redist requirement if the linker emits a dynamic
   dependency on `VCRUNTIME140.dll`.
6. **Console ≠ ConPTY** - v1 parent-console mode cannot catch every edge case
   that ConPTY would; residual gaps are why Phase 5 exists.
7. **WSL is not Windows** - WSL users run the **Linux** artifact inside Linux
   userspace; do not route `platform.system() == "Linux"` on WSL to the Win32
   module. Only native `win32` gets `console.win32.na.jac`.

## What not to port per platform

Keep platform-neutral (do not fork):

- `PROTOCOL.md` frame/command format
- `state`, `feed`, `screen`, `components`, `diff`, `input`, `ipc`
- `terminal.na.jac` ANSI sequences (VT-capable consoles on all targets)
- `host.na.jac` `:pub` ABI and threading contract
- Control-plane file list / model presets (`JAC_AI_UI_*`)
- `_dispatch_cmd`, `_frame_blob`, `ui_*` agent API

Only fork when the OS API forces it: Console API vs termios, handles vs device
paths, and (subprocess only) spawn/session flags.

## How to build & run (Windows)

```powershell
cd jac-super\jac_super\ai_tui_na
powershell -ExecutionPolicy Bypass -File build.ps1 -Quick   # or full build + tests
# from repo venv:
jac ai --tui
```

Requires **Windows Terminal** or another VT-enabled console. First launch
auto-builds via `_ensure_tui_lib` when NA sources are present; set
`JAC_AI_TUI_REBUILD=1` to force a recompile.

Cross-compile PE from Linux (no run):

```bash
JAC_AI_TUI_TARGET=win32 ./build.sh --quick
```

## Out of scope (follow-up branches)

- ConPTY v2 pseudo-console creation.
- Subprocess fallback on Windows (unless phase 6 is explicitly pulled in).
- ARM64 Windows artifact matrix (start x64; arm64 follows macOS universal pattern).
- Notarization / code-signing (N/A on Windows; Authenticode is a separate policy).
- Shipping prebuilt `tui.dll` in the PyPI wheel (source-first / compile-on-first-use
  remains the default packaging model).

## Changelog

| Date       | Phase | Notes |
| ---------- | ----- | ----- |
| 2026-06-18 | plan  | Initial Windows port plan. Contrasted with macOS one-module swap; identified `tty_read_key` / `INPUT_RECORD` translation as the crux; chose parent-console v1 + `build.ps1` + `tty/` staging; sequenced after macOS plumbing. |
| 2026-06-18 | v1    | **Implemented.** `console.win32.na.jac`, `build.ps1`, `build.sh` win32 cross-compile, control-plane branches, `test_console_win32.py`. In-process path is the supported Windows backend; subprocess IPC stubs link but are not wired. CI `windows-latest` + `SIGNOFF-win32.md` remain open. |
