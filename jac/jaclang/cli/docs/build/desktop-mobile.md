# I like to build … Desktop & mobile apps

Take a Jac app and give it a native shell -- a desktop window that embeds the OS webview, or an Android/iOS app with platform-native views through React Native. These are the `desktop` and `mobile` [project kinds](../quick-guide/project-kinds.md); a `mobile` app is a **mobUI** app, authored in the [`@jac/mobui`](../reference/plugins/jac-client.md#the-jacmobui-vocabulary) vocabulary. In a [workspace](../reference/apps.md) each one is an `[apps.<name>]` table beside your web app, over the same shared `core/`.

!!! note "Status: beta 🧪"
    The desktop binary renders your `cl` UI and runs `sv` walkers/functions **in-process** on the embedded interpreter (shipped), with full HMR dev mode via `jac run --dev <app>`. Only per-OS installers/code-signing remain open ([issue #6436](https://github.com/jaseci-labs/jaseci/issues/6436)). A mobile app is frontend-only -- it bridges to a Jac server you deploy separately (in a workspace, the `web-app` or `service` app that owns the walkers). Everything else on this page works as shown.

## Your 5-minute quick win {#desktop}

Start from any [full-stack app](fullstack-web.md). Jac compiles your `cl` UI into **one `jac build --native`d binary that embeds the OS webview** (WebKitGTK / WKWebView / WebView2) -- no Rust toolchain, no PyInstaller, no separate process. The desktop target ships with `jaclang` core, and an app of kind `desktop` builds it with no flag:

```bash
jac create --app studio --kind desktop     # [apps.studio] kind = "desktop", path = "studio"
jac build studio                           # → .jac/client/desktop/<app>  (single binary)
jac run studio                             # build + launch the native window
jac run --dev studio                       # HMR: Vite serves cl on 127.0.0.1, recompiles on .jac saves
```

(In a single-app project, `jac create myapp --kind desktop` and then plain `jac build` / `jac run`.)

In dev mode the native host is built once, then your `cl` UI is served from
Vite on loopback and recompiled on every `.jac` save -- the desktop window
hot-reloads just like `jac run --dev` does for web. Walker/function calls
still go through the embedded in-process runtime, so RPC works identically
to the packaged build.

Window title, size and the renderer are configured under `[desktop]` in `jac.toml`: `engine = "native"` (the default, the OS webview) or `engine = "cef"` for a bundled Chromium (CEF has no HMR, so `jac run --dev` needs the native engine). On Linux you need the WebKitGTK system libraries (Jac provisions them through the system package manager).

## Ship to Android & iOS {#mobile}

A `mobile` app compiles your `cl` UI to **platform-native views** via React Native (Expo/Metro). Author the UI once in the portable [`@jac/mobui`](../reference/plugins/jac-client.md#the-jacmobui-vocabulary) vocabulary (`View`, `Text`, `Pressable`, ...) and the same source also runs in a browser through `react-native-web`. The mobile app is the *frontend only* -- it bridges to your Jac server over HTTP, so deploy the backend separately (e.g. as a [backend service](backend-apis.md#service)). The app is just its kind:

```toml
[apps.mobile]
kind = "mobile"              # native views via Expo/Metro; raw HTML tags in this app's modules become E1105
path = "mobile"
```

The mobUI guard covers only this app's modules -- your HTML-based `web` app next door is untouched. Then:

```bash
# Android tools are provisioned automatically; iOS requires macOS + Xcode.
jac create --app mobile --kind mobile             # writes the table above
jac setup mobile                                 # one-time Expo scaffold (.jac/mobile-rn/)
jac run --dev mobile                             # Metro Fast Refresh on device/emulator
jac run --dev --platform web mobile              # the same screens in a browser via react-native-web
jac build mobile --platform android              # → APK (iOS: .app via xcodebuild, .ipa via EAS)
jac build mobile --platform web                  # → the browser bundle
```

`[apps.mobile] platform` sets the default platform; the Expo/EAS toolchain knobs live under `[client.react_native]`.

If what you want is a home-screen install of an existing web app rather than native views, make the web app a PWA instead: a `[client.pwa]` table in `jac.toml` adds the manifest, service worker and install banner to its build, with no rewrite (see the [PWA section](../reference/plugins/jac-client.md#pwa) of the client reference).

The flagship workspace's [`mobile/`](https://github.com/jaseci-labs/jaseci/tree/main/jac/examples/jaclang_org/mobile) app is the worked example: a React Native client for the same social graph the site serves at `/socialize`, with typed theme tokens, `.native.jac` platform-split icons, and `BridgeError` handling around every bridged call. `jac create <name> --awesome` scaffolds the whole workspace, mobile app included.

## Your learning path

- **Concepts you need** → [Core Concepts](../quick-guide/what-makes-jac-different.md) -- the client codespace · [Workspaces & Apps](../reference/apps.md) -- how a mobile app sits beside a web app over shared code
- **Build the app first** → [Full-stack web apps](fullstack-web.md) (a desktop/mobile app is a full-stack app plus a shell)
- **Build it for real** → [Desktop App](../tutorials/fullstack/desktop.md) · [Mobile App](../tutorials/fullstack/mobile.md)
- **Look it up** → [jac-desktop reference](../reference/plugins/jac-desktop.md) · [jac-client reference](../reference/plugins/jac-client.md) ([Mobile](../reference/plugins/jac-client.md#mobile))

## Going further

- Add AI features → [AI agents & LLM apps](ai-agents.md)
- Scale the backend your app talks to → [Backend APIs & services](backend-apis.md)

See [Managed build toolchains](toolchains.md) for automatic setup, download progress, caches, licenses, and offline builds.
