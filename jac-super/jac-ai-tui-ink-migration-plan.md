# Jac AI TUI → Ink Migration Plan

## Problem

The current `jac ai --tui` implementation (`jac_super/ai_tui/`) builds its own TUI from scratch:

- Manual `console.print` full-screen redraws with raw ANSI escape codes (`\033[2J\033[H`)
- `readline`-based input loop with blocking `input()` calls
- Custom state object (`TuiState`) with manual feed indexing and row management
- Hand-rolled text wrapping, truncation, status bars, progress bars
- No React-style component model, no incremental updates, no proper layout engine

Meanwhile, **jac-ink** (`~/repos/jac-tui/jac-ink/`) already provides a complete Ink + React TUI framework for Jac:

- `.cl.jac` files compile to Ink terminal apps via `jac2ink`
- Full JSX component model with props, state (`has`), hooks (`useInput`, `useEffect`, `useState`)
- Multi-file component imports
- Ink handles rendering, layout (`Box` flexbox), text styling (`Text`), keyboard input, terminal resize
- `npm start` runner with auto-generated `package.json`

**The migration replaces the hand-rolled TUI with a jac-ink client that follows the same architecture as the desktop and web UI clients.**

### Decision (locked)

- **`jac ai --tui` = Ink only.** No fallback to the Python `ai_tui/` package.
- **`ai_tui/` will be deleted** after Ink reaches command/display parity (Phase C).
- Execution order: see [jac-ai-tui-implementation-plan.md](./jac-ai-tui-implementation-plan.md).

---

## Reference Architecture: How the Existing Clients Work

Before designing the Ink TUI, it's essential to understand how the two working client implementations (web UI and desktop) are structured. The Ink TUI must follow the same patterns.

### The `ui_*` Bridge (shared core)

All three clients talk to the same agent backend through a set of bridge functions defined in `jac/jaclang/cli/ai_agent.jac` and implemented in `jac/jaclang/cli/ai_agent/impl/tui_ui_bridge.impl.jac`:

| Bridge function | Purpose |
|---|---|
| `ui_configure()` | One-time boot: set project cwd, build model, start event bus |
| `ui_send(prompt)` | Start one agent turn; returns False if already running |
| `ui_poll()` | Snapshot: events, status, phase, stats, ledger, key status |
| `ui_stream()` | SSE iterator: token-level streaming events |
| `ui_stop()` | Request stop at next checkpoint |
| `ui_reset()` | Clear conversation and ledger |
| `ui_settings()` | Get model/key/temperature/n_ctx |
| `ui_apply_settings(...)` | Apply settings changes live |
| `ui_graph()` | Phase graph nodes + edges |
| `ui_call_detail(id)` | Token-usage detail for one model call |
| `ui_phase_context(phase)` | Captured messages for a phase node |

These are **in-process** functions that read/write the global `agent` object, its `agent.bus` event bus, and `agent_model`. They are the source of truth for all client state.

### Web UI (`jac ai --ui`) Architecture

The web UI is a **child process** launched from `_run_ui_server()`:

1. **Launcher** (parent process, in `tui_ui_bridge.impl.jac`):
   - Sets env vars: `JAC_AI_UI_PROJECT`, `JAC_AI_UI_MODEL`, `JAC_AI_UI_NCTX`
   - Spawns: `python -m jaclang start main.jac` with `cwd` set to the `ai_ui/` bundled app directory
   - Waits for a URL to appear in the log, opens browser
   - Blocks on `proc.wait()`, handles Ctrl+C

2. **Server process** (child, `ai_ui/server.jac`):
   - On import, runs `ui_configure()` (reads env vars set by launcher)
   - Exposes the `ui_*` functions as HTTP endpoints:
     - `agent_poll` → `ui_poll()`
     - `agent_send` → `ui_send()`
     - `agent_stream` → `ui_stream()` (SSE)
     - `agent_graph` → `ui_graph()`
     - etc.
   - Typed view objects (`PollResult`, `UiEvent`, `TurnStatsView`, etc.) wrap raw dicts

