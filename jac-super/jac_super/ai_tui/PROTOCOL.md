# `jac ai --tui` Renderer Protocol

This is the wire contract between the Jac/Python **control plane**
(`jaclang.cli.ai_agent` + `jac_super.ai_agent.run_tui_session`) and a renderer
**sidecar** (the `na` native renderer today, a `js` OpenTUI renderer later).

It is derived from the live implementation in
`jac_super/ai_agent/impl/run_tui_session.impl.jac`. Any backend - native or JS -
that speaks this protocol is interchangeable. **Do not change it during the
initial migration**; parity is defined against this document.

## Transport

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

  | Variable             | Meaning                                  |
  | -------------------- | ---------------------------------------- |
  | `JAC_AI_UI_PROJECT`  | Normalized working directory (cwd)       |
  | `JAC_AI_UI_MODEL`    | Model name override (may be empty)       |
  | `JAC_AI_UI_NCTX`     | Context-window override as int (`0`=unset)|

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
| `QUIT`             | -                                                           | stop streaming, `ui_stop()`, then terminate the subprocess   |
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
- `QUIT` is the only command that tears down the process; the control plane also
  terminates on its own `proc.wait()` returning or on `KeyboardInterrupt`.

See `BACKENDS.md` for how a backend is selected and spawned.
