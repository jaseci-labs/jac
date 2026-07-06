# Building a Desktop App

This tutorial walks you through building and running an existing Jac full-stack
app as a native desktop app. The desktop targets turn your app into **one
`jac nacompile`d binary plus a web engine** - no Rust toolchain, no PyInstaller,
and no separate backend process. They build the same `cl` frontend the web target
produces, then compile a native host that embeds CPython to serve that bundle and
renders it in either the OS-native webview (WebKitGTK on Linux, WKWebView on
macOS, WebView2 on Windows) or Chromium Embedded Framework (CEF).

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
engine = "native"  # "native" or "cef"

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

To build with Chromium Embedded Framework instead of the OS webview, set
`engine = "cef"` and use the CEF target:

```toml
[plugins.desktop]
engine = "cef"
```

```bash
jac build --client cef
```

The CEF output lands in `.jac/client/cef/` and includes the app binary,
`dist/`, `libcef.so`, `libcef_dispatch.so`, `cef-subprocess`, Chromium `.pak`
files, locales, and support files. The first CEF build fetches the pinned CEF
runtime, so it needs network access and roughly 1 GB of disk for the cached
runtime and staged bundle.

---

## 3. Run it

```bash
jac start --client desktop      # builds (if needed) and launches the window
```

For the CEF renderer:

```bash
jac start --client cef
```

Or run the built binary directly:

```bash
(cd .jac/client/desktop && ./my-app)
```

A native window opens showing your `cl` UI, served in-process - no localhost you
manage, no second process.

The repo includes a runnable CEF example at `jac/examples/notes-app/`. It is a
small notes editor with a diagnostics drawer that checks the desktop bridge,
loopback broker, and `localStorage` persistence.

---

## CEF diagnostics and flags

Use the CEF target when you want a consistent Chromium renderer across machines
or need browser API parity beyond the platform webview. These environment
variables are useful when smoke-testing or debugging startup issues:

| Variable | Effect |
|----------|--------|
| `JAC_CEF_DISABLE_GPU=1` | Disables GPU/compositing for VMs, CI, or broken GL drivers. |
| `JAC_CEF_VERBOSE=1` | Enables Chromium logging to stderr. |
| `JAC_CEF_USER_DATA_DIR=/path` | Overrides the CEF profile directory for cookies, cache, and `localStorage`. |
| `JAC_CEF_HEADLESS=1` | Runs CEF headless and disables GPU for smoke tests. |
| `JAC_CEF_SINGLE_PROCESS=1` | Runs CEF in single-process mode for debugging only. |
| `JAC_CEF_IN_PROCESS_GPU=1` | Runs GPU work in-process for debugging GPU startup issues. |
| `FONTCONFIG_FILE=$PWD/minimal-fonts.conf` | Uses the bundled Linux fontconfig file. |
| `OZONE_PLATFORM=x11` or `wayland` | Forces Chromium's Linux display backend. |

Example Linux fallback launch:

```bash
cd .jac/client/cef
JAC_CEF_DISABLE_GPU=1 OZONE_PLATFORM=x11 ./my-app
```

---

## How it differs from the web target

| | web | desktop |
|---|---|---|
| output | bundle served by a host you run | one self-contained binary |
| UI runtime | a browser you point at the server | OS-native webview or CEF Chromium |
| backend transport | HTTP to a remote server | embedded CPython, in-process |

The same `cl`/`sv` source builds for both - only the target changes.
