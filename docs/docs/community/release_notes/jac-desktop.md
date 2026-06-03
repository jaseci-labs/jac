# jac-desktop Release Notes

## jac-desktop 0.1.1 (Latest Release)

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
