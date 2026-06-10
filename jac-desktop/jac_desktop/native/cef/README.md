# Jac-native CEF binding

The CEF (Chromium Embedded Framework) binding for `jac-desktop` provides a
consistent Chromium rendering engine across all platforms. Use the
`desktop-cef` client target (`jac build --client desktop-cef`).

## Architecture

The `desktop-cef` host uses **two independent FFI layers**. libpython is **not**
used to talk to Chromium; it only embeds a minimal CPython runtime for the
loopback HTTP server.

### FFI layers

| Library | Link style | Purpose |
|---------|------------|---------|
| **libpython** | AOT-linked via Jac `import from "libpython…"` in generated `host.na.jac` | Embed CPython: start loopback server, run `oauth_broker.py`, read `_port` |
| **libcef** | Build-time link via `libcef_shim.so` | Browser window, rendering, CEF subprocesses |

**libpython FFI**: the generated Jac `na` host (`host.na.jac`, built with
`jac nacompile`) AOT-links the system libpython soname and calls a small C-API
surface:

- `Py_Initialize` / `Py_Finalize`
- `PyRun_SimpleString`: runs embedded Python that binds `TCPServer` on
  `127.0.0.1`, serves `dist/`, and exposes `/__jac/*` via `oauth_broker.py`
- `PyRun_String` / `PyLong_AsLong`: reads `_port` from `__main__` to build the
  navigation URL
- `PyEval_SaveThread` / `PyEval_RestoreThread`: releases the GIL while the CEF
  message loop runs

The embedded interpreter uses **stdlib only** (no jaclang). `oauth_broker.jac` is
transpiled to pure-Python `oauth_broker.py` at build time and shipped beside the
binary.

**CEF FFI**: CEF's C API requires client-side vtable structs with refcount
callbacks and precise memory layout. Jac FFI handles scalars and strings cleanly
but cannot express those vtables directly. The binding follows the same pattern as
the webview integration:

| Layer | Role |
|-------|------|
| `cef_shim.c` → `libcef_shim.so` | C bridge: owns all CEF vtables, settings, browser creation |
| `cef.na.jac` | Thin Jac binding: scalar/string FFI + `CefBrowser` ergonomic wrapper (tests/smoke hosts) |
| `host.na.jac` | Production host (generated): `jac_cef_*` + embedded CPython loopback |
| `CefDesktopTarget` | Build pipeline: fetch CEF, build shim, stage runtime, compile host |

Jac code never touches CEF vtable structs; only `libcef_shim.so` exports.
The production `desktop-cef` binary links `-lcef_shim -lcef -ldl`; it does **not**
link libpython at build time (same as the native `desktop` target).

### Startup sequence

```
main()
  ├─ jac_cef_execute_process()     # CEF subprocess? exit early
  ├─ Py_Initialize()               # embed CPython (AOT-linked)
  ├─ PyRun_SimpleString(SERVE_PY)  # loopback server + oauth broker (daemon thread)
  ├─ read _port → build URL
  ├─ jac_cef_create_browser(url)   # queue browser (UI thread)
  ├─ jac_cef_initialize()          # CEF init → on_context_initialized creates window
  ├─ jac_cef_run_message_loop()    # GIL released via PyEval_SaveThread
  ├─ Py_Finalize()
  └─ jac_cef_shutdown()
```

### Comparison with the native `desktop` target

Both targets share the same loopback-server Python (`SERVE_PY`) and
`oauth_broker.py`. They differ only in how the shell renders the URL:

| | Native (`desktop`) | CEF (`desktop-cef`) |
|--|-------------------|---------------------|
| Renderer FFI | Jac `na` → `libwebview.so` (AOT link) | Jac `na` → `libcef_shim.so` → `libcef.so` |
| Host language | Jac `na` (`host` via `jac nacompile`) | Jac `na` (`host` via `jac nacompile`) |
| libpython FFI | Jac `import from "libpython..."` (AOT link) | Jac `import from "libpython..."` (AOT link) |
| Bootstrap globals | `webview_init(BOOTSTRAP_JS)` on each load | `on_context_created` in shim (V8 globals) |

Both targets now share the same host pattern: `jac nacompile` on a generated
`host.na.jac` that AOT-links libpython and the renderer shim/library.

## Contents

| File | Role |
|------|------|
| `cef.na.jac` | Jac binding over `libcef_shim.so` (`new_cef_browser`, `CefBrowser`, `cef_cleanup`) |
| `cef_shim.c` | C shim implementing CEF vtables and the scalar FFI surface |
| `build_cef_shim.sh` | Compiles `libcef_shim.so` against staged `cef_dist/libcef.so` |
| `fetch_libcef.sh` | Downloads pinned CEF binary + SDK headers (one-time, ~800 MB tarball) |
| `cef_smoke.na.jac` | Smoke test: init + shutdown via the shim |
| `cef_test_host.na.jac` | Manual test: opens example.com in a CEF window |

## Prerequisites

On first `desktop-cef` build the pipeline runs `fetch_libcef.sh` and
`build_cef_shim.sh` automatically. You need:

- `curl` for downloading
- `gcc` for building the shim
- ~1 GB disk for the cached CEF tarball + staged runtime

Generated artifacts (not committed):

- `cef_dist/`: CEF runtime (`libcef.so`, `.pak`, `locales/`, ...)
- `cef_headers/`: CEF SDK headers (build-time only)
- `libcef_shim.so`: compiled shim

On Linux, `chrome-sandbox` requires setuid root for the renderer sandbox:

```sh
sudo chown root:root cef_dist/chrome-sandbox
sudo chmod 4755 cef_dist/chrome-sandbox
```

Without setuid, the shim passes `--no-sandbox` via `no_sandbox=1` (OK for dev).

## Notes

- CEF subprocess handling is inside `new_cef_browser()` via `jac_cef_execute_process()`.
- The loopback server model matches the native target: host serves `dist/` on
  `http://127.0.0.1:<port>/` and CEF navigates there after Python starts.
- `cache_path` in `new_cef_browser()` controls CEF profile/localStorage persistence.
- **Bootstrap JS injection**: `cef_render_process_handler_t::on_context_created`
  in the shim sets `window.__JAC_DESKTOP__ = true` and
  `window.__JAC_BROKER__ = '/__jac'` on the V8 global object synchronously
  before any page scripts execute. This is the CEF equivalent of the native
  target's `webview_init(BOOTSTRAP_JS)`.
