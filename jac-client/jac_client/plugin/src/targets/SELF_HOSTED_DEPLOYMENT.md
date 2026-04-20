# Self-Hosted Mobile Deployment: Analysis & Strategy

## Overview

This document analyzes a fully self-hosted alternative to Expo Application Services (EAS) for building, deploying, and updating Jac mobile applications. The goal is to eliminate cloud dependencies while maintaining the same output quality (store-submittable APK/AAB/IPA binaries and instant OTA updates).

---

## The Two Pillars of Mobile Deployment

Mobile deployment has two distinct concerns:

| Concern | What It Does | When Needed |
|---------|-------------|-------------|
| **Native Build** | Compiles APK/AAB (Android) or IPA (iOS) | First install, native code changes, SDK upgrades |
| **OTA Update** | Pushes JavaScript/Jac code changes to installed apps | UI changes, bug fixes, feature additions (no native changes) |

EAS handles both via cloud services. A self-hosted approach replaces each independently.

---

## 1. Native Builds: Local vs EAS

### Can You Build Store-Submittable Binaries Locally?

**Yes.** EAS Build simply runs the same Gradle (Android) and Xcode (iOS) commands on cloud machines. The output binaries are identical.

| Build Type | EAS (Cloud) | Local Build | Output Identical? |
|-----------|-------------|-------------|-------------------|
| Debug APK (testing) | `eas build --profile development` | `./gradlew assembleDebug` | Yes |
| Release APK (signed) | `eas build --profile preview` | `./gradlew assembleRelease` | Yes |
| AAB (Google Play) | `eas build --profile production` | `./gradlew bundleRelease` | Yes |
| iOS Simulator | `eas build --profile development` | `xcodebuild -sdk iphonesimulator` | Yes |
| iOS IPA (App Store) | `eas build --profile production` | `xcodebuild archive + exportArchive` | Yes |

### Platform Requirements

| Platform | Can Build On Any OS? | Device Required? |
|----------|---------------------|-----------------|
| **Android** | Yes (Mac, Linux, Windows) | No |
| **iOS** | **No** -- requires macOS + Xcode | No (simulator available) |

> **Apple's restriction**: iOS builds require macOS. This is a legal and technical constraint with no workaround. Even EAS runs macOS VMs for iOS builds.

### Local Build Commands

**Android (any OS):**
```bash
# One-time: Generate native project
cd mobile
npx expo prebuild --platform android

# Debug APK (for testing)
cd android && ./gradlew assembleDebug

# Release APK (signed, distributable)
cd android && ./gradlew assembleRelease

# AAB (Google Play submission)
cd android && ./gradlew bundleRelease
```

**iOS (macOS only):**
```bash
# One-time: Generate native project
cd mobile
npx expo prebuild --platform ios

# Simulator build
cd ios && xcodebuild -workspace *.xcworkspace -scheme <AppName> -sdk iphonesimulator

# Archive for App Store
cd ios && xcodebuild archive -workspace *.xcworkspace -scheme <AppName> -archivePath build/<AppName>.xcarchive
xcodebuild -exportArchive -archivePath build/<AppName>.xcarchive -exportPath build/ -exportOptionsPlist ExportOptions.plist
```

### Store Submission

| Method | Android (Play Store) | iOS (App Store) |
|--------|---------------------|-----------------|
| **EAS Submit** | `eas submit --platform android` | `eas submit --platform ios` |
| **Fastlane** (free, open source) | `fastlane supply` | `fastlane deliver` |
| **Manual** | Play Console upload | Transporter app or `altool` |

---

## 2. OTA Updates: Self-Hosted Server

### What Is It?

