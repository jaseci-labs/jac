# Mobile Target (Expo + WebView)

The mobile target wraps your existing Jac web application in an Expo app using a WebView. Your web UI runs inside a native mobile shell — HTML, CSS, JavaScript, routing, and localStorage all work unchanged.

This is the same approach used by Capacitor/Ionic: build for web, wrap in a native container.

## Prerequisites

- **Bun** — required for package management ([bun.sh](https://bun.sh))
- **Expo Go** — install on your phone from [App Store](https://apps.apple.com/app/expo-go/id982107779) / [Play Store](https://play.google.com/store/apps/details?id=host.exp.exponent)
- **Optional**: Xcode (for iOS simulator), Android Studio (for Android emulator)

## Quick Start

### 1. Create a project (or use an existing one)

```bash
jac create my-app --use client
cd my-app
```

### 2. Setup mobile target

```bash
jac setup mobile
```

This scaffolds an Expo project in `.jac/mobile/` with:
- `App.tsx` — WebView shell that loads your web app
- `app.json` — Expo configuration (name, icons, bundle ID)
- `eas.json` — Build profiles (development, preview, production)
- Core dependencies: `expo`, `react-native`, `react-native-webview`

It also adds `[plugins.client.mobile]` to your `jac.toml`.

### 3. Start developing

```bash
# Start the backend + Expo dev server
jac start --client mobile
```

Scan the QR code with Expo Go on your phone. Your web app loads inside the WebView.

### 4. Build for production

```bash
# iOS
jac build --client mobile --target ios --profile production

# Android
jac build --client mobile --target android --profile production

# Both
jac build --client mobile --target all --profile production
```

## CLI Reference

### Setup

```bash
jac setup mobile              # One-time Expo project scaffolding
```

### Development

```bash
jac start --client mobile              # Expo Go (QR code)
jac start --client mobile --ios        # Launch iOS simulator
jac start --client mobile --android    # Launch Android emulator
jac start --client mobile --tunnel     # Use tunnel for remote devices
```

### Building

```bash
jac build --client mobile --target ios --profile production
jac build --client mobile --target android --profile preview
jac build --client mobile --target all --profile production
jac build --client mobile --target ios --profile production --local  # Local build (no EAS cloud)
```

**Build profiles:**
- `development` — development client build (for testing with dev tools)
- `preview` — internal distribution (TestFlight / internal APK)
- `production` — App Store / Play Store release

### Package Management

```bash
jac add --expo expo-camera              # Install Expo-compatible package
jac add --expo react-native-maps        # Ensures SDK-compatible version
jac remove --expo expo-camera           # Uninstall package
```

Use `--expo` (not `--npm`) for React Native/Expo packages. `expo install` resolves versions compatible with your Expo SDK.

### Expo Escape Hatch

Run any Expo CLI command directly:

```bash
jac expo doctor                # Check project health
jac expo config                # View resolved config
jac expo prebuild              # Generate native projects
jac expo prebuild --clean      # Clean and regenerate
jac expo install expo-camera   # Alternative to jac add --expo
```

## Configuration

### jac.toml

After `jac setup mobile`, your `jac.toml` includes:

```toml
[plugins.client.mobile]
scheme = "my-app"                          # Deep linking URL scheme
api_base_url = "http://localhost:8000"     # Backend URL for dev
bundle_identifier = "com.example.myapp"    # iOS bundle identifier
package_name = "com.example.myapp"         # Android package name
```

### app.json

The Expo config at `.jac/mobile/app.json` is generated from `jac.toml`. To customize app icons, splash screen, or other Expo settings, edit this file directly or use `jac expo config` to inspect the resolved config.

### eas.json

Build profiles at `.jac/mobile/eas.json`. Default:

```json
{
  "build": {
    "development": { "developmentClient": true, "distribution": "internal" },
    "preview": { "distribution": "internal" },
    "production": {}
  }
}
```

## How It Works

```
jac start --client mobile
│
├─ 1. Jac backend starts on :8000 (serves API + web bundle)
├─ 2. Expo dev server starts (serves native app shell)
├─ 3. Phone opens Expo Go → loads App.tsx
├─ 4. App.tsx renders WebView pointing to http://<lan-ip>:8000
└─ 5. Your web app runs inside the WebView on the phone

jac build --client mobile --target ios --profile production
│
├─ 1. Web bundle built (same as jac build --client web)
├─ 2. Bundle copied to .jac/mobile/assets/web/
├─ 3. EAS build packages the Expo app with embedded bundle
└─ 4. Output: iOS .ipa ready for App Store
```

## Project Structure

```
my-app/
├── jac.toml                    # Project config
├── main.jac                    # Your app code
├── components/                 # Components
├── pages/                      # File-based routes (optional)
├── assets/                     # Your static assets
└── .jac/
    ├── client/                 # Web build output
    │   └── dist/               # index.html + JS + CSS
    └── mobile/                 # Expo project (generated)
        ├── App.tsx             # WebView shell
        ├── app.json            # Expo config
        ├── eas.json            # Build profiles
        ├── package.json        # Expo dependencies
        └── assets/
            └── web/            # Embedded web bundle (for production)
```

## What Works Unchanged

Since the mobile target uses a WebView (browser engine), everything from the web target works:

- HTML elements (`<div>`, `<button>`, `<input>`, etc.)
- CSS (all styles, Tailwind, CSS modules)
- `localStorage` (persists within the WebView)
- `fetch` API calls to backend
- `BrowserRouter` / file-based routing
- `jacSpawn`, `jacLogin`, `jacSignup`, `jacLogout`, `jacIsLoggedIn`
- Error boundaries
- All npm packages that work in browsers

## Differences from Web

| Aspect | Web | Mobile (WebView) |
|--------|-----|-------------------|
| Viewport | Full browser | Phone screen with safe areas |
| Hover states | `:hover` works | No hover on touch devices |
| URL bar | Visible in browser | Not visible (full-screen WebView) |
| DevTools | Browser DevTools | React Native Debugger / Safari Web Inspector |
| Performance | Native browser speed | WebView is slightly slower than browser |
| Back button | Browser back | Android hardware back works in WebView |

## Migrating an Existing Web Project

If you have an existing Jac web project:

```bash
cd my-existing-project
jac setup mobile
jac start --client mobile
```

No code changes needed. Your web app runs on mobile immediately.

## Troubleshooting

### "Mobile target not set up"
Run `jac setup mobile` first.

### WebView shows "localhost refused to connect"
The WebView needs to reach your backend. On physical devices, `localhost` doesn't work. The dev server auto-detects your LAN IP. If that fails:
- Use `jac start --client mobile --tunnel` for a public URL
- Or set `api_base_url` in `jac.toml` to your machine's IP

### Expo Go can't find the dev server
Make sure your phone and computer are on the same Wi-Fi network. If behind a firewall, use `--tunnel`.

### EAS build requires login
Run `jac expo login` to authenticate with your Expo account (free tier available).

## Future (v2)

- **Native RN components**: `<View>`, `<Text>`, `<Pressable>` for native performance
- **WebView bridge**: Access camera, GPS, push notifications via `postMessage`
- **Platform-specific code**: `component.mobile.jac` / `component.web.jac`
- **NativeWind**: CSS class to RN StyleSheet mapping
- **Expo Router (native)**: Replace WebView routing with native navigation
