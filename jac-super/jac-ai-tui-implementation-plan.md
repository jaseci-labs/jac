# Jac AI Ink TUI — Implementation Plan

## Decision (locked)

**`jac ai --tui` is the Ink TUI only.** The hand-rolled Python package
(`jac_super/ai_tui/`) is legacy scaffolding to be **removed** once Ink reaches
parity. There is **no** long-term fallback to the in-process Python renderer.

Requirements for `--tui`:

- Node.js ≥ 22 (native `fetch`)
- `jac2ink` (via `python -m jaclang jac2ink`)
- npm (first-run install of Ink deps under `ai_tui_ink/.jac/tui/`)

If the toolchain is missing or the pipeline fails, `run_tui_session` exits with
a clear error — it does not silently degrade to Python.

## Phases

| Phase | Goal | Status |
|-------|------|--------|
| **A — Pipeline boots** | Server + `jac2ink` + `node runner.mjs` works reliably; launcher hardened | In progress |
| **B — Client parity** | Event semantics, slash commands, server endpoints for mode/guides/mcp | Not started |
| **C — Polish** | Input history, SSE streaming, delete `ai_tui/` | Not started |

### Phase A (current)

1. Spike checklist (server, poll, jac2ink, node, cleanup)
2. Launcher: port file, stderr merge, compile cache, fail-fast
3. Single Ink entry: `runtime.cl.jac` until jac2ink multi-file is fixed
4. Use `jac start --no_client` for the real server transport path

### Phase B

- Port event processing from Python TUI (`feedSinceId`, tool `#N` labels)
- Wire `/mode`, `/verbose`, `/feedback`, `/guides`, `/mcp` via sidecar endpoints
- Consolidate `runtime.cl.jac` ↔ modular tree when jac2ink allows

### Phase C

- Optional SSE (`agent_stream`)
- Delete `jac_super/ai_tui/` and Python-only tests
- Document Node/jac2ink deps in jac-super README

## Approach

Two child processes managed by a Python launcher:

```
jac ai --tui
  └─ run_tui_session(req)              # Python launcher (replaces current impl)
       ├─ jac start main.jac --no_client --port 0   # Agent API server (child 1)
       └─ node runner.mjs               # Ink TUI (child 2)
```

The agent server is the core `jac start` command with `--no_client` — no jac-client, no Vite, no npm. Just Jac compilation + bare HTTP server exposing `agent_*` endpoints.

The Ink TUI is compiled from `.cl.jac` files via `jac2ink` and runs as a Node.js process.

---

## File Map

### New files (create)

```
jac_super/
├── ai_tui_server/                      # Agent API server entry
│   ├── jac.toml                        # Project config (name + entry-point)
│   └── main.jac                        # Thin import of server.jac endpoints
│
├── ai_tui_ink/                         # Ink TUI app (compiled by jac2ink)
│   ├── jac.toml                        # Project config (name + entry-point + npm deps)
│   ├── runtime.cl.jac                  # **Launcher entry** (monolith until jac2ink multi-file works)
│   ├── main.cl.jac                     # Modular target (not used by launcher yet)
│   ├── lib/
│   │   ├── agent.cl.jac                # HTTP client: poll/send/reset/stop/settings
│   │   ├── state.cl.jac                # App state: events, status, draft, tool tracking
│   │   ├── poll.cl.jac                 # Poll loop: setInterval + process events
│   │   └── input.cl.jac               # Input handler: useInput + command parsing
│   └── components/
│       ├── Banner.cl.jac               # Title bar (cwd, model)
│       ├── StatusBar.cl.jac            # Phase + status + spinner
│       ├── StatsLine.cl.jac            # Token counts, context bar
│       ├── Transcript.cl.jac           # Scrolling event list
│       ├── InputBar.cl.jac             # Draft display + prompt indicator
│       └── HelpOverlay.cl.jac          # Slash-command reference
│
├── ai_agent/
│   ├── run_tui_session.jac             # (overwrite existing) new signature
│   └── impl/
│       └── run_tui_session.impl.jac    # (overwrite existing) new impl: launcher
```

### Existing files (modify)

```
jac_super/ai_modes/impl/tui_mode.impl.jac   # Unchanged — already delegates to run_tui_session
```

### Files to delete (Phase C — after Ink parity)

