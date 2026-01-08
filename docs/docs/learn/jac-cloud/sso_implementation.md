# SSO integration made Easy

!!! warning "Deprecated"
    **Jac Cloud is deprecated.** Use [jac-scale](../../production/index.md) for new projects.

## What Is SSO?

Single Sign-On (SSO) is an authentication process that allows users to log in once and gain access to multiple applications or services without needing to enter their credentials repeatedly. Think of it as a single key that opens multiple doors securely.

It’s especially useful for:

- Simplifying user login → Users don’t have to remember multiple usernames and passwords.

- Improving security → Credentials are managed centrally, reducing risks of weak or reused passwords.

- Enhancing user experience → Smooth, one-click login across different apps and platforms.

- Centralized control → Admins can manage authentication policies and permissions from one place.

- Integration with identity providers → Works with providers like Google, Facebook, Microsoft, or enterprise systems (Okta, Azure AD).

## Supported Platforms in Jac Cloud

Currently following SSO platforms are supported in Jac cloud for SSO

| **Platform name** | **Used for** |
|----------------------|-----------------|
| `APPLE` |  Used for apple SSO integration for both websites and mobile apps|
| `GOOGLE` | Used for gmail SSO integration for websites|
| `GOOGLE_ANDROID` | Used for gmail SSO integration for android mobile apps|
| `GOOGLE_IOS` | Used for gmail SSO integration for ios mobile apps|

## Steps to implement SSO in Jac cloud Setting Your Environment variables

### Step 1: Obtain relevant client credentials from supported platforms

First choose the supported platform and register your application with the relevant platform to get credentials needed
to setup SSO in jac cloud.You can read following documentations and tutorials to register your application.

#### Google

##### General Implementation

