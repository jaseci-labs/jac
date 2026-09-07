---
name: jac-desktop-app
description: Packaging a full-stack Jac app as a native desktop app - a `kind = "desktop"` app built and launched by `jac build <app>` / `jac run <app>`, `[desktop]` window and engine config (OS webview or CEF), the `@jac/desktop` OS-capability plugins (fs/dialog/clipboard/notification/window/shell/path IPC), OS-webview architecture (no Rust, no Electron), Linux build deps, output layout, current limitations. Load when shipping a client UI as a desktop binary or calling OS capabilities from it.
---

The desktop target turns a full-stack Jac app into **one `jac build --native`d binary plus the OS's own web engine** - no Rust toolchain, no Electron, no PyInstaller, no separate backend process. It builds the same Vite client bundle the web target produces, then compiles a native host that embeds CPython to serve that bundle on a loopback port and renders it in the OS-native webview: WebKitGTK (Linux), WKWebView (macOS), WebView2 (Windows). Same client/server source as a web app - only the kind changes.

## Build and run

The desktop target ships with `jaclang` core -- nothing extra to install. The app's kind selects it: `[project] kind = "desktop"` in a single-app project, or an `[apps.<name>] kind = "desktop"` table in a workspace (`jac create --app studio --kind desktop`); no flag is needed. The renderer is `[desktop] engine`: `"native"` (default, the OS webview) or `"cef"` (a bundled Chromium; no HMR, so `jac run --dev` needs `engine = "native"`). Both build into `.jac/client/desktop/`.

```bash
jac build studio           # -> .jac/client/desktop/<app>  (single binary + dist/); plain `jac build` in a single-app project
jac run studio             # build (if needed), then launch the native window
jac run --dev studio       # HMR: Vite on 127.0.0.1 + recompile on .jac saves
```

There is **no `jac setup desktop` step** - the native host is generated at build time. Run the built binary directly with `(cd .jac/client/desktop && ./<app>)`.

Jac provisions the native webview wrapper and its build dependencies automatically.
Use `jac setup --toolchain desktop` to prepare them ahead of time. Linux system
libraries require administrator access; downloads and generated native libraries
live in the managed toolchain cache.

## Configuration - `[desktop]` in `jac.toml`

All fields optional:

```toml
[desktop]
name = "my-app"                  # binary name
identifier = "com.example.myapp"
version = "1.0.0"
engine = "native"                # "native" (OS webview, default) or "cef" (bundled Chromium)

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

## Output layout

```
.jac/client/desktop/
  my-app          # the native binary
  dist/           # the served cl bundle
  libwebview.so   # OS-webview wrapper (resolved via $ORIGIN runpath)
```

The directory is **relocatable** - the binary finds its sibling `dist/` and `libwebview.so` relative to itself. Ship the whole directory.

## Gotchas and current limits

- **In progress** (per [issue #6436](https://github.com/jaseci-labs/jaseci/issues/6436)): per-OS packaging/signing (phase 5). The server codespace, walkers, and functions now run **in-process** on the embedded interpreter (shipped), and desktop has its own HMR dev mode: `jac run --dev <app>` builds the native host once, serves your client UI from Vite on `127.0.0.1`, and recompiles on `.jac` saves -- iterate against the real desktop window, no web fallback needed.
- **No cross-compilation yet.** `--platform` only affects sidecar *naming* (`--platform windows` selects `.exe`); build on each target OS.
- Desktop builds set `JAC_BUILD=1` so import-time server starts stay inert - guard side effects accordingly.
- `jac build --native` lowers the host with Jac's pure-Jac linker (no `cc`/`ld` at link time), but the C toolchain is still needed once for `libwebview.so`.

## See also

- `jac-project-kinds` - desktop vs web vs mobile target comparison
- `jac-fullstack-patterns` - the cl/sv app you're packaging
- `jac-cl-components` - writing the UI itself
