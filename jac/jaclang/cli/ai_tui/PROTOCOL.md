# `jac ai --tui` Renderer Protocol

This is the wire contract between the Jac/Python **control plane**
(`jaclang.cli.ai_agent` + `jaclang.cli.ai_tui.run_tui_session`) and a renderer
**sidecar** (the `na` native renderer).

It is derived from the live implementation in
`jaclang/cli/ai_tui/impl/run_tui_session.impl.jac`. Any sidecar that speaks
this protocol is interchangeable. **Do not change it casually**; behavior is
defined against this document.

## Transport

The **logical** protocol below (frame fields, command set, escaping, upsert-by-id
invariants) is identical regardless of how bytes move. Two transports carry it;
the renderer backend (`BACKENDS.md`) picks one.

### In-process transport (default)

The native renderer is loaded into the agent process as a shared library
(`ai_tui_na/bin/libtui.so`) via `ctypes`, instead of being spawned. The wire
**bytes** are the same; only the carrier changes:

- **Frames** are passed as one UTF-8 `str` per `ui_stream()` emit to
  `tui_apply_frame(blob)` - `blob` is the exact `KEY:VALUE\n…\n---` text below
  (built by the shared `_frame_blob`, the same encoder the subprocess path writes
  to stdin).
- **Commands** are **pulled**, not pushed: a keystroke handled by
  `tui_handle_key()` enqueues the same `SEND:`/`STOP:`/… line into a native queue,
  and the host drains it with `tui_next_command()` (returns `""` when empty).
  There is no native→host callback.
- The native side opens the controlling tty directly (`tui_init`'s `tty_dev`
  arg); the agent's own stdout/stderr fds are redirected away from that tty for
  the session's lifetime so stray output can't corrupt the alt-screen.

The C-ABI surface is defined in `ai_tui_na/host.na.jac` and bound by
`ai_tui/tui_host.jac`: `tui_init`, `tui_apply_frame`, `tui_wait_key`,
`tui_handle_key`, `tui_next_command`, `tui_quit_requested`, `tui_render`,
`tui_shutdown`.

### Subprocess transport (`JAC_AI_TUI_BACKEND=subprocess`)

- The control plane spawns the sidecar as a subprocess with line-buffered text
  pipes (`subprocess.Popen(..., text=True, bufsize=1)`).
- **Frames** flow control-plane → sidecar over the sidecar's **stdin**.
- **Commands** flow sidecar → control-plane over the sidecar's **stdout**.
- Both directions are UTF-8, newline-delimited text. The sidecar must keep its
  own terminal UI off stdout (the native backend renders to `/dev/tty`); stdout
  is reserved exclusively for commands.

## Startup

- The seed prompt, if any, is passed as the sidecar's **first positional
  argument** (`argv[1]`). It is omitted when empty.
- Configuration is passed via environment variables (set before spawn):

  | Variable                   | Meaning                                  |
  | -------------------------- | ---------------------------------------- |
  | `JAC_AI_UI_PROJECT`        | Normalized working directory (cwd)       |
  | `JAC_AI_UI_MODEL`          | Model name override (may be empty)       |
  | `JAC_AI_UI_NCTX`           | Context-window override as int (`0`=unset)|
  | `JAC_AI_UI_FILES`          | Newline-separated project file paths for the file picker |
  | `JAC_AI_UI_MODEL_PRESETS`  | Newline-separated quick-pick model names (`ai_agent._MODEL_PRESETS`) |

  The in-process transport sets the same `JAC_AI_UI_*` env vars (the agent reads
  them on `ui_configure`), but passes `project` / `files_env` / `presets_env` /
  `tty_dev` to the native side directly as `tui_init` arguments rather than via
  `argv` + env to a child.

## Frames (control plane → sidecar, via stdin)

A frame is a block of `KEY:VALUE` lines terminated by a line containing exactly
`---`:

```
TYPE:full|delta|hb
STATUS:<str>
ACTIVE:<str>
MODEL:<str>
NEEDS_KEY:0|1
KEY_ENV:<str>
EV:<id>:<kind>:<node>:<text_escaped>
---
```