```
jac_super/ai_tui/                            # Entire legacy Python TUI (replaced by ai_tui_ink)
├── app.jac
├── state.jac
├── view.jac
├── keys.jac
├── commands.jac
└── impl/
    ├── app.impl.jac
    └── view.impl.jac
```

---

## Milestone 1: Minimal End-to-End

**Goal**: `jac ai --tui` boots an agent server, launches an Ink app that shows events, accepts input, and sends prompts.

### Step 1.1 — Create the agent server entry

**File**: `jac_super/ai_tui_server/jac.toml`

```toml
[project]
name = "jac-ai-tui-server"
version = "0.1.0"
description = "Agent API server for the Ink TUI"
entry-point = "main.jac"
```

**File**: `jac_super/ai_tui_server/main.jac`

Import only the server-side endpoints from `ai_ui/server.jac`. No `cl` imports, no frontend code. The `with entry { ui_configure() }` block in `server.jac` runs automatically on import, booting the agent.

```jac
"""Agent API server for the Ink TUI.

Re-exports the HTTP endpoints from ai_ui/server so `jac start --no_client`
discovers them as POST /function/<name> routes. The `with entry` block in
server.jac runs ui_configure() on import, which boots the agent using
env vars set by the launcher (JAC_AI_UI_PROJECT, etc.).
"""
import from jaclang.cli.ai_ui.server {
    agent_poll,
    agent_send,
    agent_reset,
    agent_stop,
    agent_settings,
    agent_apply_settings
}
```

**Verification**: From the repo root:

```bash
cd jac_super/ai_tui_server
JAC_AI_UI_PROJECT=/tmp/test jac start main.jac --no_client --port 0
# Should print: "Jac API Server running on http://0.0.0.0:<port>"
# Then: curl http://127.0.0.1:<port>/function/agent_poll → should return JSON
```

### Step 1.2 — Create the HTTP client library

**File**: `jac_super/ai_tui_ink/lib/agent.cl.jac`

Wraps `fetch` calls to the agent server. Uses `process.env.JAC_TUI_API_URL` set by the launcher.

```jac
"""HTTP client for the agent API server."""

glob BASE: str = process.env.JAC_TUI_API_URL or "";

def agent_fetch(endpoint: str, body: any = {}) -> any {
    resp = fetch(
        BASE + "/function/" + endpoint,
        {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify(body)
        }
    );
    return resp.json();
}

def poll -> any {
    return agent_fetch("agent_poll");
}

def send(prompt: str) -> bool {
    return agent_fetch("agent_send", {"prompt": prompt});
}

def reset -> bool {
    return agent_fetch("agent_reset");
}

def stop -> bool {
    return agent_fetch("agent_stop");
}

def settings -> any {
    return agent_fetch("agent_settings");
}

def apply_settings(
    model: str, api_key: str, base_url: str,
    temperature: str, n_ctx: str
) -> any {
    return agent_fetch("agent_apply_settings", {
        "model": model, "api_key": api_key, "base_url": base_url,
        "temperature": temperature, "n_ctx": n_ctx
    });
}
```

**Risk**: `fetch`, `JSON.stringify`, `process.env` in compiled `.cl.jac` — these are Node.js globals. jac-ink's compilation doesn't shim them. They should pass through as-is since jac-ink emits standard JS and Node 22+ has native `fetch`.

### Step 1.3 — Create the Ink TUI entry

**File**: `jac_super/ai_tui_ink/jac.toml`

```toml
[project]
name = "jac-ai-tui"
version = "0.1.0"
description = "Ink-based TUI for Jac AI"
entry-point = "main.cl.jac"

[dependencies.npm]
ink = "^7.0.3"
react = "^19.2.4"
ink-text-input = "^6.0.0"
```

**File**: `jac_super/ai_tui_ink/main.cl.jac`

Minimal M1 app: poll loop, event display, text input, send.

