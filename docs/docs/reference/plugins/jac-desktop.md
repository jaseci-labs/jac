# jac-desktop Reference

The **desktop target** (historically the standalone `jac-desktop` plugin, now built
into `jaclang` core) adds a Jac-native desktop build to full-stack Jac apps. A
desktop app is **one `jac nacompile`d binary plus a web engine** - no Rust
toolchain, no PyInstaller, no separate process.

It builds the same Vite frontend that the **jac-client** framework produces (the `cl`
codespace), then compiles a native host (`na`) that embeds CPython to serve that
bundle on a loopback port and renders it in either the OS-native webview
(WebKitGTK on Linux, WKWebView on macOS, WebView2 on Windows) or Chromium
Embedded Framework (CEF). The embedded interpreter is also where the `sv`
backend runs in-process.

The `desktop` and `cef` targets register automatically as part of
`jaclang` core, so `jac build --client desktop`,
`jac start --client desktop`, `jac build --client cef`, and
`jac start --client cef` work out of the box.

---

## Installation

The desktop target ships with `jaclang` core -- there is nothing extra to install. Just install the `jac` binary:

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
```

Building a desktop app links a small native webview wrapper (`libwebview.so`),
which is compiled on first use, so the build machine needs the OS web engine plus
a C toolchain. On Debian/Ubuntu:

```bash
sudo apt-get install -y build-essential pkg-config libgtk-3-dev libwebkit2gtk-4.1-dev
```

(`jaclang` ships a helper,
`jaclang/runtimelib/client/targets/desktop/native/webview/install_webkit_deps.sh`,
that installs these.)

---

## Usage

There is **no setup step** - the native host is generated at build time.

```bash
jac build --client desktop      # -> .jac/client/desktop/<app>  (single binary + dist/)
jac start --client desktop      # build, then launch the native window

jac build --client cef  # -> .jac/client/cef/  (Chromium/CEF)
jac start --client cef  # build, then launch the CEF window
```

The output directory `.jac/client/desktop/` contains the self-contained binary,
its `dist/` (the served bundle), and `libwebview.so`. The binary resolves its
sibling `dist/` and `libwebview.so` relative to itself, so the directory is
relocatable.

Use `desktop` when you want the smallest native wrapper around the platform web
engine. Use `cef` when your app needs a consistent Chromium runtime
across machines, stricter parity with browser APIs, or CEF-specific diagnostics.
The CEF target stages the CEF runtime, `libcef_dispatch.so`, `cef-subprocess`,
and support files beside the app binary.

---

## Configuration

App identity and window geometry come from `[desktop]` in `jac.toml`:

```toml
[desktop]
name = "my-app"
identifier = "com.example.myapp"
version = "1.0.0"
engine = "native"  # "native" or "cef"

[desktop.window]
title = "My App"
width = 1000
height = 700
min_width = 800
min_height = 600
resizable = true
```

`engine` defaults to `"native"`. Set it to `"cef"` when the project should use
Chromium Embedded Framework:

```toml
[desktop]
engine = "cef"
```

Then build or launch the matching target:

```bash
jac build --client cef
jac start --client cef
```

The example app at `jac/examples/notes-app/` is a small notes editor that uses
`engine = "cef"` and includes a diagnostics drawer for the desktop bridge,
loopback broker, and `localStorage` persistence checks.

---

## CEF runtime flags

The `cef` target accepts a few environment variables for diagnostics and
platform workarounds:

| Variable | Effect |
|----------|--------|
| `JAC_CEF_DISABLE_GPU=1` | Adds Chromium GPU-disable switches; useful on VMs, CI, or machines with broken GL drivers. |
| `JAC_CEF_VERBOSE=1` | Enables Chromium logging to stderr with `--enable-logging=stderr --v=1`. |
| `JAC_CEF_USER_DATA_DIR=/path` | Overrides the CEF profile directory used for cookies, cache, and `localStorage`. |
| `JAC_CEF_HEADLESS=1` | Adds Chromium headless mode and disables GPU; useful for smoke tests. |
| `JAC_CEF_SINGLE_PROCESS=1` | Runs CEF in single-process mode for debugging only. |
| `JAC_CEF_IN_PROCESS_GPU=1` | Runs GPU work in-process for debugging GPU startup issues. |
| `FONTCONFIG_FILE=$PWD/minimal-fonts.conf` | Uses the bundled minimal fontconfig file on Linux. |
| `OZONE_PLATFORM=x11` or `wayland` | Forces Chromium's Linux display backend when auto-detection fails. |

For example:

```bash
cd .jac/client/cef
JAC_CEF_DISABLE_GPU=1 OZONE_PLATFORM=x11 ./my-app
```

---

## OS capabilities (plugin IPC)

A desktop app can reach OS capabilities the browser sandbox forbids. The native
host runs a plugin host and injects a bridge onto the webview's global:
`window.__jac.invoke(plugin, command, args)` (async; resolves to data or throws a
structured `PluginError`) and `window.__jac.on(event, callback)`. Rather than
hand-writing those magic strings, import the typed `@jac/desktop` client SDK from
`cl` code:

```jac
import from "@jac/desktop" { fs, dialog, notification }