The [Self-Hosted Expo Updates Server](https://github.com/umbertoghio/self-hosted-expo-updates-server) is an open-source implementation of the Expo Updates protocol. It lets you push JavaScript bundle updates to installed apps without going through the app store.

### Architecture

```
+-------------------+     +-------------------+     +-------------------+
|   Web Dashboard   |     |    API Server      |     |     MongoDB       |
|   (React/Vite)    |<--->|  (Node.js/Express) |<--->|    (4.2.2+)       |
|   Port 8080       |     |    Port 3000       |     |   Port 27017      |
+-------------------+     +-------------------+     +-------------------+
                                    |
                          +---------+---------+
                          |                   |
                    /updates/           /uploads/
                  (extracted           (raw zip
                   bundles)            uploads)
```

### Docker Deployment

```yaml
services:
  update-server-api:
    image: ghcr.io/umbertoghio/self-hosted-expo-updates-server-api:latest
    ports:
      - "3000:3000"
    environment:
      - FEATHERS_AUTH_SECRET=<your-jwt-secret>
      - MONGO_CONN=mongodb://db:27017/expo-updates
      - ADMIN_PASSWORD=<admin-password>
      - UPLOAD_KEY=<upload-api-key>
      - PUBLIC_URL=https://your-server.com
    volumes:
      - updates_data:/updates
      - uploads_data:/uploads

  update-server-web:
    image: ghcr.io/umbertoghio/self-hosted-expo-updates-server-web:latest
    ports:
      - "8080:8080"

  update-server-db:
    image: mongo:6.0
    volumes:
      - mongo_data:/data/db
```

### How OTA Updates Work

```
Developer                    Self-Hosted Server              Mobile App
    |                              |                             |
    |-- expo export                |                             |
    |-- zip bundle                 |                             |
    |-- POST /upload (zip) ------->|                             |
    |                              |-- extract & store metadata  |
    |                              |                             |
    |  [Release via Web Dashboard] |                             |
    |                              |                             |
    |                              |<-- GET /api/manifest -------|
    |                              |-- return signed manifest -->|
    |                              |                             |
    |                              |<-- GET /api/assets ---------|
    |                              |-- stream JS bundle -------->|
    |                              |                             |
    |                              |                   [App reloads with new code]
```

### Key API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/manifest?project={slug}&channel={channel}` | GET | Serves update manifest to mobile clients |
| `/api/assets?asset={path}&contentType={mime}` | GET | Serves individual JS/asset files |
| `/upload` | POST | Receives update zip packages from developers |

### Publishing an Update

```bash
# 1. Export the Expo bundle
npx expo export --output-dir dist

# 2. Add metadata
cp app.json package.json dist/

# 3. Zip it
cd dist && zip -r ../update.zip ./*

# 4. Upload to server
curl -X POST "$SERVER_URL/upload" \
  --form "uri=@update.zip" \
  --header "project: my-app" \
  --header "version: 1.0.0" \
  --header "release-channel: release" \
  --header "upload-key: $UPLOAD_KEY" \
  --header "git-branch: $(git rev-parse --abbrev-ref HEAD)" \
  --header "git-commit: $(git log --oneline -n 1)"
```

### Features

- Manage multiple apps and release channels
- Web dashboard for release, rollback, and monitoring
- Real-time client download tracking
- Git branch/commit metadata on every update
- Self-signed certificate generation for code signing
- Rollback to any previous update with one click

### Code Signing

The server uses RSA-SHA256 code signing:
- Server generates a self-signed certificate (private key stays on server)
- Public certificate (`certificate.pem`) is embedded in the mobile app
- Manifests are signed before delivery; the app verifies signatures
- Certificate must be generated via the web dashboard's SERVER CONFIGURATION section

App configuration for code signing:
```json
{
  "updates": {
    "url": "https://your-server.com/api/manifest?project=myapp&channel=release",
    "codeSigningCertificate": "./code-signing/certificate.pem",
    "codeSigningMetadata": {
      "alg": "rsa-v1_5-sha256",
      "keyid": "main"
    }
  }
}
```

---

## 3. Self-Hosted vs EAS: Comparison

### What Self-Hosted Replaces

| EAS Feature | Self-Hosted Alternative | Status |
|------------|------------------------|--------|
| EAS Update (OTA) | Self-hosted Expo Updates Server | Full replacement |
| EAS Build (Android) | Local Gradle / CI (GitHub Actions) | Full replacement |
| EAS Build (iOS) | Local Xcode / CI with macOS runner | Full replacement (Mac required) |
| EAS Submit | Fastlane (free, open source) | Full replacement |
| EAS Credentials | Manual keystore/cert management | Manual but doable |

### Pros of Self-Hosted

| Advantage | Details |
|-----------|---------|
| Full data sovereignty | Code and builds never leave your infrastructure |
| Zero recurring cost | No EAS pricing tiers ($0 vs $99+/month) |
| No build queue wait | EAS free tier has queues; local builds start immediately |
| Unlimited builds | EAS free tier: 30 builds/month |
| Custom update policies | Staged rollouts, per-customer channels, air-gapped deployment |
| Instant rollback | One-click rollback via web dashboard |
| Real-time monitoring | See clients downloading updates live |
| Jac ecosystem fit | Deploy alongside jac backend in same infrastructure |

### Cons of Self-Hosted

| Disadvantage | Details |
|-------------|---------|
| Infrastructure maintenance | You manage servers, database, backups, SSL |
| iOS requires Mac | No workaround for Apple's restriction |
| Manual credential management | Keystores, provisioning profiles, certificates |
| Single-maintainer project | The OTA server is a community project, no SLA |
| No global CDN | EAS uses CDN; self-hosted serves from single origin |
| Protocol tracking | Must stay compatible with Expo SDK updates |

---

## 4. The Complete Self-Hosted Toolchain

```
+---------------------------------------------------------------+
|              FULLY SELF-HOSTED MOBILE FLOW                    |
+---------------------------------------------------------------+
|                                                               |
|  BUILD (first install or native changes)                      |
|  +---------------------------------------------------------+  |
|  | Android: Gradle (any OS)                                |  |
|  |   ./gradlew assembleRelease  --> APK                    |  |
|  |   ./gradlew bundleRelease    --> AAB (Play Store)       |  |
|  |                                                         |  |
|  | iOS: Xcode (macOS only)                                 |  |
|  |   xcodebuild archive        --> IPA (App Store)         |  |
|  +---------------------------------------------------------+  |
|                                                               |
|  SUBMIT (app store distribution)                              |
|  +---------------------------------------------------------+  |
|  | Android: fastlane supply  --> Google Play Store          |  |
|  | iOS:     fastlane deliver --> Apple App Store            |  |
|  +---------------------------------------------------------+  |
|                                                               |
|  UPDATE (JS/Jac changes -- no rebuild needed)                 |
|  +---------------------------------------------------------+  |
|  | jac publish --client mobile                             |  |
|  |   --> expo export --> zip --> upload to OTA server       |  |
|  |   --> Web dashboard: release / rollback / monitor       |  |
|  |   --> App auto-downloads update on next launch          |  |
|  +---------------------------------------------------------+  |
|                                                               |
|  TOOLS (all free & open source)                               |
|  +---------------------------------------------------------+  |
|  | Gradle + Android SDK        (Android builds)            |  |
|  | Xcode                       (iOS builds)                |  |
|  | Fastlane                    (store submission)          |  |
|  | Self-hosted Update Server   (OTA updates)               |  |
|  | GitHub Actions CI           (optional automation)       |  |
|  +---------------------------------------------------------+  |
|                                                               |
|  COST: $0  (+$99/yr Apple Developer for iOS)                  |
+---------------------------------------------------------------+
```

---

## 5. Integration Plan for jac-client

### Phase 1: Local Build Support
- Add `jac build --client mobile --local` flag to skip EAS and use Gradle/Xcode directly
- Run `npx expo prebuild` to generate native projects
- Execute Gradle (Android) or Xcode (iOS) build commands locally
- Output signed APK/AAB/IPA

### Phase 2: OTA Update Server Integration
- Add `[mobile.updates]` section to `jac.toml` configuration
- Add `jac publish --client mobile` CLI command
- Implement the export -> zip -> upload workflow
- Generate Docker Compose for the self-hosted update server via `jac setup update-server`

### Phase 3: Code Signing & Security
- Integrate certificate generation/download into `jac setup mobile`
- Auto-configure `app.json` with code signing settings
- Manage upload keys securely (`.env` or `jac.toml`)

### Phase 4: Store Submission
- Add `jac submit --client mobile --platform android` command
- Integrate Fastlane for automated Play Store / App Store submission
- Support both manual and CI-driven submission workflows

---

## 6. Conclusion

A fully self-hosted mobile deployment pipeline is achievable with zero cloud dependencies (except Apple requiring macOS for iOS). The output binaries are identical to EAS-built ones, and the self-hosted OTA update server provides the same push-update capability with added benefits of full control, instant rollbacks, and real-time monitoring.

The only hard constraint: **iOS builds require macOS.** Everything else works on any OS, at zero cost.
