# Desktop Portal Architecture

Design notes and discussion reference for the Jac desktop target: how `cl → sv`
calls work, what the broker is, how this compares to FastAPI/jac-scale, and what
remains to build.

Related: `PLAN.md` (invocation dispatcher seam), `jac/jaclang/cli/skills/jac-desktop-app.md`
(user-facing skill).

---

## 1. Core architecture

The backend is a **transport-neutral `InvocationDispatcher`** in
`jac/jaclang/runtimelib/invocation.jac`. Desktop, HTTP dev server, and jac-scale
all route walker/function calls through the same dispatcher instead of each
transport owning its own execution path.

```
cl (webview)  →  inprocess_dispatch  →  InvocationDispatcher  →  ExecutionManager
HTTP client   →  JacAPIServer        →  InvocationDispatcher  →  ExecutionManager
jac-scale     →  serve.endpoints     →  InvocationDispatcher  →  ExecutionManager
```

Desktop `sv` calls are **in-process** (no socket, no FastAPI by default). That
keeps boot lean while sharing execution semantics with HTTP.

Key files:

| File | Role |
|------|------|
| `runtimelib/invocation.jac` | `InvocationRequest`, `InvocationResult`, `InvocationDispatcher` |
| `runtimelib/impl/invocation.impl.jac` | Auth, validation, execution, stream detection |
| `runtimelib/streaming.jac` | Shared sync/async generator drain, SSE frame helpers |
| `runtimelib/client/targets/desktop/native/inprocess_dispatch.jac` | Native boot, worker pool, dispatch, `forward()` sv bridge |
| `runtimelib/client/targets/desktop/native/host_boot.jac` | Host lifecycle, webview IPC wiring, loopback broker start |
| `runtimelib/client/targets/desktop/native/oauth_broker.jac` | Loopback HTTP broker (static, OAuth, session, plugin invoke) |
| `runtimelib/client/targets/desktop/native/http_sidecar.jac` | Opt-in `[desktop.http]` FastAPI sidecar (multipart/webhooks/ws/openapi) |
| `runtimelib/client/desktop_config.jac` | `[desktop.http]` config (`HttpConfig`, `get_http_config`) |
| `scale/server/impl/serve.endpoints.impl.jac` | FastAPI adapter (restspec, multipart, webhooks, WS) |

---

## 2. Streaming support

Streaming is supported when a walker or function returns a **sync or async
generator**. The dispatcher sets `InvocationResult.is_stream = True` and carries
the generator in `result.stream`.

### HTTP / jac-scale: SSE

Handler detects streaming result → `text/event-stream`. Frames from
`runtimelib/streaming.jac`:

- `data: {...}` per yielded item
- `event: end` on completion
- `event: error` on failure

Scale uses `scale/runtime/middleware/sse.jac` (`sse_frame_stream`).

### Desktop native: push protocol

Streaming does **not** use HTTP SSE on the primary native path:

1. Initial reply: `{__jac_stream: true, protocol: "push", stream_id: "..."}`
2. Frames via `window.__jac.on("__jac_stream", ...)`
3. Cancel: `{__jac_stream_ctl: "cancel", stream_id}`
4. Optional backpressure: `{__jac_stream_ctl: "ack", stream_id, n}` with `stream_window`

Recent work (7826): generator bodies that touch `root`/memory inside yield frames
run against a live request context (`context_bound_stream` /
`context_bound_async_stream`). Commits happen once at drain time.

### What does not stream

| Path | Streaming? |
|------|------------|
| Direct `__jac_invoke` (native webview) | Yes: push protocol |
| HTTP / jac-scale | Yes: SSE |
| `inprocess_forward` (sv bridge, CEF/OAuth paths) | Yes: SSE. `forward_outcome()` tags `{mode: DispatchMode.SSE, stream}`; the broker drains it via `runtimelib/streaming.drain_sse` (client disconnect cancels the generator). `forward()` (non-broker) materializes the same frames into the body. |
| Without `set_stream_emit` hook (native push) | **No**: *"streaming invocations require a native stream emit hook"* |

---

## 3. Desktop vs FastAPI: compatibility gaps

Native dispatch shares `InvocationDispatcher` execution semantics with FastAPI,
but the **transport surface is narrower**.

### Two desktop paths

| Path | How `cl` calls `sv` | FastAPI-like? |
|------|---------------------|---------------|
| **Native webview** (default) | `__jac_invoke` → `InvocationDispatcher` directly | Lean; no FastAPI loaded |
| **CEF / OAuth broker** | HTTP loopback + `inprocess_forward` sv bridge | Closer to HTTP, still not FastAPI |

