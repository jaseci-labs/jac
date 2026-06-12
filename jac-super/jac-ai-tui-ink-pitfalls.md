# Jac AI TUI → Ink Migration: Pitfalls Analysis

This document identifies problems with the current migration plan (`jac-ai-tui-ink-migration-plan.md`) and compares the HTTP-based approach against the simpler file-bridge alternative it replaced.

---

## 1. jac-client becomes a hard dependency for `--tui`

**Severity: High**

The plan reuses `ai_ui/server.jac` by running `jac start main.jac` from the `ai_ui/` directory. But `jac start` is a **jac-client command** — jac-client registers the `start` command extension and provides `WebTarget.start()`, which builds the Vite bundle and launches the jac-scale server.

```python
# _run_ui_server already checks this:
if find_spec("jac_client") is None:
    console.error("`jac ai --ui` needs the jac-client plugin, which is not installed.")
    return 1
```

This means `jac ai --tui` would require:

- `jac-client` (Python pip package)
- `jac-scale` (provides the HTTP server)
- Node.js 22+ (for Ink)
- `jac-ink` (pip package)
- npm (for Ink runtime deps)

The current `--tui` only requires Python. The web UI (`--ui`) already requires jac-client, but that's expected — it's a web app. A **terminal UI** requiring a full web stack is a surprising dependency chain.

**Contrast with the old approach**: The file-bridge plan had zero new dependencies beyond jac-ink + Node.js. The agent ran in-process, no HTTP server, no Vite, no jac-client.

---

## 2. The agent server starts the full Vite pipeline for nothing

**Severity: Medium-High**

`WebTarget.start()` (what `jac start` dispatches to) does this:

```python
def start(self, entry_file, project_dir, api_port=8000):
    # Step 1: BUILD the web bundle via Vite
    self.build(entry_file, project_dir, None)
    # Step 2: Start jac-scale server serving the built frontend + API
    server = ServerClass(module_name=mod, port=api_port, base_path=base)
    server.start(dev=False, no_client=False)
```

On first run, `self.build()` runs the full Vite pipeline: compile `.cl.jac` → JS, create `package.json`, run `npm install` (react, react-dom, cytoscape, react-router-dom, vite, typescript, etc.), bundle with Vite, output to `dist/`. The `ai_ui/jac.toml` has 7 npm dependencies and 5 dev dependencies.

**For the TUI, all of this frontend build work is thrown away.** We only need the server endpoints (`agent_poll`, `agent_send`, etc.) — not the React DOM frontend that Vite just built. We're running a full web build pipeline to get an API server.

**Mitigation options**:

- Use `--no_client` flag to skip frontend serving (if the server supports it)
- Create a minimal `main.jac` that imports only the server endpoints without any frontend code, so Vite has nothing to build
- Use the jac-scale `JacAPIServer` directly (bypassing `jac start` entirely) — see pitfall #3

---

## 3. The plan assumes `jac start` is the only way to get an API server

**Severity: Medium**

The migration plan copies `_run_ui_server()` verbatim, but `_run_ui_server` was designed for the **web UI** where you actually want Vite + frontend serving. For the TUI, we just need a bare HTTP server that exposes the `ui_*` functions as endpoints.

The `JacAPIServer` class (in `jaclang.runtimelib.server`) can serve any module's `def:pub` functions as HTTP endpoints. We could start it directly:

```python
# Instead of: subprocess.Popen(["python", "-m", "jaclang", "start", "main.jac"])
# Do this in-process or in a child:
from jaclang.runtimelib.server import JacAPIServer
server = JacAPIServer(module_name="ai_tui_server", port=0, base_path=".")
server.start(dev=False, no_client=True)
```

This would avoid the Vite build entirely. But it requires:

- A separate `main.jac` that only imports server endpoints (no frontend)
- Understanding whether `JacAPIServer` can run in a thread within the same process (currently it runs `serve_forever` which blocks)
- Or running it in a child process that doesn't go through `jac start`

The migration plan doesn't explore this simpler path.

---

## 4. Ink's `useInput` is fundamentally limited for text editing

**Severity: High**

The plan uses Ink's `useInput` hook to build a text input. But `useInput` gives you raw keypress events — it's not a text input component. The implementation in the plan:

```jac
useInput(lambda (input, key) {
    if key.backspace or key.delete {
        if len(draft) > 0 {
            draft = draft[:-1];
        }
    } else {
        draft = draft + input;
    }
});
```

This has severe limitations vs. the current `readline`-based input:

| Feature | readline (current) | useInput (plan) |
|---------|-------------------|-----------------|
| Arrow key navigation | ✅ | ❌ |
| Ctrl+A (home) | ✅ | ❌ |
| Ctrl+E (end) | ✅ | ❌ |
| Ctrl+K (kill line) | ✅ | ❌ |
| Ctrl+W (delete word) | ✅ | ❌ |
| Tab completion | ✅ (already implemented) | ❌ |
| History (up/down) | ✅ (already implemented) | ❌ |
| Multi-line input | ✅ | ❌ |
| Paste (long text) | ✅ | May break (buffer issues) |
| Unicode/IME | ✅ | Uncertain |
| Cursor positioning | ✅ | ❌ (always at end) |

