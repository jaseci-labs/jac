---
name: jac-mobile-app
description: Shipping a Jac client as a native Android/iOS app via Capacitor - `jac setup mobile`, dev loop with live reload and auto adb reverse, `jac build --client mobile`, `[client.mobile]` config, Capacitor plugins, on-device debugging. Load when targeting phones or tablets.
---

The mobile target wraps your web bundle in a native shell via [Capacitor](https://capacitorjs.com/), producing an Android APK or iOS app from the same client codebase. **Architecture first: the mobile app is FRONTEND ONLY.** The native shell is a webview running your client bundle; every walker/`def:pub` call goes over HTTP to a Jac server you deploy separately (see `jac-sv-deploy`). There is no embedded backend - plan the server deployment before shipping the app.

## Prerequisites

| Platform | Needs |
|---|---|
| both | Node.js (or Bun) |
| Android | Java/JDK 21+, Android SDK (via Android Studio) |
| iOS (macOS only) | Xcode + Command Line Tools, CocoaPods |

## One-time scaffold

```bash
jac setup mobile --platform android   # or ios (macOS only), or all
```

Installs Capacitor deps, creates `capacitor.config.json`, scaffolds `android/` (and/or `ios/`), checks for the required tools, and adds `[client.mobile]` to `jac.toml`. With no `--platform` it uses `[client.mobile].default_platform`, else the host default (`ios` on macOS, `android` elsewhere).

## Configuration - `[client.mobile]`

```toml
[client.mobile]
app_name = "My Jac App"        # display name           (default "Jac App")
app_id = "com.example.myapp"   # reverse-DNS id, both stores (default "com.jac.app")
release = false                # true = release variant instead of debug
bundle = false                 # true = AAB instead of APK (Android)
default_platform = "android"   # default for jac start --client mobile
ios_sdk = "iphonesimulator"    # "iphoneos" for device builds
ios_destination = "platform=iOS Simulator,name=iPhone 16,OS=latest"
```

Values feed `capacitor.config.json` and the native build commands automatically.

## Dev loop

```bash
jac start main.jac --client mobile --dev                  # live reload on device/emulator
jac start main.jac --client mobile --dev --platform ios   # force iOS
jac start main.jac --client mobile --dev --host 192.168.1.25   # only when auto host fails
```

Runs `cap sync` + `cap run`. Host selection is automatic; on Android, jac-client auto-attempts `adb reverse` for the Vite and API ports before launching Capacitor, so manual port forwarding is usually unnecessary. If the app loads blank: check the printed host/port, confirm `adb devices` shows the target as authorized, and fall back to manual `adb reverse tcp:5173 tcp:5173` / `tcp:8000 tcp:8000`.

## Production build

```bash
jac build --client mobile --platform android
# -> android/app/build/outputs/apk/debug/app-debug.apk
#    (release/app-release.apk with release = true; .aab with bundle = true)

jac build --client mobile --platform ios     # xcodebuild, simulator SDK by default
npx cap open ios                             # device builds, signing, App Store archive
```

Android release signing needs a keystore configured in `android/app/build.gradle`; iOS device builds need Xcode provisioning profiles.

## Capacitor plugins (camera, geolocation, push, ...)

```bash
jac install --npm @capacitor/camera
npx cap sync                       # re-sync native projects after ANY plugin change
```

## Debugging on device

- **Android:** Chrome DevTools at `chrome://inspect` while the app runs on a device/emulator.
- **iOS:** Safari Web Inspector (enable in Safari → Develop menu).

## See also

- `jac-sv-deploy` - deploying the backend the app talks to
- `jac-cl-routing` / `jac-cl-auth` - pages and login flows inside the webview
- `jac-project-kinds` - mobile vs desktop vs PWA target comparison