3. **Frontend** (`ai_ui/frontend.cl.jac`):
   - React app served by `jac-client`/Vite
   - `sv import from .server { agent_send, agent_stream, ... }` — the compiler wires these into RPC calls
   - On mount: fetch `agent_graph()` for initial state
   - Opens SSE stream (`agent_stream`) for live token-level updates
   - Calls `agent_send(text)` / `agent_stop()` / `agent_reset()` on user actions

**Key pattern**: The server process owns the agent. The frontend is a separate rendering process that talks to it over HTTP/SSE.

### Desktop (`jac ai --ui` → `--client desktop`) Architecture

The desktop app extends the web UI pattern via the `ClientTarget` plugin system:

1. **Plugin registration**: `JacDesktopPlugin.get_client_targets()` returns a `PyTauriDesktopTarget`
2. **`PyTauriDesktopTarget`** extends `WebTarget`:
   - `setup()` — scaffolds `src-pytauri/` with `app.py`, `tauri.conf.json`, capabilities
   - `build()` — runs `super.build()` (Vite web bundle), then bundles sidecar via PyInstaller
   - `dev()` — starts Vite dev server + backend server + `python app.py` with `DEV_SERVER` env
   - `start()` — builds if needed, then runs `python app.py`
3. **`app.py`** (the PyTauri shell):
   - On boot: discovers and starts the sidecar (or uses configured `base_url`)
   - Sidecar reports `JAC_SIDECAR_PORT=` on stdout → shell discovers the API URL
   - Sets `globalThis.__JAC_API_BASE_URL__` in the webview
   - The web frontend reads `__JAC_API_BASE_URL__` and makes RPC calls to the sidecar

**Key pattern**: Same frontend as web UI, but the agent runs in a sidecar process discovered at runtime. The shell bridges the two.

### jac-ink (`jac start --client tui` / `jac tui`) Architecture

jac-ink is already a working plugin that registers the `tui` client target:

1. **Plugin registration**: `JacCmd.create_cmd` hooks into the `start` command via `reg.extend_command("start", pre_hook=_handle_start_tui)`
2. **Compilation**: `jac2ink` compiles `.cl.jac` → Node.js ESM bundle in `.jac/tui/`
   - Uses `ClientBundleBuilder` (same as jac-client but skips Vite)
   - Post-processes: strips browser-only code, injects Ink/React runtime shims
3. **Runtime**: `runner.mjs` imports the bundle, calls the entry function, renders with Ink's `render()`
4. **`_wire_start_client_tui()`** adds `--client tui` support to `jac start`

**Key pattern**: jac-ink compiles `.cl.jac` → standalone Node.js app. It does NOT currently have any agent bridge — it's a generic TUI framework.

---

## Design: Ink TUI Following the Desktop Pattern

### Overview

The Ink TUI follows the **desktop sidecar pattern**: the agent runs in a Python process, the TUI is a separate Ink/Node.js process, and they communicate over a local transport.

```
┌──────────────────────────────────────────────────────────────┐
│  jac ai --tui (parent process)                               │
│                                                              │
│  1. Set env vars (JAC_AI_TUI_PROJECT, MODEL, NCTX)          │
│  2. Spawn agent server: jac start main.jac --port 0         │
│     → agent server boots, calls ui_configure()              │
│     → reads JAC_AI_TUI_PORT from stdout                     │
│     → stores API base URL                                   │
│  3. Spawn Ink TUI: jac tui main.cl.jac                      │
│     → passes API URL via JAC_TUI_API_URL env var            │
│     → TUI polls agent via HTTP (like web UI)                │
│  4. Wait for Ink process, clean up on exit                  │
└──────────────────────────────────────────────────────────────┘
```

This mirrors `_run_ui_server()` exactly — the only difference is the child process is an Ink TUI instead of a Vite web server.

### Why NOT file-based bridge

The desktop and web UIs use HTTP/RPC for agent communication because:

- The agent is a **long-running server process** — `ui_stream()` provides SSE for token-level streaming
- `ui_poll()` returns structured snapshots designed for JSON serialization (already wrapped as `PollResult`, `UiEvent`, etc. in `server.jac`)
- The same `agent_*` server endpoints work for any client (web, desktop, TUI) without modification

A file-based bridge would be inventing a new transport when the HTTP transport already exists and works. Instead, we reuse the agent server from `ai_ui/server.jac` — the same typed endpoints the web frontend calls.

