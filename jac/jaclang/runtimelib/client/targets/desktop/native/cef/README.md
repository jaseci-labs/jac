# Jac-native CEF binding

The CEF (Chromium Embedded Framework) binding for `jac-desktop` provides a
consistent Chromium rendering engine across all platforms. Use the
`cef` client target (`jac build --client cef`).

## Architecture

The `cef` host is a single `jac nacompile` binary. There is **no C
shim**: the CEF vtables and glue are written in Jac-native (`*.na.jac`) and
compiled directly. libpython is **not** used to talk to Chromium; it only
embeds a minimal CPython runtime for the loopback HTTP server.

### FFI layers

| Library | Link style | Purpose |
|---------|------------|---------|
| **libcef** | `import from "libcef.so"` in `cef.na.jac` (AOT) | Browser window, rendering, message loop |
| **libcef_dispatch** | `import from "libcef_dispatch.so"` in `cef.na.jac` (AOT) | Jac-native helper for the few things FFI can't express directly |
| **libpython** | `import from "libpython…"` in generated `host.na.jac` (AOT) | Embed CPython: loopback server, `oauth_broker.py`, read `_port` |

**CEF FFI**: CEF's C API requires client-side vtable structs with refcount
callbacks and precise memory layout. `cef_dispatch.na.jac` (compiled to
`libcef_dispatch.so`) owns all CEF vtable structs (`cef_app_t`, `cef_client_t`,
`cef_life_span_handler_t`, …) as flat Jac clib structs with `Callable` fields.
`cef.na.jac` is a thin facade over that shared library. The exported CEF
entry points used directly by hosts (`cef_run_message_loop`, `cef_shutdown`) are
imported from `libcef.so`. `libcef_dispatch.so` wraps the two things Jac FFI
cannot express: calling methods on CEF-returned objects through their vtable
pointers, and allocating data structs with mixed-size fields.

**libpython FFI**: the generated `host.na.jac` AOT-links the system libpython
soname and calls a small C-API surface (`Py_Initialize`/`Py_Finalize`,
`PyRun_SimpleString`/`PyRun_String`, `PyLong_AsLong`,
`PyEval_SaveThread`/`PyEval_RestoreThread`). The embedded interpreter is
**stdlib only** (no jaclang); `oauth_broker.jac` is transpiled to pure-Python
`oauth_broker.py` at build time and shipped beside the binary.

### CEF subprocesses

CEF spawns render/GPU/utility helper processes. These run the standalone
`cef-subprocess` binary (built from `cef_subprocess.na.jac`), staged beside the
host. The host's first call, `cef_execute_subprocess()`, returns `>= 0` when the
current process *is* a CEF subprocess so the host can exit early.

### The `close()` / RTLD_NEXT requirement

libcef's `.init_array` constructors call `dlsym(RTLD_NEXT, "close")` during
init. `RTLD_NEXT` resolves to the next definition of `close` *after* the caller
in the link map, so **libc must appear after libcef in `DT_NEEDED`**. `jac
nacompile` guarantees this by appending `libc.so.6`/`libm.so.6` last in the
needed-library list (see `nacompile.impl.jac`). No `LD_PRELOAD` or injected C
shim is required; an earlier `close_preload.c` approach was removed in favor of
this ordering.

### Startup sequence

```
with entry {                       # generated host.na.jac
  ├─ cef_execute_subprocess()      # CEF subprocess? exit early
  ├─ cef_startup(cache_path, …)    # CEF init / dispatch bootstrap
  ├─ Py_Initialize()               # embed CPython (AOT-linked)
  ├─ PyRun_SimpleString(SERVE_PY)  # loopback server + oauth broker (daemon thread)
  ├─ read _port → build URL
  ├─ cef_open_browser(url, …)      # create window + navigate
  ├─ PyEval_SaveThread()           # release GIL
  ├─ cef_run_loop()                # CEF message loop
  ├─ PyEval_RestoreThread() / Py_Finalize()
  └─ cef_cleanup()
}
```

### Comparison with the native `desktop` target

Both targets share the same loopback-server Python (`SERVE_PY`) and
`oauth_broker.py`, and both compile a generated `host.na.jac` via `jac
nacompile`. They differ only in the renderer:

| | Native (`desktop`) | CEF (`cef`) |
|--|-------------------|---------------------|
| Renderer FFI | Jac `na` → `libwebview.so` | Jac `na` → `libcef.so` + `libcef_dispatch.so` |
| Bootstrap globals | `webview_init(BOOTSTRAP_JS)` on each load | `on_context_created` in `cef_dispatch.na.jac` (V8 globals) |

## Contents

| File | Role |
|------|------|
| `cef.na.jac` | Thin Jac binding over `libcef_dispatch.so` + message-loop imports from `libcef.so` |
| `cef_dispatch.na.jac` | Source for `libcef_dispatch.so` (vtable structs, callbacks, lifecycle) |
| `cef_platform.na.jac` | Shared stub vtables + `/proc/self/cmdline` parsing (spliced into both `.na.jac` sources at the `# PLATFORM` marker) |
| `cef_subprocess.na.jac` | Source for the `cef-subprocess` helper binary |
| `build.jac` | Runnable entry: `jac run build.jac` → `libcef_dispatch.so` + `cef-subprocess` (used by CI) |
| `cef_sums.lock` | Pinned CEF version + archive SHA-1 digests (download trust anchor) |
| `minimal-fonts.conf` | fontconfig used at runtime via `FONTCONFIG_FILE` |
| `cef_smoke.na.jac` | Smoke test: init + shutdown |
| `cef_test_host.na.jac` | Manual test: opens a page in a CEF window |

## Prerequisites

On first `cef` build the pipeline fetches the CEF distribution and compiles the
native pieces automatically (all in Jac -- see `desktop_build.jac`; `build.jac`
is the standalone entry). You need:

- `jac` on `PATH` (the native pieces compile with `jac nacompile`, **no gcc**;
  the download + SHA-1 verify + unpack run in-process via the Python stdlib, so
  **no `curl`**)
- `patchelf` (optional) -- the Jac native linker already emits an `$ORIGIN`
  RUNPATH, so this is belt-and-suspenders for any host/linker that does not
- ~1 GB disk for the cached CEF tarball + staged runtime

Generated artifacts (not committed; see `.gitignore`):

- `cef_dist/`: CEF runtime (`libcef.so`, `.pak`, `locales/`, …)
- `cef_headers/`: CEF SDK headers (build-time only)
- `libcef_dispatch.so`, `cef-subprocess`: compiled native pieces

On Linux, `chrome-sandbox` requires setuid root for the renderer sandbox:

```sh
sudo chown root:root cef_dist/chrome-sandbox
sudo chmod 4755 cef_dist/chrome-sandbox
```

Without setuid, the host passes `--no-sandbox` (OK for dev).

## Notes

- **Pinned CEF version**: `cef_sums.lock` pins the exact CEF version (its
  `# version:` directive) and archive digests. The flat
  struct layouts in `cef.na.jac` / `cef_dispatch.na.jac` are version-specific
  (field offsets and `sizeof` are hard-coded for the pinned major); a version
  bump requires re-verifying every offset.
- **Bootstrap JS injection**: the `on_context_created` handler sets
  `window.__JAC_DESKTOP__ = true` and `window.__JAC_BROKER__ = '/__jac'` on the
  V8 global object before any page scripts execute (the CEF equivalent of the
  native target's `webview_init(BOOTSTRAP_JS)`).
- `cache_path` controls CEF profile/localStorage persistence.
