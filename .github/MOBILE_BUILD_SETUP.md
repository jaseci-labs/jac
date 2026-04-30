# Mobile Build CI/CD - Quick Setup

## 🚀 Quick Start (5 minutes)

### 1. Get Your Expo Token

```bash
# Login to Expo
npx eas-cli login

# Get your access token
npx eas-cli whoami
```

Or create a token from: https://expo.dev/accounts/[your-account]/settings/access-tokens

### 2. Add GitHub Secret

1. Go to: **Repository Settings** → **Secrets and variables** → **Actions**
2. Click **"New repository secret"**
3. Name: `EXPO_TOKEN`
4. Value: Paste your token from step 1
5. Click **"Add secret"**

### 3. Run Your First Build

1. Go to: **Actions** tab
2. Click: **"Build Mobile Apps"** workflow
3. Click: **"Run workflow"**
4. Choose:
   - Platform: `android` (faster for testing)
   - Profile: `preview`
   - App path: `jac-client/jac_client/examples/all-in-one` (default)
5. Click: **"Run workflow"** (green button)

### 4. Wait & Download

- Build takes ~15-20 minutes
- Check progress in Actions tab
- Download APK/IPA from "Artifacts" section

---

## 📱 Testing Your Build

### Android APK
```bash
# On your Android device
1. Download the APK artifact
2. Enable "Install from Unknown Sources"
3. Tap the APK to install
```

### iOS IPA
```bash
# Requires TestFlight or Xcode
1. Extract the .tar.gz file
2. Upload to TestFlight OR
3. Install via Xcode → Devices & Simulators
```

---

## 🔧 Build Profiles

| Profile | Android | iOS | Use For |
|---------|---------|-----|---------|
| `development` | Debug APK | Simulator | Quick testing |
| `preview` | Release APK | Device build | Internal testing |
| `production` | AAB bundle | IPA | App stores |

---

## ❓ Common Issues

### "Authentication failed"
→ Check your `EXPO_TOKEN` secret is set correctly

### "Project not found"
→ Run `eas build:configure` in your mobile directory to set up project ID

### "Build failed"
→ Check Expo dashboard for detailed logs: https://expo.dev

---

## 📚 Full Documentation

See [docs/docs/reference/mobile-cicd-setup.md](../docs/docs/reference/mobile-cicd-setup.md) for complete guide.

## 🎯 Workflow File

The workflow is defined in: [.github/workflows/build-mobile.yml](./workflows/build-mobile.yml)

---

## 🔐 Security Notes

- Never commit your `EXPO_TOKEN` to git
- Use GitHub Secrets for all credentials
- Rotate tokens periodically
- Use separate tokens for production vs development

---

Happy building! 🚀