### Why NOT in-process

The current broken TUI runs the agent and the rendering in the same Python process. This is why it has to do manual ANSI redraws — Python can't run a React/Ink render loop.

The desktop and web UIs correctly separate the two:

- **Agent** = Python process (owns `agent`, `agent_model`, event bus, tools)
- **Rendering** = separate process (browser webview or Ink Node.js)

The Ink TUI follows the same separation.

---

## Detailed Architecture

### Process topology

```
Parent (jac ai --tui)
│
├─ Child 1: Agent server (Python)
│  cwd: jac/jaclang/cli/ai_tui_server/  (bundled server app)
│  cmd: python -m jaclang start main.jac --port 0
│  env: JAC_AI_TUI_PROJECT, JAC_AI_TUI_MODEL, JAC_AI_TUI_NCTX
│  stdout → parent reads for "JAC_AI_TUI_PORT=<n>"
│  Serves: agent_poll, agent_send, agent_stream, agent_graph,
│          agent_reset, agent_stop, agent_settings, agent_apply_settings
│
└─ Child 2: Ink TUI (Node.js)
   cwd: jac-super/jac_super/ai_tui_ink/  (bundled .cl.jac app)
   cmd: node .jac/tui/runner.mjs
   env: JAC_TUI_API_URL=http://127.0.0.1:<port>
   Reads from agent server via fetch (like web frontend)
   Writes to agent server via fetch (like web frontend)
```

This is **identical** to `_run_ui_server()` except:

- `_run_ui_server()` uses `jac start main.jac` (jac-client web server) + opens browser
- TUI launcher uses `jac start main.jac` (jac-scale HTTP server) + launches Ink process

### Agent server app

The agent server is a minimal `main.jac` that reuses the existing `ai_ui/server.jac` endpoints. We can either:

**Option A (recommended): Reuse `ai_ui/server.jac` directly**

The web UI server already has all the endpoints we need (`agent_poll`, `agent_send`, `agent_stream`, etc.) and the typed view objects. The TUI can call the exact same endpoints. We just need a thin `main.jac` entry that boots the server.

```jac
# jac_super/ai_tui_server/main.jac
"""Agent server for the Ink TUI client.

Reuses the same server endpoints as the web UI (agent_poll, agent_send, etc.)
but runs without the frontend -- the Ink TUI connects as an HTTP client.
"""

# Import the server endpoints so jac-scale serves them
import from jaclang.cli.ai_ui.server {
    agent_poll,
    agent_send,
    agent_reset,
    agent_stop,
    agent_stream,
    agent_graph,
    agent_settings,
    agent_apply_settings,
    agent_call_detail,
    agent_phase_context
}
```

**Option B: Create a TUI-specific server**

Duplicate the relevant endpoints from `ai_ui/server.jac` into a new `tui_server.jac`. This gives more control but duplicates code.

**Recommendation**: Option A. The server endpoints are stable and generic — they don't know or care whether the client is a browser or an Ink TUI.

### Ink TUI client app

The Ink TUI client follows the same architecture as `ai_ui/frontend.cl.jac` — state management, event streaming, and UI components — but renders to a terminal instead of a browser DOM.

```
ai_tui_ink/
  main.cl.jac              ← entry: def:pub app()
  jac.toml                 ← entry-point = main.cl.jac
  components/
    App.cl.jac             ← root layout, state, stream loop
    Conversation.cl.jac    ← event feed (like web UI's Conversation)
    InputBar.cl.jac        ← text input with useInput
    StatusBar.cl.jac       ← phase/status/model strip (like StatsBar)
    PhaseGraph.cl.jac      ← ASCII phase graph (like PhaseGraph)
    ActivityFeed.cl.jac    ← tool events pane
    HelpPanel.cl.jac       ← slash command help
  lib/
    agent.cl.jac           ← HTTP client wrapping agent_* endpoints
    commands.cl.jac        ← slash command parser
```

### Transport: HTTP (same as web UI)

The Ink TUI calls the same agent endpoints as the web frontend. Since jac-ink runs in Node.js, we use `fetch` directly (Node 22+ has native fetch):

