# Jac Mobile Target: Architecture & Usage

## Overview

The Jac mobile target enables building mobile applications from Jac code using a **WebView-based architecture**. It extends the web target by wrapping the Jac web application inside a React Native WebView, powered by Expo SDK 54.

The mobile app is essentially a native shell (React Native + Expo) that renders the entire Jac UI inside a `WebView` component. This approach allows the same Jac frontend code to run on web, desktop, and mobile with zero changes.

---

## Architecture

### Class Hierarchy

```
ClientTarget (abstract base)
  --> WebTarget (default web target, uses ViteBundler)
    --> MobileTarget (extends WebTarget with React Native WebView wrapping)
```

`MobileTarget` inherits all web bundling capabilities from `WebTarget` and adds:
- Expo/React Native project scaffolding
- WebView wrapper generation
- Bundle-to-HTML conversion for offline loading
- EAS Build integration for native compilation
- Dev server orchestration (Vite + Backend + Expo simultaneously)

### How It Works

```
Jac Source Code
      |
      v
ViteBundler (inherited from WebTarget)
      |
      v
Web Bundle (HTML + CSS + JS)
      |
      v
create-bundle.js (Node.js script)
      |
      v
bundle.ts (self-contained HTML string with base64-encoded JS)
      |
      v
React Native WebView loads bundle.ts
      |
      v
Mobile App renders Jac UI
```

---

## Quick Start

### Prerequisites

- Python 3.12+ with `jaclang` and `jac-client` installed
- Node.js 18+ and npm
- For iOS: macOS with Xcode installed
- For Android: Android SDK (via Android Studio or standalone)

### Commands

```bash
# 1. Create a jac project (if not already)
jac create --use client my-app
cd my-app

# 2. Setup mobile target (one-time scaffolding)
jac setup mobile

# 3. Install mobile dependencies (auto-installed during setup)
# Dependencies installed automatically in .jac/mobile/ during build/dev

# 4. Start dev server (with hot reload)
jac start --client mobile --dev

# 5. Build for production
jac build --client mobile -b production -p android
jac build --client mobile -b production -p ios
jac build --client mobile -b production -p all
```

---

## Detailed Flows

### `jac setup mobile` -- Project Scaffolding

This command creates the React Native/Expo project structure with **source files only** in the `mobile/` directory.

**What gets generated:**

```
mobile/                        # Source files ONLY (tracked in git)
  app/
    index.tsx                  # WebView screen component (main app)
    _layout.tsx                # Expo Router layout (uses <Slot />)
  assets/
    icon.png                   # App icon (1024x1024)
    splash.png                 # Splash screen image
    adaptive-icon.png          # Android adaptive icon
    favicon.png                # Web favicon
    jac-app/
      create-bundle.js         # Bundle creation script (source)
  app.json                     # Expo configuration (generated from jac.toml)
  package.json                 # Dependencies manifest
  tsconfig.json                # TypeScript config
  .gitignore                   # Ignores temporarily copied bundles

.jac/mobile/                   # Build artifacts (NOT tracked in git)
  (created during build/dev)
  node_modules/                # Dependencies
  yarn.lock                    # Lock file
  .expo/                       # Expo cache
  assets/jac-app/
    bundle.html                # Generated bundle
    bundle.ts                  # Generated bundle
    client.js                  # Copied web bundle
    index.html                 # Copied web bundle
    styles.css                 # Copied web bundle
```

**Note:** Source files are in `mobile/` (tracked in git), while all build artifacts (dependencies, bundles) are in `.jac/mobile/` (not tracked). For EAS builds, bundles are temporarily copied to `mobile/assets/jac-app/` for git upload.

**Key dependencies (auto-installed with yarn):**

| Package | Version | Purpose |
|---------|---------|---------|
| `expo` | ~54.0.0 | Expo SDK |
| `expo-router` | ~6.0.23 | File-based routing |
| `react` | 19.2.4 | UI library |
| `react-native` | 0.81.5 | Native runtime |
| `react-native-webview` | 13.15.0 | WebView component |
| `react-native-screens` | ~4.24.0 | Native screen containers |
| `react-native-safe-area-context` | ~5.7.0 | Safe area handling |

**Note:** Dependencies are automatically installed with `yarn` during `jac setup mobile`.

**Configuration added to `jac.toml`:**

