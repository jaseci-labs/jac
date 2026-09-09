# jac-desktop Reference

The **desktop target** (historically the standalone `jac-desktop` plugin, now built
into `jaclang` core) adds a Jac-native desktop build to full-stack Jac apps. A
desktop app is **one `jac build --native`d binary plus a web engine** - no Rust
toolchain, no PyInstaller, no separate process.

It builds the same Vite frontend that the **jac-client** framework produces (the `cl`
codespace), then compiles a native host (`na`) that embeds CPython to serve that
bundle on a loopback port and renders it in either the OS-native webview
(WebKitGTK on Linux, WKWebView on macOS, WebView2 on Windows) or Chromium
Embedded Framework (CEF). The embedded interpreter is also where the `sv`
backend runs in-process.

The desktop target registers automatically as part of `jaclang` core. An app
declared with `kind = "desktop"` (`jac create myapp --kind desktop`, or `jac
create --app studio --kind desktop` inside a workspace) builds and launches the
native window from `jac build <app>` and `jac run <app>` with no flag. The
renderer is `[desktop] engine`: `"native"` (the default, the OS webview) or
`"cef"` (Chromium).

---

## Installation

The desktop target ships with `jaclang` core -- there is nothing extra to install. Just install the `jac` binary:

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
```

Jac provisions the native webview wrapper and its build dependencies automatically.
Use `jac setup --toolchain desktop` to prepare them ahead of time. Linux system
libraries require administrator access; downloads and generated native libraries
live in the managed toolchain cache.

---

## Usage

There is **no setup step** - the native host is generated at build time.

```toml
[apps.studio]          # or [project] kind = "desktop" in a single-app project
kind = "desktop"
path = "studio"
```

```bash
jac build studio       # -> .jac/client/desktop/<app>  (single binary + dist/)
jac run studio         # build, then launch the native window
jac run --dev studio   # HMR: Vite on loopback + recompile on .jac saves (engine = "native" only)
```

In a single-app project the app name is implied: `jac build` / `jac run`.

The output directory `.jac/client/desktop/` contains the self-contained binary,
its `dist/` (the served bundle), and the renderer's libraries: `libwebview.so`
with the native engine; the CEF runtime, `libcef_dispatch.so`, `cef-subprocess`
and support files with `engine = "cef"`. The binary resolves its siblings
relative to itself, so the directory is relocatable.

Use the native engine when you want the smallest wrapper around the platform
web engine. Use `cef` when your app needs a consistent Chromium runtime across
machines, stricter parity with browser APIs, or CEF-specific diagnostics; CEF
has no HMR, so `jac run --dev` needs `engine = "native"`.

---

## Configuration

App identity, window geometry, the engine and the backend come from `[desktop]`
in `jac.toml`. In a workspace, `[apps.<name>.desktop]` overlays it for that
app, the way `[apps.<name>.client]` overlays `[client]`:

```toml
[desktop]
name = "my-app"
identifier = "com.example.myapp"
version = "1.0.0"
engine = "native"        # "native" (OS webview) or "cef" (Chromium)
backend = "embedded"     # or the URL of the server the app talks to

[desktop.window]
title = "My App"
width = 1000
height = 700
min_width = 800
min_height = 600
resizable = true
```

`backend` says where the app's server runs:

- `"embedded"` (the default): the desktop process serves the program itself.
  The build seals the project into an image shipped beside the binary (the
  workspace's default serving app plus its colocated service apps, or the
  desktop app's own server side in a single-app project) and the host boots
  it on a loopback port.
- a URL such as `"https://jaclang.org"`: the app is a native window onto that
  server. The bundle is built with that as its API base, so every walker and
  function call goes there, and the host serves only the bundle and the
  desktop broker. The desktop app needs no server-side code of its own.

`engine` defaults to `"native"`. Set it to `"cef"` when the project should use
Chromium Embedded Framework. Then build or launch the app as usual:

```bash
jac build studio
jac run studio
```

The example app at `jac/examples/notes-app/` is a small notes editor that uses
`engine = "cef"` and includes a diagnostics drawer for the desktop bridge,
loopback broker, and `localStorage` persistence checks. `jac/examples/jaclang_org`
ships jaclang.org itself as a desktop app with `backend = "https://jaclang.org"`.

---

## CEF runtime flags

The CEF engine accepts a few environment variables for diagnostics and
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
cd .jac/client/desktop
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
   the app's client dir (`.jac/client/<app>/dist/` in a workspace). With a
   remote `backend`, that URL is baked in as the bundle's API base.
2. jac-desktop seals the program into an app image (`app.jab`, through the same
   `build_jab` that `jac build` uses) and generates a native host that:
   - boots the fused Jac runtime with an embedded CPython, materializes the
     image and runs the one Jac server (`JacAPIServer`) on a loopback port,
     serving the built bundle as its client and, for an embedded backend, the
     program with its colocated service apps behind their `/api/<app>` routes;
   - registers the desktop broker as a server extension under `/__jac/`:
     health, the SSO session, the OAuth start/callback pair, the plugin event
     stream and plugin invocation;
   - opens either an OS-native webview or a CEF browser window and navigates to
     that loopback origin. Walker and function calls are ordinary HTTP, exactly
     as in the browser; there is no second transport for the native window.
3. `jac build --native` lowers the host to a native binary via Jac's pure-Jac linker
   (no `cc`/`ld`), recording the renderer libraries with an `$ORIGIN` runpath.

Each desktop app of a workspace builds under its own `.jac/client/<app>/desktop/`.

The native webview binding, build tooling, and a dependency-free test suite live
inside `jaclang` core under `jaclang/client/targets/desktop/native/webview/`.
The CEF binding, pinned CEF fetch tooling, and QA checklist live under
`jaclang/client/targets/desktop/native/cef/`.

---

## Status

Beta 🧪. `jac build <app>` on a `desktop` app produces a working, self-contained
native desktop binary that renders your `cl` UI and serves your program from
the sealed image on a loopback port (or points at a remote server), with HMR
dev mode via `jac run --dev <app>`. Per-OS packaging/signing remains open. See
[issue #6436](https://github.com/jaseci-labs/jaseci/issues/6436).