```jac
# lib/agent.cl.jac
import from "fs" { readFileSync }

# API URL passed via env at launch
glob API_URL = "";
with entry {
    API_URL = str(process.env.JAC_TUI_API_URL or "");
}

def agent_send(prompt: str) -> bool {
    resp = fetch(
        API_URL + "/function/agent_send",
        {"method": "POST", "headers": {"Content-Type": "application/json"},
         "body": JSON.stringify({"prompt": prompt})}
    );
    data = resp.json();
    return bool(data);
}

def agent_poll -> dict {
    resp = fetch(
        API_URL + "/function/agent_poll",
        {"method": "POST", "headers": {"Content-Type": "application/json"},
         "body": "{}"}
    );
    return resp.json();
}

def agent_stop -> bool {
    resp = fetch(API_URL + "/function/agent_stop", {"method": "POST", "body": "{}"});
    return bool(resp.json());
}

def agent_reset -> bool {
    resp = fetch(API_URL + "/function/agent_reset", {"method": "POST", "body": "{}"});
    return bool(resp.json());
}
```

For streaming, we can either:

- **Poll `agent_poll`** on a timer (simpler, 200ms latency is fine for M1)
- **Read `agent_stream` SSE** from Node.js (lower latency, same as web UI)

### Launcher (run_tui_session.impl.jac)

The launcher follows `_run_ui_server()` exactly:

```python
def run_tui_session(req):
    # 1. Set env vars for the agent server
    env = dict(os.environ)
    env["JAC_AI_UI_PROJECT"] = agent.ws.cwd
    env["JAC_AI_UI_MODEL"] = str(req.model or "")
    env["JAC_AI_UI_NCTX"] = str(int(req.n_ctx or 0))

    # 2. Find the bundled server app
    server_dir = Path(jaclang.__file__).parent / "cli" / "ai_ui"
    # Or: server_dir = Path(jac_super.__file__).parent / "ai_tui_server"

    # 3. Spawn the agent server (child process)
    server_proc = subprocess.Popen(
        [sys.executable, "-m", "jaclang", "start", "main.jac", "--port", "0"],
        cwd=str(server_dir),
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, env=env, start_new_session=True
    )

    # 4. Read JAC_SIDECAR_PORT or URL from server stdout
    #    (same pattern as desktop's _start_sidecar)
    api_url = discover_server_url(server_proc)

    # 5. Compile the Ink TUI (first time or if stale)
    ink_dir = Path(jac_super.__file__).parent / "ai_tui_ink"
    ensure_ink_compiled(ink_dir)

    # 6. Spawn the Ink TUI (child process)
    tui_env = dict(os.environ)
    tui_env["JAC_TUI_API_URL"] = api_url
    tui_proc = subprocess.Popen(
        ["node", str(ink_dir / ".jac/tui/runner.mjs")],
        cwd=str(ink_dir), env=tui_env
    )

    # 7. Wait for TUI to exit, then clean up
    try:
        tui_proc.wait()
    except KeyboardInterrupt:
        pass
    finally:
        tui_proc.terminate()
        server_proc.terminate()
    return 0
```

This is a **direct structural copy** of `_run_ui_server()` — env vars, child process, URL discovery, wait/cleanup — with the browser open replaced by an Ink process launch.

---

## File Structure Changes

### Delete (replaced by Ink components)

```
jac_super/ai_tui/
  app.jac                  → replaced by Ink App.cl.jac
  state.jac                → replaced by React has/state in Ink components
  keys.jac                 → replaced by useInput in InputBar.cl.jac
  view.jac                 → replaced by Ink Box/Text components
  commands.jac             → replaced by lib/commands.cl.jac
  impl/
    app.impl.jac           → replaced
    state.impl.jac         → replaced
    view.impl.jac          → replaced
    commands.impl.jac      → replaced
```

### Add: Ink TUI app

```
jac_super/ai_tui_ink/
  main.cl.jac              ← Ink entry point
  jac.toml                 ← project config (entry-point = main.cl.jac)
  components/
    App.cl.jac             ← root layout + state + stream loop
    Conversation.cl.jac    ← event feed (like web Conversation)
    InputBar.cl.jac        ← useInput-based text entry
    StatusBar.cl.jac       ← status/phase/model/stats strip
    PhaseGraph.cl.jac      ← ASCII phase graph
    ActivityFeed.cl.jac    ← tool events
    HelpPanel.cl.jac       ← slash command help
  lib/
    agent.cl.jac           ← HTTP client for agent_* endpoints
    commands.cl.jac        ← slash command parser
```

