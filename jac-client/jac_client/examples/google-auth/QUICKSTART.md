# Quick Start Guide - Backend SSO with jac-client

## What You Need

Your `main.jac` is now configured to use the backend SSO implementation! Here's how to run it:

## File Structure Overview

```
main.jac                       ✅ Updated to use backend auth
├── Uses: lib/auth-backend.cl.jac
├── Uses: pages/login-backend.cl.jac
├── Uses: pages/callback.cl.jac
└── Routes:
    ├── / (Home)
    ├── /login (Login with Google button)
    ├── /auth/callback (OAuth callback handler)
    └── /dashboard (Protected route)

server.jac                     ✅ Backend server
└── Provides: /sso/google/login, /sso/google/register

custom_user_manager.jac        ✅ Handles redirects to frontend
```

## Setup Steps

### 1. Configure Google OAuth

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create OAuth 2.0 credentials
3. Add authorized redirect URIs:
   ```
   http://localhost:8000/sso/google/login/callback
   http://localhost:8000/sso/google/register/callback
   ```
4. Copy Client ID and Client Secret

### 2. Set Environment Variables

```bash
# Create .env from example
cp .env.example .env

# Edit .env with your credentials
nano .env  # or use your favorite editor
```

Your `.env` should look like:

```env
GOOGLE_CLIENT_ID=123456789-abcdef.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-your-secret-here
JWT_SECRET=$(openssl rand -hex 32)
SSO_HOST=http://localhost:8000/sso
```

### 3. Export Environment Variables

```bash
export $(cat .env | xargs)
```

### 4. Update jac.toml

Make sure your `jac.toml` has:

```toml
[plugins.scale]

[plugins.scale.jwt]
secret = "${JWT_SECRET}"
algorithm = "HS256"
exp_delta_days = 7

[plugins.scale.sso]
host = "${SSO_HOST}"

[plugins.scale.sso.google]
client_id = "${GOOGLE_CLIENT_ID}"
client_secret = "${GOOGLE_CLIENT_SECRET}"
```

## Running the Application

You have two options:

### Option A: Separate Backend & Frontend (Recommended)

This is clearer for debugging and understanding the flow.

**Terminal 1 - Start Backend:**

```bash
jac run server.jac
```

You should see:

```
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000
```

**Terminal 2 - Start Frontend:**

```bash
jac start
```

You should see:

```
  ➜  Local:   http://localhost:5173/
  ➜  Network: use --host to expose
```

### Option B: Combined Server (Advanced)

You can configure jac-client to proxy requests to the backend, but Option A is simpler for this example.

## Testing the Flow

1. **Open Browser**: Go to http://localhost:5173

2. **Navigate to Login**: Click "Login" or go to http://localhost:5173/login

3. **Click "Sign in with Google"**:
   - You'll be redirected to `http://localhost:8000/sso/google/login`
   - Backend redirects you to Google
   - You authorize the app
   - Google redirects back to backend callback
   - Backend validates, creates/finds user, generates JWT
   - Backend redirects to `http://localhost:5173/auth/callback?token=...`

4. **Frontend Handles Token**:
   - `callback.cl.jac` extracts token from URL
   - Stores token in localStorage
   - Redirects to dashboard

5. **Access Protected Routes**:
   - Dashboard is now accessible
   - Token included in future API calls

## How main.jac Works

### 1. **AuthProvider Wraps Everything**

```jac
<AuthProvider>  # Manages user state & token
  <Router>
    {/* routes */}
  </Router>
</AuthProvider>
```

The `AuthProvider` from `lib/auth-backend.cl.jac`:

- Checks for stored token on mount
- Provides `handleLogin()` to redirect to backend
- Provides `handleLogout()` to clear token
- Manages user state

### 2. **Routes Configuration**

```jac
<Route path="/" element={<Home />} />
<Route path="/login" element={<Login />} />
<Route path="/auth/callback" element={<OAuthCallback />} />
<Route path="/dashboard" element={<Protected><Dashboard /></Protected>} />
```

- **/** - Home page (public)
- **/login** - Login page with "Sign in with Google" button
- **/auth/callback** - Handles OAuth redirect from backend
- **/dashboard** - Protected route (requires authentication)

### 3. **Login Flow**

