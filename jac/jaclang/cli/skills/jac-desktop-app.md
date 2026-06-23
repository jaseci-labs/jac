---
name: jac-desktop-app
description: Packaging a full-stack Jac app as a native desktop app - `jac build/start --client desktop`, `[plugins.desktop]` window config, OS-webview architecture (no Rust, no Electron), Linux build deps, output layout, current limitations. Load when shipping a `cl` UI as a desktop binary.
---

The desktop target turns a full-stack Jac app into **one `jac nacompile`d binary plus the OS's own web engine** - no Rust toolchain, no Electron, no PyInstaller, no separate backend process. It builds the same Vite `cl` bundle the web target produces, then compiles a native host that embeds CPython to serve that bundle on a loopback port and renders it in the OS-native webview: WebKitGTK (Linux), WKWebView (macOS), WebView2 (Windows). Same `cl`/`sv` source as the web target - only the target flag changes.

## Build and run

The desktop target ships with `jaclang` core -- nothing extra to install.

```bash
jac build --client desktop      # -> .jac/client/desktop/<app>  (single binary + dist/)
jac start --client desktop      # build (if needed), then launch the native window
```

There is **no `jac setup desktop` step** - the native host is generated at build time. Run the built binary directly with `(cd .jac/client/desktop && ./<app>)`.

Build machine needs the OS web engine + a C toolchain (a small `libwebview.so` wrapper is compiled on first use). Debian/Ubuntu:

```bash
sudo apt-get install -y build-essential pkg-config libgtk-3-dev libwebkit2gtk-4.1-dev
```

(`jaclang` ships a helper: `jaclang/runtimelib/client/targets/desktop/native/webview/install_webkit_deps.sh`.)

## Configuration - `[plugins.desktop]` in `jac.toml`

All fields optional:

```toml
[plugins.desktop]
name = "my-app"                  # binary name
identifier = "com.example.myapp"
version = "1.0.0"

[plugins.desktop.window]
title = "My App"
width = 1000
height = 700
min_width = 800
min_height = 600
resizable = true
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

- **In progress** (per [issue #6436](https://github.com/jaseci-labs/jaseci/issues/6436)): wiring the `sv` codespace and walkers onto the embedded interpreter, HMR dev mode, and per-OS packaging/signing. Today the binary reliably renders your `cl` UI; develop/iterate against `jac start --dev` (web) and treat desktop as the packaging step.
- **No cross-compilation yet.** `--platform` only affects sidecar *naming* (`--platform windows` selects `.exe`); build on each target OS.
- Desktop builds set `JAC_BUILD=1` so import-time server starts stay inert - guard side effects accordingly.
- `jac nacompile` lowers the host with Jac's pure-Jac linker (no `cc`/`ld` at link time), but the C toolchain is still needed once for `libwebview.so`.

## See also

- `jac-project-kinds` - desktop vs web vs mobile target comparison
- `jac-fullstack-patterns` - the cl/sv app you're packaging
- `jac-cl-components` - writing the UI itself
