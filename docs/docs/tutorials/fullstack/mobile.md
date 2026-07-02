# Building a Mobile App

This tutorial walks you through shipping an existing Jac full-stack app as a native mobile app for Android and iOS. Jac ships **two** mobile targets:

- **Capacitor** (`--client mobile`) -- wraps your web bundle in a native webview. Covered in the first half of this page.
- **React Native** (`--client react-native`, beta) -- compiles your `cl` UI to platform-native views. Covered in [React Native target](#react-native-target) below.

> **Prerequisites**
>
> - Completed: [Project Setup](setup.md) -- you have a working `jac start` web app
> - Node.js is **not** required -- all JS tooling runs on the Bun runtime bundled with `jac`
> - **Android**: Java/JDK 21+, Android SDK (via [Android Studio](https://developer.android.com/studio))
> - **iOS** (macOS only): Xcode, Xcode Command Line Tools, [CocoaPods](https://cocoapods.org/)
> - Time: ~15 minutes for setup, longer on first build

---

## How a Mobile Build Works

When you run `jac build --client mobile --platform android`, the build does four things:

1. **Compiles the client bundle** -- the same Vite build the web target produces.
2. **Syncs with Capacitor** -- copies the web bundle into the native project (`android/` or `ios/`) and updates native plugins.
3. **Builds the native app** -- runs Gradle (`assembleDebug`) for Android or `xcodebuild` for iOS.
4. **Produces the artifact** -- an `.apk` file for Android, or an Xcode build for iOS.

The result is a native mobile app that loads your Jac frontend in a webview. The same client bundle that runs in the browser runs inside the native shell.

---

## One-Time Setup

From your project root:

```bash
jac setup mobile
```

This installs Capacitor dependencies, creates `capacitor.config.json`, and scaffolds the selected platform. By default, setup follows `[plugins.client.mobile].default_platform` and falls back to `ios` on macOS or `android` elsewhere.

You can force a specific scaffold explicitly:

```bash
# Android scaffold only
jac setup mobile --platform android

# iOS scaffold only (macOS only)
jac setup mobile --platform ios

# Both platforms (macOS only; Linux/Windows will scaffold Android)
jac setup mobile --platform all
```

The setup also:

- Checks for required tools (Node.js, Java/JDK, Android SDK, Xcode, CocoaPods)
- Adds a `[plugins.client.mobile]` section to your `jac.toml`
- Prints next steps for both platforms

---

## Configure App Metadata

Open `jac.toml` and edit the `[plugins.client.mobile]` section that setup created:

```toml
[plugins.client.mobile]
app_name = "My Jac App"
app_id = "com.example.myapp"
```

| Field | Description | Default |
|-------|-------------|---------|
| `app_name` | Display name of the app | `Jac App` |
| `app_id` | Reverse-DNS identifier (used by both app stores) | `com.jac.app` |
| `release` | Build release variant instead of debug | `false` |
| `bundle` | Produce AAB (Android App Bundle) instead of APK | `false` |
| `default_platform` | Default platform for `jac start --client mobile` | `android` |
| `ios_sdk` | Xcode SDK for iOS builds | `iphonesimulator` |
| `ios_destination` | Xcode destination string | `platform=iOS Simulator,name=iPhone 16,OS=latest` |

These values feed into `capacitor.config.json` and the native build commands automatically.

---

## Android Development

### Dev Loop

Build the web bundle, sync it into the Android project, and launch on a connected device or emulator:

```bash
jac start main.jac --client mobile
```

This runs `cap sync android` followed by `cap run android`.

If you need to force a specific host/IP for live reload, use:

```bash
jac start main.jac --client mobile --dev --host 192.168.1.25
```

jac-client auto-attempts `adb reverse` for the Vite and API ports before launching Capacitor on Android, so manual `adb reverse` is usually not required.

### Production Build

```bash
# Debug APK (default)
jac build --client mobile --platform android

# Release APK (set release = true in jac.toml)
# Or release AAB (set bundle = true in jac.toml)
```

The APK lands in `android/app/build/outputs/`. The build uses the project's `gradlew` wrapper automatically.

### Where to Find the APK

After a successful build:

```
android/app/build/outputs/apk/debug/app-debug.apk
```

For release builds:

```
android/app/build/outputs/apk/release/app-release.apk
```

---

## iOS Development

> **Note:** iOS builds require macOS with Xcode installed. You can scaffold the project on any OS, but building requires a Mac.

### Dev Loop

```bash
jac start main.jac --client mobile --platform ios
```

This syncs the web bundle and opens the project on the iOS Simulator via `cap run ios`.

### Production Build

```bash
jac build --client mobile --platform ios
```

This runs `xcodebuild` targeting the iOS Simulator by default. For device builds or App Store archives, open the project in Xcode:

```bash
npx cap open ios
```

From Xcode you can:

- Select a physical device or simulator
- Configure signing and provisioning profiles
- Archive for App Store distribution

### CocoaPods

Capacitor iOS uses CocoaPods for native dependencies. If `pod install` hasn't been run, Capacitor's sync step handles it. If you add native plugins later, run:

```bash
cd ios/App && pod install
```

---

## Cross-Platform Tips

### Shared Web Bundle

Both platforms use the exact same web bundle. Write your UI once; Capacitor wraps it natively for each platform.

### Native Plugins

Capacitor has a rich plugin ecosystem for camera, geolocation, push notifications, etc. Install them via npm:

```bash
jac add --npm @capacitor/camera
npx cap sync
```

### Testing on Real Devices

- **Android**: Enable USB debugging on your device, connect via USB, and `cap run android` deploys directly.
- **iOS**: Register your device in your Apple Developer account, select it in Xcode, and build.

### Mobile Dev Networking

When using `jac start ... --client mobile --dev`, jac-client auto-selects a reachable host by default:

```bash
# Auto host selection (recommended)
jac start main.jac --client mobile --dev
```

Override host selection only when needed:

```bash
jac start main.jac --client mobile --dev --host 192.168.1.25
```

You can still force iOS or Android in dev with:

```bash
jac start main.jac --client mobile --dev --platform ios
```

### Debugging

- **Android**: Use Chrome DevTools -- navigate to `chrome://inspect` while the app is running on a device/emulator.
- **iOS**: Use Safari Web Inspector -- enable it in Safari → Develop menu.

### Troubleshooting

If mobile dev starts but the app does not load correctly:

1. Check `jac start` output for selected host and Vite port.
2. If needed, set an explicit host with `--host <ip>`.
3. Confirm `adb devices` shows your Android target as authorized.
4. If port forwarding fails, run manual fallback:
   - `adb reverse tcp:5173 tcp:5173`
   - `adb reverse tcp:8000 tcp:8000`
5. Re-run sync after plugin changes:
   - `npx cap sync android`
   - `npx cap sync ios`
6. For iOS signing or provisioning issues, open Xcode:
   - `npx cap open ios`

---

## React Native target

The React Native target (`--client react-native`, beta) is the **native** mobile path: instead of wrapping a web bundle in a webview, it compiles your `cl` UI to platform-native views via Expo/Metro/Hermes. This gives native gesture/scroll performance and access to the React Native ecosystem, at the cost of a different rendering and styling model.

### mobUI projects and `@jac/mobui`

A React Native app is a **mobUI** project -- one source tree that compiles to both web (via `react-native-web`) and native (Android/iOS). Because React Native has no DOM, mobUI projects do not use HTML tags. Instead they use Jac's `@jac/mobui` component vocabulary, which projects to every target:

| `@jac/mobui` | Replaces HTML |
|-----------|---------------|
| `View` | `div`, `section`, `main`, `article`, `header`, `footer`, `nav`, `aside` |
| `Text` | `span`, `p`, `h1`-`h6`, `label`, `strong`, `em`, `small` |
| `Pressable` | `button`, `a` |
| `TextInput` | `input`, `textarea` |
| `Image` | `img` |
| `ScrollView` | `ul`, `ol`, scroll areas |
| `StyleSheet` | CSS / `className` |

Styling is `style={{...}}` objects over a flexbox subset -- no CSS files, no `className`. In a mobUI project, raw HTML tags (`<div>`, `<span>`, ...) are **compile errors** (`E1105`) with a fix-it pointing at the `@jac/mobui` primitive to use instead. See the [diagnostics reference](../../reference/diagnostics.md#mobui-project-jsx-host-tags) for details.

### One-time setup

From your project root:

```bash
jac setup react-native
```

This scaffolds an Expo/Metro project at `.jac/mobile-rn/` (configurable via `[plugins.client.react_native].project_dir`; it lives under the centralized `.jac` build root, so it stays out of the source tree) and prints next steps.

Then opt in to the mobUI project kind in `jac.toml`:

```toml
[project]
name = "myapp"
version = "0.1.0"
client_kind = "mobui"
```

### Authoring UI with `@jac/mobui`

```jac
cl {
    import from "@jac/mobui" {
        View, Text, Pressable, TextInput, ScrollView, StyleSheet
    }

    glob styles = StyleSheet.create({
        screen: {flex: 1, backgroundColor: "#10131c", padding: 24, gap: 16},
        title: {fontSize: 22, fontWeight: "bold", color: "#f4f5fb"},
        button: {padding: 12, borderRadius: 10, backgroundColor: "#6c5ce7", alignItems: "center"},
    });

    def:pub app -> JsxElement {
        has name: str = "";
        return
            <ScrollView style={styles.screen}>
                <Text style={styles.title}>Hello, {name or "stranger"}</Text>
                <TextInput
                    value={name}
                    placeholder="Type your name"
                    onChangeText={lambda t: str { name = t; }}
                />
                <Pressable style={styles.button} onPress={lambda { name = "Jac"; }}>
                    <Text>Reset</Text>
                </Pressable>
            </ScrollView>;
    }
}
```

The same source builds for web (`jac build`) and native (`jac build --client react-native`).

### Development

```bash
jac start main.jac --client react-native --dev
```

This launches the Jac backend, compiles `.cl.jac` to JS, and runs `expo start` on the bundled Bun. Metro serves both platforms -- pick the device in the Expo CLI (press `a` for Android, `i` for the iOS simulator) or scan the QR code in Expo Go. Editing a `.cl.jac` file recompiles and Metro Fast Refreshes the device. Dev networking is auto-resolved (LAN IPv4 > `127.0.0.1`, override with `JAC_RN_DEV_HOST`); Metro defaults to port `8081` (`JAC_RN_METRO_PORT`); `adb reverse` is auto-attempted for Android.

### Production build

```bash
# Android
jac build --client react-native --platform android

# iOS (macOS only; non-macOS points at EAS Build)
jac build --client react-native --platform ios
```

Android produces an APK via `gradlew assembleDebug`. iOS produces a simulator-installable `.app` bundle via `xcodebuild` on macOS (a distributable `.ipa` comes from the EAS Build path); on other platforms the build errors out and points you at EAS Build. Release variants via `[plugins.client.react_native].release = true`.

### EAS Update (OTA)

`jac setup react-native` scaffolds a baseline `eas.json` (with `preview` and `production` profiles). To push OTA updates after each build:

1. **One-time** (inside `.jac/mobile-rn/`): install the updates module and link your EAS project:

   ```bash
   npx expo install expo-updates
   eas update:configure      # writes expo.updates.url into app.json
   ```

   `expo-updates` is not pinned in the scaffold -- `npx expo install` resolves the SDK-matched version.

2. **Opt in** via `jac.toml`:

   ```toml
   [plugins.client.react_native]
   eas_update = true
   eas_update_branch = "production"   # "" -> "production" (release) / "preview" (debug)
   ```

3. **Build** as usual -- a successful `jac build --client react-native` then runs `eas update --branch <branch>` automatically. Set `eas_update_message` to pin a message; leave it empty to let EAS derive one.

See the [jac-client Reference -> EAS Update (OTA)](../../reference/plugins/jac-client.md#eas-update-ota) for the full field list.

### Platform-specific files

When you need platform-exclusive native modules, add a `.native.cl.jac` variant alongside a `.cl.jac` module. The compiler picks up the `.native.cl.jac` file when `--client react-native` is selected and falls back to `.cl.jac` otherwise. This is a last resort -- prefer components from the `@jac/mobui` vocabulary, which absorb platform divergence internally. (A `Platform.select` one-liner API is planned but not yet part of `@jac/mobui`.)

### What carries over

The React Native target reuses the same Jac -> JS compilation pipeline, the same `JacForm` form system (adapted to RN `TextInput`), the same auth helpers (backed by `expo-secure-store`), and the same walker-call API. Routing is adapted to React Navigation: `Router` -> `NavigationContainer`, `Routes` + `Route` -> `Stack.Navigator` + `Stack.Screen`.

For the full reference, see the [jac-client Reference -> React Native Target](../../reference/plugins/jac-client.md#react-native-target-beta).

---

## What You've Built

By now you should have:

- A `[plugins.client.mobile]` section in `jac.toml` controlling app name, identifier, and build mode.
- An `android/` directory with a Capacitor-wrapped Android project.
- An `ios/` directory with a Capacitor-wrapped iOS project (on macOS).
- The ability to build and deploy to both platforms from the same Jac codebase.

For the full reference -- including every CLI option and configuration field -- see the [jac-client Reference → Mobile Target](../../reference/plugins/jac-client.md#mobile-target-capacitor).