- **`TYPE`**
  - `full` - a complete snapshot. The sidecar replaces its entire transcript
    with the `EV:` lines in this frame.
  - `delta` - an incremental update carrying a single `EV:` line. The sidecar
    upserts that event **by id** (replace if the id already exists, else append).
  - `hb` - heartbeat. The control plane currently **skips** emitting these to the
    sidecar; a sidecar that receives one should treat it as a no-op keep-alive.
- **`STATUS`** - session status string (e.g. `idle`, `running`, `done`,
  `stopping`).
- **`ACTIVE`** - active phase/node label (may be empty).
- **`MODEL`** - current model name shown in the header.
- **`NEEDS_KEY`** - `1` when the selected model needs an API key that is not set;
  the sidecar should surface a key warning. `0` otherwise.
- **`KEY_ENV`** - the name of the env var the missing key would come from.
- **`EV:`** - one transcript event. Field order is
  `id:kind:node:text_escaped`, split on the **first three** colons only (text
  may contain colons). For a `full` frame there are zero or more `EV:` lines;
  for a `delta` frame there is exactly one.

### Event fields

- **`id`** - integer, monotonically assigned by the agent bus. Upsert key.
- **`kind`** - one of: `user`, `answer`, `reasoning`, `system`, `error`,
  `phase`, `call`, `tool_result`. Drives prefix + color in the renderer.
- **`node`** - phase name (e.g. `Plan` / `Build` / `QA`) for `phase` events;
  otherwise typically empty.
- **`text_escaped`** - the event body with text escaping applied (see below).

### Text escaping

Applied by the control plane when serializing, reversed by the sidecar:

```
"\\"  ->  "\\\\"     (backslash first)
"\n"  ->  "\\n"      (newline)
```

The sidecar reverses this exactly (`\\n` → newline, `\\\\` → backslash) when
unmarshaling an `EV:` line.

## Commands (sidecar → control plane, via stdout)

Each command is a single trimmed line. Empty lines are ignored.

| Command            | Argument format                                              | Effect (control plane)                                      |
| ------------------ | ----------------------------------------------------------- | ----------------------------------------------------------- |
| `SEND:<prompt>`    | everything after `SEND:` is the prompt (verbatim, one line) | `ui_send(prompt)` - enqueue a turn (no-op if already running) |
| `STOP`             | -                                                           | `ui_stop()` - request cancellation of the running turn       |
| `RESET`            | -                                                           | `ui_reset()` - clear transcript/ledger (refused mid-turn)    |
| `QUIT`             | -                                                           | stop streaming, `ui_stop()`, then terminate the subprocess (subprocess transport) or set the stop event so the ticker tears down the in-process renderer (in-process transport) |
| `APPLY:<k=v,...>`  | comma-separated `key=value` pairs (see below)               | `ui_apply_settings(...)` - rebuild model live                |

### `APPLY:` argument grammar

`APPLY:` is followed by comma-separated `key=value` pairs. Recognized keys:

```
model=<str>,n_ctx=<str>,api_key=<str>,base_url=<str>,temperature=<str>
```

- Parsing splits on `,` then on the first `=` in each part; keys/values are
  trimmed. Missing keys default to empty string.
- `n_ctx` and `temperature` arrive as strings and are coerced control-plane side.

## Invariants (parity contract)

- A `full` frame fully reconstructs sidecar state; a `delta` only mutates the
  event identified by its `EV:` id.
- Event identity is the integer `id`; re-sending an id replaces in place.
- The sidecar owns terminal I/O and input; the control plane owns agent state.
  Neither side blocks the other (both run on dedicated writer/reader threads).
- `QUIT` is the command that tears down the renderer; on the subprocess transport
  the control plane also terminates on its own `proc.wait()` returning or on
  `KeyboardInterrupt`. On the in-process transport, quit flows through the stop
  event (also polled via `tui_quit_requested()`); in raw mode Ctrl-C is a
  keystroke, not `SIGINT`.

See `BACKENDS.md` for how the sidecar is spawned.