### Gap matrix

| Feature | FastAPI / jac-scale | Desktop native |
|---------|---------------------|----------------|
| `@restspec` custom paths/verbs | Yes | Yes: via shared `http_surface` route table (sv bridge) |
| GET + query-param binding | Yes | Yes: `http_surface.bind` (declared query fields, scalar coercion) |
| Multipart / `UploadFile` | Yes | Yes: opt-in `[desktop.http]` sidecar (`http_sidecar.jac`); lean mode returns a structured 415 capability error |
| Webhooks (`APIProtocol.WEBHOOK`) | Yes | Yes (thin); opt-in sidecar `POST /webhook/{name}` → dispatcher |
| WebSockets (`APIProtocol.WEBSOCKET`) | Yes | Yes (thin); opt-in sidecar `/ws/walker/{name}` → dispatcher |
| Microservices gateway | Yes | No |
| SSO login flows (`/sso/...`) | Yes | No (HTTP-only; desktop uses broker OAuth) |
| Pydantic validation / OpenAPI | Yes | OpenAPI via opt-in sidecar (`/docs`, `/openapi.json`); validation stays in the dispatcher |
| Bearer JWT | Yes | Yes (`token` in envelope) |
| Cookie / session auth | Yes | No |
| Middleware (`_before_request`, CORS, tracing) | Yes | No |
| Generator streaming | SSE | Push protocol (native) / SSE (sv bridge) |
| Concurrency | Per-connection async | Bounded worker pool (default 4); sidecar shares the dispatcher on its own uvicorn loop |

Native envelope (frozen):

```json
{ "kind": "walker|function", "name": "...", "node": "...", "fields": {...}, "token": "..." }
```

### What matches

- Walker/function execution, OCC, graph writes
- Bearer-token identity resolution
- Basic field validation / 422 errors
- Generator streaming (direct native path only)
- Same `{ok, data, error}` success envelope

---

## 4. What the broker is

The **broker** is the desktop app's small **loopback HTTP server** in
`oauth_broker.jac`, started by `host_boot._start_loopback()`.

Despite the name, it is **not** the application backend. It is **shell
infrastructure**: things a desktop window needs that webview IPC cannot do alone.

Implementation: `ThreadingTCPServer` on `127.0.0.1:<port>`,
`http.server.SimpleHTTPRequestHandler` extended with fixed routes under `/__jac`.

### Broker routes

| Route | Method | Purpose |
|-------|--------|---------|
| `/` (static) | GET | Serve built UI from `dist/` |
| `/__jac/health` | GET | Liveness |
| `/__jac/session` | GET/POST/DELETE | Auth token on disk (`SessionStore` → `.jac/desktop/session.json`) |
| `/__jac/oauth/start` | GET | Open system browser for OAuth |
| `/__jac/oauth/callback/<state>` | GET | OAuth redirect handler |
| `/__jac/events` | GET (SSE) | Desktop event push |
| `/__jac/invoke` | POST | CEF IPC shim + `@jac/desktop` plugin dispatch |
| `/walker/*`, `/function/*` | POST/GET | CEF `sv_bridge` → `inprocess_forward_outcome` (streaming-aware: SSE via `drain_sse`, else verbatim JSON) |

Client sees: `window.__JAC_BROKER__ = '/__jac'` (same-origin relative URL).

The opt-in `[desktop.http]` FastAPI sidecar is a **separate** loopback server
(`http_sidecar.jac`), not a broker route. Its base + auto-generated bearer token +
capability list are exposed to the renderer as `window.__JAC_HTTP__ =
{base, token, capabilities}` (injected via the host bootstrap, alongside
`__JAC_NATIVE__`/`__JAC_BROKER__`).

### Broker is NOT

- FastAPI / jac-scale
- Where normal sv calls go on native webview (those use `__jac_invoke` IPC)
- A general API server (no route registration, no OpenAPI, no middleware chain)

### Why it exists

1. **Serve the UI**: webview needs a URL (`http://127.0.0.1:PORT/`)
2. **OAuth**: login opens real browser; provider redirects to callback URL
3. **Session persistence**: token stored on disk; UI polls after login
4. **Plugin IPC**: `@jac/desktop` (`fs`, `dialog`, etc.) uses `POST /__jac/invoke`
   via `desktop_api.jac` when broker is present

### Three IPC channels on desktop

