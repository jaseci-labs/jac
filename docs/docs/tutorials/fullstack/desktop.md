# Building a Desktop App

This tutorial walks you through building and running an existing Jac full-stack
app as a native desktop app. The desktop target turns your app into **one
`jac nacompile`d binary plus the OS's own web engine** - no Rust toolchain, no
PyInstaller, and no separate backend process. It builds the same `cl` frontend
the web target produces, then compiles a native host that embeds CPython to serve
that bundle and renders it in the OS-native webview (WebKitGTK on Linux,
WKWebView on macOS, WebView2 on Windows).

!!! note "Status"
    `jac build --client desktop` produces a working, self-contained desktop
    binary that renders your `cl` UI. Wiring the `sv` backend/walkers onto the
    embedded interpreter, HMR dev mode, and per-OS installers/signing are in
    progress - see [issue #6436](https://github.com/jaseci-labs/jaseci/issues/6436).

> **Prerequisites**
>
> - Completed: [Project Setup](setup.md) - you have a working `jac start` web app
> - The full-stack client and desktop framework ships with `jaclang` core -- nothing extra to install
> - Installed: the OS web engine + a C toolchain (the native host links a small
>   `libwebview.so`, built on first use). On Debian/Ubuntu:
>   `sudo apt-get install -y build-essential pkg-config libgtk-3-dev libwebkit2gtk-4.1-dev`
> - **No Rust toolchain required.**

---

## 1. Configure the window

Add a `[plugins.desktop]` section to your `jac.toml` (all fields optional):

```toml
[plugins.desktop]
name = "my-app"

[plugins.desktop.window]
title = "My App"
width = 1000
height = 700
```

There is no `jac setup desktop` step - the native host is generated at build time.

---

## 2. Build the desktop app

```bash
jac build --client desktop
```

This:

1. builds your `cl` codespace with the standard Vite pipeline (`.jac/client/dist/`),
2. generates a native host that embeds CPython to serve that bundle on a loopback
   port and renders it in the OS webview,
3. compiles the host with `jac nacompile` into a single binary.

The output lands in `.jac/client/desktop/`:

```
.jac/client/desktop/
  my-app          # the native binary
  dist/           # the served cl bundle
  libwebview.so   # the OS-webview wrapper (resolved via $ORIGIN)
```

The directory is relocatable - the binary finds its sibling `dist/` and
`libwebview.so` relative to itself.

---

## 3. Run it

```bash
jac start --client desktop      # builds (if needed) and launches the window
```

Or run the built binary directly:

```bash
(cd .jac/client/desktop && ./my-app)
```

A native window opens showing your `cl` UI, served in-process - no localhost you
manage, no second process.

---

## How it differs from the web target

| | web | desktop |
|---|---|---|
| output | bundle served by a host you run | one self-contained binary |
| UI runtime | a browser you point at the server | the OS-native webview |
| backend transport | HTTP to a remote server | embedded CPython, in-process |

The same `cl`/`sv` source builds for both - only the target changes.
