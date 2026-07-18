# jac-desktop Release Notes

## jac-desktop 0.2.0 (Latest Release)

### Breaking Changes

- **PyTauri/PyInstaller replaced by a Jac-native desktop host**: The desktop target is now Jac-native. `jac build --client desktop` builds your `cl` bundle and compiles a single native host (`jac nacompile`) that embeds the OS webview to render it - no Rust toolchain, no PyInstaller sidecar, no separate process. Output is one self-contained binary under `.jac/client/desktop/`.
- **Removed**: the PyTauri shell, the PyInstaller sidecar, the `jac desktop plugin` CLI (Tauri plugin catalog), and the `pytauri-wheel`/`anyio`/`pyinstaller` dependencies. There is no longer a `jac setup desktop` step or `src-pytauri/` scaffold.
- **Added**: the native webview binding + build tooling under `jac_desktop/native/webview/`, with a dependency-free test suite. The host embeds CPython to serve the bundle on loopback (and to host `sv` in-process).
- **Config**: `[plugins.desktop]` keeps app identity + `[plugins.desktop.window]` geometry; the Tauri-plugin / sidecar config fields are gone.
- See [issue #6436](https://github.com/jaseci-labs/jaseci/issues/6436).

## jac-desktop 0.1.1

### New Features

- **Feature: jac-desktop plugin**: New PyTauri-based desktop target plugin with three entry points: `jac desktop` (CLI), `desktop_plugin_config` (schema), and `jac_client` group `desktop` (runtime `get_client_targets` hook on jac-client's plugin manager).
- **Feature: `[plugins.desktop]` configuration**: Desktop app metadata, window geometry, sidecar plugin bundling, and Tauri plugin ids live under `[plugins.desktop]` in `jac.toml`, using the same `PluginConfigBase` pattern as jac-scale and jac-client.
- **Feature: `jac desktop plugin` commands**: `list`, `add`, `remove`, and `sync` manage `[plugins.desktop].tauri_plugins`, regenerate `capabilities/` and sync matching `@tauri-apps/plugin-*` npm dependencies. The `src-pytauri/app.py` stub is stable and delegates to `jac_desktop.runtime`.

### Documentation

- **Docs: jac-desktop reference**: New dedicated reference page at `reference/plugins/jac-desktop.md` (nav under Full-Stack Development). Desktop-specific content moved out of jac-client; tutorial and CLI cross-link to the new page.

## jac-desktop 0.1.0

Initial release of jac-desktop, the native desktop target and PyTauri plugin manager for Jac, split out of `jac-client`.

### Features

- **Desktop build target**: Registers a `desktop` target with `jac-client`'s target registry, so `jac setup desktop`, `jac build --client desktop`, and `jac start --client desktop --dev` work once the package is installed -- no Rust toolchain required (built on [PyTauri](https://pytauri.github.io/)).
- **Plugin manager CLI**: `jac desktop plugin list/add/remove/sync` manages the tauri plugins an app links against, editing `[plugins.desktop].tauri_plugins` in `jac.toml` and regenerating capabilities + npm wiring -- without opening a Python file.
- **Sidecar bundling**: The Jac backend is frozen to a standalone PyInstaller binary; the PyTauri webview shell runs via `python app.py` with `pytauri-wheel`.
- **Plugin system**: Full Jac plugin exposing `jac` and `jac_client` entry points (`JacCmd`, `JacDesktopPluginConfig`, `JacDesktopPlugin`).