- [Step by step to integrate Google OAuth2/SSO](https://dev.to/idrisakintobi/a-step-by-step-guide-to-google-oauth2-authentication-with-javascript-and-bun-4he7) - Complete guide with JavaScript and Bun
- [Easy Configure SSO with Google](https://developer.slashid.dev/docs/access/guides/SSO/oauth_creds_google) - Simplified configuration guide

##### Platform-Specific Guides

- **Web**: [Implementation guide for Web](https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid) - Official Google documentation
- **Android**: [Implementation guide for Android](https://developer.android.com/identity/sign-in/credential-manager-siwg) - Using Credential Manager
- **iOS**: [Implementation guide for iOS](https://developers.google.com/identity/sign-in/ios/start-integrating) - Google Sign-In for iOS

#### Apple

- [Easy Configure SSO with Apple](https://developer.slashid.dev/docs/access/guides/SSO/oauth_creds_apple) - Configuration guide for Apple ID authentication

---

### Step 2: Setup relevant env variables

### Basic Pattern

```bash
# Replace PLATFORM with: GOOGLE, GITHUB, FACEBOOK, etc.
export SSO_{PLATFORM}_CLIENT_ID="your_client_id"
export SSO_{PLATFORM}_CLIENT_SECRET="your_client_secret"
```

#### Google Web Example

```bash
export SSO_GOOGLE_CLIENT_ID="123456789-abcdef.apps.googleusercontent.com"
export SSO_GOOGLE_CLIENT_SECRET="GOCSPX-abcdefghijklmnop"
```

#### Google iOS Example

```bash
export SSO_GOOGLE_IOS_CLIENT_ID="123456789-abcdef.apps.googleusercontent.com"
export SSO_GOOGLE_IOS_CLIENT_SECRET="GOCSPX-abcdefghijklmnop"
```

#### Google Android Example

```bash
export SSO_GOOGLE_ANDROID_CLIENT_ID="123456789-abcdef.apps.googleusercontent.com"
export SSO_GOOGLE_ANDROID_CLIENT_SECRET="GOCSPX-abcdefghijklmnop"
```

#### Apple-Specific SSO Configuration

Apple requires a special configuration for client secret generation:

| **Variable** | **Description** |
|--------------|-----------------|
| `SSO_APPLE_CLIENT_ID` | Apple client ID |
| `SSO_APPLE_CLIENT_TEAM_ID` | Apple developer team ID |
| `SSO_APPLE_CLIENT_KEY` | Apple client key |
| `SSO_APPLE_CLIENT_CERTIFICATE_PATH` | Path to Apple client certificate |
| `SSO_APPLE_CLIENT_CERTIFICATE` | Raw Apple client certificate content |

### Step 3: Call Register Callback Endpoint Provided by JAC Cloud

#### 1. Start the Backend Server

Once all the relevant platform specific environment variables are set, run the backend using:

```bash
jac serve main.jac
```

This command will provide the `backendURL` of the FastAPI server.

#### 2. Obtain ID Token from Frontend

In your frontend application (Web App, Android, or iOS), use the relevant libraries provided by each framework to get the `id_token`:

- **Web**: Google Sign-In JavaScript library
- **Android**: Google Sign-In for Android / Apple Sign-In
- **iOS**: Google Sign-In SDK / Apple Sign-In

#### 3. Call the Callback Endpoint

Once the `id_token` is obtained, call the callback endpoint provided by JAC Cloud

##### Endpoint Format

```
$GET {backendURL}/sso/${provider}/register/callback?id_token=${id_token}
```

##### Curl Example for apple with id_token

```bash
curl -X 'GET' \
  'http://localhost:8000/sso/apple/register/callback?id_token=eyJraWQiOiJFNnE4M1JCMTVuIiwiYWxnIjoiUlMyNTYifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwiYXVkIjoibGlmZS50b2J1IiwiZXhwIjoxNzU2NTYxOTg0LCJpYXQiOjE3NTY0NzU1ODQsInN1YiI6IjAwMDkwNC5hMTI5MDJmMzA1ZGE0ZWY1ODE5MGVmN2VjMGQ3ODE1OS4xMzU3IiwiY19oYXNoIjoiQksxdTdBYmlua2RsMUlBWUVISWp2dyIsImVtYWlsIjoicWM5N2s3Mm5mN0Bwcml2YXRlcmVsYXkuYXBwbGVpZC5jb20iLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwiaXNfcHJpdmF0ZV9lbWFpbCI6dHJ1ZSwiYXV0aF90aW1lIjoxNzU2NDc1NTg0LCJub25jZV9zdXBwb3J0ZWQiOnRydWV9.iC_vnj2Ar268Z2IW0Ums1gr6OT0UFZocUFJaU_X1S9fudnd_pmIvgOgnlYO8Y7_P134xzjyrHV2-sB_APjZluaUNid7dUkLu7FaCEjU4GReuXlav9Ek9pZfV0FY0D2wqEJhMZ2EcQfgBJbthSewlbbwIeEF4OTHOPB3Pfw8jVJxEMseJ6glxOL0UHC7jRAJNsyYePG2ld1o66UMiFpOaIuuoTjJmigaPA4Mwe1Tiu_ZtGPONd9TEZo7xCXP_c2E68Rh9dLZcqULXAot58l71XEJJok63SQfGMfolR-ibCRAbWvqfe-ZFYYuxVIplva1MnLmiwuPCsb76nUxn0nNa5Q' \
  -H 'accept: application/json'
```

#### Supported Providers

The `${provider}` parameter can take the following values based on your frontend platform.

| Platform | Provider Value |
|----------|----------------|
| Apple (any platform) | `apple` |
| Google Web | `google` |
| Google Android | `google_android` |
| Google iOS | `google_ios` |

This will register your user with jac cloud and sso platform and returns you the required user informations like name,email etc

#### Example Calls

```bash
# For Apple Sign-In
curl "${backendURL}/sso/apple/register/callback?id_token=${id_token}"

# For Google Web
curl "${backendURL}/sso/google/register/callback?id_token=${id_token}"

# For Google Android
curl "${backendURL}/sso/google_android/register/callback?id_token=${id_token}"

# For Google iOS
curl "${backendURL}/sso/google_ios/register/callback?id_token=${id_token}"
```
