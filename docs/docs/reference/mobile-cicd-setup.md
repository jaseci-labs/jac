# Mobile CI/CD Setup Guide

This guide explains how to set up and use the mobile build pipeline for iOS and Android apps.

## Prerequisites

1. **Expo Account**
   - Sign up at [https://expo.dev](https://expo.dev)
   - Create a project or use an existing one

2. **EAS CLI** (for local testing)

   ```bash
   npm install -g eas-cli
   eas login
   ```

3. **GitHub Repository Access**
   - Admin access to add secrets
   - Actions enabled

---

## Setup Instructions

### Step 1: Generate Expo Access Token

1. Log in to your Expo account:

   ```bash
   eas login
   ```

2. Generate an access token:

   ```bash
   eas whoami
   ```

   Or create a personal access token from the Expo dashboard:
   - Go to [https://expo.dev/accounts/[account]/settings/access-tokens](https://expo.dev/accounts/)
   - Click "Create Token"
   - Give it a name (e.g., "GitHub Actions")
   - Copy the token (you won't see it again!)

### Step 2: Add Secret to GitHub

1. Go to your repository on GitHub
2. Navigate to: **Settings** → **Secrets and variables** → **Actions**
3. Click **"New repository secret"**
4. Add the following secret:
   - **Name**: `EXPO_TOKEN`
   - **Value**: Your Expo access token from Step 1

### Step 3: Verify Mobile Project Configuration

Ensure your mobile project has the required files:

```
jac-client/jac_client/examples/all-in-one/mobile/
├── app.json          # Expo configuration
├── eas.json          # EAS build profiles
├── package.json      # Dependencies
└── app/              # React Native code
```

If the `mobile/` directory doesn't exist, the workflow will automatically run `jac setup mobile`.

---

## Using the Build Pipeline

### Manual Trigger (Recommended to Start)

1. Go to your repository on GitHub
2. Click **Actions** tab
3. Select **"Build Mobile Apps"** workflow
4. Click **"Run workflow"** button
5. Choose your options:
   - **Platform**: `all`, `ios`, or `android`
   - **Profile**: `development`, `preview`, or `production`
   - **App path**: Path to your app (default: `jac-client/jac_client/examples/all-in-one`)
6. Click **"Run workflow"**

### Build Profiles Explained

| Profile | Android Output | iOS Output | Use Case |
|---------|---------------|------------|----------|
| **development** | Debug APK | Simulator build | Local testing with Expo Go |
| **preview** | Release APK | Device build | Internal testing (TestFlight) |
| **production** | AAB (App Bundle) | IPA (Archive) | App Store submission |

---

## Monitoring Build Progress

### In GitHub Actions

1. Go to the **Actions** tab
2. Click on your running workflow
3. Expand the job for each platform
4. View logs in real-time

### In Expo Dashboard

1. Go to [https://expo.dev](https://expo.dev)
2. Navigate to your project
3. Click **"Builds"** tab
4. View detailed build logs and status

---

## Downloading Build Artifacts

### From GitHub Actions

1. After the workflow completes, scroll to the bottom of the workflow run page
2. Under **"Artifacts"**, you'll see:
   - `mobile-app-android-{profile}-{run_number}` (APK or AAB)
   - `mobile-app-ios-{profile}-{run_number}` (IPA tar.gz)
3. Click to download

**Retention**: Artifacts are kept for 30 days

### From Expo Dashboard

1. Go to your project builds page
2. Click on the completed build
3. Click **"Download"** to get the APK/IPA directly

---

## Installing Builds on Devices

### Android (APK)

**Method 1: Direct Install**

1. Download the APK to your Android device
2. Enable "Install from Unknown Sources" in Settings
3. Tap the APK file to install

**Method 2: ADB**

```bash
adb install app-android-preview.apk
```

### Android (AAB - Production)

App Bundles (`.aab`) cannot be installed directly. They must be uploaded to Google Play Console.

### iOS (IPA)

**Method 1: TestFlight** (Preview/Production)

1. Upload to App Store Connect
2. Share TestFlight link with testers

**Method 2: Xcode** (Development)

1. Extract the tar.gz file
2. Use Xcode → Devices to install on connected device

---

## Troubleshooting

### Build Fails with "Authentication Error"

**Solution**: Verify `EXPO_TOKEN` secret is set correctly:

```bash
# Test locally first
eas whoami
```

### Build Fails with "Invalid Project ID"

**Solution**: Ensure `app.json` has the correct `projectId`:

```json
{
  "expo": {
    "extra": {
      "eas": {
        "projectId": "your-project-id-here"
      }
    }
  }
}
```

Run `eas build:configure` to generate/update the project ID.

### Workflow Doesn't Appear in Actions

**Solution**: Make sure the workflow file is on the correct branch (usually `main`).

### Build Takes Too Long

EAS builds can take 10-30 minutes depending on:

- Platform (iOS is typically slower)
- Queue time (Expo's build servers)
- Build profile (production builds take longer)

The workflow will wait for the build to complete automatically.

### No Artifacts Uploaded

**Possible causes**:

1. Build failed on EAS (check Expo dashboard)
2. Download step failed (check workflow logs)
3. Network timeout (retry the workflow)

---

## Build Costs

### EAS Build Limits

- **Free Tier**: Limited builds per month
- **Paid Plans**: Unlimited builds with faster queues

Check your usage at [https://expo.dev/accounts/[account]/settings/billing](https://expo.dev/accounts/)

To avoid unexpected charges, consider:

- Building only when necessary (manual trigger)
- Using development profile for testing
- Caching dependencies

---

## Advanced Configuration

### Automatic Versioning

Edit the workflow to bump version numbers automatically:

```yaml
- name: Bump version
  working-directory: ${{ github.event.inputs.app_path }}/mobile
  run: |
    # Get version from git tag
    VERSION="${{ github.ref_name }}"

    # Update app.json
    jq ".expo.version = \"$VERSION\"" app.json > tmp.json
    mv tmp.json app.json
```

### App Store Submission

After a production build completes, you can submit directly to app stores:

```yaml
- name: Submit to App Store
  if: matrix.platform == 'ios' && github.event.inputs.profile == 'production'
  working-directory: ${{ github.event.inputs.app_path }}/mobile
  env:
    EXPO_TOKEN: ${{ secrets.EXPO_TOKEN }}
  run: |
    eas submit --platform ios --latest
```

### Slack Notifications

Add a step to notify your team:

```yaml
- name: Notify Slack
  if: always()
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "Mobile build ${{ job.status }}: ${{ matrix.platform }} (${{ github.event.inputs.profile }})"
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

## Next Steps

1. ✅ Set up `EXPO_TOKEN` secret
2. ✅ Run your first manual build
3. ✅ Download and test the artifact
4. 📱 Configure automatic triggers (tags, PRs)
5. 🚀 Set up app store submission

---

## Support

- **Expo Documentation**: [https://docs.expo.dev/build/introduction/](https://docs.expo.dev/build/introduction/)
- **EAS CLI Reference**: [https://docs.expo.dev/eas-cli/](https://docs.expo.dev/eas-cli/)
- **GitHub Actions**: [https://docs.github.com/en/actions](https://docs.github.com/en/actions)

For issues specific to this pipeline, check the [jaseci repository issues](https://github.com/jaseci-labs/jaseci/issues).