```jac
"""Jac AI Ink TUI — minimal viable client."""
import from "ink" { Box, Text, useApp, useInput }
import from "ink-text-input" { TextInput }
import from .lib.agent { poll, send, stop, reset }
import from .lib.state { AppState }
import from .lib.poll { startPolling, stopPolling }
import from .lib.input { handleKey }

def:pub app() -> JsxElement {
    has status: str = "idle",
        events: list[any] = [],
        draft: str = "",
        feedSinceId: int = 0;

    app_state = AppState(events=events, feedSinceId=feedSinceId);

    useInput(lambda (input: str, key: any) -> None {
        handleKey(input, key, app_state, {
            "setStatus": lambda s: str { status = s; },
            "setDraft": lambda d: str { draft = d; },
            "setEvents": lambda e: list { events = e; },
            "setFeedSinceId": lambda n: int { feedSinceId = n; }
        });
    });

    startPolling(app_state, {
        "setStatus": lambda s: str { status = s; },
        "setEvents": lambda e: list { events = e; }
    });

    spinner = "●" if status == "running" else "○";
    color = "green" if status == "done" else (
        "cyan" if status == "running" else "yellow" if status == "error" else "dim"
    );

    return (
        <Box flexDirection="column" padding={1}>
            <Box marginBottom={1}>
                <Text bold color="magenta">jac</Text>
                <Text bold color="cyan">.ai</Text>
                <Text> </Text>
                <Text color={color}>{spinner} {status}</Text>
            </Box>
            <Box flexDirection="column" marginBottom={1}>
                {events.map(lambda (ev: any) -> any {
                    kind = str(ev.get("kind", ""));
                    text = str(ev.get("text", ""));
                    if not text { return None; }
                    c = "green" if kind == "answer" else (
                        "yellow" if kind == "tool" else (
                            "blue" if kind == "reasoning" else "dim"
                        )
                    );
                    return <Text color={c}>{kind}: {text}</Text>;
                })}
            </Box>
            <Box borderStyle="single" borderColor="gray" paddingLeft={1}>
                <Text color="cyan">&gt; </Text>
                <TextInput value={draft} onChange={lambda v: str { draft = v; }} onSubmit={
                    lambda v: str {
                        if v.strip() {
                            send(v.strip());
                        }
                        draft = "";
                    }
                } />
            </Box>
        </Box>
    );
}
```

**Note on `ink-text-input`**: This gives us proper single-line text editing (cursor movement, backspace, delete). It's the official Ink input component. We lose readline history/tab-completion but gain Ink-native rendering. History and commands can be layered on top in later milestones.

### Step 1.4 — Create the state library

**File**: `jac_super/ai_tui_ink/lib/state.cl.jac`

```jac
"""TUI application state container."""

class AppState {
    has events: list[any] = [],
        feedSinceId: int = 0,
        toolSeq: int = 1,
        toolLabels: dict[int, str] = {};
}
```

### Step 1.5 — Create the poll loop

**File**: `jac_super/ai_tui_ink/lib/poll.cl.jac`

```jac
"""Polling loop for the agent API."""
import from .agent { poll }

glob _timer: any = None;

def startPolling(state: any, setters: any) -> None {
    if _timer is not None { return; }
    _timer = setInterval(lambda {
        try {
            snap = poll();
            setters["setStatus"](snap.status);
            events = snap.events;
            newEvents: list[any] = [];
            for ev in events {
                eid = int(ev.id or 0);
                if eid <= state.feedSinceId { continue; }
                newEvents.append(ev);
            }
            if len(newEvents) > 0 {
                setters["setEvents"](events);
            }
        } except Exception { }
    }, 200);
}

def stopPolling -> None {
    if _timer is not None {
        clearInterval(_timer);
        _timer = None;
    }
}
```

### Step 1.6 — Create the input handler

**File**: `jac_super/ai_tui_ink/lib/input.cl.jac`

```jac
"""Key/input handler for the TUI."""
import from "ink" { useApp }
import from .agent { send, stop, reset }

def handleKey(
    input: str, key: any, state: any, setters: any
) -> None {
    # Ctrl+C handling is automatic via Ink's useApp
    # Escape stops the running turn
    if key.escape {
        stop();
        return;
    }
}
```

### Step 1.7 — Rewrite the launcher

**File**: `jac_super/ai_agent/run_tui_session.jac` (overwrite)

```jac
"""TUI session entry point for `jac ai --tui`.

Spawns an agent API server (jac start --no_client) and an Ink TUI process,
passing the server URL via an env var.
"""

def run_tui_session(req: object) -> int;
```

**File**: `jac_super/ai_agent/impl/run_tui_session.impl.jac` (overwrite)

