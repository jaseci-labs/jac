# `jac ai --tui` - Architecture (current)

Terminal UI for the Jac coding agent. The agent runs in the `jac ai` CLI;
rendering and keyboard handling run in a native NA renderer. The two halves are
separated by one frozen text protocol (`PROTOCOL.md`) and the renderer can run
behind that seam in **either** of two transports:

- **In-process (default)** - the renderer is loaded into the agent process as
  `libtui.so` via ctypes; the same protocol bytes cross via function calls + a
  pull queue. See [In-process model](#in-process-model).
- **Subprocess (`JAC_AI_TUI_BACKEND=subprocess`)** - the renderer is spawned as
  a separate process (`jac-na-tui`) and the protocol flows over pipes. The
  [Process model](#process-model) section below describes this fallback.

Related docs:

| Doc | Contents |
| --- | -------- |
| `PROTOCOL.md` | Wire format (frames + commands) - **do not change casually** |
| `BACKENDS.md` | Binary path, spawn flags, env vars |
| `PORTING.md` | macOS / Windows port plan |
| `../../PLAN.md` | Feature roadmap and phase history |
| `../../../agents.md` | Agent-oriented file map and protocol summary |

## Design goals

1. **Separation of concerns** - agent loop (LLM, tools, bus) and terminal UI
   evolve independently behind `PROTOCOL.md`.
2. **No render deps** - renderer is Jac NA + libc FFI only (no custom `.c`).
3. **Clean terminal I/O** - protocol uses pipes; the real TTY is opened separately
   so stdin/stdout are not shared with the drawing surface.
4. **Control plane owns I/O policy** - filesystem walks, model presets, loguru/litellm
   capture, and stdout gating stay in Python/Jac; the sidecar is a dumb renderer +
   keyboard front-end.

### Subprocess fallback (`JAC_AI_TUI_BACKEND=subprocess`)

The sidecar transport remains for crash isolation and third-party renderers that
speak `PROTOCOL.md` over pipes. In-process is the default because it avoids
spawn/`setsid` plumbing and ships one `libtui.so` artifact. The subprocess path
keeps stdin/stdout as IPC pipes and opens the real TTY on a separate fd (see
`PROTOCOL.md`).

## Process model

```
  User terminal (/dev/pts/N)
         │
         │  keyboard + ANSI display
         ▼
┌────────────────────────────────────────────────────────────┐
│  jac-na-tui  (child, own session via setsid)               │
│  ai_tui_na/ - native binary, jac nacompile                 │
│                                                            │
│  stdin  ◄── frames (KEY:VALUE + "---")                     │
│  fd 3   ──► commands (SEND:/STOP:/QUIT:/APPLY:)            │
│  fd 1   ──► ANSI render (stderr dup'd here after remap)    │
│  tty fd ──► keyboard (opens JAC_AI_TUI_TTY)                │
└────────────────────────▲───────────────────────────────────┘
                         │ subprocess.Popen(pipes)
┌────────────────────────┴───────────────────────────────────┐
│  jac ai  (parent, Python/Jac control plane)                  │
│                                                            │
│  JacSuperAiPlugin.run_ai_agent  →  run_tui_session           │
│  ai_agent.ui_configure / ui_stream / ui_stop               │
│                                                            │
│  Thread A: ui_stream() → serialize frames → child.stdin    │
│  Thread B: child.stdout → dispatch SEND/STOP/QUIT/APPLY    │
│  Main:     proc.wait()                                     │
└────────────────────────────────────────────────────────────┘
```

**Not** inside `jac start` / sv unless wired separately. Entry: `jac ai --tui`.

## In-process model

The default backend collapses the two processes into one. The renderer
is `dlopen`'d as `ai_tui_na/bin/libtui.so` and driven over ctypes; the protocol
(`PROTOCOL.md`) is unchanged - frames cross as a `str` to `tui_apply_frame`, and
commands are **pulled** from `tui_next_command()` rather than read from a pipe.

```
┌─────────────────────────────────────────────────────────────────┐
│  jac ai --tui   (single process: sv control plane + libtui.so)   │
│                                                                  │
│  ┌────────────────────────┐        ┌──────────────────────────┐ │
│  │ sv control plane       │        │ na renderer (libtui.so)  │ │
│  │ agent loop + bus       │        │ TuiState in native mem   │ │
│  │                        │        │                          │ │
│  │ feeder thread ─frame─► │──ctypes─►│ tui_apply_frame(blob)  │ │
│  │ ticker thread ─poll──► │──ctypes─►│ tui_wait_key / handle  │ │
│  │               render─► │──ctypes─►│ tui_render()           │ │
│  │ ◄─ next_command() ──── │◄────────│ cmd queue (obj glob)    │ │
│  └────────────────────────┘        └────────────┬─────────────┘ │
│   real stdout/stderr → /dev/null                │ tty fd ≥ 10    │
└─────────────────────────────────────────────────┼───────────────┘
                                                   ▼
                                        /dev/pts/N  (keyboard + ANSI)
```

| Piece | Location |
| ----- | -------- |
| ctypes binding (`TuiHost`) | `jac_super/ai_agent/tui_host.jac` |
| feeder/ticker driver + lifecycle | `jac_super/ai_agent/impl/run_tui_in_process.impl.jac` |
| shared encoder/dispatcher (both backends) | `jac_super/ai_agent/tui_shared.jac` |
| backend selection | `jac_super/ai_agent/impl/plugin.impl.jac` (`JAC_AI_TUI_BACKEND`) |
| `:pub` C-ABI surface | `ai_tui_na/host.na.jac` (built to `bin/libtui.so`) |

**Two threads, one lock.** A *feeder* thread reads `ui_stream()` and calls
`tui_apply_frame`; a *ticker* thread polls (`tui_wait_key`, lock-free), then under
a render lock dispatches the key (`tui_handle_key`), drains the command queue, and
renders (`tui_render`). Commands are drained under the lock but **dispatched after
releasing it**, so the render lock and the agent bus lock are never nested.

**What in-process must pay for** (the subprocess boundary gave these for free):

- **Crash isolation** - a fault in `libtui.so` now kills the whole agent, not
  just a sidecar. Use `JAC_AI_TUI_BACKEND=subprocess` when you need isolation.
- **fd hygiene** - fd 1/2 *are* the alt-screen tty in-process, so the driver
  redirects the agent's real stdout/stderr to `/dev/null` for the session and
  restores them on shutdown. Set `JAC_AI_TUI_DEBUG_LOG=<path>` to see diagnostics
  (otherwise a traceback is invisible).
- **Signals** - raw mode clears `ISIG`, so Ctrl-C is a keystroke (→ `QUIT`), not
  `SIGINT`.

## Entry path

```
jac ai --tui
  → jaclang.cli.commands.ai (tui flag)
  → build_agent_request(..., tui=True)
  → JacSuperAiPlugin.run_ai_agent (jac_super/ai_agent/impl/plugin.impl.jac)
  → run_tui_in_process (jac_super/ai_agent/impl/run_tui_in_process.impl.jac)
  → ctypes: ai_tui_na/bin/libtui.so
```

(`JAC_AI_TUI_BACKEND=subprocess` swaps the last two steps for
`run_tui_session` → `ai_tui_na/bin/jac-na-tui`.)

## Control plane (`jac ai` parent)

| Piece | Location | Role |
| ----- | -------- | ---- |
| Agent loop + bus | `jaclang/cli/ai_agent.jac`, `impl/ai_agent.impl.jac` | Runs turns, tools, phases |
| UI mode hooks | `ui_configure`, `ui_stream`, `ui_stop` | Gate stdout/loguru; yield frame dicts |
| Session bridge (default) | `run_tui_in_process.impl.jac` | ctypes host, threads, frame encode, cmd dispatch |
| Session bridge (fallback) | `run_tui_session.impl.jac` | Spawn sidecar, env, threads, frame encode, cmd dispatch |
| Plugin hook | `plugin.impl.jac` | Routes `req.tui` to in-process or subprocess backend |

### Parent threads

| Thread | Work |
| ------ | ---- |
| **Main** | `proc.wait()`; cleanup on exit / Ctrl+C |
| **stream_writer** | `for frame in ui_stream(): _write_frame(proc.stdin, frame)` |
| **cmd_reader** | `for line in proc.stdout: _dispatch_cmd(...)` |

`ui_stream()` is a generator over the agent bus: status, active phase, model,
and `EV:id:kind:node:text` events. Heartbeats are skipped on the wire.

### Control-plane responsibilities (kept out of NA)

- Resolve and pass `JAC_AI_TUI_TTY` (`os.ttyname` on stderr/stdin/stdout)
- Build `JAC_AI_UI_FILES` (`git ls-files` or bounded walk)
- Export `JAC_AI_UI_MODEL_PRESETS` from `ai_agent._MODEL_PRESETS`
- Compile `jac-na-tui` on first run when sources are newer (`_ensure_tui_binary`)
- Capture loguru / litellm output into the bus when `JAC_AI_UI_ACTIVE=1`

## Sidecar (`jac-na-tui` child)

Built from `jac-super/jac_super/ai_tui_na/` via `build.sh` (`jac nacompile`).

### Layer stack

```
tui.na.jac              main loop: poll → keys → IPC → diff render
├── input.na.jac        key dispatch → editor / overlays / commands
├── screen.na.jac       layout: header, transcript viewport, editor, overlays
├── feed.na.jac         Event[] → DisplayRow[] (markdown, tool blocks, …)
├── state.na.jac        TuiState, EditorState, Event, viewport scroll
├── ipc.na.jac          frame parser, command sender
├── diff.na.jac         ANSI diff engine (minimize flicker)
├── editor.na.jac       multiline prompt editor
├── overlay.na.jac      command / model / file pickers
├── commands.na.jac     palette entries, APPLY:model=
├── markdown.na.jac     answer/reasoning → ANSI rows
├── tool_block.na.jac   tool call/result styling
├── component.na.jac    component spine (pi-tui pattern)
├── terminal.na.jac     escape sequences (alt screen, CSI 2026, SGR helpers)
├── libc_tty.na.jac     raw TTY: open, poll, read_key, stdio remap
├── width.na.jac / theme.na.jac
└── select_list.na.jac  filtered list widget
```

### Sidecar main loop (`tui.na.jac`)

Each iteration (~50 ms poll timeout):

1. `tty_poll` - check IPC stdin (fd 0) and keyboard (tty fd)
2. **Keyboard first** - `handle_key` (avoids IPC starvation during streaming)
3. **IPC frame** - `ipc_read_frame_v2` → update `TuiState`
4. **Render if dirty** - `screen_render` → `DiffEngine.paint` to fd 1

Startup: `tty_open` → `tty_init_stdio_remap` (save IPC on fd 3) → alt screen.
Shutdown: restore cursor, leave alt screen, restore stdio, close tty.

### Stdio remap (why three fds matter)

| fd | After remap | Purpose |
| -- | ----------- | ------- |
| 0 | pipe from parent | Incoming frames |
| 1 | user terminal (via stderr inherit + dup2) | ANSI drawing |
| 3 | saved stdout pipe | Outgoing commands to parent |

Keyboard uses a **separate** open of `JAC_AI_TUI_TTY` (relocated to fd ≥ 10) because
`start_new_session=True` drops the controlling tty and fd 3 is reserved for IPC.

## Data flow

### Agent output → screen

```
LLM / tools / bus
  → ai_agent routes events into ui_stream() frame dicts
  → run_tui_session._write_frame (text lines + "---")
  → sidecar ipc_read_frame_v2
  → state.upsert_event
  → feed.build_rows (on layout_dirty)
  → screen_render (viewport_top / follow_tail)
  → diff_engine.paint
  → terminal (ANSI)
```

### User input → agent

```
keyboard on /dev/pts/N
  → libc_tty.tty_read_key
  → input.handle_key
  → ipc_send_cmd(fd 3, "SEND:…" | "STOP" | …)
  → parent cmd_reader
  → _dispatch_cmd → ui agent APIs
```

## Protocol seam (summary)

Full spec: `PROTOCOL.md`.

**Frames (parent → child stdin):** `TYPE`, `STATUS`, `ACTIVE`, `MODEL`,
`NEEDS_KEY`, `KEY_ENV`, zero or more `EV:…` lines, terminator `---`.

**Commands (child → parent via fd 3 / saved stdout pipe):** one line each -
`SEND:`, `STOP`, `RESET`, `QUIT`, `APPLY:`.

## Platform

**Linux / WSL only** today. Terminal backend is `libc_tty.na.jac` (glibc FFI,
`/dev/tty`, termios, poll). See `PORTING.md` for macOS and Windows.

## Testing

| Layer | Location |
| ----- | -------- |
| Protocol + resolver + stdout gating (subprocess) | `jac-super/tests/test_ai_tui_bridge.jac` |
| In-process `TuiHost` binding + real-PTY input→command (in-process) | `jac-super/tests/test_ai_tui_host.jac` |
| Native host gate: load `libtui.so`, parse+render headless | `ai_tui_na/test_host.py` (in `build.sh`) |
| Picker / overlay logic (headless) | `ai_tui_na/test_pickers.na.jac` (in `build.sh`) |
| Libc tty smoke | `ai_tui_na/proto/no_c_*.na.jac` (needs real TTY) |

## Out of scope for the sidecar

- Git / filesystem enumeration
- Model / API key management (beyond displaying state and sending `APPLY:`)
- LLM calls and tool execution
- Terminal scrollback (uses alt screen; in-app transcript viewport instead)
