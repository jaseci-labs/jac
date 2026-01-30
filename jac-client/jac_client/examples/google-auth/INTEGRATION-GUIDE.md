# Integrating jac-scale Backend SSO with jac-client Frontend

## Summary of Changes

This guide shows how to properly integrate the jac-scale backend SSO system with your jac-client frontend application.

## Key Concepts

### The Problem with Current Implementation

Your current `google-auth` example uses **client-only OAuth**:

- `@react-oauth/google` library handles OAuth in the browser
- JWT token from Google is decoded client-side with `jwtDecode`
- No backend verification or persistent user storage
- Security risk: Anyone can forge tokens since validation is client-only

### The Proper Solution with jac-scale

jac-scale provides a **complete backend SSO system**:

- Backend handles OAuth flow and token exchange with Google
- User information stored securely in database
- JWT tokens issued by your backend (not Google's)
- Frontend receives verified, backend-signed tokens
- Tokens can be validated on every API request

## Architecture Comparison

### ❌ Old: Client-Only OAuth

```
┌─────────┐          ┌────────┐
│ Browser │  OAuth   │ Google │
│ React   │<-------->│        │
└─────────┘          └────────┘
     │
     └─> Decode JWT client-side (insecure!)
```

### ✅ New: Backend SSO with jac-scale

```
┌─────────┐     ┌──────────┐     ┌────────┐
│ Browser │     │  Backend │     │ Google │
│ React   │     │ jac-scale│     │  OAuth │
└────┬────┘     └────┬─────┘     └───┬────┘
     │               │               │
     │ 1. Login      │               │
     ├──────────────>│               │
     │               │ 2. Redirect   │
     │               ├──────────────>│
     │               │               │
     │ 3. Callback   │               │
     │<──────────────┼───────────────┤
     │               │ 4. Validate   │
     │               │<──────────────┤
     │ 5. JWT Token  │               │
     │<──────────────┤               │
```

## Implementation Overview

### 1. Backend Setup (jac-scale)

The backend is already implemented in `jac-scale/jac_scale/`:

**Key Files:**

- `google_sso_provider.jac` - Google OAuth implementation
- `sso_provider.jac` - Abstract SSO interface
- `user_manager.jac` - User management with SSO support
- `serve.jac` - API server with SSO endpoints

**Endpoints Provided:**

- `GET /sso/google/login` - Initiate login
- `GET /sso/google/register` - Initiate registration
- `GET /sso/google/{operation}/callback` - Handle OAuth callbacks

### 2. Configuration (jac.toml)

```toml
[plugins.scale]

[plugins.scale.jwt]
secret = "${JWT_SECRET}"
algorithm = "HS256"
exp_delta_days = 7

[plugins.scale.sso]
host = "http://localhost:8000/sso"

[plugins.scale.sso.google]
client_id = "${GOOGLE_CLIENT_ID}"
client_secret = "${GOOGLE_CLIENT_SECRET}"
```

### 3. Frontend Integration

**New Files Created:**

1. `server.jac` - Backend server entry point
2. `custom_user_manager.jac` - Custom user manager for frontend redirects
3. `lib/auth-backend.cl.jac` - Backend-based auth provider
4. `pages/login-backend.cl.jac` - Login page using backend SSO
5. `pages/callback.cl.jac` - OAuth callback handler

**Key Changes:**

- Remove `@react-oauth/google` dependency
- Remove `jwt-decode` dependency
- Use backend redirect flow instead of client OAuth
- Store backend-issued JWT tokens
- Validate tokens with backend on protected routes

## Complete Flow

### Login Flow

1. **User clicks "Sign in with Google"**

   ```javascript
   // Frontend redirects to backend
   window.location.href = "/sso/google/login";
   ```

2. **Backend initiates OAuth**
   - jac-scale server receives request at `/sso/google/login`
   - Creates Google OAuth URL with proper callback
   - Redirects user to Google's authorization page

3. **User authorizes on Google**
   - User logs in to Google
   - User authorizes the application
   - Google redirects back to callback URL

4. **Backend handles callback**
   - Receives callback at `/sso/google/login/callback?code=...`
   - Exchanges authorization code for access token
   - Retrieves user info from Google (email, name, etc.)
   - Checks if user exists in database
   - Generates JWT token signed with backend secret

5. **Backend redirects to frontend**
   - Redirects to frontend callback page with token
   - `http://localhost:5173/auth/callback?token=JWT_TOKEN_HERE`

6. **Frontend stores token**
   ```javascript
   // Extract token from URL
   const token = searchParams.get("token");
   // Store in localStorage
   localStorage.setItem("auth_token", token);
   // Redirect to dashboard
   navigate("/dashboard");
   ```

### Protected Route Flow

1. **Frontend includes token in requests**

   ```javascript
   fetch("/api/some-endpoint", {
     headers: {
       Authorization: `Bearer ${token}`,
     },
   });
   ```

2. **Backend validates token**
   - jac-scale extracts JWT from Authorization header
   - Verifies signature with secret key
   - Checks expiration
   - Returns user info or 401 Unauthorized

## File Structure

```
google-auth/
├── server.jac                    # NEW: Backend server
├── custom_user_manager.jac       # NEW: Custom SSO handler
├── main.jac                      # MODIFIED: Use backend auth
├── jac.toml                      # MODIFIED: Add SSO config
├── .env.example                  # NEW: Environment template
├── README-BACKEND-SSO.md         # NEW: Setup instructions
│
├── lib/
│   ├── auth.cl.jac              # OLD: Client-only auth
│   └── auth-backend.cl.jac      # NEW: Backend-based auth
│
└── pages/
    ├── login.cl.jac             # OLD: Client-only login
    ├── login-backend.cl.jac     # NEW: Backend SSO login
    └── callback.cl.jac          # NEW: OAuth callback handler
```

## Migration Steps

### Step 1: Install jac-scale

```bash
cd /path/to/jaseci
pip install -e jac-scale/
```

### Step 2: Configure Google OAuth

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create OAuth credentials
3. Add redirect URIs:
   - `http://localhost:8000/sso/google/login/callback`
   - `http://localhost:8000/sso/google/register/callback`

### Step 3: Set Environment Variables

```bash
# Create .env file
cp .env.example .env

# Edit .env with your credentials
GOOGLE_CLIENT_ID=your_client_id
GOOGLE_CLIENT_SECRET=your_client_secret
JWT_SECRET=$(openssl rand -hex 32)

# Export variables
export $(cat .env | xargs)
```

### Step 4: Update jac.toml

Add jac-scale configuration (see Configuration section above)

### Step 5: Run Backend & Frontend

**Terminal 1 - Backend:**

```bash
cd jac-client/jac_client/examples/google-auth
jac run server.jac
# Server runs on http://localhost:8000
```

**Terminal 2 - Frontend:**

```bash
cd jac-client/jac_client/examples/google-auth
jac start
# Frontend runs on http://localhost:5173
```

### Step 6: Test the Flow

1. Open http://localhost:5173
2. Click "Login"
3. Click "Sign in with Google"
4. You'll be redirected to Google
5. Authorize the application
6. You'll be redirected back with a token
7. Access protected dashboard

## Benefits of Backend SSO

### Security

- ✅ OAuth tokens never exposed to client
- ✅ JWT signed with backend secret
- ✅ Token validation on every request
- ✅ Secure user session management

### Features

- ✅ Persistent user storage in database
- ✅ Multiple SSO providers (Google, Microsoft, GitHub)
- ✅ Traditional username/password login option
- ✅ Token refresh mechanism
- ✅ User profile management
- ✅ SSO account linking (link multiple providers)

### Developer Experience

- ✅ Centralized authentication logic
- ✅ Easy to add new SSO providers
- ✅ Consistent API for all auth methods
- ✅ Built-in token management
- ✅ Automatic token expiration handling

## Extending to Other Providers

jac-scale makes it easy to add more SSO providers:

### Add Microsoft SSO

1. **Create provider** (in jac-scale):

```jac
obj MicrosoftSSOProvider(SSOProvider) {
    async def initiate_auth(operation: str) -> Response {
        # Implementation
    }

    async def handle_callback(request: Request) -> SSOUserInfo {
        # Implementation
    }

    def get_platform_name() -> str {
        return "microsoft";
    }
}
```

2. **Register in UserManager**:

```jac
impl JacScaleUserManager.get_sso(platform: str, operation: str) {
    if platform == "microsoft" {
        return MicrosoftSSOProvider(...);
    }
    # ... existing Google logic
}
```

3. **Configure in jac.toml**:

```toml
[plugins.scale.sso.microsoft]
client_id = "${MICROSOFT_CLIENT_ID}"
client_secret = "${MICROSOFT_CLIENT_SECRET}"
```

4. **Use in frontend**:

```javascript
window.location.href = "/sso/microsoft/login";
```

## API Endpoints Reference

### SSO Endpoints (jac-scale)

| Method | Path                            | Description                |
| ------ | ------------------------------- | -------------------------- |
| GET    | `/sso/{platform}/login`         | Initiate login flow        |
| GET    | `/sso/{platform}/register`      | Initiate registration flow |
| GET    | `/sso/{platform}/{op}/callback` | OAuth callback handler     |

### User Management (jac-scale)

| Method | Path                    | Description                         |
| ------ | ----------------------- | ----------------------------------- |
| POST   | `/user/login`           | Traditional username/password login |
| POST   | `/user/register`        | Traditional registration            |
| POST   | `/user/refresh`         | Refresh JWT token                   |
| POST   | `/user/update_username` | Update username                     |
| POST   | `/user/update_password` | Update password                     |

### Example Request

```bash
# Login via SSO (browser redirect)
curl -L http://localhost:8000/sso/google/login

# Validate token
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     http://localhost:8000/api/some-protected-endpoint

# Refresh token
curl -X POST http://localhost:8000/user/refresh \
     -H "Content-Type: application/json" \
     -d '{"token": "YOUR_JWT_TOKEN"}'
```

## Troubleshooting

### Backend Issues

**"SSO_NOT_CONFIGURED" error**

- Check environment variables are exported
- Verify jac.toml configuration
- Ensure Google credentials are valid

**"Redirect URI mismatch"**

- Callback URLs must match exactly in Google Console
- Check port numbers (8000 for backend)

**"User table not found"**

- jac-scale creates tables automatically on first run
- Check database permissions
- Verify SQLite file location

### Frontend Issues

**Token not received**

- Check browser console for errors
- Verify backend is running on port 8000
- Check callback URL in custom_user_manager.jac

**CORS errors**

- Ensure backend allows frontend origin
- Check CORS middleware configuration
- Verify frontend port (default: 5173)

**Token validation fails**

- JWT secret must match between sessions
- Check token expiration (default: 7 days)
- Verify Authorization header format

## Production Considerations

### Security

1. **Use HTTPS everywhere**

   ```toml
   [plugins.scale.sso]
   host = "https://yourdomain.com/sso"
   ```

2. **Strong JWT secret**

   ```bash
   JWT_SECRET=$(openssl rand -hex 32)
   ```

3. **Disable insecure HTTP**
   ```jac
   GoogleSSOProvider(
       allow_insecure_http=False
   )
   ```

### Scalability

1. **Use PostgreSQL**

   ```toml
   [plugins.scale.database]
   type = "postgresql"
   url = "${DATABASE_URL}"
   ```

2. **Token expiration**

   ```toml
   [plugins.scale.jwt]
   exp_delta_days = 30  # Longer for production
   ```

3. **Rate limiting**
   - Implement rate limiting on SSO endpoints
   - Add CAPTCHA for registration
   - Monitor for abuse

### Monitoring

1. **Log SSO events**

   ```jac
   logger.info(f"SSO login: {email} via {platform}")
   ```

2. **Track failures**

   ```jac
   logger.error(f"SSO failed: {error} for {platform}")
   ```

3. **Monitor token usage**
   - Track token refresh rates
   - Alert on unusual patterns

## Additional Resources

- [jac-scale SSO Guide](../../../jac-scale/docs/sso-guide.md)
- [jac-scale Documentation](../../../jac-scale/README.md)
- [Google OAuth Documentation](https://developers.google.com/identity/protocols/oauth2)
- [JWT Best Practices](https://tools.ietf.org/html/rfc8725)

## Summary

The key insight is: **Don't handle OAuth in the frontend**. Use jac-scale's backend SSO system, which:

1. Handles OAuth flow securely server-side
2. Stores users in a database
3. Issues JWT tokens signed by your backend
4. Provides easy integration with any frontend
5. Supports multiple SSO providers
6. Includes full user management features

Your frontend's only job is:

- Redirect to backend SSO endpoint
- Receive and store JWT token
- Include token in API requests
- Handle token expiration

This architecture is secure, scalable, and follows industry best practices.
