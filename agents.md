# TUI Rendering - Agent Notes

## Current approach: NA native renderer (in-process by default)

`jac ai --tui` renders the terminal UI with a **Jac NA module** (`ai_tui_na/`)
compiled to `libtui.so` and loaded into the agent process via ctypes. The default
path is in-process (`run_tui_in_process`); set `JAC_AI_TUI_BACKEND=subprocess`
to spawn the `jac-na-tui` sidecar over pipes instead.

See `jac-super/jac_super/ai_tui/ARCHITECTURE.md` for the full layout, threading
model, and transport details.

### File layout

```
jac-super/jac_super/ai_tui_na/
  host.na.jac         # :pub C-ABI surface (tui_init, tui_apply_frame, …)
  tui_core.na.jac     # shared setup/loop/teardown for host + subprocess entry
  tui.na.jac          # subprocess fallback binary entry
  screen.na.jac       # layout: header, transcript viewport, editor, overlays
  input.na.jac        # keyboard dispatch, editor, overlays, commands
  ipc.na.jac          # frame parser + command queue
  libc_tty.na.jac     # raw TTY: open, poll, read_key, write
  build.sh            # nacompile jac-na-tui + libtui.so; runs headless gates
  bin/
    libtui.so         # in-process renderer (default)
    jac-na-tui        # subprocess fallback binary

jac-super/jac_super/ai_agent/
  tui_host.jac              # ctypes binding to libtui.so
  tui_shared.jac            # shared frame/command encoder + dispatcher
  run_tui_in_process.jac    # default in-process driver (feeder + ticker threads)
  run_tui_session.jac       # subprocess fallback driver
  impl/plugin.impl.jac      # routes --tui to in-process or subprocess backend

jac/jaclang/cli/
  ai_agent.jac / impl/ai_agent.impl.jac   # agent loop + ui_stream() frames
```

### Protocol seam

Frozen wire format: `jac-super/jac_super/ai_tui/PROTOCOL.md`.

- **Frames (agent → renderer):** `KEY:VALUE` lines terminated by `---`
- **Commands (renderer → agent):** `SEND:`, `STOP`, `RESET`, `QUIT`, `APPLY:`

In-process: frames pass to `tui_apply_frame(blob)`; commands are pulled from
`tui_next_command()`. Subprocess: same bytes over stdin/stdout pipes.
