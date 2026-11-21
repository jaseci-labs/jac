# CEF binding

The CEF (Chromium Embedded Framework) engine for `jac-desktop` renders a desktop
app in a bundled Chromium instead of the OS webview. An app selects it with
`[desktop] engine = "cef"` in `jac.toml`; `jac build` and `jac run` then go
through the CEF shell ([`cef_shell.jac`](../../cef_shell.jac)). Linux only.

## Layout

| File | Role |
|------|------|
| `cef.jac` | Jac API the generated host imports (`cef_startup`, `cef_open_browser`, `cef_run_loop`, ...) |
| `cef_dispatch.c` | Source of `libcef_dispatch.so`: CEF handlers, settings, browser creation, window title and size |
| `cef_subprocess.c` | Source of `cef-subprocess`, the helper CEF launches for renderer, GPU and utility processes |
| `bootstrap.js` | Script every page's main frame runs first (`window.__jac`, `__JAC_DESKTOP__`, `__JAC_BROKER__`) |
| `cef_sums.lock` | Pinned CEF version and archive SHA-1 digests |
| `minimal-fonts.conf` | fontconfig file the app points `FONTCONFIG_FILE` at |

## How it builds

1. `ensure_cef` downloads the pinned CEF distribution, checks its digest, and
   stages `cef_dist/` (runtime) and `cef_headers/` (C API headers).
2. `cef_dispatch.c` is compiled with `cc` against `cef_headers/include/capi`
   into `libcef_dispatch.so`, linked to `libcef.so` with an `$ORIGIN` runpath.
   `bootstrap.js` is embedded into it at build time.
3. `cef_subprocess.c` is compiled into `cef-subprocess`, linked to
   `libcef_dispatch.so`, so helper processes run the same handlers as the app.
4. The generated `host.jac` is compiled with `jac build --native` and calls
   `libcef_dispatch.so` through the declarations in `cef.jac`.

Structs come from CEF's own headers, so a CEF version bump is a new
`cef_sums.lock` and a rebuild. Building needs a C compiler (`cc`), which the
native webview engine already requires.

## Startup

```
cef_execute_subprocess()   # a CEF helper process exits here
cef_startup(cache_path)    # cef_initialize with the app's handlers
host_boot.boot()           # embedded Python: plugins and the loopback server
cef_open_browser(url, ...) # the window, loading the loopback URL
cef_run_loop()             # until the window closes
cef_cleanup()
```

The generated host starts CEF with its sandbox off (`no_sandbox = 1`).
