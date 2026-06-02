# jac-desktop

Native desktop target and plugin manager for [Jac](https://jac-lang.org), built on
[PyTauri](https://pytauri.github.io/) -- no Rust toolchain required.

This package extracts the desktop functionality that used to live inside
`jac-client` so that web-only users don't have to pull in pytauri/anyio and so
that desktop-specific commands can grow without bloating the client surface.

## What you get

- A `desktop` build target registered with `jac-client`'s target registry, so
  `jac setup desktop`, `jac build --client desktop`, and
  `jac start --client desktop --dev` all keep working -- install this package
  and the target appears.
- A native CLI for managing the pytauri plugins your app links against,
  without ever opening a Python file:

  ```sh
  jac desktop plugin list                # show available + installed
  jac desktop plugin add dialog fs       # add to [plugins.desktop].tauri_plugins, regen caps + npm
  jac desktop plugin remove dialog       # remove from jac.toml and regenerate
  jac desktop plugin sync                # idempotent regen after manual edits
  ```

## Install

```sh
pip install jac-client jac-desktop
```

`jac-desktop` depends on `jac-client` because the desktop target extends
`WebTarget` (the same web/vite pipeline) for its frontend build.

## Project flow

```sh
jac create --use fullstack my-app       # or start from an existing web app
cd my-app
jac setup desktop                       # one-time scaffold of src-pytauri/
jac desktop plugin add dialog fs        # opt into tauri plugins
jac start --client desktop --dev        # live-reload dev shell
jac build --client desktop              # production-style staging build
```

## Distribution status

`jac build --client desktop` is a **dev/build pipeline**, not a shipping platform yet:

- **Sidecar** (Jac backend): PyInstaller-frozen standalone binary; no Python required at runtime.
- **Shell** (PyTauri webview): runs via `python app.py`; requires Python and `pytauri-wheel` on the machine that launches the app.

Build output under `src-pytauri/dist/` includes `run.sh` / `run.bat` launchers for local testing. The sidecar under `src-pytauri/binaries/` is standalone; the shell still needs Python + `pytauri-wheel`. Standalone shell packaging is planned.

See the [Building a Desktop App](https://github.com/jaseci-labs/jaseci/blob/main/docs/docs/tutorials/fullstack/desktop.md) tutorial and [jac-desktop Reference](https://github.com/jaseci-labs/jaseci/blob/main/docs/docs/reference/plugins/jac-desktop.md).
