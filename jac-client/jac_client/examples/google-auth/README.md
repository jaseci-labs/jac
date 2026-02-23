# Google OAuth Authentication with Jac-Client

A complete guide to implementing Google OAuth authentication in your Jac-Client application using jac-scale's built-in SSO support.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Backend Setup](#backend-setup)
- [Google Cloud Console Setup](#google-cloud-console-setup)
- [Environment Variables](#environment-variables)
- [Frontend Implementation](#frontend-implementation)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## Overview

This guide demonstrates how to:

- Configure jac-scale backend for Google OAuth
- Set up Google Cloud Console OAuth credentials
- Implement authentication flow in the frontend
- Handle protected routes and user sessions

**Authentication Flow:**

```
User clicks "Sign in with Google"
    ↓
Backend redirects to Google OAuth
    ↓
User authorizes on Google
    ↓
Google redirects to /sso/google/login/callback
    ↓
Backend exchanges code for token
    ↓
Backend redirects to /auth/callback?token=...
    ↓
Frontend stores token and navigates to dashboard
```

---

## Prerequisites

- Jac-Client project initialized
- Google Cloud account
- Basic understanding of OAuth 2.0

---

## Backend Setup

### 1. Configure `jac.toml`

Add the following configuration to your `jac.toml` file:

```toml
[project]
name = "your-app-name"
version = "1.0.0"
entry-point = "main.jac"

[serve]
base_route_app = "app"

# JWT Configuration for token generation
[plugins.scale]
[plugins.scale.jwt]
secret = "your_jwt_secret_key_change_in_production"
algorithm = "HS256"
exp_delta_days = 7  # Token expires in 7 days

# SSO Configuration
[plugins.scale.sso]
host = "http://localhost:8000/sso"  # Change to your domain in production
client_auth_callback_url = "http://localhost:8000/auth/callback"  # Redirect URL after OAuth

# Google OAuth Provider
[plugins.scale.sso.google]
client_id = "${GOOGLE_CLIENT_ID}"
client_secret = "${GOOGLE_CLIENT_SECRET}"
```

**Configuration Explained:**

- `jwt.secret`: Secret key for signing JWT tokens (change in production!)
- `jwt.algorithm`: Algorithm for JWT signing (HS256 recommended)
- `jwt.exp_delta_days`: How long tokens remain valid
- `sso.host`: Base URL for SSO endpoints
- `sso.client_auth_callback_url`: URL to redirect to after OAuth callback (with token or error params). If not set, returns JSON response.
- `sso.google.*`: Google OAuth credentials (loaded from environment variables)

---

## Google Cloud Console Setup

### 1. Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click **"Create Project"** or select existing project
3. Name your project (e.g., "My Jac App")

### 2. Enable Google+ API

1. Navigate to **APIs & Services** > **Library**
2. Search for **"Google+ API"**
3. Click **Enable**

### 3. Configure OAuth Consent Screen

1. Go to **APIs & Services** > **OAuth consent screen**
2. Choose **External** (for testing) or **Internal** (for organization)
3. Fill in required fields:
   - **App name**: Your application name
   - **User support email**: Your email
   - **Developer contact**: Your email
4. Click **Save and Continue**
5. **Scopes**: Add these scopes:
   - `email`
   - `profile`
   - `openid`
6. **Test users** (for External apps): Add your Gmail for testing
7. Click **Save and Continue**

### 4. Create OAuth 2.0 Credentials

1. Go to **APIs & Services** > **Credentials**
2. Click **Create Credentials** > **OAuth client ID**
3. Choose **Web application**
4. Configure:
   - **Name**: "Jac Client Web App"
   - **Authorized JavaScript origins**:

     ```
     http://localhost:8000
     ```

   - **Authorized redirect URIs**:

     ```
     http://localhost:8000/sso/google/login/callback
     http://localhost:8000/sso/google/register/callback
     ```

5. Click **Create**
6. **Copy** your Client ID and Client Secret (you'll need these!)

**Production Setup:**

- Add your production domain to authorized origins
- Add production callback URLs (e.g., `https://yourdomain.com/sso/google/login/callback`)

---

## Environment Variables

### 1. Create `.env` file

In your project root, create a `.env` file:

```bash
# Google OAuth Credentials
GOOGLE_CLIENT_ID="your-client-id-here.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET="your-client-secret-here"

# JWT Secret (change in production!)
JWT_SECRET="your-super-secret-key-change-me-in-production"
```

### 2. Add `.env` to `.gitignore`

**IMPORTANT**: Never commit credentials to version control!

```bash
echo ".env" >> .gitignore
```

### 3. Load Environment Variables

The jac-scale backend automatically loads environment variables referenced with `${VARIABLE_NAME}` syntax in `jac.toml`.

---

## Frontend Implementation

### Project Structure

```
your-app/
├── jac.toml
├── .env
├── main.jac
├── lib/
│   ├── auth.cl.jac              # Authentication context/provider
│   └── protected-route.cl.jac   # Protected route wrapper
├── pages/
│   ├── login.cl.jac             # Login page
│   ├── callback.cl.jac          # OAuth callback handler
│   ├── dashboard.cl.jac         # Protected dashboard
│   └── home.cl.jac              # Public home page
└── components/
    └── Button.cl.jac            # Reusable button component
```

### Key Implementation Files

See the example files in this directory for complete implementations:

- **`main.jac`** - Application entry point with routing
- **`lib/auth.cl.jac`** - Authentication provider with JWT validation
- **`lib/protected-route.cl.jac`** - Protected route wrapper component
- **`pages/login.cl.jac`** - Login page with Google sign-in button
- **`pages/callback.cl.jac`** - OAuth callback handler
- **`pages/dashboard.cl.jac`** - Protected dashboard page

### Important Notes

1. **Component Nesting**: Ensure Router wraps components using router hooks:

   ```jac
   <AuthProvider>
       <Router>
           {/* Components using Link, useNavigate, etc. */}
       </Router>
   </AuthProvider>
   ```

2. **Token Handling**: The callback component stores the token and reloads:

   ```jac
   localStorage.setItem('auth_token', token);
   window.location.href = '/dashboard';  // Full page reload
   ```

3. **Protected Routes**: Wrap protected pages with `<Protected>` component:

   ```jac
   <Route path="/dashboard" element={
       <Protected><Dashboard /></Protected>
   } />
   ```

---

## Testing

### 1. Start the Development Server

```bash
cd jac-client/jac_client/examples/google-auth
jac start main.jac
```

### 2. Test the Authentication Flow

1. **Open browser**: `http://localhost:8000`
2. **Navigate to login**: Go to `/login`
3. **Click "Sign in with Google"**
4. **Authorize**: Select your Google account
5. **Success**: Should redirect to dashboard with your email

### 3. Expected Console Output

```
OAuth Callback Location: {pathname: '/auth/callback', search: '?token=...'}
✅ Login successful: your-email@gmail.com
[Page reloads to /dashboard]
User authenticated: {name: 'your-email@gmail.com', email: 'your-email@gmail.com'}
DASHBOARD CTX: {user: {...}, token: '...', loading: false}
```

### 4. Test Protected Routes

1. **Logout**: Click logout button
2. **Try accessing dashboard**: Go to `/dashboard`
3. **Verify redirect**: Should redirect to `/login`

### 5. Test Token Persistence

1. **Login** with Google
2. **Refresh** the page
3. **Verify**: Should stay logged in (dashboard visible)

---

## Troubleshooting

### Issue: "SSO for platform 'google' is not configured"

**Solution:**

- Verify `.env` file exists with correct credentials
- Ensure environment variables are loaded
- Restart the server after adding `.env`

### Issue: "redirect_uri_mismatch"

**Solution:**

- Check Google Console authorized redirect URIs
- Must exactly match: `http://localhost:8000/sso/google/login/callback`
- No trailing slashes
- Ensure both login and register callbacks are added

### Issue: "User redirected back to login after OAuth"

**Solution:**

- Check browser console for errors
- Verify token is stored in localStorage (DevTools > Application > Local Storage)
- Ensure AuthProvider validates token on mount
- Make sure callback uses `window.location.href` for full page reload

### Issue: "Cannot destructure property 'basename'"

**Solution:**

- Ensure `<Router>` wraps all components using `<Link>` or router hooks
- Correct structure: `<AuthProvider><Router>...</Router></AuthProvider>`
- Move any navigation menus inside `<Router>`

### Issue: "Authentication failed: (invalid_grant) Bad Request"

**Solution:**

- Client secret may be incorrect
- Authorization code may have expired (only valid for ~60 seconds)
- Check that callback URL in Google Console matches exactly
- Ensure clock synchronization on server

### Issue: Token expires too quickly

**Solution:**

- Increase `exp_delta_days` in `jac.toml`:

  ```toml
  [plugins.scale.jwt]
  exp_delta_days = 30  # 30 days instead of 7
  ```

---

## Security Best Practices

1. **Never commit credentials**:
   - Keep `.env` in `.gitignore`
   - Use environment variables in production

2. **Change JWT secret in production**:

   ```toml
   secret = "${JWT_SECRET}"  # Load from secure environment
   ```

3. **Use HTTPS in production**:
   - Update callback URLs to `https://`
   - Update `sso.host` to your domain

4. **Validate tokens**:
   - Backend creates and signs tokens
   - Frontend validates expiration
   - Never trust client-only validation

5. **Token storage**:
   - localStorage is acceptable for demo
   - Consider httpOnly cookies for production
   - Implement token refresh for long sessions

---

## Production Deployment

### 1. Update Google Console

Add production URLs:

- **Authorized origins**: `https://yourdomain.com`
- **Redirect URIs**:
  - `https://yourdomain.com/sso/google/login/callback`
  - `https://yourdomain.com/sso/google/register/callback`

### 2. Update `jac.toml`

```toml
[plugins.scale.sso]
host = "https://yourdomain.com/sso"
```

### 3. Set Environment Variables

On your production server:

```bash
export GOOGLE_CLIENT_ID="your-production-client-id"
export GOOGLE_CLIENT_SECRET="your-production-secret"
export JWT_SECRET="your-strong-secret-key"
```

### 4. Deploy

Follow your hosting provider's deployment process.

---

## Architecture Overview

### Backend (jac-scale)

1. **SSO Endpoints**:
   - `/sso/google/login` - Initiates OAuth flow
   - `/sso/google/login/callback` - Handles Google redirect
   - `/sso/google/register` - Registration flow
   - `/sso/google/register/callback` - Registration callback

2. **Token Management**:
   - Creates JWT tokens after successful OAuth
   - Validates user existence (login) or creates user (register)
   - Redirects to frontend with token

### Frontend (jac-client)

1. **Routes**:
   - `/` - Home page
   - `/login` - Login page with Google button
   - `/auth/callback` - Handles token from backend redirect
   - `/dashboard` - Protected dashboard page

2. **State Management**:
   - `AuthProvider` - Manages authentication state
   - `Protected` - Route wrapper for auth-required pages
   - localStorage - Token persistence

---

## Additional Resources

- [Google OAuth 2.0 Documentation](https://developers.google.com/identity/protocols/oauth2)
- [Jac Documentation](https://www.jac-lang.org/)
- [JWT Best Practices](https://tools.ietf.org/html/rfc8725)

---

## License

This example is provided as-is for educational purposes.

---

**🎉 Congratulations!** You've successfully implemented Google OAuth authentication with Jac-Client!

For questions or issues, please refer to the Jac community resources or open an issue on GitHub.