```toml
[mobile]
name = "my-app"
bundle_id = "com.example.myapp"
version = "1.0.0"
display_name = "My App"
slug = "my-app"
scheme = "myapp"

[mobile.platforms]
ios = true
android = true

[mobile.features]
use_sidecar = false
api_url = ""

# Expo app configuration (generates app.json)
[mobile.expo]
orientation = "portrait"
userInterfaceStyle = "light"
icon = "./assets/icon.png"

[mobile.expo.splash]
image = "./assets/splash.png"
resizeMode = "contain"
backgroundColor = "#ffffff"

[mobile.expo.ios]
supportsTablet = true

[mobile.expo.android.adaptiveIcon]
foregroundImage = "./assets/adaptive-icon.png"
backgroundColor = "#ffffff"

[mobile.expo.web]
favicon = "./assets/favicon.png"

# EAS Build profiles (generates eas.json)
[mobile.eas.profiles.development]
distribution = "internal"
developmentClient = true

[mobile.eas.profiles.preview]
distribution = "internal"

[mobile.eas.profiles.production]
distribution = "store"
```

**Note:** The `app.json` and `eas.json` files are now generated from this TOML configuration, making it easier to version control and maintain your mobile app configuration in one place.

---

### `jac start --client mobile --dev` -- Dev Mode

This starts three servers simultaneously for live development:

```
Step 1: Build web bundle (ViteBundler produces initial HTML/CSS/JS)
    |
Step 2: Create mobile bundle (fallback for bundle mode)
    |
Step 3: Start Vite dev server (port 5173)
    |     Serves web content with Hot Module Replacement (HMR)
    |
Step 4: Start Jac backend server (port 9000)
    |     Serves API endpoints (walkers, nodes, etc.)
    |
Step 5: Start Expo dev server
          Scan QR code with Expo Go to test on physical device
```

**Output:**

```
  Vite dev server: http://172.20.10.2:5173
  Backend API: http://172.20.10.2:9000

  Two modes available:
     Bundle mode (default): Loads pre-built HTML from assets
     Dev mode (HMR): Set USE_DEV_SERVER = true in .jac/mobile/app/index.tsx
                     Loads from Vite dev server with instant updates
```

**IP Detection:** The system automatically detects your local network IP (not `localhost`) so that physical devices on the same WiFi network can reach the dev servers. This IP is written to `.jac/mobile/dev-config.json`.

**Two Rendering Modes:**

| Mode | How to Enable | Source | Live Reload |
|------|--------------|--------|-------------|
| **Bundle mode** (default) | `USE_DEV_SERVER = false` in `index.tsx` | Loads `bundle.ts` (embedded HTML string) | No -- rebuild required |
| **Dev mode (HMR)** | `USE_DEV_SERVER = true` in `index.tsx` | Loads from `http://<IP>:5173` | Yes -- instant updates |

**Cleanup:** Pressing `Ctrl+C` gracefully stops all three servers (5-second timeout before force kill).

---

### `jac build --client mobile` -- Production Build

```
Step 1: Build web bundle
    |   ViteBundler produces optimized HTML + CSS + JS in .jac/client/dist/
    |
Step 2: Copy web bundle to mobile assets
    |   index.html  --> .jac/mobile/assets/jac-app/index.html
    |   *.css        --> .jac/mobile/assets/jac-app/styles.css
    |   *.js (largest) --> .jac/mobile/assets/jac-app/client.js
    |
Step 3: Create mobile bundle
    |   node create-bundle.js
    |   Produces bundle.html (standalone) and bundle.ts (importable string)
    |
Step 4: Build with EAS (or local)
        eas build --profile <build_type> --platform <platform>
        Outputs APK/AAB (Android) or IPA (iOS)
```

**Build profiles:**

| Profile | Android Output | iOS Output | Distribution |
|---------|---------------|------------|-------------|
| `development` | Debug APK | Simulator build | Internal testing |
| `preview` | Release APK | Device IPA | Internal distribution |
| `production` | Release AAB | Release IPA | App Store / Play Store |

**CLI examples:**

```bash
# Development build for Android
jac build --client mobile -b development -p android

# Preview build for iOS
jac build --client mobile -b preview -p ios

# Production build for both platforms
jac build --client mobile -b production -p all
```

---

## WebView Architecture

### How the WebView Works

The entire mobile app is a single React Native screen containing a `WebView` component. The Jac UI (HTML/CSS/JS compiled from `.jac` files) runs inside this WebView.

