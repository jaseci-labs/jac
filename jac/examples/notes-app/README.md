# Notes app (`desktop-cef`)

Minimal Jac client app that exercises the **CEF desktop target** end-to-end. It
doubles as the smoke test for the CEF target before shipping PR #6572.

## What it checks

- CEF window opens and loads the Vite bundle from the loopback server
- `window.__JAC_DESKTOP__` and `window.__JAC_BROKER__` are set before page scripts
- `GET /__jac/health` and `GET /__jac/session` respond
- `localStorage` persists on the stable loopback origin across restarts

## Build and run

From this directory (the desktop targets ship in core `jaclang`):

```bash
jac build --client desktop-cef
cd .jac/client/desktop-cef/notes-app
./notes-app
```

Or build + launch in one step:

```bash
jac start --client desktop-cef
```

On success you should see in the terminal:

```
JAC_DESKTOP_SERVING http://127.0.0.1:<port>/
```

The UI shows bootstrap flags, broker JSON, and a localStorage note field.

## First-time CEF fetch

The first build downloads ~1.4 GB of CEF binaries via
`jaclang/runtimelib/client/targets/desktop/native/cef/fetch_libcef.sh` and
compiles `libcef_dispatch.so`.

## Troubleshooting

**Fontconfig warnings (`48-guessfamily.conf`, `invalid attribute xsi:nil`)**

Harmless noise from Arch's system fontconfig - Chromium still starts. Ignore them,
or upgrade/fix your system `fontconfig` package. The build also stages
`minimal-fonts.conf`; use it when launching manually:

```bash
FONTCONFIG_FILE=$PWD/minimal-fonts.conf ./notes-app
```

**`cannot open shared object file: libpython3.x.so.1.0`**

The host binary links the Python version used at **build** time. Rebuild on your
machine:

```bash
jac build --client desktop-cef
```

If it still fails, confirm libpython is installed (Arch: `python` package) and
run with `LD_LIBRARY_PATH` pointing at your Python `LIBDIR` (often `/usr/lib`).

**App prints `JAC_DESKTOP_SERVING` but no window appears**

CEF is stuck in `cef_initialize()` before the browser is created. Try:

```bash
jac start --client desktop-cef
```

or manually with GPU fallback:

```bash
cd .jac/client/desktop-cef
JAC_CEF_DISABLE_GPU=1 OZONE_PLATFORM=x11 ./notes-app
```

Watch stderr for `[cef]` lines - you should eventually see
`context initialized` and `create_browser returned 1`. If you only see
`startup: initializing CEF`, file a bug with your GPU/display stack details.
