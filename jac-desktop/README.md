# jac-desktop

Jac-native desktop target for [Jac](https://jac-lang.org): a desktop app is **one
`jac nacompile`d binary + the OS's own web engine** - no Rust toolchain, no
PyInstaller, no separate process.

## What you get

- A `desktop` build target registered with `jac-client`'s target registry, so
  `jac build --client desktop` and `jac start --client desktop` work once this
  package is installed.
- The build pipeline:
  1. builds your `cl` codespace with the standard Vite pipeline (via `WebTarget`),
  2. compiles a native host (`na`) that embeds CPython to serve that bundle on a
     loopback port and renders it in the OS-native webview (WebKitGTK on Linux /
     WKWebView on macOS / WebView2 on Windows),
  3. produces a single self-contained binary under `.jac/client/desktop/`.

The native webview binding + build tooling live under
[`jac_desktop/native/webview/`](jac_desktop/native/webview/) (see its README for
the phase-by-phase design and the dependency-free test suite).

### CEF target (`desktop-cef`)

Set `engine = "cef"` under `[plugins.desktop]` in `jac.toml`, then:

```sh
jac build --client desktop-cef   # -> .jac/client/desktop-cef/
```

This uses Chromium Embedded Framework instead of the OS web engine. The loopback
server and OAuth broker are **identical** to the native target; only the renderer
differs. See [`jac_desktop/native/cef/README.md`](jac_desktop/native/cef/README.md)
for the full CEF design.

### FFI: two libraries, two jobs

Every desktop host (native or CEF) embeds **libpython** to run the loopback HTTP
server (`dist/` + `/__jac/*` OAuth broker). That is separate from the **renderer**
FFI that paints the window:

| Target | Renderer FFI | libpython FFI |
|--------|--------------|---------------|
| `desktop` (native) | Jac `na` → `libwebview.so` | Jac `na` `import from "libpython..."` |
| `desktop-cef` | Jac `na` → `libcef_shim.so` → `libcef.so` | Jac `na` `import from "libpython..."` |

libpython is **not** used for CEF/Chromium calls; it only starts the embedded
Python TCP server. CEF integration goes exclusively through `cef_shim.c`.

## Install

```sh
pip install jac-client jac-desktop
```

Building a **native** desktop app needs the OS web engine + a C toolchain so the
host can link `libwebview.so` (built on first use). The **CEF** target instead
downloads a pinned CEF binary dist (~1 GB) on first build; no WebKitGTK required.
Both need a system libpython (AOT-linked in the `na` host). `gcc` is only required
to build `libcef_shim.so` / `libwebview.so` on first use.

On Debian/Ubuntu (native target):

```sh
sudo ./jac_desktop/native/webview/install_webkit_deps.sh
# (build-essential, pkg-config, libgtk-3-dev, libwebkit2gtk-4.1-dev)
```

## Project flow

```sh
jac create --use fullstack my-app      # or any project with a cl codespace
cd my-app
jac build --client desktop             # -> .jac/client/desktop/<app>  (single binary)
jac start --client desktop             # build + launch the native window
```

Window geometry + app identity come from `[plugins.desktop]` in `jac.toml`:

```toml
[plugins.desktop]
name = "my-app"

[plugins.desktop.window]
title = "My App"
width = 1000
height = 700
```

## Status

`jac build --client desktop` produces a working, self-contained native desktop
binary that renders your `cl` UI. The host embeds CPython (it serves the bundle
and is where `sv` runs in-process). Remaining: wiring the `sv` codespace/walkers
onto the embedded interpreter, HMR dev mode, and per-OS packaging/signing - see
[issue #6436](https://github.com/jaseci-labs/jaseci/issues/6436).
