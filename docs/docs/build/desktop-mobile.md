# I like to build … Desktop & mobile apps

Take a full-stack Jac app and wrap it in a native shell -- a desktop window that embeds the OS webview, or an Android/iOS build. These map to the `desktop` and `mobile` [project kinds](../quick-guide/project-kinds.md).

## Your 5-minute quick win {#desktop}

Start from any [full-stack app](fullstack-web.md). Jac compiles your `cl` UI into **one `jac nacompile`d binary that embeds the OS webview** (WebKitGTK / WKWebView / WebView2) -- no Rust toolchain, no PyInstaller, no separate process. The desktop target ships with `jaclang` core:

```bash
jac build --client desktop      # → .jac/client/desktop/<app>  (single binary)
jac start --client desktop      # build + launch the native window
```

Window title and size are configured under `[plugins.desktop]` in `jac.toml`. On Linux you need the WebKitGTK system libraries (a bundled helper script installs them).

## Ship to Android & iOS {#mobile}

Ship the same client bundle to mobile via **Capacitor**, which wraps it in a native webview. The mobile app is the *frontend only* -- it talks to your Jac server over HTTP, so deploy the backend separately (e.g. as a [backend service](backend-apis.md#service)):

```bash
# prerequisites: Node.js; Android: JDK + Android SDK; iOS (macOS): Xcode
jac setup mobile --platform android               # one-time scaffold
jac start main.jac --client mobile --dev          # live reload on device/emulator
jac build --client mobile --platform android      # → app-debug.apk
```

Use `--platform ios` on macOS to produce an Xcode project. App name and id are set under `[plugins.client.mobile]`.

## Your learning path

- **Concepts you need** → [Core Concepts](../quick-guide/what-makes-jac-different.md) -- the client codespace
- **Build the app first** → [Full-stack web apps](fullstack-web.md) (a desktop/mobile app is a full-stack app plus a shell)
- **Build it for real** → [Desktop App](../tutorials/fullstack/desktop.md) · [Mobile App](../tutorials/fullstack/mobile.md)
- **Look it up** → [jac-desktop reference](../reference/plugins/jac-desktop.md) · [jac-client reference](../reference/plugins/jac-client.md)

## Going further

- Add AI features → [AI agents & LLM apps](ai-agents.md)
- Scale the backend your app talks to → [Backend APIs & services](backend-apis.md)
