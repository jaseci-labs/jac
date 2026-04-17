# Building a Desktop App

This tutorial walks you through shipping an existing Jac full-stack app as a native desktop installer for Windows, macOS, and Linux. Unlike the web target -- which assumes a hosted backend somewhere -- the desktop target packages the **entire** Jac runtime, your `.jac` sources, and any plugins you depend on into a single installer that end users can double-click.

> **Prerequisites**
>
> - Completed: [Project Setup](setup.md) -- you have a working `jac start` web app
> - Installed: [Rust toolchain](https://rustup.rs) (`cargo --version` should work)
> - Installed: `pip install pyinstaller Pillow` -- PyInstaller freezes the sidecar; Pillow is required on Windows so `jac setup desktop` can produce `icon.ico` for the NSIS/MSI bundler (without it, `cargo tauri build` fails on Windows with a missing-icon error)
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
4. **Builds the installer with Tauri** -- produces a platform-native installer (`.msi`, `.dmg`, `.AppImage`, `.deb`, `.rpm`) under `src-tauri/target/<triple>/release/bundle/` (e.g. `target/x86_64-pc-windows-msvc/release/bundle/`). `jac build --platform <x>` passes `--target <triple>` to Cargo, so the triple subdirectory is part of the path on every platform.

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

When this finishes, look in `src-tauri/target/<triple>/release/bundle/` (the `<triple>` is the Rust target triple for your platform -- e.g. `x86_64-pc-windows-msvc`, `aarch64-apple-darwin`, `x86_64-unknown-linux-gnu`). You'll find one subdirectory per format your platform produces:

- `nsis/` and `msi/` on Windows
- `dmg/` and `macos/` on macOS
- `appimage/`, `deb/`, and `rpm/` on Linux

If you're scripting against these paths (CI uploads, release tooling), use a glob like `target/**/release/bundle/**/*.msi` so it works regardless of which triple Cargo picked.

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

## CI Builds (GitHub Actions)

For releases, build on hosted runners so each installer is produced on a clean matching OS -- no cross-compilation quirks, no "works on my machine." Drop the workflow below into `.github/workflows/build-desktop.yml` in your project, change the three lines marked **CONFIGURE**, and you can trigger builds for all three platforms from the Actions tab.

```yaml
name: Build Desktop App

on:
  workflow_dispatch:        # manual trigger from the Actions tab
  # push:
  #   tags: ['v*']          # uncomment to also build on version tags

permissions:
  contents: read

env:
  # CONFIGURE (1): path to the folder containing your jac.toml and main.jac.
  # For a standard `jac create` project at the repo root, use ".".
  APP_DIR: "."
  PYTHON_VERSION: "3.12"

jobs:
  build:
    strategy:
      fail-fast: false
      matrix:
        include:
          - os: windows-latest
            platform: windows
            artifact_name: windows-installer
          - os: macos-latest
            platform: macos
            artifact_name: macos-dmg
          - os: ubuntu-22.04        # pinned: newer GLIBC breaks .deb/.rpm on older distros
            platform: linux
            artifact_name: linux-deb-rpm

    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      # ── System deps (Linux only) ──────────────────────────────
      - name: Install Linux system deps
        if: matrix.platform == 'linux'
        run: |
          sudo apt-get update
          sudo apt-get install -y \
            libwebkit2gtk-4.1-dev libappindicator3-dev librsvg2-dev \
            libgtk-3-dev libsoup-3.0-dev libjavascriptcoregtk-4.1-dev \
            patchelf libfuse2

      # ── Rust (not pre-installed on runners) ──────────────────
      - uses: dtolnay/rust-toolchain@stable

      - name: Cache Cargo registry
        uses: actions/cache@v4
        with:
          path: |
            ~/.cargo/registry
            ~/.cargo/git
          key: cargo-reg-${{ matrix.os }}-${{ hashFiles('**/Cargo.lock') }}
          restore-keys: cargo-reg-${{ matrix.os }}-

      # ── Python + Jac ─────────────────────────────────────────
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ env.PYTHON_VERSION }}

      - name: Install Jac packages
        run: |
          pip install --upgrade pip
          # CONFIGURE (2): install your Jac stack. For most projects, PyPI
          # wheels are fine. If you need plugins (byllm, jac-mcp, etc.), add
          # them here so they're available when PyInstaller freezes the sidecar.
          pip install jaseci jac-client jac-scale
          pip install pyinstaller Pillow

      - uses: oven-sh/setup-bun@v2
        with:
          bun-version: latest

      # ── Tauri CLI ────────────────────────────────────────────
      - name: Install Tauri CLI
        shell: bash
        run: |
          if command -v cargo-tauri &>/dev/null; then
            echo "already installed"
          elif command -v cargo-binstall &>/dev/null || \
               (curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash); then
            cargo binstall tauri-cli --no-confirm --force || cargo install tauri-cli --locked
          else
            cargo install tauri-cli --locked
          fi

      # ── Scaffold src-tauri/ fresh so setup doesn't skip ──────
      - name: Setup desktop target
        working-directory: ${{ env.APP_DIR }}
        shell: bash
        run: |
          rm -rf src-tauri
          jac setup desktop

      # ── Disable AppImage on Linux (GitHub runners lack FUSE) ─
      - name: Disable AppImage on Linux
        if: matrix.platform == 'linux'
        working-directory: ${{ env.APP_DIR }}
        shell: bash
        run: |
          python3 -c "
          import json
          with open('src-tauri/tauri.conf.json') as f: c = json.load(f)
          c['bundle']['targets'] = ['deb', 'rpm']
          with open('src-tauri/tauri.conf.json', 'w') as f: json.dump(c, f, indent=2)
          "

      # ── Build ────────────────────────────────────────────────
      - name: Build desktop app
        working-directory: ${{ env.APP_DIR }}
        env:
          JAC_BUILD: "1"
        run: jac build --client desktop --platform ${{ matrix.platform }}
        timeout-minutes: 90

      # ── Upload artifacts ─────────────────────────────────────
      # `jac build --platform <x>` passes `--target <triple>` to Cargo, so
      # bundles land under target/<triple>/release/bundle/ -- the `**` in the
      # glob matches that triple subdirectory.
      - name: Upload installer artifacts
        uses: actions/upload-artifact@v4
        with:
          name: desktop-${{ matrix.artifact_name }}
          path: |
            ${{ env.APP_DIR }}/src-tauri/target/**/release/bundle/**/*.exe
            ${{ env.APP_DIR }}/src-tauri/target/**/release/bundle/**/*.msi
            ${{ env.APP_DIR }}/src-tauri/target/**/release/bundle/**/*.dmg
            ${{ env.APP_DIR }}/src-tauri/target/**/release/bundle/**/*.deb
            ${{ env.APP_DIR }}/src-tauri/target/**/release/bundle/**/*.rpm
          if-no-files-found: warn
          retention-days: 14
```

### What to Configure

Three places in the workflow need to match your project:

1. **`APP_DIR`** (line 15) -- folder containing your `jac.toml` and `main.jac`. For a standard `jac create myapp` project where you committed `myapp/` at the repo root, use `APP_DIR: myapp`. For a project where `jac.toml` lives in the repo root, use `APP_DIR: "."`.

2. **`Install Jac packages` step** -- add any Jac plugins your app imports (`byllm`, `jac-mcp`, `jac-coder`, etc.) so PyInstaller can freeze them into the sidecar. The build collects plugins from the Python environment it runs in, not from PyPI.

3. **Trigger** (the `on:` block at the top) -- the template uses `workflow_dispatch` (manual "Run workflow" button). Uncomment the `push.tags` block to also build automatically on version tags like `v1.0.0`.

### Why These Choices

- **`fail-fast: false`** keeps the other platforms building when one fails -- useful when a regression only hits one OS.
- **`ubuntu-22.04`** (not `ubuntu-latest`) is deliberate: AppImages built against a newer GLIBC won't run on older Linux distributions; 22.04 keeps installers compatible with most distros from 2022 onward.
- **Cargo registry is cached, `src-tauri/target/` is not.** A stale target cache can cause `jac setup desktop` to skip regeneration and ship an outdated config -- safer to recompile.
- **AppImage is disabled on Linux in CI** because AppImage bundling uses `linuxdeploy`, which needs FUSE. GitHub runners don't provide FUSE, and the available workarounds are flaky. If you need AppImages, build them locally or on a self-hosted runner.
- **`timeout-minutes: 90`** -- the first Rust build on a cold cache exceeds the default 60-minute runner timeout.

### Triggering a Build

Once the workflow is on your default branch:

- **From the UI:** Actions tab → "Build Desktop App" → "Run workflow" button.
- **From the CLI:** `gh workflow run build-desktop.yml`.
- **Automatically on release:** uncomment the `push.tags` trigger block and push a `v*` tag.

### Where the Artifacts Land

After the run finishes, open the run summary page and scroll to the "Artifacts" section at the bottom. You'll see three zips:

- `desktop-windows-installer` -- contains `.exe` and `.msi`
- `desktop-macos-dmg` -- contains `.dmg`
- `desktop-linux-deb-rpm` -- contains `.deb` and `.rpm`

They're retained for 14 days. Download from the web UI, or use the CLI:

```bash
gh run download <run-id>                          # all three
gh run download <run-id> -n desktop-windows-installer   # just Windows
```

To attach these to a GitHub Release automatically, add a second job that runs after `build`, uses `actions/download-artifact@v4` to pull all three, and `softprops/action-gh-release@v2` to upload them against the current tag.

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

## Bundling Extra Data Files

Some apps need data files that aren't picked up automatically -- YAML schemas, prompt templates, seed data, TOML configs -- things loaded at runtime with `open(Path(__file__).parent / "config/prompts.yaml")` or similar. Declare them under `[desktop.bundle] extra_data` as a list of glob patterns rooted at the project directory:

```toml
[desktop.bundle]
extra_data = [
    "config/**/*.yaml",
    "prompts/*.txt",
    "data/seed.sqlite",
]
```

The build resolves each glob relative to your project root and copies matches into the PyInstaller bundle, preserving the relative path. So `config/prompts.yaml` in your source tree lands at `config/prompts.yaml` inside the frozen sidecar, and `Path(__file__).parent / "config/prompts.yaml"` resolves correctly at runtime.

Use this for anything the sidecar reads from disk that isn't Python code or a Jac source file -- those are already handled automatically.

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
