# Building a Desktop App

This tutorial walks you through shipping an existing Jac full-stack app as a native desktop installer for Windows, macOS, and Linux. Unlike the web target -- which assumes a hosted backend somewhere -- the desktop target packages the **entire** Jac runtime, your `.jac` sources, and any plugins you depend on into a single installer that end users can double-click.

> **Prerequisites**
>
> - Completed: [Project Setup](setup.md) -- you have a working `jac start` web app
> - Installed: [Rust toolchain](https://rustup.rs) (`cargo --version` should work)
> - Installed: Platform build tools
>   - **Windows**: Visual Studio Build Tools (with the C++ workload)
>   - **macOS**: `xcode-select --install`
>   - **Linux**: `webkit2gtk-4.1`, `libssl-dev`, `librsvg2-dev`, `libayatana-appindicator3-dev`
> - Time: ~30 minutes (longer on the first build while Rust crates compile)

---

## How a Desktop Build Works

When you run `jac build --client desktop`, the build does five things:

1. **Compiles the client bundle** -- the same Vite build the web target produces.
2. **Bundles a sidecar** -- PyInstaller freezes Python, jaclang, jac-client, and any plugins you enabled into a single executable. Your `.jac` sources, `jac.toml`, and `assets/` are copied alongside it as bundle resources.
3. **Generates the Tauri shell** -- regenerates `src-tauri/tauri.conf.json` and `main.rs` from `[desktop]` in your `jac.toml`.
4. **Builds the installer with Tauri** -- produces a platform-native installer (`.msi`, `.dmg`, `.AppImage`, `.deb`, `.rpm`) under `src-tauri/target/release/bundle/`.

At runtime, the Tauri shell launches the sidecar on a free local port, reads `JAC_SIDECAR_PORT=<port>` from its stdout, and injects the resulting URL into the webview as `window.__JAC_API_BASE_URL__` before any page JavaScript runs. From the user's perspective it's a single double-click; under the hood it's just `jac start` running inside a webview shell.

---

## One-Time Setup

From your project root:

```bash
jac setup desktop
```

This creates `src-tauri/` with the Rust project skeleton, default icons, and a `tauri.conf.json` derived from your `jac.toml`. You only need to run this once per project; subsequent builds regenerate the relevant pieces from `jac.toml`.

---

## Configure Window and App Metadata

Open `jac.toml` and add a `[desktop]` section. None of these fields are mandatory -- they default off your `[project]` name and version -- but you'll usually want to override at least the window title and identifier:

```toml
[desktop]
name = "Day Planner"
identifier = "com.example.dayplanner"  # reverse-DNS, used by macOS/Linux
version = "1.0.0"

[desktop.window]
title = "Day Planner"
width = 1200
height = 800
min_width = 800
min_height = 600
resizable = true
fullscreen = false

[desktop.platforms]
windows = true
macos = true
linux = true
```

The next `jac build --client desktop` will pick these up automatically -- you don't need to edit `tauri.conf.json` by hand.

---

## Run a Development Build

The fastest dev loop is:

```bash
jac start main.jac --client desktop --dev
```

This launches the Tauri window pointing at the Vite dev server with HMR enabled. Edit a `.cl.jac` file, save, and the window updates without restarting.

For a full installer build:

```bash
jac build --client desktop
```

When this finishes, look in `src-tauri/target/release/bundle/`. You'll find one subdirectory per format your platform produces:

- `nsis/` and `msi/` on Windows
- `dmg/` and `macos/` on macOS
- `appimage/`, `deb/`, and `rpm/` on Linux

---

## Cross-Platform Builds

By default, `jac build --client desktop` builds for the platform you're running on. To target a different platform, pass `--platform`:

```bash
jac build --client desktop --platform windows
jac build --client desktop --platform macos
jac build --client desktop --platform linux
jac build --client desktop --platform all
```

Cross-compilation has the same caveats as any Rust+Tauri project: targeting macOS from Linux requires extra toolchain setup, and code-signing is platform-specific. CI is the easiest way to produce all three -- run a separate matrix job per platform.

---

## Choosing Which Plugins to Bundle

By default the sidecar bundles four Jac plugins: **jac-scale** (FastAPI server, auth, persistence), **byllm** (LLM provider integration), **jac-coder**, and **jac-mcp**. If your app doesn't use one of them, drop it from the bundle to shrink the installer:

```toml
[desktop.plugins]
jac_scale = true
byllm = false       # don't ship LLM providers
jac_coder = false
jac_mcp = false
```

A few rules to know:

- The plugins you list must already be installed in the **build environment** (`pip show jac-scale`, etc.) -- the build collects them from your current Python environment, not from PyPI.
- `jac_client` is **always** bundled regardless of this section, because the sidecar entry point imports it directly. Setting `jac_client = false` is silently ignored.
- Python dependencies declared under `[dependencies]` in `jac.toml` are auto-installed before PyInstaller runs -- you don't need to pre-install them yourself.

---

## Where Your Data Lives

This is the part that surprises most people the first time they install their own desktop build:

> The Jac runtime and jac-scale write the SQLite database, session files, and `.jac/data/` to the working directory by default. **An installed desktop app's working directory is read-only.**

`.AppImage` files mount under `/tmp/.mount_AppXXX/` (a read-only squashfs), `.deb` packages install to `/usr/lib/`, `.msi` installers land in `C:\Program Files\`. Writing to any of those will fail or crash, depending on the operation.

The sidecar handles this for you. Before importing any Jac module, it picks a writable path, sets `JAC_DATA_PATH` to it, and `chdir`s in. The Jac runtime's database resolver and jac-scale's config loader both honor this variable, so the database lands in a place the user can actually write to.

The default fallback chain:

| Platform | First choice | Fallback | Last resort |
|----------|--------------|----------|-------------|
| Linux / macOS | `~/.local/share/jac-app` | `~/.jac-app` | `/tmp/jac-app-{uid}` |
| Windows | `%LOCALAPPDATA%\jac-app` | `~/AppData/Local/jac-app` | `%TEMP%\jac-app` |

The sidecar tries each candidate in order and probes it with a touch/unlink test. If none of them work, the app exits with a loud error rather than silently writing to nowhere.

**Override the location** by exporting `JAC_DATA_PATH` before launching the app, or by passing `--data-path` directly to the sidecar binary if you're invoking it manually:

```bash
./src-tauri/binaries/jac-sidecar --data-path /var/lib/myapp
```

**Practical implications:**

- During development you can find a user's data with `ls ~/.local/share/jac-app` (Linux/macOS) or `%LOCALAPPDATA%\jac-app` (Windows).
- Uninstalling the app does **not** delete this directory -- it's user data, not application data.
- If you want to wipe state during testing, delete that directory and relaunch.

---

## Client-Only Mode (Thin Native Shell)

Sometimes you don't want a sidecar at all -- you have a hosted jac-scale backend somewhere, and the desktop app is just a native window pointing at it. For that, set `client_only = true`:

```toml
[desktop]
client_only = true

[plugins.client.api]
base_url = "https://api.example.com"
```

In this mode the build:

- **Skips the entire PyInstaller step.** No Python bundle, no plugin collection -- the installer is dramatically smaller and the build is much faster.
- **Requires** `[plugins.client.api] base_url` to be set. The build raises an error if it isn't, since the webview has nothing local to talk to.
- **Still produces a full Tauri installer** -- you just get a thin native shell around a remote API.

This is also useful in CI for verifying the web bundle compiles inside a desktop build without paying for the PyInstaller round-trip.

---

## Debugging Installed Builds

When something works in `jac start --dev` but breaks inside the installer, the usual culprits are: the data path is wrong, the sidecar can't find a plugin, or the API URL never reached the webview. The fastest way to triage:

1. **Run the sidecar binary directly.** Find it under `src-tauri/binaries/jac-sidecar` (or `.exe` on Windows) and run it from a terminal. It writes `JAC_SIDECAR_PORT=<port>` to stdout on startup and sends every other log line to stderr -- watch for `[sidecar] Cannot use data path …`, plugin registration messages, and any tracebacks.
2. **Use the Debug page.** The `all-in-one` example app ships a debug page at `examples/all-in-one/pages/debug.jac` that displays the resolved API base URL, whether `window.__TAURI__` is present, the `get_api_url` Tauri command result, and live walker/HTTP probes. Drop it into your own app while you're tracking down a connectivity issue.
3. **Check the data path.** The sidecar prints which fallback it settled on. If you see `/tmp/jac-app-{uid}`, that means both your home directory and the platform default failed -- probably a permissions issue.

A few platform-specific quirks worth knowing:

- **AppImage** injects `PYTHONHOME`, `PYTHONPATH`, and `PYTHONDONTWRITEBYTECODE` into the environment, which would break the bundled Python interpreter. The generated `main.rs` strips these before spawning the sidecar -- if you customized `main.rs`, make sure that logic survives.
- **Windows** doesn't keep stdout open after Tauri reads the port line. The sidecar redirects stdout to stderr after the port handshake to avoid `OSError: [Errno 22] Invalid argument` on subsequent prints. If you customized the sidecar entry point, do the same.

---

## What You've Built

By now you should have:

- A `[desktop]` section in `jac.toml` controlling window, identifier, and bundled plugins.
- An installer for your platform under `src-tauri/target/release/bundle/`.
- A clear picture of where the bundled app stores user data and how to redirect it.
- A debugging path for the inevitable "works in dev, fails when installed" moment.

For the full reference -- including every option in `[desktop]`, the sidecar CLI flags, and the runtime API URL injection mechanism -- see the [jac-client Reference → Desktop Target](../../reference/plugins/jac-client.md#desktop-target-tauri).
