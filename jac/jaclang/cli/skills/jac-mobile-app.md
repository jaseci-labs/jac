---
name: jac-mobile-app
description: Shipping a Jac mobile app to Android/iOS - a `kind = "mobile"` app (`[apps.<name>]` in a workspace) rendered through React Native, `jac setup <app>` (Expo scaffold), the `jac run --dev <app>` Metro loop, `jac build <app> --platform android|ios|web`, `[client.react_native]` config (builders, release, EAS Build / EAS Update), `[dependencies.npm.native]`, on-device debugging. Load when targeting phones or tablets; the `@jac/mobui` UI vocabulary itself is in `jac-mobui`.
---

A mobile app is an app of kind `mobile`: its `cl` UI compiles to platform-native views through [React Native](https://reactnative.dev/) (Expo/Metro/Hermes), written in the `@jac/mobui` vocabulary (see `jac-mobui`). The same source also builds for a browser through `react-native-web` (`--platform web`). **Architecture first: the mobile app is FRONTEND ONLY.** Every walker/`def:pub` call bridges over HTTP to a Jac server you deploy separately (see `jac-sv-deploy`) - in a workspace, the `web-app` or `service` app that owns the walkers. There is no embedded backend - plan the server deployment before shipping the app.

In a workspace it is an `[apps.<name>]` table beside the web app (`jac create --app mobile --kind mobile` writes `kind = "mobile"`, `path = "mobile"`; add `platform = "android"` or `"ios"` for a default platform); in a single-app project it is `[project] kind = "mobile"`. The commands below name the app `mobile` - drop the name in a single-app project.

## Prerequisites

| Platform | Needs |
|---|---|
| both | Nothing extra for JS tooling: installs, Expo/Metro and Vite run on the Bun runtime bundled with `jac` (`JAC_BUN` overrides which bun is used) |
| Android | Managed JDK 21 and Android SDK; accept SDK licenses during setup |
| iOS (macOS only) | Xcode + Command Line Tools; Jac provisions Ruby/CocoaPods; other hosts need a hosted macOS builder |

## One-time scaffold

```bash
jac setup mobile      # the app named mobile; `jac setup` alone for the default app
```

Scaffolds an Expo project at `.jac/mobile-rn/` (`[client.react_native].project_dir` relocates it; it stays under the `.jac` build root, out of the source tree), merges `[dependencies.npm.native]` into its `package.json`, installs them, and writes a baseline `eas.json` (`preview` / `production` profiles). `jac build` runs the scaffold itself when it is missing; `jac run --dev` needs it in place.

## Configuration - `[client.react_native]`

```toml
[client.react_native]
project_dir = ".jac/mobile-rn"   # Expo project location
release = false                  # true = release variant instead of debug
default_platform = "android"     # platform for a plain `jac run mobile` ([apps.mobile] platform wins)
android_builder = "gradle"       # "gradle" (local) or "eas" (EAS Build)
ios_builder = "xcodebuild"       # "xcodebuild" (local, macOS) or "eas" (EAS Build)
eas_profile = ""                 # "" -> "production" (release) / "preview" (debug)
eas_update = false               # true: publish an EAS Update after each successful build
eas_update_branch = ""           # "" -> "production" (release) / "preview" (debug)
eas_update_message = ""          # "" -> `eas update --auto`
```

npm packages the web bundle needs go under `[dependencies.npm]` (or the app's `[apps.mobile.dependencies.npm]` overlay); packages only the Expo project needs go under `[dependencies.npm.native]`. Run `jac install` after editing `jac.toml`.

## Dev loop

```bash
jac run --dev mobile                          # Metro Fast Refresh: press a / i, or scan the Expo Go QR
jac run --dev --platform web mobile           # the same screens in a browser via react-native-web (Vite HMR)
jac run web                                   # another terminal: the server the screens bridge to
```

`--dev` compiles the app's modules with the native runtime, starts a Jac API backend beside Metro, injects the dev API base URL into `app.json` (restored on exit), and recompiles on `.jac` saves. The device-visible host is auto-detected from your LAN IPv4 (`JAC_RN_DEV_HOST` overrides it); Metro listens on `8081` (`JAC_RN_METRO_PORT`); `adb reverse` is attempted for the Metro and API ports on Android. If the app cannot reach the server: check the printed host/port and confirm `adb devices` shows the target as authorized.

**Iterate in the browser first** - `--platform web` hot-reloads in seconds and needs no device; native needs Metro plus a device or simulator.

## Production build

```bash
jac build mobile --platform android          # APK via gradlew (or EAS Build with android_builder = "eas")
jac build mobile --platform ios              # simulator .app via xcodebuild (macOS); .ipa through ios_builder = "eas"
jac build mobile --platform web              # browser bundle; with `jac build --all --platform web` it lands in dist/mobile/
jac run mobile                               # build for the app's platform, then install + launch on a device/simulator
```

`jac run mobile` (no `--dev`) picks the platform from `--platform`, else `[apps.mobile] platform`, else `[client.react_native].default_platform`, else `android`; `jac run --platform ... mobile` sets `JAC_MOBILE_PLATFORM` for that run. Android install is `adb install -r <apk>`; iOS is `xcrun simctl install booted <app>`. `--platform ios` on a non-macOS host errors and points at EAS Build. Signing, provisioning and store distribution follow the Expo docs for the builder you chose.

**EAS Update (OTA):** inside `.jac/mobile-rn/`, `npx expo install expo-updates` then `eas update:configure`; set `eas_update = true` and every successful `jac build` publishes to `eas_update_branch` (`preview` for debug, `production` for release unless set). Without `expo-updates` installed and `expo.updates.url` in `app.json`, updates publish but the app never checks for them.

## Debugging on device

- **Bridge errors:** wrap bridged calls in `try { ... } except BridgeError as e { ... }` and show a retry banner (`jac-sv-microservices`); a blank screen is almost always an unreachable API URL.
- **Backend reachability:** `jac run --dev` prints the Metro and API URLs it injected; open the API URL from the device's browser before blaming the app.
- **Native logs:** `adb logcat` on Android; the Xcode device console on iOS.

## See also

- `jac-mobui` - the `@jac/mobui` primitives, styling, `.native.jac` variants (E5105), the no-HTML rule (E1105)
- `jac-sv-deploy` - deploying the backend the app talks to
- `jac-sv-microservices` - the bridge the screens call through and the `BridgeError` family
- `jac-project-kinds` - mobile vs desktop vs PWA comparison