```
+------------------------------------------+
|          React Native Shell               |
|  +------------------------------------+  |
|  |          SafeAreaView              |  |
|  |  +------------------------------+  |  |
|  |  |                              |  |  |
|  |  |         WebView              |  |  |
|  |  |                              |  |  |
|  |  |   Jac Web Application        |  |  |
|  |  |   (HTML + CSS + JS)          |  |  |
|  |  |                              |  |  |
|  |  |   Compiled from .jac files   |  |  |
|  |  |   via ViteBundler            |  |  |
|  |  |                              |  |  |
|  |  +------------------------------+  |  |
|  +------------------------------------+  |
+------------------------------------------+
```

### Bundle Mode (Default -- Offline Capable)

In bundle mode, the app loads a self-contained HTML string from `bundle.ts`:

1. **ViteBundler** compiles Jac source to `index.html` + `styles.css` + `client.js`
2. **`create-bundle.js`** combines these into a single HTML:
   - CSS is inlined via `<style>` tags
   - JavaScript is **base64-encoded** and loaded via a Blob URL
   - The `__jac_init__` configuration is preserved as a script tag
   - A `window.JAC_BACKEND_URL` placeholder is injected (replaced at runtime)
3. The result is exported as a TypeScript string constant (`JAC_BUNDLE_HTML`)
4. The WebView loads it via `source={{ html: htmlContent }}`

**Why base64 + Blob URL?** WebView's `source={{ html: ... }}` mode doesn't support `<script type="module" src="...">` with relative paths. The Blob URL technique makes the entire JS bundle loadable as a module from an inline HTML string.

### Dev Mode (HMR -- Live Reload)

In dev mode, the WebView points to the Vite dev server:

```typescript
// source={{ uri: "http://172.20.10.2:5173" }}
```

This provides full Hot Module Replacement -- code changes in `.jac` files are reflected instantly in the app without rebuilding.

### Backend API Connection

The WebView needs to communicate with the Jac backend server for walker/node operations:

| Environment | API URL |
|------------|---------|
| Android Emulator | `http://10.0.2.2:9000` (emulator alias for host localhost) |
| iOS Simulator | `http://<local-network-IP>:9000` |
| Physical Device | `http://<local-network-IP>:9000` |
| Production | Configured via `jac.toml` or environment |

### Error Bridging

The WebView injects JavaScript that forwards errors from the web context to React Native:

- `console.error` is overridden to send messages via `window.ReactNativeWebView.postMessage()`
- `window.onerror` and `unhandledrejection` events are captured
- React Native logs these with `[WebView Error]` prefix for debugging

---

## Configuration Reference

### `jac.toml` -- Mobile Section

```toml
# Mobile target configuration
[mobile]
name = "my-app"                          # App name
identifier = "com.example.myapp"         # Bundle identifier (reverse domain)
version = "1.0.0"                        # App version
enabled = true                           # Enable mobile target

[mobile.platforms]
ios = true                               # Enable iOS builds
android = true                           # Enable Android builds

[mobile.features]
webview_debugging = true                 # Enable WebView inspector in dev
local_storage = true                     # Enable local storage in WebView
camera = false                           # Camera access (future)
geolocation = false                      # GPS access (future)
push_notifications = false               # Push notifications (future)

# Mobile-specific response headers (for WebView CORS compatibility)
[environments.mobile.response.headers]
Cross-Origin-Opener-Policy = "unsafe-none"
Cross-Origin-Embedder-Policy = "unsafe-none"
Access-Control-Allow-Origin = "*"
Access-Control-Allow-Methods = "GET, POST, PUT, DELETE, OPTIONS"
Access-Control-Allow-Headers = "Content-Type, Authorization"
```

### EAS Build Profiles (auto-generated from TOML)

The `eas.json` file is **automatically generated** from your `jac.toml` configuration with three default profiles. You no longer need to maintain a separate `eas.json` file!

**Default profiles defined in `jac.toml`:**

```toml
[mobile.eas.profiles.development]
distribution = "internal"
developmentClient = true

[mobile.eas.profiles.preview]
distribution = "internal"

[mobile.eas.profiles.production]
distribution = "store"
```

**Generated `eas.json`:**

