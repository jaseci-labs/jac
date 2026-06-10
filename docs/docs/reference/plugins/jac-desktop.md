# jac-desktop Reference

**jac-desktop** adds a Jac-native desktop build target to full-stack Jac apps. A
desktop app is **one `jac nacompile`d binary plus the OS's own web engine** -
no Rust toolchain, no PyInstaller, no separate process.

It builds the same Vite frontend that **jac-client** produces (the `cl`
codespace), then compiles a native host (`na`) that embeds CPython to serve that
bundle on a loopback port and renders it in the OS-native webview (WebKitGTK on
Linux, WKWebView on macOS, WebView2 on Windows). The embedded interpreter is also
where the `sv` backend runs in-process.

Install jac-client first; jac-desktop registers the `desktop` target through
jac-client's plugin hook system so `jac build --client desktop` and
`jac start --client desktop` work once both packages are installed.

---

## Installation

```bash
pip install jac-client jac-desktop
```

Building a desktop app links a small native webview wrapper (`libwebview.so`),
which is compiled on first use, so the build machine needs the OS web engine plus
a C toolchain. On Debian/Ubuntu:

```bash
sudo apt-get install -y build-essential pkg-config libgtk-3-dev libwebkit2gtk-4.1-dev
```

(The `jac-desktop` package ships a helper,
`jac_desktop/native/webview/install_webkit_deps.sh`, that installs these.)

---

## Usage

There is **no setup step** - the native host is generated at build time.

```bash
jac build --client desktop      # -> .jac/client/desktop/<app>  (single binary + dist/)
jac start --client desktop      # build, then launch the native window
```

The output directory `.jac/client/desktop/` contains the self-contained binary,
its `dist/` (the served bundle), and `libwebview.so`. The binary resolves its
sibling `dist/` and `libwebview.so` relative to itself, so the directory is
relocatable.

---

## Configuration

App identity and window geometry come from `[plugins.desktop]` in `jac.toml`:

```toml
[plugins.desktop]
name = "my-app"
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

---

## How it works

1. `WebTarget` builds the `cl` codespace with the standard Vite pipeline into
   `.jac/client/dist/`.
2. jac-desktop generates a native host that:
   - `Py_Initialize()`s an embedded CPython and starts `http.server` on a
     loopback port in a daemon thread, serving `dist/` (resolved next to the
     binary);
   - opens an OS-native webview and navigates to that loopback URL.
3. `jac nacompile` lowers the host to a native binary via Jac's pure-Jac linker
   (no `cc`/`ld`), recording `libwebview.so` as a needed library with an
   `$ORIGIN` runpath.

The native webview binding, build tooling, and a dependency-free test suite live
inside the package under `jac_desktop/native/webview/`.

---

## Status

`jac build --client desktop` produces a working, self-contained native desktop
binary that renders your `cl` UI. In progress: wiring the `sv` codespace and
walkers onto the embedded interpreter, HMR dev mode, and per-OS
packaging/signing. See
[issue #6436](https://github.com/jaseci-labs/jaseci/issues/6436).
