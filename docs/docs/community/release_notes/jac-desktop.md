# jac-desktop Release Notes

## jac-desktop 0.1.0 (Latest Release)

Initial release of jac-desktop, the native desktop target and PyTauri plugin manager for Jac, split out of `jac-client`.

### Features

- **Desktop build target**: Registers a `desktop` target with `jac-client`'s target registry, so `jac setup desktop`, `jac build --client desktop`, and `jac start --client desktop --dev` work once the package is installed -- no Rust toolchain required (built on [PyTauri](https://pytauri.github.io/)).
- **Plugin manager CLI**: `jac desktop plugin list/add/remove/sync` manages the tauri plugins an app links against, editing `[plugins.desktop].tauri_plugins` in `jac.toml` and regenerating capabilities + npm wiring -- without opening a Python file.
- **Sidecar bundling**: The Jac backend is frozen to a standalone PyInstaller binary; the PyTauri webview shell runs via `python app.py` with `pytauri-wheel`.
- **Plugin system**: Full Jac plugin exposing `jac` and `jac_client` entry points (`JacCmd`, `JacDesktopPluginConfig`, `JacDesktopPlugin`).