```json
{
  "cli": { "version": ">= 13.2.0" },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal",
      "android": {
        "gradleCommand": ":app:assembleDebug",
        "buildType": "apk"
      },
      "ios": {
        "simulator": true,
        "buildConfiguration": "Debug"
      }
    },
    "preview": {
      "distribution": "internal",
      "android": {
        "gradleCommand": ":app:assembleRelease",
        "buildType": "apk"
      },
      "ios": {
        "simulator": false,
        "buildConfiguration": "Release"
      }
    },
    "production": {
      "distribution": "store",
      "android": {
        "gradleCommand": ":app:bundleRelease",
        "buildType": "app-bundle"
      },
      "ios": {
        "simulator": false,
        "buildConfiguration": "Release"
      }
    }
  },
  "submit": {}
}
```

Custom EAS profiles can be defined in `jac.toml` under `[mobile.eas.profiles.YOUR_PROFILE_NAME]` and will be deep-merged with these defaults.

---

## Project Structure

After `jac setup mobile`, the project looks like:

```
my-app/
  main.jac                    # Jac entry point
  jac.toml                    # Project configuration (includes mobile config)
  .jac/
    mobile/                   # React Native/Expo project
      app/
        index.tsx             # WebView screen (main app screen)
        _layout.tsx           # Expo Router root layout
      assets/
        icon.png              # App icon
        splash.png            # Splash screen
        adaptive-icon.png     # Android adaptive icon
        favicon.png           # Web favicon
        jac-app/
          index.html          # Copied from Vite build
          styles.css          # Copied from Vite build
          client.js           # Copied from Vite build (largest JS)
          bundle.html         # Standalone HTML (for debugging)
          bundle.ts           # Importable HTML string (used by WebView)
          create-bundle.js    # Bundle creation script
      app.json                # Expo configuration (generated from jac.toml)
      eas.json                # EAS build profiles (generated from jac.toml)
      package.json            # Dependencies
      tsconfig.json           # TypeScript config
      dev-config.json         # Dev server IP config (auto-generated)
      node_modules/           # Installed dependencies (gitignored)
    client/
      dist/                   # ViteBundler output (HTML + CSS + JS)
      compiled/               # Compiled Jac code
```

**Key Points:**

- `mobile/` directory at project root with source files only (tracked in git)
- `.jac/mobile/` directory with build artifacts (not tracked in git)
- `app.json` is generated from `[mobile.expo]` section in `jac.toml`
- `eas.json` is generated from `[mobile.eas]` section in `jac.toml`
- All mobile configuration is centralized in `jac.toml`
- Dependencies auto-installed with yarn during setup

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `Stub file not found at .../typeshed/stdlib/typing.pyi` | Git submodule not initialized | `git submodule update --init --recursive` from repo root |
| `expo-dev-client` plugin error | Missing dependency | `cd .jac/mobile && npx expo install expo-dev-client` |
| `eas.json not found` | Setup didn't generate EAS config | Build will generate it automatically, or create manually in `mobile/` |
| `Mobile target already set up. Skipping...` | `mobile/` directory exists | Delete `mobile/` and `.jac/mobile/` and re-run `jac setup mobile` |
| `Bun is required but not installed` | Bun not in PATH | Install Bun: `curl -fsSL https://bun.sh/install \| bash` then restart shell |
| WebView shows blank screen | Backend not running or wrong IP | Check `dev-config.json` has correct local IP; ensure backend is on correct port |
| HMR not working | Bundle mode is active | Set `USE_DEV_SERVER = true` in `.jac/mobile/app/index.tsx` (copied from source during build) |
| Android emulator can't reach API | Wrong API URL | Android emulator uses `10.0.2.2` as alias for host machine's `localhost` |

### Dev Mode Checklist

1. Ensure all three servers are running (Vite, Backend, Expo)
2. Mobile device/emulator is on the same WiFi network as your machine
3. `USE_DEV_SERVER = true` is set in `.jac/mobile/app/index.tsx` for HMR
4. `dev-config.json` contains the correct local network IP
5. No firewall blocking ports 5173 (Vite), 9000 (Backend), or 8081 (Expo)

---

## Current Status

| Feature | Status |
|---------|--------|
| `jac setup mobile` | Working |
| `jac start --client mobile --dev` | Working |
| `jac build --client mobile` (EAS) | Working (requires EAS account) |
| Local builds (without EAS) | Not yet implemented |
| OTA updates | Not yet implemented |
| Store submission | Not yet implemented |