```jac
"""Launcher: spawn agent API server + Ink TUI, manage lifecycle."""
import os, re, sys, time, signal, subprocess;
import jaclang;
import jac_super;
import from pathlib { Path }
import from jaclang.cli.console { console }

impl run_tui_session(req: object) -> int {
    r: any = req;

    # --- Resolve paths ---
    super_pkg = Path(jac_super.__file__).parent;
    server_dir = str(super_pkg / "ai_tui_server");
    ink_dir = str(super_pkg / "ai_tui_ink");
    ink_out = str(Path(ink_dir) / ".jac" / "tui");

    server_entry = os.path.join(server_dir, "main.jac");
    if not os.path.exists(server_entry) {
        console.error(f"TUI server entry not found: {server_entry}");
        return 1;
    }

    # --- Set agent env vars (same as web UI launcher) ---
    env = dict(os.environ);
    env["JAC_AI_UI_PROJECT"] = os.path.normpath(str(r?.cwd or os.getcwd()));
    env["JAC_AI_UI_MODEL"] = str(r?.model or "");
    env["JAC_AI_UI_NCTX"] = str(int(r?.n_ctx or 0));

    # --- Step 1: Spawn agent API server (no Vite, no npm) ---
    server_proc: any = None;
    api_url = "";
    try {
        server_proc = subprocess.Popen(
            [sys.executable, "-m", "jaclang", "start", "main.jac",
             "--no_client", "--port", "0"],
            cwd=server_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=env,
            start_new_session=True
        );
        # Read stdout until we see the port line
        url_re = re.compile(r"http://0\.0\.0\.0:(\d+)");
        deadline = time.time() + 30;
        while time.time() < deadline {
            if server_proc.poll() is not None {
                break;
            }
            line = server_proc.stdout.readline();
            m = url_re.search(line);
            if m {
                port = int(m.group(1));
                api_url = f"http://127.0.0.1:{port}";
                break;
            }
        }
    } except Exception as e {
        console.error(f"Failed to start agent server: {e}");
        return 1;
    }

    if not api_url {
        console.error("Agent server did not start within 30s");
        if server_proc and server_proc.poll() is not None {
            stderr = server_proc.stderr.read();
            console.print(stderr, style="muted");
        }
        if server_proc {
            try { os.killpg(os.getpgid(server_proc.pid), signal.SIGTERM); } except {}
        }
        return 1;
    }

    # --- Step 2: Compile Ink TUI ---
    compile_ret = subprocess.call(
        [sys.executable, "-m", "jaclang", "jac2ink",
         "main.cl.jac", "--out", ink_out, "--no_run"],
        cwd=ink_dir
    );
    if compile_ret != 0 {
        console.error("Ink TUI compilation failed");
        try { os.killpg(os.getpgid(server_proc.pid), signal.SIGTERM); } except {}
        return 1;
    }

    # --- Step 3: npm install (if needed) ---
    node_modules = os.path.join(ink_out, "node_modules");
    if not os.path.exists(node_modules):
        install_ret = subprocess.call(
            ["npm", "install", "--ignore-scripts"],
            cwd=ink_out
        );
        if install_ret != 0 {
            console.error("npm install failed for Ink TUI");
            try { os.killpg(os.getpgid(server_proc.pid), signal.SIGTERM); } except {}
            return 1;
        }

    # --- Step 4: Launch Ink TUI ---
    tui_env = dict(os.environ);
    tui_env["JAC_TUI_API_URL"] = api_url;

    tui_proc: any = None;
    try {
        tui_proc = subprocess.Popen(
            ["node", "runner.mjs"],
            cwd=ink_out,
            env=tui_env
        );
    } except Exception as e {
        console.error(f"Failed to launch Ink TUI: {e}");
        try { os.killpg(os.getpgid(server_proc.pid), signal.SIGTERM); } except {}
        return 1;
    }

    # --- Step 5: Wait for TUI, then clean up ---
    code = 0;
    try {
        code = tui_proc.wait();
    } except KeyboardInterrupt {
        console.print("\nStopping TUI…", style="muted");
    }
    finally {
        if tui_proc and tui_proc.poll() is None {
            tui_proc.terminate();
            try { tui_proc.wait(timeout=5); } except { tui_proc.kill(); }
        }
        if server_proc and server_proc.poll() is None {
            try { os.killpg(os.getpgid(server_proc.pid), signal.SIGTERM); } except {}
        }
    }
    return code;
}
```