### Add: Agent server entry (thin)

```
jac_super/ai_tui_server/
  main.jac                 ← re-exports server.jac endpoints
  jac.toml                 ← project config
```

Or: reuse `jaclang/cli/ai_ui/main.jac` directly (no new files needed if the server already works as-is).

### Modify: launcher

```
jac_super/ai_agent/
  run_tui_session.jac           ← keep interface
  impl/run_tui_session.impl.jac ← rewrite: spawn server + spawn ink (like _run_ui_server)
```

### Keep unchanged

```
jac_super/ai_modes/              ← mode registry stays the same
jac_super/ai_modes/tui_mode.jac  ← still calls run_tui_session
jac_super/shadcn/                ← unrelated
jac_super/plugin/                ← unrelated
jac/jaclang/cli/ai_ui/server.jac ← reused as-is for agent endpoints
jac/jaclang/cli/ai_agent.jac     ← ui_* bridge unchanged
jac/jaclang/cli/ai_agent/impl/   ← bridge impl unchanged
```

---

## Step-by-Step Implementation

### Step 1: Install jac-ink as a dependency

- Add `jac-ink` to `jac-super/jac.toml` as a pip dependency (or ensure it's installed in the same venv).
- Verify `jac jac2ink` and `jac tui` commands are available.

### Step 2: Verify the agent server works standalone

- Test that `python -m jaclang start main.jac --port 0` works from the `ai_ui/` directory
- Verify that `agent_poll`, `agent_send`, etc. respond over HTTP
- This confirms we can reuse the existing server without changes

### Step 3: Create the Ink TUI HTTP client library

Create `ai_tui_ink/lib/agent.cl.jac`:

- `API_URL` glob read from `process.env.JAC_TUI_API_URL`
- `agent_poll()` → fetch POST to `/function/agent_poll`
- `agent_send(prompt)` → fetch POST to `/function/agent_send`
- `agent_stop()` → fetch POST to `/function/agent_stop`
- `agent_reset()` → fetch POST to `/function/agent_reset`
- `agent_settings()` → fetch POST to `/function/agent_settings`
- `agent_apply_settings(...)` → fetch POST to `/function/agent_apply_settings`

These are Node.js `fetch` calls (available in Node 22+), identical to what the web frontend does via the compiler's `sv import` RPC wiring, but explicit since jac-ink doesn't have `sv import`.

### Step 4: Build the Ink TUI components

#### `main.cl.jac` — entry point

```jac
"""Jac AI TUI — Ink terminal client."""
import from .components.App { App }

def:pub app() -> JsxElement {
    return <App/>;
}
```

#### `App.cl.jac` — root layout + state + poll loop

Follows `ai_ui/frontend.cl.jac` structure: holds all state, drives the update loop, renders child components.

```jac
import from "ink" { Box }
import from .Conversation { Conversation }
import from .StatusBar { StatusBar }
import from .InputBar { InputBar }
import from ..lib.agent { agent_poll, agent_send, agent_stop, agent_reset }

def:pub App() -> JsxElement {
    has events: list = [],
        status: str = "idle",
        active: str = "",
        model: str = "",
        draft: str = "";

    # Poll loop — same role as the web frontend's SSE stream
    useEffect(lambda {
        interval = setInterval(lambda {
            snap = agent_poll();
            events = snap.events;
            status = snap.status;
            active = snap.active;
            model = snap.model_name;
        }, 200);
        return lambda { clearInterval(interval); };
    }, []);

    def send {
        text = draft.strip();
        if not text { return; }
        draft = "";
        agent_send(text);
    }

    def stop { agent_stop(); }
    def reset { agent_reset(); events = []; status = "idle"; }

    return (
        <Box flexDirection="column" padding={1}>
            <StatusBar {status} {active} {model}/>
            <Conversation {events}/>
            <InputBar
                draft={draft}
                onDraftChange={lambda v { draft = v; }}
                onSend={send}
                onStop={stop}
                onReset={reset}
            />
        </Box>
    );
}
```

#### `StatusBar.cl.jac`

```jac
import from "ink" { Box, Text }

def:pub StatusBar(props: any) -> JsxElement {
    status = props.status or "idle";
    active = props.active or "";
    model = props.model or "";

    return (
        <Box borderStyle="single" borderColor="cyan" paddingLeft={1} paddingRight={1}>
            <Text bold>{status}</Text>
            <Text> | </Text>
            <Text color="yellow">{active or "Ready"}</Text>
            <Text> | </Text>
            <Text dimColor>{model}</Text>
        </Box>
    );
}
```

#### `Conversation.cl.jac`

```jac
import from "ink" { Box, Text }

def:pub Conversation(props: any) -> JsxElement {
    events: list = list(props.events or []);

    return (
        <Box flexDirection="column" marginTop={1} flexGrow={1}>
            {events.map(lambda (ev) {
                kind = str(ev.kind or "");
                text = str(ev.text or "");
                color = "red" if kind == "error" else
                        "cyan" if kind == "tool" else
                        "green" if kind == "answer" else "white";
                return <Text color={color}>{kind} &gt; {text}</Text>;
            })}
        </Box>
    );
}
```

#### `InputBar.cl.jac`

```jac
import from "ink" { Box, Text, useInput, useApp }

def:pub InputBar(props: any) -> JsxElement {
    has draft: str = props.draft or "";
    onDraftChange: any = props.onDraftChange;
    onSend: any = props.onSend;
    onStop: any = props.onStop;
    onReset: any = props.onReset;
    has { exit } = useApp();

    useInput(lambda (input, key) {
        if key.escape {
            onStop();
        } elif key.return {
            text = draft.strip();
            if text == "/exit" or text == "/quit" {
                exit();
            } elif text == "/stop" {
                onStop();
            } elif text == "/reset" {
                onReset();
            } elif text.startswith("/") {
                # TODO: handle other slash commands
            } elif text {
                onSend(text);
            }
            draft = "";
            onDraftChange("");
        } elif key.backspace or key.delete {
            if len(draft) > 0 {
                draft = draft[:-1];
                onDraftChange(draft);
            }
        } else {
            draft = draft + input;
            onDraftChange(draft);
        }
    });

    return (
        <Box borderStyle="single" borderColor="gray" paddingLeft={1}>
            <Text bold color="cyan">&gt; </Text>
            <Text>{draft}</Text>
            <Text dimColor>▌</Text>
        </Box>
    );
}
```

### Step 5: Rewrite the launcher

Rewrite `run_tui_session.impl.jac` to follow `_run_ui_server()`:

1. Set env vars (`JAC_AI_UI_PROJECT`, `JAC_AI_UI_MODEL`, `JAC_AI_UI_NCTX`)
2. Find the `ai_ui/` server directory
3. Spawn `python -m jaclang start main.jac --port 0` as a child process
4. Read URL from child stdout (same URL discovery as `_run_ui_server`)
5. Compile the Ink TUI (call `jac2ink` if not already compiled)
6. Spawn `node .jac/tui/runner.mjs` with `JAC_TUI_API_URL` env var
7. Wait for Ink process, clean up both children

### Step 6: Clean up deleted files

Remove the old `ai_tui/` directory and its `impl/` subdirectory. The only import is in `run_tui_session.impl.jac`, which is being rewritten.

### Step 7: Update tests

- `test_ai_tui_bridge.jac` — update to test agent server endpoints over HTTP
- `test_ai_tui_commands.jac` — update to test slash commands via HTTP
- `test_ai_tui_state.jac` — delete (state is now in React/Ink)
- `test_console_renderer.jac` — delete (rendering is now Ink's job)
- `test_console_capability.jac` — update if it tests TUI mode launch
- Add: test that `jac2ink` compilation succeeds for `ai_tui_ink/`
- Add: integration test that agent server boots and responds to `agent_poll`

---

## How This Differs From the Web UI

| Aspect | Web UI | Ink TUI |
|--------|--------|---------|
| Agent server | Same (`ai_ui/server.jac` via `jac start main.jac`) | Same |
| Transport | HTTP + SSE (via `sv import` compiler wiring) | HTTP (explicit `fetch` in `lib/agent.cl.jac`) |
| Frontend | React DOM (browser, `jac-client` Vite) | React Ink (terminal, `jac-ink` Node.js) |
| Rendering | Browser DOM + CSS | Ink `Box`/`Text` (terminal flexbox) |
| Input | HTML `<input>` + `<textarea>` | Ink `useInput` |
| Streaming | SSE (`EventSource` / `fetch` body reader) | Poll `agent_poll` on timer (M1); SSE later |
| Entry point | `jac start main.jac` (serves frontend + API) | `jac start main.jac` (API only) + `node runner.mjs` (TUI) |

The **only** meaningful difference is the frontend rendering target. Everything behind the agent server is identical.

---

## Dependencies

| Dependency | Source | Purpose |
|-----------|--------|---------|
| jac-ink | `~/repos/jac-tui/jac-ink` | Compile `.cl.jac` → Ink app |
| jac-scale | (existing in jac) | HTTP server for agent endpoints |
| ink | npm (auto by jac-ink) | Terminal React renderer |
| react | npm (auto by jac-ink) | Component model |
| Node.js 22+ | system | Ink runtime + native fetch |

---

## Milestones

### M1: Agent server + minimal Ink TUI

- [ ] Install jac-ink in this repo's venv
- [ ] Verify agent server works standalone (`jac start main.jac` from `ai_ui/`)
- [ ] Create `ai_tui_ink/` with `main.cl.jac`, `jac.toml`
- [ ] Create `lib/agent.cl.jac` (HTTP client)
- [ ] Create minimal `App.cl.jac` (poll + status + events display)
- [ ] Rewrite `run_tui_session.impl.jac` to spawn server + Ink process
- [ ] Verify `jac ai --tui` launches, shows live agent events

**Acceptance**: `jac ai --tui` starts an agent server and an Ink TUI that displays live events.

### M2: Interactive TUI with input

- [ ] Add `InputBar.cl.jac` with `useInput` for prompt entry
- [ ] Add `agent_send` / `agent_stop` / `agent_reset` integration
- [ ] Add slash command parser (`/help`, `/stop`, `/reset`, `/exit`)
- [ ] Add `StatusBar.cl.jac` with phase, model, mode, tool count
- [ ] Verify prompt → agent → events → TUI roundtrip

**Acceptance**: Full interactive session — type prompt, see streaming response, use slash commands.

### M3: Parity + polish

- [ ] Port all slash commands (`/model`, `/mode`, `/context-max`, `/compact`, `/usage`, `/stats`, `/guides`, `/mcp`)
- [ ] Add `PhaseGraph.cl.jac` (ASCII phase visualization)
- [ ] Add `ActivityFeed.cl.jac` (tool events pane)
- [ ] Add `HelpPanel.cl.jac` overlay
- [ ] Compact mode toggle
- [ ] Switch from polling to SSE stream for lower latency
- [ ] Update all tests
- [ ] Delete old `ai_tui/` directory

**Acceptance**: Ink TUI has full feature parity with the web UI for terminal workflows.

---

## Risks

| Risk | Mitigation |
|------|-----------|
| Ink `useInput` cursor/echo handling is limited | Ink 4+ supports `useFocus`; if needed, add an Ink TextInput component |
| Polling latency vs SSE | Start with 200ms poll; web UI already proves the endpoints work for SSE, switch later |
| jac-ink JSX limitations (no conditional rendering) | Use ternary expressions or helper functions; see `docs/LIMITATIONS.md` |
| Agent server port discovery | Reuse the exact pattern from `_run_ui_server()` (read URL from stdout) |
| Two child processes to manage | Reuse desktop's cleanup pattern (terminate both, wait with timeout) |
| `fetch` in Node.js `.cl.jac` code | Node 22+ has native fetch; jac-ink compiles to Node.js, not browser |

## Non-Changes

- No changes to `ai_agent.jac` core (tools, phases, event bus)
- No changes to `ui_*` bridge functions
- No changes to `ai_ui/server.jac` endpoints (reused as-is)
- No changes to `--ui` web mode
- No changes to one-shot prompt behavior
- No changes to mode registry architecture (`ai_modes/`)
- No changes to jac-ink plugin itself (used as-is via `jac2ink` / `jac tui`)