| Channel | Used for |
|---------|----------|
| `__jac_invoke` (webview IPC) | Walker/function sv calls |
| Broker `POST /__jac/invoke` | `@jac/desktop` OS plugins |
| Broker `/__jac/oauth/*`, `/session` | Login + token storage |

---

## 5. How it actually works at runtime

**Not** "native OR FastAPI." **One** `InvocationDispatcher`, **multiple front
doors**.

```
                    ┌─────────────────────────┐
                    │  InvocationDispatcher    │  ← ONE backend
                    └───────────┬─────────────┘
                                │
         ┌──────────────────────┼──────────────────────┐
         │                      │                      │
  webview IPC            loopback broker           FastAPI sidecar
  __jac_invoke           oauth_broker              http_sidecar.jac
  (native webview)       (static + OAuth + CEF)    (opt-in [desktop.http])
```

### Boot sequence (`host_boot.boot()`)

1. `inprocess_boot()` → `InvocationDispatcher` live
2. `_start_loopback()` → broker thread on `127.0.0.1:<port>`
3. Webview loads broker URL; bootstrap sets `__JAC_NATIVE__=true`
4. Webview binds `__jac_invoke` → `HostContext.dispatch()` → `inprocess_dispatch_sync()`

### Walker call (native webview)

```
Button onClick
  → __jacCallWalker("SaveItem", node, {title: "foo"})
    → __doWalkerFetch
      → if __JAC_NATIVE__ && __jac_invoke:
          → __nativeInvoke → webview IPC
            → HostContext.dispatch(json)
              → inprocess_dispatch_sync
                → InvocationDispatcher.invoke(SaveItem)
                  → graph write, commit
                ← {ok: true, data: {...}}
      ← unwrap data
  ← UI updates
```

No HTTP. Broker not involved for sv calls on native webview.

Client routing (`client_runtime_core.impl.jac`):

```javascript
// Walker/function: native path
if (globalThis.__JAC_NATIVE__ && globalThis.__jac_invoke) {
    response = await __nativeInvoke(...);
} else {
    response = await fetch(url, ...);  // web / remote HTTP
}
```

### CEF mode

CEF cannot use webview IPC the same way. `__jac_invoke` → `fetch('/__jac/invoke')`
on broker → `dispatch_http()` → same `inprocess_dispatch_outcome()` → same
dispatcher. `sv_bridge=inprocess_forward` parses `/walker/foo` HTTP-shaped URLs.

### OAuth flow

```
jacSsoLogin("google")
  → fetch("/__jac/oauth/start?platform=google&...")
    → broker opens system browser
    → provider redirects to /__jac/oauth/callback/<state>
      → broker writes token to SessionStore
  → client polls fetch("/__jac/session") until token appears
  → token → localStorage (jac_token)
  → native invoke includes token in envelope
```

Cannot work over `__jac_invoke`; needs real URLs, browser windows, redirects.

---

## 6. Why not just FastAPI?

### Native dispatch is for the common case

Most desktop apps: UI calls own walkers in-process with JSON fields + bearer auth.
Shipping FastAPI for all of them adds startup time, memory, and packaging cost
with no benefit.

### IPC vs HTTP

`__jac_invoke` is frozen JSON RPC over webview binding; no HTTP parsing, routing,
or status-line quirks. Loopback HTTP for every `cl → sv` call adds overhead when
both sides are in the same process.

### Streaming

Native push protocol maps to webview IPC. SSE over loopback needs an HTTP server
always running.

### Bounded resources

Worker pool (default 4) suits one UI + few concurrent calls. FastAPI's
per-connection async model targets server deployment.

### Smaller attack surface

Native IPC: no open port for sv calls. Loopback broker/sidecar need port binding,
origin checks, shutdown hygiene.

### When FastAPI makes sense

- Multipart file uploads
- External webhooks (Stripe, etc.)
- WebSockets to external clients
- OpenAPI `/docs` for third-party consumers
- Cookie/SSO for HTTP clients

Opt-in sidecar, not replacement for native dispatch.

---

## 7. Recommended path to close gaps

**Do not chase full FastAPI parity inside `__jac_invoke`.**

### Strategy: B + A hybrid

| Component | Role |
|-----------|------|
| **B: `http_surface`** | Transport-neutral route table + binding; shared by native adapter and FastAPI |
| **A: Lazy FastAPI sidecar** | Opt-in loopback server for HTTP-only features |
| **C: Broker** | Keep fixed-purpose (static, OAuth, CEF shim); do not grow into general HTTP server |
| **D: Full FastAPI always** | **Rejected** |