### Step 1.8 — Wire it up (no change needed)

`tui_mode.impl.jac` already delegates to `run_tui_session(req)` — no changes needed.

### M1 Verification

```bash
# From the jac-ai-tui repo root
cd /home/jac/repos/jac-ai-tui

# 1. Verify agent server boots standalone
JAC_AI_UI_PROJECT=/tmp/test python -m jaclang start jac_super/ai_tui_server/main.jac --no_client --port 0

# 2. Verify Ink compilation
cd jac_super/ai_tui_ink && jac jac2ink main.cl.jac --no_run && cd ../..

# 3. End-to-end test
jac ai --tui --model openai/gpt-4o-mini "hello"
```

**M1 delivers**: Agent boots, events render, user can type prompts, see responses stream in.

---

## Milestone 2: Command Parity

**Goal**: All slash commands from the current Python TUI work in the Ink TUI.

### Slash commands to implement

| Command | Current | Ink approach |
|---------|---------|-------------|
| `/help` | Toggle help panel | Toggle `<HelpOverlay>` component |
| `/model [name]` | Show/switch model | Call `agent_settings` / `agent_apply_settings` |
| `/mode safe\|yolo` | Toggle approvals | Call `agent_apply_settings` (needs new endpoint or flag) |
| `/context-max [n]` | Show/set context | Call `agent_apply_settings` |
| `/compact [on\|off]` | Toggle layout | Toggle component visibility in Ink |
| `/reset` | Clear session | Call `agent_reset` + clear state |
| `/clear` | Clear display | Clear events array |
| `/stop` | Stop running turn | Call `agent_stop` |
| `/usage` | Toggle usage panel | Toggle `<StatsLine>` visibility |
| `/mcp` | Show MCP status | Read from poll result |

### Implementation

Extend `input.cl.jac` to parse slash commands when the draft starts with `/`. On Enter:

- If draft starts with `/`, parse command, call agent API, update state
- Otherwise, call `agent_send(draft)`

Add `HelpOverlay.cl.jac` — a collapsible `<Box>` listing commands.
Add `StatsLine.cl.jac` — token counts, context bar (reuse logic from `view.jac`).

---

## Milestone 3: Rich Event Display

**Goal**: Events render with proper styling, wrapping, and categorization.

### Components

- **`Transcript.cl.jac`**: Scrollable event list with:
  - Answer text (green, full width)
  - Tool calls (yellow, with `#N` labels)
  - Tool results (dim, truncated)
  - Reasoning (blue, italic)
  - Phase transitions (system messages)
  - System/info messages (dim)

- **`StatusBar.cl.jac`**: Status bar with:
  - Spinner (animated for "running")
  - Phase name and path
  - Model name
  - Tool counter (total/active)

- **`Banner.cl.jac`**: Top banner with:
  - `jac.ai` branding
  - Working directory
  - Compact mode toggle

### Event processing

Move the event processing logic from the Python `run_tui_session.impl.jac` into the Ink poll loop:

- Track `feedSinceId` to avoid re-processing old events
- Assign tool labels (`#1`, `#2`, …)
- Match tool results to their tool calls

---

## Milestone 4: Input Polish

**Goal**: Improved text input experience.

### Enhancements

1. **Command history**: Store last N inputs in a `useState` array. Up/Down arrows cycle through history. Requires custom input handling (beyond `ink-text-input`).

2. **Tab completion**: Not feasible with Ink's `useInput` alone — tab is captured by the terminal. Consider:
   - Manual tab handling in `useInput` callback
   - Match against a static command list (slash commands + file paths)
   - Limited but useful for `/model <tab>` → cycle through presets

3. **Multi-line input**: Accept Shift+Enter for newlines (if terminal passes it through — YMMV).

4. **Draft persistence**: Write history to `~/.jac_ai_tui_history` (or project-local `.jac_ai_tui_history`) on exit, read on start. Use `fs` module from Node.js.

---

## Milestone 5: Streaming (SSE)

**Goal**: Token-level streaming instead of polling.

### Approach