Ink has a `TextInput` component from `ink-text-input` npm package, but it only supports single-line input and still doesn't support history or tab completion.

The current TUI may be ugly with its manual ANSI redraws, but its **input handling is actually more capable** than what Ink provides out of the box.

**Mitigation**: Use `ink-text-input` for basic editing, and implement history/tab-completion manually. Or use a different input strategy (see alternative approaches at the end).

---

## 5. Two child processes to manage — tripled process count

**Severity: Medium**

The current TUI is a **single Python process** (agent + rendering in the same process). The plan spawns **two additional processes** (agent server + Ink TUI) managed by a parent process.

```
Current:  1 process (agent + TUI)
Plan:     3 processes (parent + agent server + Ink TUI)
```

This adds:

- **Startup latency**: agent server boot + Vite build (first run) + npm install + jac2ink compile + Ink process launch
- **Cleanup complexity**: parent must track both children, handle signals, avoid zombies
- **Failure modes**: agent server crash leaves TUI hanging, TUI crash leaves server running, parent crash orphans both
- **Resource usage**: three processes each with their own memory footprint

The desktop app does this (sidecar + PyTauri shell), but PyTauri has mature lifecycle management. Here we're reimplementing that management in the `run_tui_session` launcher.

---

## 6. First-run experience is very slow

**Severity: Medium**

On first `jac ai --tui`:

1. Check/install jac-client → may need to pip install
2. `jac start` triggers `WebTarget.start` which calls `self.build()`:
   - Creates Vite `package.json` with 12 npm deps
   - `npm install` — downloads react, react-dom, cytoscape, vite, typescript, etc.
   - Vite build — compiles and bundles the web frontend
3. jac-scale server boots, loads the agent
4. `jac2ink` compiles the Ink TUI `.cl.jac` files:
   - Creates another `package.json` with ink + react
   - `npm install` — downloads ink, react (again)
   - Generates `runner.mjs`, `runtime_shim.mjs`, `module.mjs`
5. `node runner.mjs` starts the Ink TUI

**Total first-run cost**: ~2 npm installs, ~2 compilations, ~3 process spawns, potentially minutes of waiting.

`jac ai --ui` has the same first-run cost, but users expect a web app to need npm. For a terminal tool, the expectation is instant startup.

---

## 7. jac-ink compilation may not handle the required patterns

**Severity: Medium**

The plan's components use patterns that haven't been tested with jac-ink:

1. **`fetch` calls**: jac-ink runs in Node.js, so `fetch` is available (Node 22+). But jac-ink's bundle post-processing rewrites imports — it needs to not strip or break bare `fetch` calls (which aren't imported from anywhere).

2. **`process.env`**: The plan reads `process.env.JAC_TUI_API_URL`. But jac-ink's runtime shim may not expose `process` — it's a Node.js global, but the compiled `.cl.jac` code needs to reference it.

3. **`setInterval` / `clearInterval`**: Used for the poll loop. Same concern — these are Node.js globals, not imported from any module.

4. **`JSON.parse` / `JSON.stringify`**: jac-ink's compilation may not handle these correctly depending on how the Jac compiler emits them.

5. **Object destructuring in fetch responses**: `snap.events`, `snap.status` — jac-ink's JS output needs to handle property access on parsed JSON correctly.

6. **`.map()` with lambdas on lists**: The `events.map(lambda (ev) {...})` pattern in the plan needs to compile correctly through jac-ink's bundle pipeline.

The jac-ink examples (`Counter`, `Header`, `StatusBar`, `Footer`) use a limited subset of these features. The plan pushes significantly beyond what's been tested.

---

## 8. HTTP transport adds serialization overhead for streaming

**Severity: Low-Medium**

The web UI gets token-level streaming via SSE (`agent_stream`). The plan starts with HTTP polling (`agent_poll` at 200ms intervals) for M1, with a note to add SSE later.

But SSE in Node.js from a `.cl.jac` compiled app is uncharted territory:

- The web frontend uses `resp.body.getReader()` + `TextDecoder` — browser APIs that may or may not work through jac-ink's compilation
- The `fetch` response streaming API (`ReadableStream`) has different behavior in Node.js vs browsers
- jac-ink's runtime shim doesn't provide these APIs

Without streaming, the TUI gets updates in 200ms chunks — noticeably more jerky than the web UI's token-by-token streaming, and worse than the current Python TUI which calls `ui_poll()` directly every 120ms with zero serialization overhead.

---

## 9. The agent server URL discovery is fragile

**Severity: Low-Medium**

The plan follows `_run_ui_server()`'s pattern of reading the server URL from a log file. But:

```python
# _run_ui_server writes stdout to a log file, then reads it:
log_f = open(log_path, "w")
proc = subprocess.Popen(..., stdout=log_f, stderr=subprocess.STDOUT)
# Then polls the log file for a URL:
m = url_re.search(log_text)
```

