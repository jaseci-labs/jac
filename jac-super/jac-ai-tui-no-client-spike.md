# `jac start --no_client`: The Sweet Spot?

The question: can we use the core `jac start` server (API endpoints) without
triggering the jac-client Vite pipeline?

## How `jac start` actually works

There are **two** `jac start` paths — the core command and jac-client's extension:

### Core `jac start` (jaclang built-in)

```
jac start main.jac --no_client --port 0
```

Path: `execution.impl.jac` → `start()`:

1. Compile `main.jac` (standard Jac compilation)
2. `Jac.get_api_server_class()` → get `JacAPIServer` (or jac-scale's enhanced class)
3. Create server: `ServerClass(module_name=mod, port=0, base_path=base)`
4. **If `--no_client`**: skip all client bundle building, skip Vite entirely
5. **If not `--dev`**: skip HMR, skip watchdog, skip Vite dev server
6. `server.start(dev=False, no_client=True)` → bare HTTP API server
7. Prints: `"Jac API Server running on http://0.0.0.0:{self.port}"`
8. Serves `POST /function/<name>` endpoints for all `def:pub` functions

**No jac-client needed. No Vite. No npm.** Just Jac compilation + HTTP server.

### jac-client's `jac start` extension

jac-client registers a `pre_hook` on the `start` command. When it fires:

1. Reads `--client` arg → defaults to `"web"` if not specified
2. If `target_name == "web"` → does **NOT cancel** → falls through to core `jac start`
3. If `target_name != "web"` (desktop, pwa, mobile) → cancels core execution → calls `target.start()` which includes Vite build

So when you run `jac start main.jac` without `--client`, jac-client's pre_hook
does nothing (falls through), and the core path runs — which is just compilation + HTTP server.

### What `_run_ui_server` does (current web UI launcher)

```python
subprocess.Popen(
    [sys.executable, "-m", "jaclang", "start", "main.jac"],
    cwd=ui_dir,  # ai_ui/ directory
    ...
)
```

This runs **without** `--no_client`. That means:

- jac-client's pre_hook fires, sees `--client` defaulting to `"web"`
- Falls through to core `jac start`
- Core `start()` with `no_client=False` → `server.start(no_client=False)`
- `JacAPIServer.start()` checks for client exports, builds the client bundle (Vite)
- Serves both the API endpoints AND the web frontend

The web UI **needs** this because it actually serves the React frontend. But we don't.

## The discovery: `jac start main.jac --no_client` is exactly what we need

```
jac start main.jac --no_client --port 0
```

This gives us:

- ✅ Jac compilation of `main.jac` (loads the module, discovers `def:pub` endpoints)
- ✅ `JacAPIServer` HTTP server on a random port
- ✅ All `agent_*` endpoints served as `POST /function/agent_poll`, etc.
- ✅ `ui_configure()` runs on import (via `with entry` in `server.jac`)
- ❌ No Vite build
- ❌ No npm install
- ❌ No jac-client dependency (the pre_hook falls through)
- ❌ No frontend serving

The agent server prints `Jac API Server running on http://0.0.0.0:{port}` to stdout,
which we can capture to discover the port (same pattern as `_run_ui_server`).

## What about `ai_ui/server.jac`?

`ai_ui/server.jac` has a `with entry { ui_configure(); }` block that runs on import.
It also defines all the endpoints as `def:pub` functions.

If we run `jac start main.jac --no_client` from the `ai_ui/` directory:

1. `main.jac` imports `frontend.cl.jac` (which imports `server.jac`)
2. `server.jac`'s `with entry` runs → `ui_configure()` boots the agent
3. All `agent_*` functions are discovered as endpoints
4. But `frontend.cl.jac` has `cl def:pub app` → client exports exist
5. With `--no_client`, the server skips building them → ✅ no Vite

**Problem**: `frontend.cl.jac` uses `sv import from .server` and browser APIs
(`window`, `fetch`, `localStorage`, `TextDecoder`, `AbortController`). These
may fail during compilation or import even though `--no_client` skips the Vite build.

### Better: create a thin TUI-specific server entry

Instead of reusing `ai_ui/main.jac` (which pulls in the browser frontend),
create a minimal `main.jac` that imports only the server endpoints:

```jac
# jac_super/ai_tui_server/main.jac
"""Agent API server for the Ink TUI client.

Imports only the server-side endpoints — no browser frontend.
ui_configure() runs via server.jac's `with entry` block.
"""
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
    agent_phase_context,
    # The typed view objects are also needed so the endpoints return them
    PollResult,
    UiEvent,
    TurnStatsView,
    GraphData,
    SettingsView,
    SettingsResult,
    CallDetail,
    PhaseContext
}
```

This has **no `cl` imports** → no client exports → no Vite trigger even
without `--no_client`. But we'd still use `--no_client` as a safety net.

### The server.jac `with entry` concern

`server.jac` has:

```jac
with entry {
    ui_configure();
}
```

This runs `ui_configure()` when the module is imported. It reads env vars:

- `JAC_AI_UI_PROJECT` → sets agent workspace
- `JAC_AI_UI_MODEL` → sets model
- `JAC_AI_UI_NCTX` → sets context limit

These env vars are set by the launcher before spawning the server child process.
This is the exact same pattern as `_run_ui_server` — ✅ works as-is.

## Updated launcher pseudocode

```python
def run_tui_session(req):
    import jaclang
    from pathlib import Path

    # 1. Set env vars for the agent server (same as _run_ui_server)
    env = dict(os.environ)
    env["JAC_AI_UI_PROJECT"] = agent.ws.cwd
    env["JAC_AI_UI_MODEL"] = str(req.model or "")
    env["JAC_AI_UI_NCTX"] = str(int(req.n_ctx or 0))

    # 2. Find the TUI server entry (thin wrapper, no frontend)
    server_dir = Path(jac_super.__file__).parent / "ai_tui_server"

    # 3. Spawn bare API server (no Vite, no npm, no jac-client needed)
    server_proc = subprocess.Popen(
        [sys.executable, "-m", "jaclang", "start", "main.jac",
         "--no_client", "--port", "0"],
        cwd=str(server_dir),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,  # separate stderr to avoid terminal conflicts
        text=True,
        env=env,
        start_new_session=True
    )

    # 4. Discover port from server stdout
    url_re = re.compile(r"http://0\.0\.0\.0:(\d+)")
    api_url = ""
    deadline = time.time() + 30
    while time.time() < deadline:
        line = server_proc.stdout.readline()
        m = url_re.search(line)
        if m:
            port = int(m.group(1))
            api_url = f"http://127.0.0.1:{port}"
            break
        if server_proc.poll() is not None:
            break

    if not api_url:
        server_proc.terminate()
        return 1

    # 5. Compile + launch the Ink TUI
    ink_dir = Path(jac_super.__file__).parent / "ai_tui_ink"
    ensure_ink_compiled(ink_dir)  # runs jac2ink if needed

    tui_env = dict(os.environ)
    tui_env["JAC_TUI_API_URL"] = api_url
    tui_proc = subprocess.Popen(
        ["node", str(ink_dir / ".jac/tui/runner.mjs")],
        cwd=str(ink_dir),
        env=tui_env
    )

    # 6. Wait for TUI exit, clean up both children
    try:
        tui_proc.wait()
    except KeyboardInterrupt:
        pass
    finally:
        tui_proc.terminate()
        server_proc.terminate()
    return 0
```

## What this solves from the pitfalls list

| Pitfall | Status |
|---------|--------|
| #1 jac-client hard dependency | **Solved** — core `jac start --no_client` doesn't need it |
| #2 Vite build for nothing | **Solved** — `--no_client` skips client bundle entirely |
| #3 Only path to API server | **Solved** — `JacAPIServer` is the core jac runtime, not jac-client |
| #5 First-run latency | **Mostly solved** — only one npm install (Ink), no Vite |
| #7 Terminal conflicts | **Mitigated** — stderr piped separately, not to terminal |
| #9 URL discovery fragile | **Solved** — `JacAPIServer.start()` prints port to stdout reliably |

## What this does NOT solve

| Pitfall | Status |
|---------|--------|
| #4 Ink useInput limitations | **Unchanged** — still a fundamental Ink constraint |
| #6 jac-ink untested patterns | **Unchanged** — still need fetch/setInterval/JSON.parse spike |
| #8 HTTP streaming overhead | **Unchanged** — still polling or SSE over HTTP |
| #10 Two processes | **Unchanged** — still agent server + Ink process |

## Remaining dependency list

| Dependency | Required | Why |
|-----------|----------|-----|
| jac-ink | Yes | Compile `.cl.jac` → Ink app |
| Node.js 22+ | Yes | Ink runtime + native fetch |
| npm | Yes | Ink npm packages |
| jac-client | **No** | Not needed with `--no_client` |
| Vite | **No** | Not needed with `--no_client` |
| jac-scale | Optional | Enhances `JacAPIServer` but core server works without it |

## Pre-implementation spike needed

Before committing, verify:

1. `jac start main.jac --no_client --port 0` boots and serves endpoints from a thin server entry that imports `ai_ui/server.jac`
2. The `with entry { ui_configure() }` in `server.jac` runs correctly when imported from a different `main.jac`
3. `POST /function/agent_poll` returns valid JSON from the thin server
4. Port discovery from stdout works reliably
5. jac-ink can compile an app that uses `fetch`, `process.env`, `setInterval`, `JSON.parse`
