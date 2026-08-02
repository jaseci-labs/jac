---
name: jac-desktop-app
description: Packaging a full-stack Jac app as a native desktop app - `jac build/start --client desktop`, `[desktop]` window config, the `@jac/desktop` OS-capability plugins (fs/dialog/clipboard/notification/window/shell/path IPC), OS-webview architecture (no Rust, no Electron), Linux build deps, output layout, current limitations. Load when shipping a client UI as a desktop binary or calling OS capabilities from it.
---

The desktop target turns a full-stack Jac app into **one `jac nacompile`d binary plus the OS's own web engine** - no Rust toolchain, no Electron, no PyInstaller, no separate backend process. It builds the same Vite client bundle the web target produces, then compiles a native host that embeds CPython to serve that bundle on a loopback port and renders it in the OS-native webview: WebKitGTK (Linux), WKWebView (macOS), WebView2 (Windows). Same client/server source as the web target - only the target flag changes.

## Build and run

The desktop target ships with `jaclang` core -- nothing extra to install.

```bash
jac build --client desktop      # -> .jac/client/desktop/<app>  (single binary + dist/)
jac start --client desktop      # build (if needed), then launch the native window
jac start --client desktop --dev   # HMR: Vite on 127.0.0.1 + recompile on .jac saves
```

There is **no `jac setup desktop` step** - the native host is generated at build time. Run the built binary directly with `(cd .jac/client/desktop && ./<app>)`.

Build machine needs the OS web engine + a C toolchain (a small `libwebview.so` wrapper is compiled on first use). Debian/Ubuntu:

```bash
sudo apt-get install -y build-essential pkg-config libgtk-3-dev libwebkit2gtk-4.1-dev
```

(`jaclang` ships a helper: `jaclang/runtimelib/client/targets/desktop/native/webview/install_webkit_deps.sh`.)

## Configuration - `[desktop]` in `jac.toml`

All fields optional:

```toml
[desktop]
name = "my-app"                  # binary name
identifier = "com.example.myapp"
version = "1.0.0"

[desktop.window]
title = "My App"
width = 1000
height = 700
min_width = 800
min_height = 600
resizable = true
```

## OS capabilities - the `@jac/desktop` plugins (IPC)

The native host exposes OS capabilities to your client UI through a plugin bridge: `window.__jac.invoke(plugin, command, args)` (async, resolves to data or throws) and `window.__jac.on(event, cb)`. Don't hand-write those magic strings - import the typed SDK instead:

```jac
import from "@jac/desktop" { fs, dialog, notification }

async def export_notes(text: str) -> None {
    picked = await dialog.save_file("Export", "notes.txt");   # POSITIONAL args - see gotcha
    if not picked["canceled"] {
        await fs.write_file(picked["path"] as str, text);     # dict values are `any` - cast at the boundary
        await notification.send("Saved", "Notes exported.");
    }
}
```

Seven built-in capability objects (every method is `async`, call with `await`):

| Import | Capability | Methods |
|---|---|---|
| `fs` | Filesystem | `read_file`, `write_file`, `list_dir`, `exists`, `mkdir`, `remove`, `stat` |
| `dialog` | Native dialogs | `open_file`, `save_file`, `message` |
| `clipboard` | System clipboard | `read`, `write` |
| `notification` | OS notifications | `send` |
| `app_window` | Window control | `set_title`, `set_size`, `fullscreen`, `terminate` |
| `shell` | Run a command | `exec` |
| `path` | OS dirs | `home`, `data`, `config`, `cache`, `temp`, `resolve` |

The window object is imported as **`app_window`, not `window`** - it must not shadow the browser's ambient `window` global.

### Security gating - `[desktop.plugins]` in `jac.toml`

Each key is a plugin name; the value is `true` (enabled with defaults) or a table of per-plugin config. **`window`, `path`, `notification`, `dialog` are enabled by default; `shell` is deny-all by default.** Set a plugin to `false` to disable it entirely. A typo'd plugin key is rejected (not silently ignored).

```toml
[desktop.plugins]
fs = { allow_read = ["$HOME"], allow_write = ["$APP_DATA"] }   # glob allow-lists (these are the defaults)
clipboard = { allow_read = true, allow_write = true }
shell = { allow = ["git *"] }                                  # deny-all until you allow patterns
notification = true
```

**Gotcha - pass arguments POSITIONALLY, not by keyword.** The client compiler can't resolve param names across the `@jac/desktop` module boundary, so `dialog.save_file(title="Export")` silently compiles to one options object in the first positional slot and the host rejects it. Use `dialog.save_file("Export", "notes.txt")`. (Tracked in [#6675](https://github.com/jaseci-labs/jaseci/issues/6675).)

## Opt-in HTTP sidecar - `[desktop.http]` in `jac.toml`

Most desktop apps never need HTTP: the UI calls its own walkers/functions
in-process over `__jac_invoke`. For the HTTP-only features (multipart file
uploads, external webhooks, websockets, OpenAPI docs) enable the **sidecar** - a
loopback FastAPI server that is *only* imported when you opt in, so a default app
stays FastAPI-free and lean.

```toml
[desktop.http]
enabled = true                       # opt-in; lazy-loads the FastAPI stack
capabilities = ["multipart"]         # subset of: multipart, webhooks, websockets, openapi
port = 0                             # 0 = random loopback port
```