async def export_notes(text: str) -> None {
    picked = await dialog.save_file("Export", "notes.txt");
    if not picked["canceled"] {
        await fs.write_file(picked["path"] as str, text);   # dict values are `any` - cast at the boundary
        await notification.send("Saved", "Notes exported.");
    }
}
```

Seven built-in capability plugins ship with the desktop target (every method is
`async`):

| SDK object | Capability | Methods |
|---|---|---|
| `fs` | Filesystem | `read_file`, `write_file`, `list_dir`, `exists`, `mkdir`, `remove`, `stat` |
| `dialog` | Native dialogs | `open_file`, `save_file`, `message` |
| `clipboard` | System clipboard | `read`, `write` |
| `notification` | OS notifications | `send` |
| `app_window` | Window control | `set_title`, `set_size`, `fullscreen`, `terminate` |
| `shell` | Run a command | `exec` |
| `path` | OS directories | `home`, `data`, `config`, `cache`, `temp`, `resolve` |

The window-control object is named `app_window` (not `window`) so it never
shadows the ambient browser `window` global.

`@jac/*` modules resolve through the `jac.modules` entry-point group, so SDKs like
`@jac/desktop` are available without vendoring them into your project.

### Security gating

Each capability is gated under `[desktop.plugins]` in `jac.toml`. A key is
a plugin name; its value is either `true` (enabled with defaults) or a table of
per-plugin config. `window`, `path`, `notification`, and `dialog` are enabled by
default; `shell` is **deny-all** by default. An unknown plugin key is reported as
an error rather than silently ignored.

```toml
[desktop.plugins]
fs = { allow_read = ["$HOME"], allow_write = ["$APP_DATA"] }   # glob allow-lists (defaults shown)
clipboard = { allow_read = true, allow_write = true }
shell = { allow = ["git *"] }                                  # patterns must be explicitly allowed
notification = true
```

!!! warning "Pass SDK arguments positionally"
    Call SDK methods with positional arguments, not keywords. The `cl` compiler
    cannot resolve parameter names across the `@jac/desktop` module boundary, so a
    keyword call such as `dialog.save_file(title="Export")` compiles to a single
    options object in the first positional slot and the host rejects it. Use
    `dialog.save_file("Export", "notes.txt")`. Tracked in
    [issue #6675](https://github.com/jaseci-labs/jaseci/issues/6675).

---

## How it works

1. `WebTarget` builds the `cl` codespace with the standard Vite pipeline into
   `.jac/client/dist/`.
2. jac-desktop generates a native host that:
   - `Py_Initialize()`s an embedded CPython and starts `http.server` on a
     loopback port in a daemon thread, serving `dist/` (resolved next to the
     binary);
   - opens either an OS-native webview or a CEF browser window and navigates to
     that loopback URL.
3. `jac nacompile` lowers the host to a native binary via Jac's pure-Jac linker
   (no `cc`/`ld`), recording the renderer libraries with an `$ORIGIN` runpath.

The native webview binding, build tooling, and a dependency-free test suite live
inside `jaclang` core under `jaclang/runtimelib/client/targets/desktop/native/webview/`.
The CEF binding, pinned CEF fetch tooling, and QA checklist live under
`jaclang/runtimelib/client/targets/desktop/native/cef/`.

---

## Status

`jac build --client desktop` produces a working, self-contained native desktop
binary that renders your `cl` UI. In progress: wiring the `sv` codespace and
walkers onto the embedded interpreter, HMR dev mode, and per-OS
packaging/signing. See
[issue #6436](https://github.com/jaseci-labs/jaseci/issues/6436).