Replace `setInterval(poll, 200)` with an SSE connection to `agent_stream`. This is what the web UI does. The challenge is making `ReadableStream` + `TextDecoder` work through jac-ink's compilation.

### Spike needed

Test whether jac-ink can compile code that uses:

- `fetch()` with streaming response (`resp.body.getReader()`)
- `TextDecoder`
- `ReadableStream` iteration
- Manual SSE parsing (`data: {json}\n\n` framing)

If streaming doesn't work through jac-ink compilation, keep polling as a fallback. 200ms polling is acceptable for M1–M4.

---

## Implementation Order

```
M1 (core loop)
  Step 1.1  Agent server entry     ─── verify standalone
  Step 1.2  HTTP client library    ─── verify fetch works through jac-ink
  Step 1.3  Ink TUI entry          ─── verify jac2ink compiles it
  Step 1.4  State library
  Step 1.5  Poll loop
  Step 1.6  Input handler
  Step 1.7  Launcher rewrite       ─── end-to-end test
  Step 1.8  Wire-up (no change)

M2 (commands)          ~1 day
M3 (rich display)      ~1 day
M4 (input polish)      ~1 day
M5 (streaming)         ~0.5 day (or "nice to have")

Cleanup (Phase C)
  Delete jac_super/ai_tui/          # mandatory — Python TUI is not kept
  Remove Python TUI tests or rewrite against Ink
  Update jac-super README (Node, jac2ink, npm)
```

---

## Pre-Implementation Spike Checklist

Before writing any production code, verify these assumptions:

- [ ] `jac start main.jac --no_client --port 0` boots and serves endpoints from `ai_tui_server/main.jac`
- [ ] `ui_configure()` runs correctly when `server.jac` is imported from a different entry point
- [ ] `POST /function/agent_poll` returns valid JSON with event data
- [ ] Port discovery from stdout works (`http://0.0.0.0:\d+` regex match)
- [ ] jac-ink compiles `.cl.jac` files that use `fetch`, `JSON.stringify`, `process.env`
- [ ] jac-ink compiles `.cl.jac` files that use `setInterval`, `clearInterval`
- [ ] jac-ink compiles `.cl.jac` files that use `ink-text-input` (npm dep)
- [ ] `ink-text-input` renders correctly in a compiled jac-ink app
- [ ] Multi-file imports work (main.cl.jac → lib/agent.cl.jac, lib/state.cl.jac, etc.)
- [ ] `node runner.mjs` reads `process.env.JAC_TUI_API_URL` correctly
- [ ] Parent process can read child stdout line-by-line for URL discovery
- [ ] Two child processes clean up correctly on Ctrl+C / normal exit / crash

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `fetch`/`JSON` don't compile through jac-ink | Medium | Blocks M1 | Spike first; if fails, use Node `http` module or raw `XMLHttpRequest` |
| `ink-text-input` doesn't work with jac-ink | Low-Medium | Degrades input | Fall back to `useInput` + manual buffer (M1 minimal input) |
| `process.env` not available in compiled code | Low | Blocks config | Pass URL via CLI arg instead: `node runner.mjs <url>` |
| `setInterval` not available | Low | Blocks polling | Use `useEffect` + recursive `setTimeout` instead |
| `server.jac` import fails from thin entry | Low-Medium | Blocks M1 | Copy endpoint functions into `ai_tui_server/main.jac` directly |
| Agent server stderr corrupts TUI | Low | UX annoyance | stderr piped to `subprocess.PIPE`, not terminal |
| First-run npm install is slow | Medium | Bad UX | Show progress message; cache node_modules |
| `ink-text-input` lacks features | High | Feature gap | Accept for M1; custom input component for M4 |

---

## Dependencies

| Dependency | Version | Purpose | Required at |
|-----------|---------|---------|-------------|
| Node.js | ≥22 | Ink runtime + native `fetch` | Runtime |
| npm | any | Install Ink + react packages | First run |
| jac-ink | latest | Compile `.cl.jac` → Ink app | Build time |
| ink | ^7.0.3 | Terminal rendering framework | npm dep |
| react | ^19.2.4 | Ink's rendering engine | npm dep |
| ink-text-input | ^6.0.0 | Text input component | npm dep |

**NOT required**: jac-client, Vite, TypeScript, any web frontend tooling.
