# Native webview binding

`webview.jac` binds the upstream webview C API. Linux builds use WebKitGTK.

Run `jac setup --toolchain desktop` to prepare the build tools, or build a desktop
app and let Jac provision them automatically. The adapter in
`jaclang/toolchains/desktop.jac` fetches the pinned, SHA-256-verified header and
builds the shared library in Jac's writable toolchain cache. System dependencies
are handled by `jaclang/toolchains/system.jac`; no shell installers are required.

The existing `jac/tests/client/test_desktop_binding.jac` exercises the FFI binding.
See the managed toolchains build guide for cache overrides and platform limits.