```jac
# In pages/login-backend.cl.jac
def handleGoogleLogin() -> None {
    auth?.handleLogin('google');  # Redirects to /sso/google/login
}
```

This triggers the backend OAuth flow.

### 4. **Callback Handling**

```jac
# In pages/callback.cl.jac
useEffect(() => {
    token = searchParams.get('token');
    if token {
        localStorage.setItem('auth_token', token);
        navigate('/dashboard');
    }
}, [searchParams]);
```

Extracts token and stores it for future API calls.

### 5. **Protected Routes**

```jac
# In lib/protected-route.cl.jac
if not auth?.user {
    return <Navigate to="/login" replace />;
}
return props.children;
```

Redirects to login if not authenticated.

## Verification Checklist

✅ **Backend is running** (Terminal 1 shows Uvicorn server)
✅ **Frontend is running** (Terminal 2 shows Vite dev server)
✅ **Environment variables are set** (`echo $GOOGLE_CLIENT_ID`)
✅ **Google Console has correct redirect URIs**
✅ **jac.toml has SSO configuration**

## Troubleshooting

### "Cannot connect to backend"

- Check Terminal 1 - is backend running?
- Verify it's on port 8000: `curl http://localhost:8000/docs`

### "Redirect URI mismatch"

- Ensure Google Console has EXACT URLs:
  - `http://localhost:8000/sso/google/login/callback`
  - `http://localhost:8000/sso/google/register/callback`
- No trailing slashes!

### "SSO_NOT_CONFIGURED"

- Backend can't find Google credentials
- Check: `echo $GOOGLE_CLIENT_ID`
- Re-export: `export $(cat .env | xargs)`
- Restart backend (Terminal 1)

### "Module not found: pages.callback"

- The import path should match your file structure
- Current: `cl import from '.pages.callback' { OAuthCallback }`
- Check: `pages/callback.cl.jac` exists

### Token not being stored

- Check browser console (F12) for errors
- Verify `OAuthCallback` component is rendered
- Check URL has `?token=` parameter after Google login

## What Happens Behind the Scenes

### Backend (server.jac)

```jac
import from jac_scale.serve { JacAPIServer }
import from custom_user_manager { CustomUserManager }

# CustomUserManager extends jac-scale to redirect with token
server = JacAPIServer(user_manager=CustomUserManager());
server.start(dev=True);
```

Automatically provides:

- `GET /sso/google/login` - Initiates OAuth
- `GET /sso/google/login/callback` - Handles Google callback
- `POST /user/login` - Traditional login
- `POST /user/register` - Traditional registration
- All other jac-scale endpoints

### Custom User Manager

```jac
# In custom_user_manager.jac
async def sso_callback(...) -> Response {
    result = await super.sso_callback(...);
    if result.success {
        token = result.data.get('token');
        # Redirect to frontend with token
        return RedirectResponse(
            url=f"http://localhost:5173/auth/callback?token={token}"
        );
    }
}
```

This is the key modification that makes the backend SSO work with your React frontend.

## Next Steps

### Add More Features

1. **User Profile Page**

   ```jac
   <Route path="/profile" element={<Protected><Profile /></Protected>} />
   ```

2. **Logout Button**

   ```jac
   def handleLogout() -> None {
       auth?.handleLogout();
       navigate('/');
   }
   ```

3. **Token Refresh**
   ```jac
   # Already implemented in AuthProvider
   # Automatically refreshes expired tokens
   ```

### Add More SSO Providers

See [INTEGRATION-GUIDE.md](INTEGRATION-GUIDE.md#extending-to-other-providers) for how to add:

- Microsoft
- GitHub
- Custom SAML providers

### Deploy to Production

See [INTEGRATION-GUIDE.md](INTEGRATION-GUIDE.md#production-considerations) for:

- Using HTTPS
- PostgreSQL database
- Environment configuration
- Security hardening

## Summary

Your `main.jac` is now properly configured! Just:

1. **Set environment variables** (`export $(cat .env | xargs)`)
2. **Run backend** (`jac run server.jac`)
3. **Run frontend** (`jac start`)
4. **Test login** at http://localhost:5173/login

The backend handles all OAuth securely, and your React frontend just redirects users to the backend endpoints. 🚀
