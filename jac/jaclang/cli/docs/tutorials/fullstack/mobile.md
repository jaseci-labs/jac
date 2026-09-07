# Building a Mobile App

This tutorial walks you through shipping a Jac app as a native mobile app for Android and iOS. A mobile app is an app of kind `mobile` -- `[project] kind = "mobile"` in a single-app project, or an `[apps.<name>]` table in a workspace next to your web app (`jac create --app mobile --kind mobile` writes one). Its `cl` UI compiles to **platform-native views** through [React Native](https://reactnative.dev/) (Expo/Metro/Hermes), and the same source also runs in a browser through `react-native-web`.

The mobile app is the *frontend only*: every walker and `def:pub` call bridges over HTTP to a Jac server you deploy separately -- in a workspace, the `web-app` or `service` app that owns the walkers. The examples below name the app `mobile`; in a single-app project drop the name (`jac run --dev`, `jac build --platform android`).

If what you want is a home-screen install of an existing web app rather than native views, you do not need a mobile app at all: a `[client.pwa]` table in `jac.toml` makes the web app a [PWA](../../reference/plugins/jac-client.md#pwa) with no rewrite.

> **Prerequisites**
>
> - Completed: [Project Setup](setup.md) -- you have a working `jac run` web app
> - Node.js is **not** required -- all JS tooling runs on the Bun runtime bundled with `jac`
> - **Android**: JDK 21 and Android SDK are provisioned automatically; SDK license acceptance is required
> - **iOS** (macOS only): Xcode and its Command Line Tools; Jac provisions Ruby and CocoaPods
> - Time: ~15 minutes for setup, longer on first build

---

## How a Mobile Build Works

When you run `jac build mobile --platform android`, the build does four things:

1. **Compiles the app's modules** with the native client runtime -- Jac to JS, `@jac/mobui` primitives lowering to React Native components.
2. **Stages them into the Expo project** at `.jac/mobile-rn/` (scaffolding it first if it is missing) and runs `expo prebuild` for the platform.
3. **Builds the native app** -- Gradle for Android, `xcodebuild` for iOS (or EAS Build for either).
4. **Produces the artifact** -- an `.apk` for Android, a simulator `.app` for iOS (an `.ipa` through EAS).

`jac build mobile --platform web` runs the same source through the Vite pipeline instead, producing a browser bundle via `react-native-web`.

---

## mobUI and `@jac/mobui`

A `mobile` app is a **mobUI** app: one source tree that compiles to both native (Android/iOS) and web. Because React Native has no DOM, mobUI apps do not use HTML tags. Instead they use Jac's `@jac/mobui` component vocabulary, which projects to every platform:

| `@jac/mobui` | Replaces HTML |
|-----------|---------------|
| `View` | `div`, `section`, `main`, `article`, `header`, `footer`, `nav`, `aside` |
| `Text` | `span`, `p`, `h1`-`h6`, `label`, `strong`, `em`, `small` |
| `Pressable` | `button`, `a` |
| `TextInput` | `input`, `textarea` |
| `Image` | `img` |
| `ScrollView` | `ul`, `ol`, scroll areas |
| `FlatList` / `SectionList` | long or grouped lists (virtualized -- prefer over `ScrollView`) |
| `Modal` | `dialog` |
| `Switch` | `input type="checkbox"` |
| `Alert` / `Linking` | `window.alert` / `window.open` |
| `StyleSheet` | CSS / `className` |

Styling is `style={{...}}` objects over a flexbox subset -- no CSS files, no `className`. In a mobile app, raw HTML tags (`<div>`, `<span>`, ...) are **compile errors** (`E1105`) with a fix-it pointing at the `@jac/mobui` primitive to use instead. See the [diagnostics reference](../../reference/diagnostics.md#mobui-project-jsx-host-tags) for details.

---

## One-Time Setup

Declare the app in `jac.toml` -- `jac create --app mobile --kind mobile` writes this (and `jac create myapp --kind mobile` writes the single-app form, `[project] kind = "mobile"`):

```toml
[apps.mobile]
kind = "mobile"
path = "mobile"
platform = "android"      # optional default for `jac run mobile` / `jac build mobile`
```

The kind turns on the `@jac/mobui` host-tag guard for every module under `mobile/` -- and only there, so a web app in the same workspace keeps its HTML. Then, from the project root:

```bash
jac setup mobile
```

This scaffolds an Expo/Metro project at `.jac/mobile-rn/` (configurable via `[client.react_native].project_dir`; it lives under the centralized `.jac` build root, so it stays out of the source tree), merges `[dependencies.npm.native]` into its `package.json`, installs the packages, and prints next steps.

---

## Configure the Toolchain

The Expo/EAS knobs live under `[client.react_native]` in `jac.toml` (all optional):

```toml
[client.react_native]
project_dir = ".jac/mobile-rn"   # Expo project location
release = false                  # true for release variants
default_platform = "android"     # platform for a plain `jac run mobile` ([apps.mobile] platform wins)
android_builder = "gradle"       # "gradle" (local) or "eas" (EAS Build)
ios_builder = "xcodebuild"       # "xcodebuild" (local, macOS) or "eas" (EAS Build)
eas_profile = ""                 # "" -> "production" (release) / "preview" (debug)
```

npm packages the web platform needs go under `[dependencies.npm]` (or the app's `[apps.mobile.dependencies.npm]` overlay); packages only the Expo project needs go under `[dependencies.npm.native]`. Run `jac install` after editing `jac.toml`.

---

## Authoring UI with `@jac/mobui`

```jac
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
                onChangeText={lambda (t: str) { name = t; }}
            />
            <Pressable style={styles.button} onPress={lambda { name = "Jac"; }}>
                <Text>Reset</Text>
            </Pressable>
        </ScrollView>;
}
```

The same source builds for native (`jac build mobile --platform android`) and, through `react-native-web`, for the browser (`jac build mobile --platform web`).

---

## Development

```bash
jac run --dev mobile                    # native: Metro Fast Refresh on a device or simulator
jac run --dev --platform web mobile     # the same screens in a browser (Vite HMR)
```

The native dev loop launches a Jac backend, compiles `.jac` to JS, and runs `expo start` on the bundled Bun. Metro serves both platforms -- pick the device in the Expo CLI (press `a` for Android, `i` for the iOS simulator) or scan the QR code in Expo Go. Editing a `.jac` file recompiles and Metro Fast Refreshes the device. The dev API base URL is injected into `app.json` and restored on exit. Dev networking is auto-resolved (LAN IPv4 > `127.0.0.1`, override with `JAC_RN_DEV_HOST`); Metro defaults to port `8081` (`JAC_RN_METRO_PORT`); `adb reverse` is auto-attempted for Android.

The web platform needs no device and hot-reloads in seconds, so iterate there first and check native as you go.

### Troubleshooting

If the app starts but cannot reach the server:

1. Check the `jac run` output for the Metro and API URLs it printed.
2. Confirm `adb devices` shows your Android target as authorized.
3. If port forwarding failed, run it by hand: `adb reverse tcp:8081 tcp:8081` and `adb reverse tcp:8000 tcp:8000` (or whichever API port was printed).
4. Set `JAC_RN_DEV_HOST=<ip>` when the auto-detected LAN address is not the one the device can reach.

---

## Production Build

```bash
jac build mobile --platform android     # APK
jac build mobile --platform ios         # macOS only; non-macOS points at EAS Build
jac build mobile --platform web         # browser bundle (dist/mobile/ under `jac build --all --platform web`)
```

Android produces an APK via `gradlew assembleDebug` (or EAS Build with `android_builder = "eas"`); install it with `adb install -r <apk>`. iOS produces a simulator-installable `.app` bundle via `xcodebuild` on macOS (`xcrun simctl install booted <app>`); a distributable `.ipa` comes from the EAS Build path (`ios_builder = "eas"`), and on other hosts `--platform ios` errors out and points you at EAS Build. Release variants via `[client.react_native].release = true`. Signing, provisioning and store distribution follow the Expo docs for the builder you chose.

`jac run mobile` (no `--dev`) builds for the app's platform and installs and launches the result on a connected device or booted simulator. The platform is `--platform` if given, else `[apps.mobile] platform`, else `[client.react_native].default_platform`, else `android`.

When `jac build --all --platform web` builds the workspace, the mobile app's browser bundle lands in `dist/mobile/` and the served web app mounts it at `/cl/mobile/`.

### EAS Update (OTA)

`jac setup mobile` scaffolds a baseline `eas.json` (with `preview` and `production` profiles). To push OTA updates after each build:

1. **One-time** (inside `.jac/mobile-rn/`): install the updates module and link your EAS project:

   ```bash
   npx expo install expo-updates
   eas update:configure      # writes expo.updates.url into app.json
   ```

   `expo-updates` is not pinned in the scaffold -- `npx expo install` resolves the SDK-matched version.

2. **Opt in** via `jac.toml`:

   ```toml
   [client.react_native]
   eas_update = true
   eas_update_branch = "production"   # "" -> "production" (release) / "preview" (debug)
   ```

3. **Build** as usual -- a successful `jac build mobile` then runs `eas update --branch <branch>` automatically. Set `eas_update_message` to pin a message; leave it empty to let EAS derive one.

See the [jac-client Reference -> EAS Update (OTA)](../../reference/plugins/jac-client.md#eas-update-ota) for the full field list.

---

## Platform-specific files

When you need platform-exclusive native modules, add a `.native.jac` variant alongside a `.jac` module. The variant is selected by the app's platform: the compiler picks up the `.native.jac` file for the app's native platforms (android / ios) and the base `.jac` for its web platform -- the filename alone decides nothing. The two files must agree on their public surface (names, kinds of declaration, parameters, annotations, `has` fields); each disagreement is `E5105` on the variant, so a drifted pair is caught by `jac check` rather than at first launch. The flagship workspace's `mobile/icon.jac` / `mobile/icon.native.jac` is the worked example. This is a last resort -- prefer components from the `@jac/mobui` vocabulary, which absorb platform divergence internally. Use a file pair only when the platforms need *different imports*; to branch on values, `Platform` is part of the vocabulary already, so `Platform.OS` and `Platform.select({ios: ..., android: ..., default: ...})` work inline.

## What carries over from a web app

A mobile app reuses the same Jac -> JS compilation pipeline, the same `JacForm` form system (adapted to RN `TextInput`), the same auth helpers (backed by `expo-secure-store`), and the same walker-call API. Routing is adapted to React Navigation: `Router` -> `NavigationContainer`, `Routes` + `Route` -> `Stack.Navigator` + `Stack.Screen`.

---

## What You've Built

By now you should have:

- An `[apps.mobile]` table (or `[project] kind = "mobile"`) declaring the app, with the toolchain knobs under `[client.react_native]`.
- An Expo project under `.jac/mobile-rn/` that `jac build` and `jac run --dev` drive for you.
- Screens written once in `@jac/mobui` that run on Android, iOS and the web.
- The ability to build and deploy to both platforms from the same Jac codebase.

For the full reference -- including every CLI option and configuration field -- see the [jac-client Reference -> Mobile](../../reference/plugins/jac-client.md#mobile).