```
InvocationDispatcher (unchanged)
        ↑
   http_surface (route specs + binding → InvocationRequest)
        ↑
  ┌─────┴─────┬─────────────┐
  │           │             │
native     broker shim   sidecar (opt-in)
adapter    (CEF only)   (multipart, webhooks, WS, OpenAPI)
```

### Per-gap decisions

| Gap | Decision |
|-----|----------|
| `@restspec`, GET, query binding | **Build native** in `http_surface` |
| Validation (422) | **Keep in dispatcher**; route table supplies metadata |
| Multipart / file upload | **Delegate to sidecar**; lean mode returns explicit 415/501 |
| Webhooks | **Delegate to sidecar** |
| WebSockets | **Delegate to sidecar** |
| SSO / cookies | **Split**: broker OAuth for desktop login; full HTTP SSO via sidecar |
| ASGI middleware | **Sidecar only** |
| OpenAPI | **Sidecar only**; lean mode may expose route manifest at most |
| `sv_bridge` streaming | **Build** after stream lifecycle hardening |
| Worker pool | **Keep**; document vs FastAPI concurrency |

### Implementation order

1. **`http_surface` contract** + cross-transport compatibility tests: **done**
2. **Refactor `inprocess_forward`** to use route table (remove hard-coded path parsing): **done**
3. **Register FastAPI routes from same `RouteSpec`** (reduce drift in `serve.endpoints.impl.jac`): **done**
4. **Native restspec/GET/query tests**: **done**
5. **Stream context lifecycle** hardening (prerequisite for bridge streaming): **done**
6. **Tagged `sv_bridge` streaming** + broker SSE draining: **done**
7. **Lazy sidecar capability** (`[desktop.http]` in `jac.toml`; multipart first): **done** (`http_sidecar.jac`, `[desktop.http]` config, `window.__JAC_HTTP__`, capability errors, centralized client routing)
8. **Narrow invocation hooks**: deferred (no proven use case yet)

### `jac.toml` shape (implemented)

```toml
[desktop]
# existing window/plugins config...

[desktop.http]
enabled = false                    # opt-in; lazy-loads FastAPI stack
capabilities = []                  # "multipart", "webhooks", "websockets", "openapi"
port = 0                           # 0 = random loopback port
# token auto-generated; exposed to renderer via window.__JAC_HTTP__
```

Parsed by `runtimelib/client/desktop_config.jac` (`HttpConfig` /
`get_http_config()`), validated (unknown capability / out-of-range port rejected),
and threaded through the generated host into `host_boot.boot()`. When `enabled`,
`host_boot._start_http_sidecar()` lazily imports `http_sidecar.jac` (which itself
lazy-imports FastAPI/uvicorn; the lean-boot guard keeps the default path
FastAPI-free) and starts a loopback server sharing the one `InvocationDispatcher`
via `inprocess_dispatch.runtime()`. The sidecar stops on host close
(`HostContext.close_http()`).

### Client routing decision tree (target state)

```
walker/function call (standard)  → __jac_invoke (if __JAC_NATIVE__)
file upload                      → sidecar HTTP (if [desktop.http] enabled) else error
OAuth / session                  → broker (/__jac/oauth/*, /session)
@jac/desktop plugins             → broker POST /__jac/invoke
external webhook                 → sidecar only
web / remote                     → fetch(api_base_url)
```

This decision tree is now centralized in the client runtime
(`runtimelib/impl/client_runtime_core.impl.jac`): `__jacRoute(kind, upload)`
returns the channel (`native` / `http` / `sidecar` / `error`), consulted by
`__doWalkerFetch` / `__doFuncFetch` (native-vs-web) and by the new public
`jacUploadFile()` (sidecar-vs-capability-error). `__jacCapabilityError()` mirrors
the sv-side `http_surface.capability_error()` envelope. `@jac/desktop` plugin IPC
stays in `desktop_api.jac` (broker `POST /__jac/invoke`).

---

## 8. What else is needed

### Implementation gaps

| Gap | Status |
|-----|--------|
| Shared `http_surface` route table | **Built** (`runtimelib/http_surface.jac`) |
| `sv_bridge` streaming | **Built** (`forward_outcome` SSE + broker `drain_sse`) |
| Stream request-context lifetime | Hardened (`context_bound_stream`); best-effort for very long streams |
| Capability discovery (`window.__JAC_HTTP__`) | **Built** (host bootstrap injects `{base, token, capabilities}`) |
| Explicit capability errors (415/501 + hint) | **Done**: sv-side `http_surface.capability_error`, cl-side `__jacCapabilityError` |
| Optional FastAPI sidecar | **Built** (`http_sidecar.jac`, opt-in `[desktop.http]`) |
| Client routing module (centralized) | **Built** (`__jacRoute` in the client runtime) |
| Lean-boot import guard tests (no FastAPI on default path) | **Done** (`test_http_surface_bridge`, `test_http_sidecar`) |