This works for the web UI because `jac start` prints the URL during Vite/jac-scale boot. But if we skip the Vite build (per pitfall #2), the URL format may change. And if we use `--port 0` (random port), we need the server to print its actual port — the behavior depends on jac-scale's startup logging.

The desktop sidecar has the same pattern (`JAC_SIDECAR_PORT=`) but it's explicitly designed for it. The jac-scale HTTP server may not print in the same format.

---

## 10. Terminal ownership conflicts between processes

**Severity: Medium**

The Ink TUI process takes over the terminal (raw mode, alternate screen buffer). But the agent server is also a child of the same parent, and its stderr may still be connected to the terminal.

If the agent server logs anything (warnings, errors, model loading output), those writes will corrupt the Ink TUI's display. The current TUI handles this with `agent.cfg.tui_active = True` to suppress conflicting prints, but that flag only works in the same process.

With separate processes, the agent server has no idea that a TUI is active on the same terminal. Any stderr output from the Python agent server will interleave with Ink's rendering.

---

## Comparison: What the Old File-Bridge Approach Got Right

The previous version of the migration plan (file-based bridge) avoided several of these pitfalls:

| Concern | HTTP approach (current plan) | File bridge (old plan) |
|---------|------------------------------|----------------------|
| jac-client dependency | Required | Not needed |
| Vite/npm build | Required (wasted) | Not needed |
| Process count | 3 (parent + server + ink) | 2 (parent + ink) |
| First-run latency | High (npm install ×2) | Lower (npm install ×1) |
| Streaming | HTTP SSE (complex in Ink) | File writes (trivial) |
| Input handling | Ink useInput (limited) | Ink useInput (same limitation) |
| Transport complexity | HTTP + JSON serialization | JSON file read/write |
| Terminal conflicts | Possible (stderr from server) | None (agent is in-process) |
| Agent access | Indirect (HTTP → server → agent) | Direct (ui_poll() in-process) |

The file bridge's main weakness was "inventing a new transport." But that transport is trivially simple — one JSON file written by the agent thread, read by the Ink process. The HTTP transport is "reusing an existing transport," but it drags in the entire jac-client + Vite + jac-scale stack.

---

## Suggested Mitigations

### For the hard dependencies (#1, #2, #3)

**Skip `jac start`. Use `JacAPIServer` directly** in a child process or thread:

```python
# Instead of: subprocess.Popen(["python", "-m", "jaclang", "start", "main.jac"])
# Create a minimal server that only exposes agent endpoints:
def run_tui_session(req):
    ui_configure()

    # Start a bare JacAPIServer (no Vite, no jac-client, no npm)
    # This requires a minimal .jac module with the server endpoints
    # or wiring them programmatically
    import from jaclang.runtimelib.server { JacAPIServer }
    server = JacAPIServer(module_name="ai_tui_server", port=0)
    threading.Thread(target=server.start, daemon=True).start()
    api_url = f"http://127.0.0.1:{server.port}"

    # Then launch Ink as before
    ...
```

This would eliminate the jac-client and Vite dependencies entirely.

### For the input problem (#4)

**Consider a hybrid approach**: Keep the Python process for input handling (using `readline` or a proper input library), and use Ink only for the rendering pane. This is how many terminal apps work — one thread handles input, another handles rendering.

Alternatively, use `ink-text-input` for M1 and accept limited editing, then investigate a richer input component for later milestones.

### For the process management (#5, #9, #10)

If we keep the two-process approach, adopt the desktop's sidecar pattern more faithfully:

- Agent server writes `JAC_AI_TUI_PORT=<n>` to stdout (explicit protocol)
- Parent reads stdout with a timeout
- Both children get their own stderr pipes (no terminal conflicts)
- Signal handling terminates both children cleanly

### For the compilation risks (#7)

**Spike first**: Before committing to the Ink approach, compile a minimal test app that uses `fetch`, `process.env`, `setInterval`, and `JSON.parse` through jac-ink. If these don't work, the entire approach needs rethinking.

---

## Alternative: Python TUI Library Instead of Ink

If the Ink approach's pitfalls prove too severe, consider using a Python TUI library (like **Textual**) that runs in the same process as the agent:

```
jac ai --tui
  └─ run_tui_session(req)
       ├─ ui_configure() + agent thread (in-process, like current)
       ├─ Textual app (Python, same process)
       │   ├─ Calls ui_poll() directly (no transport)
       │   ├─ Calls ui_send() directly (no transport)
       │   ├─ Rich rendering (scrollable panes, forms, graphs)
       │   └─ Full input handling (text editing, history, completion)
       └─ Single process, no HTTP, no Node.js, no npm
```

Pros:

- Zero new system dependencies (Python only)
- Direct in-process bridge (no transport overhead)
- Full text editing (Textual has proper input widgets)
- Same process → no terminal conflicts, no process management
- Fast startup (no compilation, no npm install)

Cons:

- Not using jac-ink (defeats the "use the existing plugin" goal)
- Adds Textual as a dependency
- Not React/JSX-based (different component model)
