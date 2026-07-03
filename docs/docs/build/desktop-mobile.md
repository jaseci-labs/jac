# I like to build … Desktop & mobile apps

Take a full-stack Jac app and wrap it in a native shell -- a desktop window that embeds the OS webview, an Android/iOS webview build, or (for platform-native views) a React Native build. These map to the `desktop` and `mobile` [project kinds](../quick-guide/project-kinds.md) and the `mobui` client kind.

!!! note "Status: beta 🧪"
    The desktop binary renders your `cl` UI today; wiring `sv` walkers onto the embedded interpreter, HMR dev mode, and per-OS installers/signing are in progress ([issue #6436](https://github.com/jaseci-labs/jaseci/issues/6436)). Both mobile paths are frontend-only -- the app talks to a Jac server you deploy separately. Everything else on this page works as shown.

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
# prerequisites: Android: JDK + Android SDK; iOS (macOS): Xcode (no Node.js -- JS tooling runs on the bundled Bun)
jac setup mobile --platform android               # one-time scaffold
jac start main.jac --client mobile --dev          # live reload on device/emulator
jac build --client mobile --platform android      # → app-debug.apk
```

Use `--platform ios` on macOS to produce an Xcode project. App name and id are set under `[plugins.client.mobile]`.

## Ship platform-native views (React Native) {#react-native}

For **true native views** instead of a webview, the React Native target compiles your `cl` UI to platform-native components via Expo/Metro. Author the UI once in the portable [`@jac/mobui`](../reference/plugins/jac-client.md#the-jacmobui-vocabulary) vocabulary (`View`, `Text`, `Pressable`, ...) and the same source also runs on the web -- set `client_kind = "mobui"` under `[project]` and raw HTML tags become compile errors ([`E1105`](../reference/diagnostics.md#mobui-project-jsx-host-tags)) so the tree stays portable:

```bash
# prerequisites: Android: JDK + Android SDK; iOS (macOS): Xcode (no Node.js -- JS tooling runs on the bundled Bun)
jac setup react-native                            # one-time Expo scaffold (.jac/mobile-rn/)
jac start main.jac --client react-native --dev    # Metro Fast Refresh on device/emulator
jac build --client react-native --platform android  # → APK (iOS: .app via xcodebuild, .ipa via EAS)
```

Start from [`examples/mobui/hello`](https://github.com/jaseci-labs/jaseci/tree/main/jac/examples/mobui/hello); [`examples/mobui/littlex`](https://github.com/jaseci-labs/jaseci/tree/main/jac/examples/mobui/littlex) shows the full-stack picture including `.native.cl.jac` platform-split modules.

## Your learning path

- **Concepts you need** → [Core Concepts](../quick-guide/what-makes-jac-different.md) -- the client codespace
- **Build the app first** → [Full-stack web apps](fullstack-web.md) (a desktop/mobile app is a full-stack app plus a shell)
- **Build it for real** → [Desktop App](../tutorials/fullstack/desktop.md) · [Mobile App](../tutorials/fullstack/mobile.md) (covers both Capacitor and React Native)
- **Look it up** → [jac-desktop reference](../reference/plugins/jac-desktop.md) · [jac-client reference](../reference/plugins/jac-client.md) ([React Native target](../reference/plugins/jac-client.md#react-native-target-beta))

## Going further

- Add AI features → [AI agents & LLM apps](ai-agents.md)
- Scale the backend your app talks to → [Backend APIs & services](backend-apis.md)