Everything the sidecar serves still funnels through the same
`InvocationDispatcher` your native calls use - no forked execution semantics,
same OCC/graph writes/auth. The sidecar auto-generates a bearer token and exposes
its discovery info to the renderer as
`window.__JAC_HTTP__ = {base, token, capabilities}`.

Upload a file from client code with `jacUploadFile` (from `@jac/runtime`); it
routes to the sidecar when present and fails with a clear capability error when
the sidecar is disabled:

```jac
import from "@jac/runtime" { jacUploadFile }

# save_upload is a walker with e.g. `has file: bytes; has label: str;`
result = await jacUploadFile("save_upload", {"label": "avatar"}, {"file": theFile});
```

## Output layout

```
.jac/client/desktop/
  my-app          # the native binary
  dist/           # the served cl bundle
  libwebview.so   # OS-webview wrapper (resolved via $ORIGIN runpath)
```

The directory is **relocatable** - the binary finds its sibling `dist/` and `libwebview.so` relative to itself. Ship the whole directory.

## Gotchas and current limits

- **In progress** (per [issue #6436](https://github.com/jaseci-labs/jaseci/issues/6436)): per-OS packaging/signing (phase 5). The server codespace, walkers, and functions now run **in-process** on the embedded interpreter (shipped), and desktop has its own HMR dev mode: `jac start --client desktop --dev` builds the native host once, serves your client UI from Vite on `127.0.0.1`, and recompiles on `.jac` saves -- iterate against the real desktop window, no web fallback needed.
- **No cross-compilation yet.** `--platform` only affects sidecar *naming* (`--platform windows` selects `.exe`); build on each target OS.
- Desktop builds set `JAC_BUILD=1` so import-time server starts stay inert - guard side effects accordingly.
- `jac nacompile` lowers the host with Jac's pure-Jac linker (no `cc`/`ld` at link time), but the C toolchain is still needed once for `libwebview.so`.

## Native dispatch - parity notes and known limitations

Desktop `sv` calls go **direct** through the transport-neutral `InvocationDispatcher`
(the same dispatcher HTTP uses), not through FastAPI. That keeps boot lean (no
FastAPI/Starlette/Pydantic loaded for a minimal app) but the native `__jac_invoke`
JSON envelope is a narrower surface than HTTP. What to expect:

- **Input validation is lightweight, not Pydantic.** The dispatcher coerces the
  common scalars (numeric-string → `int`/`float`, truthy tokens → `bool`) and
  rejects missing-required or uncoercible fields with a stable
  `VALIDATION_ERROR` (`http_status` 422) on **both** HTTP and native. It does not
  reconstruct arbitrary Pydantic models; complex/nested shapes are passed through
  as-is (walker/function body errors then normalize to `EXECUTION_ERROR`, never a
  raw traceback).
- **restspec paths/verbs, GET, and query binding now work on desktop.** They are
  served by the shared transport-neutral `http_surface` route table that both
  FastAPI and the desktop `sv` bridge consume, so `@restspec` custom paths/verbs,
  GET-vs-POST semantics, and query-parameter binding behave identically across
  transports (native webview calls still use the frozen `__jac_invoke` JSON
  envelope; the CEF/broker `sv` bridge resolves HTTP-shaped paths through the same
  table).
- **Multipart uploads / webhooks / websockets / OpenAPI are opt-in via
  `[desktop.http]`.** These HTTP-only features are served by a lazily-started
  loopback FastAPI *sidecar* (no FastAPI is loaded unless you enable it). See the
  `[desktop.http]` section below. In lean mode (sidecar disabled), attempting an
  upload fails fast with a structured capability error (`CAPABILITY_NOT_AVAILABLE`,
  HTTP 415/501) whose hint names `[desktop.http]` and the missing capability.
- **Auth is Bearer-token only on native.** The middleware chain (CORS, tracing,
  rate limiting, request-context, JWT) runs only under HTTP. Native carries a
  `token` string; cookie/SSO/session auth is an HTTP-only concern.
- **Concurrency is a bounded worker pool.** Native invocations run on a small pool
  (`boot(..., pool_size=N)`, default 4), each worker holding a persistent event
  loop so loop-bound resources survive across calls. Execution is OCC-guarded
  exactly as under HTTP. A saturated queue returns `NATIVE_DISPATCH_BUSY`; a call
  exceeding the timeout returns `NATIVE_DISPATCH_TIMEOUT` and the pool stays
  healthy for the next item.
- **Streaming uses a push protocol with cancellation + optional backpressure.** A
  generator walker/function replies with `{__jac_stream, protocol:push,
  stream_id}` and frames arrive via `window.__jac.on("__jac_stream", ...)`. The
  consumer signals teardown with a `{__jac_stream_ctl:"cancel", stream_id}` frame
  (stops the pump and closes the generator promptly) and can pace the producer
  with `{__jac_stream_ctl:"ack", stream_id, n}` when the stream was opened with a
  positive `stream_window`. **Known limitation:** if the client never acks, the
  pump falls back to fire-and-forget (bounded to one window per burst, not truly
  backpressured), and the streaming request-context lifetime tracks the same
  open question as HTTP SSE.
- **`http_status` rides inside the JSON body**, not a real transport status line,
  so a consumer that keyed on an HTTP status must read `body`/`http_status`
  instead.

## See also

- `jac-project-kinds` - desktop vs web vs mobile target comparison
- `jac-fullstack-patterns` - the cl/sv app you're packaging
- `jac-cl-components` - writing the UI itself
