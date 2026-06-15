# TUI Rendering - Agent Notes

## Current approach: NA-compiled binary sidecar

The `jac ai --tui` command renders the terminal UI via a **native (NA) binary** compiled from `.na.jac` sources. This is the second rewrite; the history is:

1. **Ink (Node.js/React)** - spawned a Node sidecar, compiled via `ink_compile`; killed because of slow startup and brittle npm bundling.
2. **Textual (Python)** - in-process Python TUI; deleted (files in `jac-super/jac_super/ai_tui/` are now gone). Removed because Textual's event loop conflicted with the byLLM async agent loop.
3. **NA binary (current)** - `jac nacompile` produces a standalone native binary that owns the terminal; Python feeds it frames over a subprocess pipe.

### File layout

```
jac-super/jac_super/ai_tui_na/
  tui.na.jac          # main loop: poll IPC + keyboard, call render_full on dirty
  render.na.jac       # ANSI renderer: banner/status/transcript/input rows
  state.na.jac        # TuiState + Event objects
  ipc.na.jac          # stdin frame parser (key:value blocks terminated by "---")
  input.na.jac        # keyboard dispatcher (arrow keys, Ctrl-G stop, /commands)
  feed.na.jac         # events_to_rows: Event list -> wrapped ANSI display rows
  tui_helpers.c       # low-level C shim: termios raw mode, winsize, poll, /dev/tty
  build.sh            # gcc libtui_helpers.so + jac nacompile tui.na.jac -o bin/jac-na-tui
  bin/
    jac-na-tui        # compiled binary (checked in or built locally)
    libtui_helpers.so # C shim DSO (RUNPATH $ORIGIN so it finds the .so next to the binary)
  proto/
    rawmode_proto.na.jac  # phase-0 smoke-test: validate C shim before full build
```

The Python side lives in:

```
jac-super/jac_super/ai_agent/
  impl/run_tui_session.impl.jac   # spawns bin/jac-na-tui as subprocess, bridges IPC
  impl/plugin.impl.jac            # run_ai_agent hook: routes --tui to run_tui_session
jac/jaclang/cli/
  ai_agent.jac                    # AgentConfig, ui_configure/send/stop/reset/stream
  impl/ai_agent.impl.jac          # full agent loop + ui_stream() frame generator
```

### IPC protocol (Python → binary)

Frames are newline-separated `key:value` lines terminated by `---`:

```
TYPE:full|delta|hb
STATUS:idle|running|done|stopping
ACTIVE:<phase label>
MODEL:<model name>
NEEDS_KEY:0|1
KEY_ENV:<env var name>
EV:<id>:<kind>:<node>:<text_escaped>
---
```

`text_escaped`: `\n → \\n`, `\\ → \\\\`. The binary unescape is in `ipc.na.jac::_unescape`.

Binary -> Python: single-line commands on stdout - `SEND:<prompt>`, `STOP`, `RESET`, `QUIT`, `APPLY:key=val,key=val`.

### Known NA codegen workarounds

Two active bugs are worked around in the na sources:

- `feed.na.jac` - nested `for` loops that reassign locals inside the word-wrap path segfault at runtime. Workaround: `body.replace("\n", " ")` flattens to one row per event (no multi-line wrapping).
- `state.na.jac` - `os.getenv(...) or os.getcwd()` segfaults when the input module is linked. Workaround: explicit `if proj is not None { if len(proj) > 0 { ... } }` branch in `tui.na.jac`.

### OpenTUI FFI: `ptr` support (blocked upstream)

Live reproduction tests in `jac-super/jac_super/ai_tui_na/`:

| File | What it probes |
|------|----------------|
| `test_ptr_ops.na.jac` | `ptr` variable declaration, passing to FFI, `shim_write16` |
| `test_ptr_index.na.jac` | `p[i] = val` (subscript write) |
| `test_ptr_read.na.jac` | `v = p[i]` (subscript read) |
| `test_ffi.na.jac` | `shim_fill_rect`, `shim_draw_text` end-to-end |
| `test_noscalar_ptr.na.jac` | `ptr` as FFI return/param type |

Results (2026-06-15):

| Test | Result | Error |
|------|--------|-------|
| `ptr` as FFI return/param type | compiles & runs | n/a |
| `ptr` variable declaration & passing | works | n/a |
| `p[i] = val` (write) | ✗ compile error | "does not yet support subscript assignment" |
| `v = p[i]` (read) | ✗ compile error | "does not yet support subscript/index access" |

**Waiting on upstream (Jac NA compiler):** ptr subscript write and ptr subscript read. Until both land, the C shim in `opentui_shim.c` must keep the scalar wrappers - `shim_write16`, `shim_fill_rect`, and `shim_draw_text` are the exact minimum surface needed to build RGBA buffers and call OpenTUI from Jac NA without direct `p[i]` access.

---

## Next step: in-process rendering (sv server target)

**Goal:** remove the subprocess. Run the NA TUI render loop directly inside the Python process hosting the `jac ai` agent server (the `sv`/jac-svelte server, where `jac start` launches the in-process dispatch).

The plan is to load `libtui_helpers.so` via `ctypes` (or the NA runtime's FFI layer) and call the NA-compiled render functions in a thread from Python, replacing the `subprocess.Popen` + stdin/stdout pipes in `run_tui_session.impl.jac` with direct function calls.

This eliminates:

- The `bin/jac-na-tui` build/install step
- The subprocess teardown edge cases (SIGCHLD, pipe close races)
- The text-encode/decode round-trip on the IPC pipe

The render loop and keyboard poll would live in a dedicated thread (`_tui_thread`) that shares a `TuiState`-equivalent Python object (or the NA object itself if the runtime exposes it) with the agent coroutine. The `ui_stream()` generator already produces the frame dict; the in-process path would apply it directly to `TuiState` instead of serializing to the pipe.

Status as of 2026-06-15: **not yet started** - current branch (`jac-ai-tui`) has the working sidecar in place. The in-process wiring is the next work item.
