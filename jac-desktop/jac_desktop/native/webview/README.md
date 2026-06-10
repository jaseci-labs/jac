# Jac-native webview binding

The native foundation for the `jac-desktop` `desktop` target (issue #6436): a Jac
binding to the OS web engine via the small cross-platform `webview` C library
(WebKitGTK on Linux, WKWebView on macOS, WebView2 on Windows). A `na` host that
imports this binding compiles - with `jac nacompile` and Jac's pure-Jac linker
(no cc/ld) - to a single binary that owns an OS-native window.

The `desktop` build target ([`jac_desktop/targets/native_desktop_target.jac`](../../targets/native_desktop_target.jac))
generates and compiles such a host at build time; this directory ships the
binding it links against.

## Contents

| File | Role |
|------|------|
| `webview.na.jac` | The binding: clib externs (create/size/navigate/html/run/bind/return/eval) + an ergonomic `obj:pub Webview` + `respond` helper + `HINT_*` constants. The opaque `webview_t` handle and C `const char*` callback args are carried as 64-bit `int` to keep C-owned strings out of Jac's reference-counted string type. |
| `build_libwebview.sh` | Builds `libwebview.so` from the pinned upstream `webview/webview` source against the system WebKitGTK. Invoked on first build by the desktop target. |
| `install_webkit_deps.sh` | Installs the toolchain + WebKitGTK dev headers (Debian/Ubuntu). |

The binding's dependency-free test lives with the package's other tests at
[`jac_desktop/tests/test_binding.jac`](../../tests/test_binding.jac) (jac toolchain
only - no WebKitGTK/libpython/display): a host that uses the binding compiles and
links `libwebview.so` with an `$ORIGIN` runpath, and an embedded-CPython host
links libpython.

## Prerequisites (to build a host)

Building links `libwebview.so`, which is compiled on first use, so you need the OS
web engine + a C toolchain. On Debian/Ubuntu:

```sh
sudo ./install_webkit_deps.sh
# build-essential, pkg-config, libgtk-3-dev, libwebkit2gtk-4.1-dev
```

## Notes

- `import from "libwebview.so" { ... }` records a `DT_NEEDED` entry + `$ORIGIN`
  runpath, so a binary finds a sibling `libwebview.so` regardless of launch dir.
- Compiling a host needs no `.so` present (AOT records the link, never dlopens) -
  which is why the tests run with nothing installed.
- WSLg/WebKit rendering needs `GDK_BACKEND=x11` + the DMABUF/compositor disables
  (the desktop target sets these when it launches the app).
- `libwebview.so` and build caches are git-ignored; regenerate with
  `build_libwebview.sh`.