### Cross-cutting concerns

- **Dev mode origin split**: Vite on one port, broker on another; CEF breaks on
  origin mismatch. Native uses `JAC_DESKTOP_DEV_PORT`.
- **Auth token plumbing**: broker `SessionStore`, `localStorage` (`jac_token`),
  native envelope `token`; needs documented contract.
- **Shutdown lifecycle**: worker pool drain, stream cancel on window close, broker
  stop, (future) sidecar shutdown.
- **Streaming backpressure**: best-effort today; not true flow control if client
  never acks.

### Product limits (parallel work, not blocking transport)

- Packaging/signing in progress ([#6436](https://github.com/jaseci-labs/jaseci/issues/6436))
- No cross-compilation
- CEF has no HMR dev mode
- `@jac/desktop` keyword args silently break ([#6675](https://github.com/jaseci-labs/jaseci/issues/6675))
- `JAC_BUILD=1`: guard import-time side effects in sv code

### What NOT to build

- Full FastAPI in every desktop boot
- Pydantic/OpenAPI in native code
- Generic ASGI middleware clone in `inprocess_dispatch`
- Turn `oauth_broker` into a general HTTP server
- `ExecutionManager` calls from desktop dispatch (bypass dispatcher)
- Import `jaclang.scale.server` on default boot path
- Native multipart parser (delegate to sidecar)

---

## 9. Minimum viable "complete" picture

1. **`http_surface`**: single route source of truth - **done**
2. **Bridge streaming fix**: `sv_bridge` + stream lifecycle - **done**
3. **Capability config**: `[desktop.http]` opt-in in `jac.toml` - **done**
4. **Client routing module**: one place picks IPC vs broker vs sidecar - **done** (`__jacRoute`)
5. **Capability errors**: clear failures when HTTP-only feature used in lean mode - **done**
6. **Docs**: decision tree for app authors (this file + `jac-desktop-app` skill update) - **done**

All six MVP items are implemented and covered by tests (`test_http_surface_bridge`,
`test_cross_transport_parity`, `test_inprocess_dispatch`, `test_streaming`,
`test_desktop_native_target`, `test_http_sidecar`, `test_desktop_routing`).
Remaining non-blocking work: microservices gateway, cookie/SSO for HTTP clients,
richer webhook/websocket parity (signature verification, connection manager),
and CEF-mode `window.__JAC_HTTP__` injection (the sidecar starts in CEF mode; only
the renderer-side discovery hook is native-webview-only so far).

---

## 10. Key code references

| Concern | Location |
|---------|----------|
| Client native vs HTTP branch | `runtimelib/impl/client_runtime_core.impl.jac` (`__doWalkerFetch`, `__doFuncFetch`) |
| Centralized client routing | `runtimelib/impl/client_runtime_core.impl.jac` (`__jacRoute`, `jacUploadFile`, `__jacCapabilityError`) |
| Opt-in HTTP sidecar | `runtimelib/client/targets/desktop/native/http_sidecar.jac`; started by `host_boot._start_http_sidecar` |
| Capability errors (sv-side) | `runtimelib/http_surface.jac` (`capability_error`, `HTTP_CAPABILITIES`) |
| Native dispatch + sv bridge | `runtimelib/client/targets/desktop/native/inprocess_dispatch.jac` |
| Host boot + broker start | `runtimelib/client/targets/desktop/native/host_boot.jac` |
| Broker routes | `runtimelib/client/targets/desktop/native/oauth_broker.jac` |
| Webview IPC bootstrap | `runtimelib/client/targets/desktop/_host_bootstrap.jac` |
| `@jac/desktop` plugin bridge | `runtimelib/client/targets/desktop/plugin/desktop_api.jac` |
| Dispatcher | `runtimelib/invocation.jac`, `runtimelib/impl/invocation.impl.jac` |
| Streaming helpers | `runtimelib/streaming.jac` |
| FastAPI adapter | `scale/server/impl/serve.endpoints.impl.jac` |
| User-facing limits | `jaclang/cli/skills/jac-desktop-app.md` |
| Invocation seam plan | `PLAN.md` |

---

*Generated from architecture discussion, 2026-08-01.*
