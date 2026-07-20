# Scale -- HTTP API & Walkers

> Part of the [Scale subsystem](jac-scale.md).

## Starting a Server

### Basic Server

!!! note
    `main.jac` is the default entry point. If your entry point has a different name (e.g., `app.jac`), pass it explicitly: `jac start app.jac`.

```bash
jac start
```

### Server Options

| Option | Description | Default |
|--------|-------------|---------|
| `--port` `-p` | Server port (auto-fallback if in use) | 8000 |
| `--main` `-m` | Treat as `__main__` | false |
| `--faux` `-f` | Print generated API docs only (no server) | false |
| `--dev` `-d` | Enable HMR (Hot Module Replacement) mode | false |
| `--api_port` `-a` | Separate API port for HMR mode (0=same as port) | 0 |
| `--no-client` `-n` | Skip client bundling/serving (API only) | false |
| `--profile` | Configuration profile to load (e.g. prod, staging) | - |
| `--client` | Client build target for dev server (web, desktop, pwa) | - |
| `--scale` | Deploy to a target platform instead of running locally | false |
| `--experimental` `-e` | Use experimental mode (install from repo instead of PyPI) | false |
| `--target` | Deployment target (kubernetes, aws, gcp) | kubernetes |
| `--enable-tls` | Enable HTTPS via Let's Encrypt (run after pointing your domain CNAME to the NLB) | false |
| `--dry-run` | Print the manifests that would be applied; change nothing | false |
| `--show-yaml` | With `--dry-run`: dump the raw YAML stream | false |

### Examples

```bash
# Custom port
jac start --port 3000

# Development with HMR (client framework built into jaclang core)
jac start --dev

# API only -- skip client bundling
jac start --dev --no-client

# Preview generated API endpoints without starting
jac start --faux

# Production with profile
jac start --port 8000 --profile prod
```

### Default Persistence

When running locally (without `--scale`), Jac uses **SQLite** for graph persistence by default. You'll see `"Using SQLite for persistence"` in the server output. No external database setup is required for development.

When `MONGODB_URI` is set (or `--scale` provisions Mongo on Kubernetes), persistence flips to `MongoBackend`. The MongoDB backend has full Layer 1+2+3 schema-migration support: every persisted document is stamped with `arch_module`, `arch_type`, `fingerprint`, and `format_version`; documents that can't be deserialized (un-resolvable archetype class, corrupt data, deserialize exception) are moved to a `<collection>_quarantine` companion collection instead of being silently dropped; and DB-resident class-rename aliases live in `<collection>_aliases` and are merged into the in-process Serializer registry on every connect. The same `jac db inspect / quarantine / alias / recover` operator commands work against Mongo deployments unchanged -- see [CLI → Database Operations](../cli/index.md#database-operations) and [Persistence & Schema Migration](../persistence.md) for the full model.

```bash
# Inspect a live Mongo-backed deployment.
jac db inspect --app app.jac

# Operator rescue: register a class-rename alias in production without redeploying.
jac db alias add "old.module.LegacyName" "new.module.NewName" --app app.jac
jac db recover-all --app app.jac
```

### Server Configuration

```toml
[scale.server]
port = 8000
host = "0.0.0.0"
docs_enabled = true                  # Enable /docs, /redoc, /openapi.json (default: true)
suppress_health_check_logs = false   # Suppress health-check access log entries (default: false)
```

Set `docs_enabled = false` to disable Swagger UI, ReDoc, and the OpenAPI JSON endpoint in production.

Set `suppress_health_check_logs = true` to suppress access log entries for health-check and documentation endpoints (`/`, `/docs`, `/openapi.json`, `/health`, `/healthz`, `/healthz/ready`, `/healthz/live`) from CLI output and Kubernetes pod logs. Useful for reducing log noise in production.

### CORS Configuration

In single-process `jac start` mode the FastAPI app installs a permissive
CORS middleware (`allow_origins=['*']`, all methods/headers); there is
no `[scale.cors]` knob to tune it.

In **microservice mode** (`[scale.microservices] enabled = true`),
the gateway exposes a configurable CORS section:

```toml
[scale.microservices.cors]
allow_origins = ["https://example.com"]
allow_methods = ["GET", "POST", "PUT", "DELETE"]
allow_headers = ["*"]
```

Defaults are open (`allow_origins = ["*"]`); set `allow_origins = []` to
disable. Additional CORS keys (`allow_credentials`, `expose_headers`,
`max_age`) are recognised under the same section.

---

## API Endpoints

### Automatic Endpoint Generation

Each walker becomes an API endpoint:

```jac
walker get_users {
    can fetch with Root entry {
        report [];
    }
}
```

Becomes: `POST /walker/get_users`

### Request Format

Walker parameters become request body:

```jac
walker search {
    has query: str;
    has limit: int = 10;
}
```

```bash
curl -X POST http://localhost:8000/walker/search \
  -H "Content-Type: application/json" \
  -d '{"query": "hello", "limit": 20}'
```

### Response Format

Walker `report` values become the response.

---

## Middleware Walkers

Walkers prefixed with `_` act as middleware hooks that run before or around normal request processing.

### Request Logging

```jac
walker _before_request {
    has request: dict;

    can log with Root entry {
        print(f"Request: {self.request['method']} {self.request['path']}");
    }
}
```

### Authentication Middleware

```jac
walker _authenticate {
    has headers: dict;

    can check with Root entry {
        token = self.headers.get("Authorization", "");

        if not token.startswith("Bearer ") {
            report {"error": "Unauthorized", "status": 401};
            return;
        }

        # Validate token...
        report {"authenticated": True};
    }
}
```

!!! tip "Middleware vs Built-in Auth"
    The `_authenticate` middleware pattern gives you custom authentication logic. For standard JWT authentication, use jac-scale's built-in auth endpoints (`/user/register`, `/user/login`) instead -- see [Authentication](#authentication) below.

---

## @restspec Decorator

The `@restspec` decorator customizes how walkers and functions are exposed as REST API endpoints.

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `method` | `HTTPMethod` | `POST` | HTTP method for the endpoint |
| `path` | `str` | `""` (auto-generated) | Custom URL path for the endpoint |
| `protocol` | `APIProtocol` | `APIProtocol.HTTP` | Protocol for the endpoint (`HTTP`, `WEBHOOK`, or `WEBSOCKET`) |
| `broadcast` | `bool` | `False` | Broadcast responses to all connected WebSocket clients (only valid with `WEBSOCKET` protocol) |

> **Note:** `APIProtocol` and `restspec` are builtins and do not require an import statement. `HTTPMethod` must be imported with `import from http { HTTPMethod }`.

### Custom HTTP Method

By default, walkers are exposed as `POST` endpoints. Use `@restspec` to change this:

```jac
import from http { HTTPMethod }

@restspec(method=HTTPMethod.GET)
walker :pub get_users {
    can fetch with Root entry {
        report [];
    }
}
```

This walker is now accessible at `GET /walker/get_users` instead of `POST`.

### Custom Path

Override the auto-generated path:

```jac
@restspec(method=HTTPMethod.GET, path="/custom/users")
walker :pub list_users {
    can fetch with Root entry {
        report [];
    }
}
```

Accessible at `GET /custom/users`.

### Path Parameters

Define path parameters using `{param_name}` syntax:

```jac
import from http { HTTPMethod }

@restspec(method=HTTPMethod.GET, path="/items/{item_id}")
walker :pub get_item {
    has item_id: str;
    can fetch with Root entry { report {"item_id": self.item_id}; }
}

@restspec(method=HTTPMethod.GET, path="/users/{user_id}/orders")
walker :pub get_user_orders {
    has user_id: str;          # Path parameter
    has status: str = "all";   # Query parameter
    can fetch with Root entry { report {"user_id": self.user_id, "status": self.status}; }
}
```

Parameters are classified as: **path** (matches `{name}` in path) → **file** (`UploadFile` type) → **query** (GET) → **body** (other methods).

### Functions

`@restspec` also works on standalone functions:

```jac
@restspec(method=HTTPMethod.GET)
def :pub health_check() -> dict {
    return {"status": "healthy"};
}

@restspec(method=HTTPMethod.GET, path="/custom/status")
def :pub app_status() -> dict {
    return {"status": "running", "version": "1.0.0"};
}
```

### Webhook Mode

See the [Webhooks](#webhooks) section below.

---

## Authentication

jac-scale uses an **identity-based authentication system**. Each user can sign in through multiple identities (username, email, or an SSO provider like Google or GitHub), and all of them resolve to the same account.

### Identity Model

A user document has this shape:

```
user_id        UUID (primary key)
status         "active" | "disabled"
role           "admin" | "system" | "user"
identities     [{type, value_raw, value_normalized, verified, is_recovery}, ...]
credentials    [{type, password_hash}, ...]
root_id        hex ID of the user's Jac graph root node
profile        {firstname?, lastname?, ..., sso?: {<platform>: {...}}}
created_at     ISO 8601 timestamp
updated_at     ISO 8601 timestamp
```

**Example (sanitized):**

```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "active",
  "role": "user",
  "identities": [
    {
      "type": "email",
      "value_raw": "user@example.com",
      "value_normalized": "user@example.com",
      "verified": false,
      "is_recovery": true
    },
    {
      "type": "sso",
      "provider": "google",
      "external_id": "<google-numeric-id>",
      "verified": true,
      "linked_at": "2025-01-15T10:30:00.000000+00:00"
    }
  ],
  "credentials": [
    {"type": "password", "password_hash": "<bcrypt-hash>"}
  ],
  "root_id": "<32-hex-chars>",
  "profile": {
    "firstname": "Alice",
    "lastname": "Doe",
    "sso": {
      "google": {
        "display_name": "Alice Doe",
        "first_name": "Alice",
        "last_name": "Doe",
        "picture": "<google-cdn-picture-url>"
      }
    }
  },
  "created_at": "2025-01-15T10:30:00.000000+00:00",
  "updated_at": "2025-01-15T10:30:00.000000+00:00"
}
```

**Identity types:**

| Type | Description | Notes |
|------|-------------|-------|
| `username` | A unique username | Always verified on creation |
| `email` | An email address | Marked as recovery identity by default |
| `sso` | SSO provider link | Added automatically on SSO login; includes `provider` and `external_id` fields |

A user can have at most **one** identity of each non-SSO type (one username, one email). All identity values are normalized (lowercased, stripped) before storage and lookup, preventing case-sensitivity duplicates.

**Credential types:**

| Type | Description |
|------|-------------|
| `password` | Bcrypt-hashed password |

Passwords are hashed with [bcrypt](https://en.wikipedia.org/wiki/Bcrypt) (random salt per password). Plain-text passwords never leave the request handler.

### Storage Backends

The identity storage layer is backend-agnostic. jac-scale automatically selects the backend based on your database configuration:

- **SQLite** (default) -- used when no `mongodb_uri` is configured. User data is stored in `.jac/data/users.db` relative to your project root using SQLAlchemy. Good for development and single-instance deployments.
- **MongoDB** -- used when `mongodb_uri` is set (via `jac.toml` or `MONGODB_URI` environment variable). User data is stored in the `users` collection of the `jac_db` database. Required for multi-instance production deployments.

Both backends implement the same `IdentityStorage` interface. Application code (endpoints, walkers, middleware) is completely unaware of which backend is in use.

```toml
# jac.toml -- use MongoDB
[scale.database]
mongodb_uri = "mongodb://localhost:27017"
```

```bash
# Or via environment variable
export MONGODB_URI="mongodb://localhost:27017"
```

When no MongoDB URI is configured, SQLite is used automatically with no additional setup.

### User Registration

```bash
curl -X POST http://localhost:8000/user/register \
  -H "Content-Type: application/json" \
  -d '{
    "identities": [
      {"type": "username", "value": "myuser"},
      {"type": "email", "value": "user@example.com"}
    ],
    "credential": {"type": "password", "password": "secret"},
    "profile": {"firstname": "Alice", "lastname": "Doe"}
  }'
```

Returns on success (HTTP 201):

```json
{
  "ok": true,
  "data": {
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "message": "User registered successfully"
  }
}
```

Registration does **not** return a token. Use `/user/login` after registration to authenticate.

**Validation rules:**

- At least one identity is required
- Only `username` and `email` types are accepted
- No duplicate identity types (e.g., two usernames)
- Identity values must be unique across all users (checked after normalization)
- Credential type must be `password` with a non-empty password

**Optional `profile` field** -- attach arbitrary fields like `firstname`, `lastname`, `address`, `postcode`. Bounded for safety:

| Limit | Value |
|---|---|
| Max keys | 20 |
| Max key length | 64 |
| Max value length | 1024 chars |
| Max total size (JSON) | 8192 bytes |
| Allowed value types | `str`, `int`, `float`, `bool` |
| Key pattern | `^[a-zA-Z][a-zA-Z0-9_]{0,63}$` |

The key pattern blocks MongoDB operator injection (`$where`), dot-path traversal, and JS prototype pollution (`__proto__`). Profile is stored under the `profile` sub-document, never spread into the user-doc root, so a profile key cannot collide with `role` / `user_id` / etc.

### User Login

Log in with **any** identity (username or email) and a password:

```bash
curl -X POST http://localhost:8000/user/login \
  -H "Content-Type: application/json" \
  -d '{
    "identity": {"type": "username", "value": "myuser"},
    "credential": {"type": "password", "password": "secret"}
  }'
```

Returns on success (HTTP 200):

```json
{
  "ok": true,
  "data": {
    "user_id": "550e8400-...",
    "token": "eyJ...",
    "root_id": "a1b2c3d4...",
    "role": "user"
  }
}
```

The same user can log in with their email instead:

```bash
curl -X POST http://localhost:8000/user/login \
  -H "Content-Type: application/json" \
  -d '{
    "identity": {"type": "email", "value": "user@example.com"},
    "credential": {"type": "password", "password": "secret"}
  }'
```

### Authenticated Requests

```bash
curl -X POST http://localhost:8000/walker/my_walker \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### Token Refresh

Refresh a JWT token before it expires to get a new token with a fresh expiration window:

```bash
curl -X POST http://localhost:8000/user/refresh-token \
  -H "Content-Type: application/json" \
  -d '{"token": "eyJ..."}'
```

The `token` value can optionally include the `Bearer` prefix (it will be stripped automatically).

Returns on success:

```json
{
  "ok": true,
  "data": {
    "token": "eyJ...(new token)...",
    "message": "Token refreshed successfully"
  }
}
```

Returns HTTP 401 if the token is invalid or expired.

### Password Update

Update the authenticated user's password. Requires the current password for verification:

```bash
curl -X PUT http://localhost:8000/user/password \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "current_password": "old_secret",
    "new_password": "new_secret"
  }'
```

Returns on success:

```json
{
  "ok": true,
  "data": {
    "user_id": "550e8400-...",
    "message": "Password updated successfully"
  }
}
```

Returns HTTP 400 if the current password is incorrect or the new password is empty.

### JWT Configuration

JWT tokens use `user_id` (UUID) as the primary claim, not the username. This means users can change their username or email without invalidating existing tokens.

Configure JWT via `jac.toml` or environment variables:

```toml
[scale.jwt]
secret = "your-secret-key-here"
algorithm = "HS256"
exp_delta_days = 7
```

| Variable | `jac.toml` key | Description | Default |
|----------|---------------|-------------|---------|
| `JWT_SECRET` | `secret` | Secret key for JWT signing | `supersecretkey_for_testing_only!` |
| `JWT_ALGORITHM` | `algorithm` | JWT signing algorithm | `HS256` |
| `JWT_EXP_DELTA_DAYS` | `exp_delta_days` | Token expiration in days | `7` |

!!! warning "Production: change the JWT secret"
    The default JWT secret is for development only. In production, set a long, random secret via environment variable or `jac.toml`. Anyone who knows the secret can forge valid tokens for any user.

**JWT claims:**

| Claim | Description |
|-------|-------------|
| `user_id` | UUID of the authenticated user |
| `role` | User role (`admin`, `system`, or `user`) |
| `exp` | Expiration timestamp |
| `iat` | Issued-at timestamp |

**Current limitations:**

- No token blacklist or revocation -- tokens remain valid until they expire
- No refresh token rotation -- the refresh endpoint issues a new token but does not invalidate the old one

### Roles

jac-scale has three built-in roles:

| Role | Value | Description |
|------|-------|-------------|
| Admin | `admin` | Full administrative access, including the admin portal |
| System | `system` | Internal system account (cannot be deleted) |
| User | `user` | Standard user (default for new registrations) |

Roles are stored in the user document and included in JWT claims. The admin user is bootstrapped automatically on first server start (see [Admin Portal](#admin-portal) for configuration).

**Protected accounts** that cannot be deleted:

- The bootstrap admin (fixed UUID `00000000-0000-0000-0000-000000000000`)
- System accounts (role `system`)
- The guest account (identity `__guest__`)

The guest account's root is the deployment's public graph - every unauthenticated request runs on it, and Jac code addresses it from any request as `root.shared` (see [The Shared Root](../language/osp.md#6-the-shared-root-rootshared)).

Roles are managed via the admin portal API or programmatically through the `UserManager`:

```bash
# Set user role via admin API
curl -X PUT http://localhost:8000/admin/users/{username} \
  -H "Authorization: Bearer <admin_token>" \
  -H "Content-Type: application/json" \
  -d '{"role": "admin"}'
```

### SSO (Single Sign-On)

jac-scale supports SSO with **Google**, **Apple**, and **GitHub**. SSO accounts are stored as identities within the user document (type `sso` with a `provider` field), not in a separate collection.

**How SSO login works:**

1. User is redirected to the provider's login page
2. Provider calls back with an authorization code
3. jac-scale exchanges the code for user info (email, external ID, plus optional `display_name`, `first_name`, `last_name`, `picture`)
4. If a user with that email exists, the SSO identity is linked and a JWT is returned
5. If no user exists, a new account is created with a verified email identity, the SSO identity is linked, and a JWT is returned

**Profile population.** The optional fields the provider returns (`display_name`, `first_name`, `last_name`, `picture`) are written to `profile.sso.<platform>` on the user record. They are refreshed from the latest provider data on every SSO login, so display names and avatar URLs stay current. Developer-set fields outside the `sso` namespace (e.g. `profile.firstname` set during `/user/register`) are never overwritten by the SSO refresh.

**Configuration via `jac.toml`:**

```toml
[scale.sso]
host = "http://localhost:8000"  # Your server's public URL
client_auth_callback_url = ""   # Optional: redirect to frontend after SSO

[scale.sso.google]
client_id = "your-google-client-id"
client_secret = "your-google-client-secret"

[scale.sso.apple]
client_id = "your-apple-client-id"
client_secret = "your-apple-client-secret"

[scale.sso.github]
client_id = "your-github-client-id"
client_secret = "your-github-client-secret"
```

Only providers with both `client_id` and `client_secret` configured are enabled. Unconfigured providers return HTTP 501 with a descriptive message.

**SSO Endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| GET | `/sso/{platform}/login` | Redirect to provider login page |
| GET | `/sso/{platform}/register` | Redirect to provider registration |
| GET | `/sso/{platform}/callback` | OAuth callback handler (GET) |
| POST | `/sso/{platform}/callback` | OAuth callback handler (POST, for Apple Sign In) |

Where `{platform}` is `google`, `apple`, or `github`.

**Frontend Callback Redirect:**

For browser-based OAuth flows, configure `client_auth_callback_url` in `jac.toml` to redirect the SSO callback to your frontend application instead of returning JSON:

```toml
[scale.sso]
client_auth_callback_url = "http://localhost:3000/auth/callback"
```

When set, the callback endpoint redirects to the configured URL with query parameters:

- On success: `{client_auth_callback_url}?token={jwt_token}`
- On failure: `{client_auth_callback_url}?error={error_code}&message={error_message}`

**SSO Account Linking/Unlinking:**

SSO accounts can be linked and unlinked programmatically. An SSO identity is automatically linked when a user logs in via SSO. To unlink, use the admin portal API or the `UserManager.unlink_sso_account()` method. Unlinking removes the SSO identity from the user's identity array but does not delete the user account.

**Example:**

```bash
# Redirect user to Google login
curl -L http://localhost:8000/sso/google/login

# Redirect user to GitHub login
curl -L http://localhost:8000/sso/github/login
```

### Legacy User Migration

If you are upgrading from an older version of jac-scale that used flat username/password user documents, the MongoDB backend automatically migrates legacy users on server startup. This migration:

1. Converts flat `username`/`email`/`password_hash` fields into the identity + credential array format
2. **Progressively rehashes** old SHA-256 passwords to bcrypt on the next successful login (no user action required)
3. Handles **case collisions** -- if normalization causes two legacy usernames to collide, the duplicate is marked as `disabled`
4. Preserves existing `root_id`, `role`, and other fields

The migration runs once during `UserManager` initialization and is idempotent. SQLite deployments do not need migration since they use the new format from the start.

!!! note
    The legacy SHA-256 migration code is marked as removable. Once all users have logged in at least once (triggering the bcrypt rehash), the migration path can be safely removed in a future release.

### Get Current User

Fetch the authenticated user's profile, identities, role, and metadata. Credentials are never returned.

```bash
curl http://localhost:8000/user/me \
  -H "Authorization: Bearer <token>"
```

Returns (HTTP 200):

```json
{
  "ok": true,
  "data": {
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "role": "user",
    "status": "active",
    "identities": [
      {
        "type": "email",
        "value": "user@example.com",
        "verified": false,
        "is_recovery": true
      },
      {
        "type": "sso",
        "provider": "google",
        "verified": true,
        "is_recovery": false
      }
    ],
    "profile": {
      "firstname": "Alice",
      "lastname": "Doe",
      "sso": {
        "google": {
          "display_name": "Alice Doe",
          "first_name": "Alice",
          "last_name": "Doe",
          "picture": "<google-cdn-picture-url>"
        }
      }
    },
    "created_at": "2025-01-15T10:30:00.000000+00:00",
    "updated_at": "2025-01-15T10:30:00.000000+00:00"
  }
}
```

The response strips internal fields (`credentials`, `password_hash`, `value_normalized`, identity `external_id`, `root_id`). For SSO identities, the `provider` is exposed instead of the user-supplied `value`. Use `profile.sso.<platform>.picture` to render an avatar in your UI.

Returns `401 UNAUTHORIZED` for a missing or expired token, `404 NOT_FOUND` if the user has been deleted but the token is still valid.

### Identity Management & Password Reset

In addition to the static identities supplied at registration, users can attach more identities (e.g. add an email to a username-registered account), verify them via emailed links, and reset their password through a single-use token. All four endpoints share the same `Emailer` plug-in (see [Emailer](#emailer)); if no emailer is configured, identity additions still work for non-email types and password reset is disabled.

**Tokens are:**

- **Random** 32-byte URL-safe strings issued per request.
- **SHA256-hashed at rest** so the raw token never lives in the database.
- **Single-use**: consumed on first successful redeem, all other outstanding reset tokens for the same user are revoked on a successful password reset.
- **TTL-bounded**: defaults are 24h for verify, 30min for reset; both configurable.
- Stored in MongoDB with a TTL index when MongoDB is configured, in-process otherwise.

Configure TTLs and the URLs the emails should point at:

```toml
[scale.auth]
verify_token_ttl_seconds = 86400    # 24h
reset_token_ttl_seconds  = 1800     # 30min
verify_url_template      = "https://app.example.com/verify?token={token}"
reset_url_template       = "https://app.example.com/reset?token={token}"
```

The `{token}` placeholder in each template is replaced with the raw token before the email is sent. Leave a template empty to receive the bare token in the email body (useful in tests/dev).

#### Add Identity

Attach a new identity to the authenticated user. **This endpoint never sends mail** -- it just adds the identity (email identities are stored as `verified=false`). To dispatch a verification email afterwards, call `/user/send-verification`.

```bash
curl -X POST http://localhost:8000/user/add-identity \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "identity": {"type": "email", "value": "alice@example.com"},
    "is_recovery": true
  }'
```

Returns HTTP 200:

```json
{
  "ok": true,
  "data": {"status": "added", "verified": false},
  "meta": {"extra": {"http_status": 200}}
}
```

Errors: `401 UNAUTHORIZED`, `409 IDENTITY_TAKEN`, `404 NOT_FOUND`.

#### Send Verification

Issue a verification token for an email identity on the authenticated user and deliver it via the configured emailer. Idempotent: returns `already_verified` if the identity is already verified. Calling it again on an unverified identity revokes prior outstanding verification tokens for the user and issues a fresh one (clean retry/resend).

```bash
curl -X POST http://localhost:8000/user/send-verification \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"identity": {"type": "email", "value": "alice@example.com"}}'
```

Returns HTTP 202 (email queued):

```json
{
  "ok": true,
  "data": {"status": "pending_verification", "email_sent": true},
  "meta": {"extra": {"http_status": 202}}
}
```

Returns HTTP 200 when the identity is already verified:

```json
{
  "ok": true,
  "data": {"status": "already_verified"},
  "meta": {"extra": {"http_status": 200}}
}
```

Errors: `400 VALIDATION_ERROR` (non-email identity or missing value), `401 UNAUTHORIZED`, `404 NOT_FOUND` (identity is not on the current user), `503 EMAIL_DISABLED` (no emailer configured).

#### Verify Identity

Consume the verification token delivered in the email. No Bearer token required; the verification token _is_ the credential.

```bash
curl -X POST http://localhost:8000/user/verify-identity \
  -H "Content-Type: application/json" \
  -d '{"token": "<verification-token-from-email>"}'
```

Returns HTTP 200:

```json
{
  "ok": true,
  "data": {"status": "verified", "identity": "alice@example.com"},
  "meta": {"extra": {"http_status": 200}}
}
```

Errors: `400 INVALID_TOKEN` (expired, already-consumed, or unknown).

#### Forgot Password

Issue a one-time reset token to the user's verified recovery email. **Always returns HTTP 200** regardless of whether the account exists, to avoid leaking account existence to a probing attacker.

```bash
curl -X POST http://localhost:8000/user/forgot-password \
  -H "Content-Type: application/json" \
  -d '{"identity": {"type": "email", "value": "alice@example.com"}}'
```

Always returns:

```json
{
  "ok": true,
  "data": {
    "status": "ok",
    "message": "If that account exists, a reset link has been sent."
  },
  "meta": {"extra": {"http_status": 200}}
}
```

#### Reset Password

Consume the reset token (delivered to the recovery email) and set a new password. Other outstanding reset tokens for the same user are revoked on success.

```bash
curl -X POST http://localhost:8000/user/reset-password \
  -H "Content-Type: application/json" \
  -d '{
    "token": "<reset-token-from-email>",
    "new_password": "newSecret123"
  }'
```

Returns HTTP 200:

```json
{
  "ok": true,
  "data": {"status": "password_reset"},
  "meta": {"extra": {"http_status": 200}}
}
```

Errors: `400 INVALID_TOKEN`.

### Auth Endpoint Summary

| Method | Path | Auth Required | Description |
|--------|------|--------------|-------------|
| POST | `/user/register` | No | Create a new user |
| POST | `/user/login` | No | Authenticate and get JWT |
| POST | `/user/refresh-token` | No (token in body) | Refresh an existing JWT |
| GET | `/user/me` | Yes (Bearer) | Get the authenticated user's profile |
| PUT | `/user/password` | Yes (Bearer) | Update password |
| POST | `/user/add-identity` | Yes (Bearer) | Attach an email/username identity to the current user (no email sent) |
| POST | `/user/send-verification` | Yes (Bearer) | Dispatch a verification email for an unverified email identity |
| POST | `/user/verify-identity` | No (token in body) | Confirm an email identity via the token sent by email |
| POST | `/user/forgot-password` | No | Start the password-reset flow (always returns 200) |
| POST | `/user/reset-password` | No (token in body) | Consume a reset token and set a new password |
| GET | `/sso/{platform}/{operation}` | No | Initiate SSO flow |
| GET/POST | `/sso/{platform}/callback` | No | SSO callback handler |
| POST | `/api-key/create` | Yes (Bearer) | Create an API key |
| GET | `/api-key/list` | Yes (Bearer) | List API keys |
| DELETE | `/api-key/{api_key_id}` | Yes (Bearer) | Revoke an API key |

---

## Emailer

jac-scale's `Emailer` is a thin abstraction (`jaclang.scale.emailer.emailer.Emailer`) used by the framework to send verification and password-reset emails. It ships with a built-in SMTP implementation and accepts any user-supplied subclass via `jac.toml` -- no jac-scale code changes required.

### Configuration

```toml
[scale.emailer]
provider     = "smtp"                   # 'smtp', a registered short name, or 'pkg.module:ClassName'
from_address = "no-reply@example.com"
enabled      = true                     # set false to disable email features without removing config
```

| Key | Description | Default |
|-----|-------------|---------|
| `provider` | Resolution token. `"smtp"` selects the built-in SMTPEmailer, any other registered short name selects a class registered via `emailer_factory.register()`, and `"pkg.module:ClassName"` is dynamically imported. Empty means email is disabled. | `""` (disabled) |
| `from_address` | Default `From:` address used when a handler doesn't override `from_addr`. | `""` |
| `enabled` | Soft kill-switch; the framework treats the emailer as disabled when `false`. | `true` |

### Resolution Order

The factory resolves `provider` in this order:

1. `"smtp"` → built-in `SMTPEmailer` (uses the `[scale.emailer.smtp]` table).
2. A name registered programmatically via `emailer_factory.register(name, cls)`.
3. A `"pkg.module:ClassName"` (or fallback `"pkg.module.ClassName"`) string is imported via `importlib`, validated as a subclass of `Emailer`, and instantiated with the resolved config dict.

If `provider` is empty or import/validation fails, the factory returns `None` and the framework logs that email features are disabled.

### Built-in SMTP

```toml
[scale.emailer]
provider     = "smtp"
from_address = "no-reply@example.com"

[scale.emailer.smtp]
host     = "smtp.example.com"
port     = 587
username = "apikey"
# password = "..."          # or set EMAILER_SMTP_PASSWORD env var (preferred)
use_tls  = true
timeout  = 10.0
```

| SMTP key | Description | Default |
|----------|-------------|---------|
| `host` | SMTP server hostname | `localhost` |
| `port` | SMTP port | `25` |
| `username` | SMTP auth username | `""` |
| `password` | SMTP auth password. **Prefer the `EMAILER_SMTP_PASSWORD` env var.** | `""` |
| `use_tls` | STARTTLS upgrade after connect | `true` |
| `timeout` | Connection timeout in seconds | `10.0` |

### Custom Emailer (Python or Jac)

Subclass `Emailer` and point `provider` at your class. The factory imports it dynamically at server startup and instantiates it with the full emailer config dict.

```python
# myapp/email.py
from jaclang.scale.emailer.emailer import Emailer
import os, sendgrid

class SendGridEmailer(Emailer):
    def postinit(self):
        self._client = sendgrid.SendGridAPIClient(api_key=os.environ["SENDGRID_API_KEY"])

    def send_email(self, to_addr, subject, body_text, body_html=None, from_addr=None):
        # ... use self._client to send ...
        return True

    def is_ready(self):
        return self.enabled and self._client is not None
```

```toml
[scale.emailer]
provider     = "myapp.email:SendGridEmailer"
from_address = "no-reply@example.com"
```

The constructor receives the resolved config dict, so any extra TOML keys you put under `[scale.emailer.<your_section>]` are available via `self.config`. Keep secrets (API keys, passwords) in environment variables -- the constructor can read `os.environ` directly.

### Examples

#### Example 1 -- Built-in SMTP (default emailer)

Use this when you have an SMTP relay already (Gmail, AWS SES SMTP interface, your own postfix, etc.). No custom code required.

```toml
# jac.toml
[scale.emailer]
provider     = "smtp"
from_address = "no-reply@example.com"

[scale.emailer.smtp]
host     = "smtp.gmail.com"
port     = 587
username = "no-reply@example.com"
use_tls  = true

[scale.auth]
verify_token_ttl_seconds = 86400
reset_token_ttl_seconds  = 1800
verify_url_template      = "https://app.example.com/verify?token={token}"
reset_url_template       = "https://app.example.com/reset?token={token}"
```

Export the password before starting the server:

```bash
export EMAILER_SMTP_PASSWORD="<app-password>"
jac start
```

Test the flow end to end:

```bash
# 1) Register
curl -X POST http://localhost:8000/user/register \
  -H "Content-Type: application/json" \
  -d '{
    "identities": [{"type": "email", "value": "alice@example.com"}],
    "credential": {"type": "password", "password": "secret"}
  }'

# 2) Trigger forgot-password (always returns 200)
curl -X POST http://localhost:8000/user/forgot-password \
  -H "Content-Type: application/json" \
  -d '{"identity": {"type": "email", "value": "alice@example.com"}}'

# 3) Click the link in the email; the frontend pulls the token out of the
#    URL and posts it back:
curl -X POST http://localhost:8000/user/reset-password \
  -H "Content-Type: application/json" \
  -d '{"token": "<token-from-email>", "new_password": "brandNew123"}'
```

#### Example 2 -- Custom SendGrid emailer

Use this when you want SendGrid's REST API instead of SMTP (better deliverability stats, templates, webhooks).

```python
# myapp/email.py
from jaclang.scale.emailer.emailer import Emailer
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail
import os, logging

logger = logging.getLogger(__name__)

class SendGridEmailer(Emailer):
    def postinit(self):
        api_key = os.environ.get("SENDGRID_API_KEY", "")
        self._client = SendGridAPIClient(api_key=api_key) if api_key else None

    def send_email(self, to_addr, subject, body_text, body_html=None, from_addr=None):
        if self._client is None:
            logger.warning("SendGrid client not configured; dropping email to %s", to_addr)
            return False
        msg = Mail(
            from_email=from_addr or self.from_address,
            to_emails=to_addr,
            subject=subject,
            plain_text_content=body_text,
            html_content=body_html,
        )
        try:
            resp = self._client.send(msg)
            return 200 <= resp.status_code < 300
        except Exception as e:
            logger.error("SendGrid send failed: %s", e)
            return False

    def is_ready(self):
        return self.enabled and self._client is not None
```

```toml
# jac.toml
[scale.emailer]
provider     = "myapp.email:SendGridEmailer"
from_address = "no-reply@example.com"

[scale.auth]
verify_token_ttl_seconds = 86400
reset_token_ttl_seconds  = 1800
verify_url_template      = "https://app.example.com/verify?token={token}"
reset_url_template       = "https://app.example.com/reset?token={token}"
```

Run:

```bash
export SENDGRID_API_KEY="SG.xxxxxxxx"
jac start
```

Run `jac start` from the directory containing `myapp/` so the package is importable. The factory verifies `issubclass(SendGridEmailer, Emailer)` at startup; on a typo or wrong base class it logs an error and disables email (the server keeps running).

---

## Admin Portal

jac-scale includes a built-in admin portal for managing users, roles, and SSO configurations.

### Accessing the Admin Portal

Navigate to `http://localhost:8000/admin` to access the admin dashboard. On first server start, an admin user is automatically bootstrapped.

### Configuration

```toml
[scale.admin]
enabled = true
username = "admin"
session_expiry_hours = 24
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | `true` | Enable/disable admin portal |
| `username` | string | `"admin"` | Admin username |
| `session_expiry_hours` | int | `24` | Admin session duration in hours |
| `require_password_reset` | bool | `true` | Force admin to change the default password on first login |

**Environment Variables:**

| Variable | Description |
|----------|-------------|
| `ADMIN_USERNAME` | Admin username (overrides jac.toml) |
| `ADMIN_EMAIL` | Admin email (overrides jac.toml) |
| `ADMIN_DEFAULT_PASSWORD` | Initial password (overrides jac.toml) |

### User Roles

| Role | Value | Description |
|------|-------|-------------|
| `ADMIN` | `admin` | Full administrative access |
| `SYSTEM` | `system` | Internal system account (cannot be deleted) |
| `USER` | `user` | Standard user access |

See [Roles](#roles) in the Authentication section for details on protected accounts and role management.

### Admin API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/admin/login` | Admin authentication |
| GET | `/admin/users` | List all users |
| GET | `/admin/users/{username}` | Get user details |
| POST | `/admin/users` | Create a new user |
| PUT | `/admin/users/{username}` | Update user role/settings |
| DELETE | `/admin/users/{username}` | Delete a user |
| POST | `/admin/users/{username}/force-password-reset` | Force password reset |
| GET | `/admin/sso/providers` | List SSO providers |
| GET | `/admin/sso/users/{username}/accounts` | Get user's SSO accounts |

---

## Permissions & Access Control

### Access Levels

| Level | Value | Description |
|-------|-------|-------------|
| `NO_ACCESS` | `-1` | No access to the object |
| `READ` | `0` | Read-only access |
| `CONNECT` | `1` | Can traverse edges to/from this object |
| `WRITE` | `2` | Full read/write access |

### Granting Permissions

#### To Everyone

Use `perm_grant` to allow all users to access an object at a given level:

```jac
with entry {
    # Allow everyone to read this node
    perm_grant(node, READ);

    # Allow everyone to write
    perm_grant(node, WRITE);
}
```

#### To a Specific Root

Use `allow_root` to grant access to a specific user's root graph:

```jac
with entry {
    # Allow a specific user to read this node
    allow_root(node, target_root_id, READ);

    # Allow write access
    allow_root(node, target_root_id, WRITE);
}
```

### Revoking Permissions

#### From Everyone

```jac
with entry {
    # Revoke all public access
    perm_revoke(node);
}
```

#### From a Specific Root

```jac
with entry {
    # Revoke a specific user's access
    disallow_root(node, target_root_id, READ);
}
```

### Secure-by-Default Endpoints

All walker and function endpoints are **protected by default** -- they require JWT authentication. You must explicitly opt-in to public access using the `:pub` modifier. This secure-by-default approach prevents accidentally exposing endpoints without authentication.

```jac
# Protected (default) -- requires JWT token, runs on the caller's own isolated root
walker get_profile {
    can fetch with Root entry { report [-->]; }
}

# Public -- no authentication required
walker :pub health_check {
    can check with Root entry { report {"status": "ok"}; }
}

# Private -- identical to the default; `:priv` is the explicit spelling
walker :priv internal_process {
    can run with Root entry { }
}
```

### Walker Access Levels

Walkers have two access levels when served as API endpoints (`:priv` is the explicit spelling of the default):

| Access | Description |
|--------|-------------|
| Public (`:pub`) | Accessible without authentication. Anonymous callers run on the shared guest graph (`root.shared`); a caller presenting a valid token runs on their own root. |
| Default, Protected (`:protect`), and Private (`:priv`) | Require JWT authentication; per-user isolated (each user operates on their own graph). For endpoint auth these behave identically -- **only `:pub` is exempt**. `:protect` is _not_ a middle auth tier; its three-way gradient applies to source-level [visibility](../language/access-modifiers.md), not to authentication. |

### Permission Functions Reference

| Function | Signature | Description |
|----------|-----------|-------------|
| `perm_grant` | `perm_grant(archetype, level)` | Allow everyone to access at given level |
| `perm_revoke` | `perm_revoke(archetype)` | Remove all public access |
| `allow_root` | `allow_root(archetype, root_id, level)` | Grant access to a specific root |
| `disallow_root` | `disallow_root(archetype, root_id, level)` | Revoke access from a specific root |

---

## Webhooks

Webhooks allow external services (payment processors, CI/CD systems, messaging platforms, etc.) to send real-time notifications to your Jac application. Jac-Scale provides:

- **Dedicated `/webhook/` endpoints** for webhook walkers
- **API key authentication** for secure access
- **HMAC-SHA256 signature verification** to validate request integrity
- **Automatic endpoint generation** based on walker configuration

### Configuration

Webhook configuration is managed via the `jac.toml` file in your project root.

```toml
[scale.webhook]
secret = "your-webhook-secret-key"
signature_header = "X-Webhook-Signature"
verify_signature = true
api_key_expiry_days = 365
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `secret` | string | `"webhook-secret-key"` | Secret key for HMAC signature verification. Can also be set via `WEBHOOK_SECRET` environment variable. |
| `signature_header` | string | `"X-Webhook-Signature"` | HTTP header name containing the HMAC signature. |
| `verify_signature` | boolean | `true` | Whether to verify HMAC signatures on incoming requests. |
| `api_key_expiry_days` | integer | `365` | Default expiry period for API keys in days. Set to `0` for permanent keys. |

**Environment Variables:**

For production deployments, use environment variables for sensitive values:

```bash
export WEBHOOK_SECRET="your-secure-random-secret"
```

### Creating Webhook Walkers

To create a webhook endpoint, use the `@restspec(protocol=APIProtocol.WEBHOOK)` decorator on your walker definition.

#### Basic Webhook Walker

```jac
@restspec(protocol=APIProtocol.WEBHOOK)
walker PaymentReceived {
    has payment_id: str,
        amount: float,
        currency: str = 'USD';

    can process with Root entry {
        # Process the payment notification
        report {
            "status": "success",
            "message": f"Payment {self.payment_id} received",
            "amount": self.amount,
            "currency": self.currency
        };
    }
}
```

This walker will be accessible at `POST /webhook/PaymentReceived`.

#### Important Notes

- Webhook walkers are **only** accessible via `/webhook/{walker_name}` endpoints
- They are **not** accessible via the standard `/walker/{walker_name}` endpoint

### API Key Management

Webhook endpoints require API key authentication. Users must first create an API key before calling webhook endpoints.

> **Note:** API key metadata is stored persistently in MongoDB (in the `webhook_api_keys` collection), so keys survive server restarts. Previously, keys were held in memory only.

#### Creating an API Key

**Endpoint:** `POST /api-key/create`

**Headers:**

- `Authorization: Bearer <jwt_token>` (required)

**Request Body:**

```json
{
    "name": "My Webhook Key",
    "expiry_days": 30
}
```

**Response:**

```json
{
    "api_key": "eyJhbGciOiJIUzI1NiIs...",
    "api_key_id": "a1b2c3d4e5f6...",
    "name": "My Webhook Key",
    "created_at": "2024-01-15T10:30:00Z",
    "expires_at": "2024-02-14T10:30:00Z"
}
```

#### Listing API Keys

**Endpoint:** `GET /api-key/list`

**Headers:**

- `Authorization: Bearer <jwt_token>` (required)

### Calling Webhook Endpoints

Webhook endpoints require two headers for authentication:

1. **`X-API-Key`**: The API key obtained from `/api-key/create`
2. **`X-Webhook-Signature`**: HMAC-SHA256 signature of the request body

#### Generating the Signature

The signature is computed as: `HMAC-SHA256(request_body, api_key)`

**cURL Example:**

```bash
API_KEY="eyJhbGciOiJIUzI1NiIs..."
PAYLOAD='{"payment_id":"PAY-12345","amount":99.99,"currency":"USD"}'
SIGNATURE=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$API_KEY" | cut -d' ' -f2)

curl -X POST "http://localhost:8000/webhook/PaymentReceived" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $API_KEY" \
    -H "X-Webhook-Signature: $SIGNATURE" \
    -d "$PAYLOAD"
```

### Webhook vs Regular Walkers

| Feature | Regular Walker (`/walker/`) | Webhook Walker (`/webhook/`) |
|---------|----------------------------|------------------------------|
| Authentication | JWT Bearer token | API Key + HMAC Signature |
| Use Case | User-facing APIs | External service callbacks |
| Access Control | User-scoped | Service-scoped |
| Signature Verification | No | Yes (HMAC-SHA256) |
| Endpoint Path | `/walker/{name}` | `/webhook/{name}` |

### Webhook API Reference

#### Webhook Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/webhook/{walker_name}` | Execute webhook walker |

#### API Key Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api-key/create` | Create a new API key |
| GET | `/api-key/list` | List all API keys for user |
| DELETE | `/api-key/{api_key_id}` | Revoke an API key |

#### Required Headers for Webhook Requests

| Header | Required | Description |
|--------|----------|-------------|
| `Content-Type` | Yes | Must be `application/json` |
| `X-API-Key` | Yes | API key from `/api-key/create` |
| `X-Webhook-Signature` | Yes* | HMAC-SHA256 signature (*if `verify_signature` is enabled) |

---

## WebSockets

Jac Scale provides built-in support for WebSocket endpoints, enabling real-time bidirectional communication between clients and walkers.

### Overview

WebSockets allow persistent, full-duplex connections between a client and your Jac application. Unlike REST endpoints (single request-response), a WebSocket connection stays open, allowing multiple messages to be exchanged in both directions. Jac Scale provides:

- **Dedicated `/ws/` endpoints** for WebSocket walkers
- **Persistent connections** with a message loop
- **JSON message protocol** for sending walker fields and receiving results
- **JWT authentication** via query parameter or message payload
- **Connection management** with automatic cleanup on disconnect
- **HMR support** in dev mode for live reloading

### Creating WebSocket Walkers

To create a WebSocket endpoint, use the `@restspec(protocol=APIProtocol.WEBSOCKET)` decorator on an `async walker` definition.

#### Basic WebSocket Walker (Public)

```jac
@restspec(protocol=APIProtocol.WEBSOCKET)
async walker : pub EchoMessage {
    has message: str;
    has client_id: str = "anonymous";

    async can echo with Root entry {
        report {
            "echo": self.message,
            "client_id": self.client_id
        };
    }
}
```

This walker will be accessible at `ws://localhost:8000/ws/EchoMessage`.

#### Authenticated WebSocket Walker

To create a private walker that requires JWT authentication, simply remove `: pub` from the walker definition.

#### Broadcasting WebSocket Walker

Use `broadcast=True` to send messages to ALL connected clients of this walker:

```jac
@restspec(protocol=APIProtocol.WEBSOCKET, broadcast=True)
async walker : pub ChatRoom {
    has message: str;
    has sender: str = "anonymous";

    async can handle with Root entry {
        report {
            "type": "message",
            "sender": self.sender,
            "content": self.message
        };
    }
}
```

When a client sends a message, **all connected clients** receive the response, making it ideal for:

- Chat rooms
- Live notifications
- Real-time collaboration
- Game state synchronization

#### Private Broadcasting Walker

To create a private broadcasting walker, remove `: pub` from the walker definition. Only authenticated users can connect and send messages, and all authenticated users receive broadcasts.

### Important Notes

- WebSocket walkers **must** be declared as `async walker`
- Use `: pub` for public access (no authentication required) or omit it to require JWT auth
- Use `broadcast=True` to send responses to ALL connected clients (only valid with WEBSOCKET protocol)
- WebSocket walkers are **only** accessible via `ws://host/ws/{walker_name}`
- The connection stays open until the client disconnects

## Microservice Interop (sv-to-sv)

Jac Scale lets you split a server-side codebase into multiple independently-deployed microservices without changing call sites. When two `sv` (server) modules each run as their own server process, an `sv import` from one to the other generates HTTP client stubs at compile time, so calls become RPCs over the wire instead of in-process imports.

### Overview

The `sv import` keyword has two flavors depending on where the importer and the importee live:

- **cl-to-sv**: client code calls server functions. Calls go over HTTP from browser to server.
- **sv-to-sv**: one server module calls another server module that runs as a separate microservice. Calls go over HTTP from one server process to another.

In the sv-to-sv flavor, `order_service.jac` doing `sv import from inventory_service { check_stock }` does not load `inventory_service` into the consumer's process. Calling `check_stock(sku)` issues a `POST /function/check_stock` against the inventory service's URL and returns the result. The same source runs unchanged whether `inventory_service` is a separate microservice, a sibling process started by the same `jac start` command, or (when `sv import` is absent) a normal in-process import.

Both `def:pub` functions and `walker:pub` archetypes can cross the boundary. Function imports POST to `/function/<name>` and return the function's value. Walker imports POST to `/walker/<name>` and return the rehydrated walker instance with its `has` fields populated and `reports` attached, so call sites read the result the same way they would after a local spawn. See [Walker Imports](#walker-imports) for the wire shape and ergonomics.

For a step-by-step walkthrough that covers project setup, running both services, and watching the round-trip, see the [Microservices tutorial](../../tutorials/production/microservices.md). The rest of this section is a reference for the discovery rules, wire contract, and plugin override surface.

### Requirements

A few preconditions for `sv import` to work:

- **Public functions only.** Provider functions reached through `sv import` must be declared `def:pub`; non-public functions are not exposed as endpoints, and calls into them return 404. Walkers similarly need `walker:pub`.
- **jac-scale on the consumer.** Explicit URLs and env vars work with any jaclang install. Automatic spawning of siblings is provided by jac-scale; a bare jaclang install can still call providers registered by URL.
- **Project layout.** `jac start <relative-path>` requires a `jac.toml` in the current directory. Run `jac create` first, or pass an absolute path.
- **Services in the same directory when auto-spawning.** If the consumer auto-spawns a provider, it loads the provider source from the directory you ran `jac start` in. Keep all services in the same project directory, or point the consumer at a provider URL explicitly so auto-spawning never runs.

### Boundary Types

Types that cross the service boundary use the same wire contract as cl-to-sv interop. The compiler emits a matching wrapper on the consumer side for every type referenced in an `sv import`, so values serialize transparently into JSON on the way out and deserialize back into the declared type on the way in.

What works:

- **`obj` types** -- fields hydrated recursively, including nested objects.
- **`enum` types** -- serialized by name.
- **Primitives** -- `int`, `float`, `str`, `bool`, `None`, `list[T]`, `dict[K, V]`.
- **Bidirectional** -- typed function arguments are wrapped on the way out and unwrapped on the way in.
- **`walker:pub` archetypes** -- when imported by name. The consumer-side stub mirrors the provider's `has` fields, and the round-trip rehydrates the walker into a real instance with `reports` populated. See [Walker Imports](#walker-imports).

What doesn't:

- **Anchors, closures** -- not wire-friendly. Pass identifiers (e.g. `jid`) and re-resolve on the other side.
- **Live database handles, file handles** -- service-local resources only.

Failures (network errors, missing service, error envelope from the provider) raise `RuntimeError`. The message form depends on which kind of symbol was being called:

- Function: `sv-to-sv RPC '{module}.{func}' failed: {msg}`
- Walker: `sv-to-sv walker spawn '{module}.{walker}' failed: {msg}`

### Walker Imports

A consumer can `sv import` a `walker:pub` archetype the same way it imports a function. The compiler generates a stub class on the consumer side whose name and `has` field shape mirror the provider's walker, so type identity is preserved and the call site reads like a local construction.

```jac
# notify_service.jac (provider)
walker:pub Greet {
    has name: str;
    can greet with Root entry {
        report f"hello, {self.name}";
    }
}

# dispatcher_service.jac (consumer)
sv import from notify_service { Greet }

walker:pub TriggerGreet {
    has who: str;
    can run with Root entry {
        rg = Greet(name=self.who);   # POST /walker/Greet on the provider
        report rg.reports[0];        # "hello, <who>"
    }
}
```

What happens when the consumer evaluates `Greet(name=self.who)`:

1. The stub class collects the keyword arguments into a JSON dict (boundary-typed values are serialized via `_to_wire` first).
2. The runtime POSTs that dict to `/walker/Greet` on the resolved provider URL using the same dispatch chain as function calls (test client → registry → `JAC_SV_<MOD>_URL` → automatic spawn).
3. The provider spawns and runs the walker, then returns a `TransportResponse` envelope whose `data.result` is the executed walker as a dict and whose `data.reports` is the list of values it emitted via `report`.
4. The consumer rehydrates `data.result` into an instance of the local stub class, attaches `data.reports` as the instance's `reports` attribute, and returns it.

The result is a normal walker instance on the consumer: `rg.name`, `rg.reports[0]`, and `isinstance(rg, Greet)` all work. Boundary-typed values inside the walker's `has` fields and inside the `reports` list are unwrapped recursively, so a walker that emits an `obj` type comes back as that type, not as a raw dict.

A few notes:

- **Spawn semantics, not construction.** Locally, `Greet(name="x")` only constructs a walker; you still need `spawn` to run it. Across the boundary, instantiating a sv-imported walker is **spawn-and-execute** -- there is no useful concept of an unexecuted remote walker. The consumer-side class accepts only the `has` fields as keyword arguments and always returns a post-execution instance.
- **`walker:pub` only.** Private walkers are not exposed as endpoints, so calls into them return 404. Boundary types from a walker's signature (used in `has` fields or referenced in `report` arguments) need to be `sv import`ed alongside the walker.
- **Same retry, breaker, auth, and tracing as functions.** The plugin override surface is `sv_walker_call`, not `sv_service_call`, but they share the per-provider circuit breaker and `rpc_timeout` config -- a tripped breaker protects either RPC kind. See [Plugin Override: Custom Service Spawning](#plugin-override-custom-service-spawning).

This applies to **sv-to-sv** imports. Walker imports across the **cl-to-sv** boundary (browser calling a server walker) are not currently generated; for cl-to-sv use a `def:pub` wrapper that spawns the walker server-side.

### Automatic Startup

When you run `jac start consumer.jac`, the consumer finds every service it `sv import`s from and brings them all up **before** it starts accepting requests. Transitive dependencies are included: if A imports B and B imports C, starting A brings up all three.

Startup is **fail-fast**: if any service fails to come up (missing source file, syntax error, port in use), the consumer crashes at startup with the underlying error. You find out at deploy time, not at first request.

Automatic startup only applies to `jac start`. `jac run` is for one-shot scripts and does not bring up long-running sibling services; if it calls an `sv import`-ed function it will try to discover the provider lazily using the rules in [Service Discovery](#service-discovery) below.

### Service Discovery

For each `sv import`-ed provider, the consumer resolves it in this order. The first match wins:

1. **Test client** -- if tests have wired up an in-process `TestClient` for the provider, calls go through it with no HTTP. See [Testing](#testing).
2. **Explicit URL** -- a URL the consumer was handed programmatically (e.g. by a custom orchestrator). See the [sv_client API](#sv_client-api-reference).
3. **`JAC_SV_<MODULE>_URL` environment variable** -- automatically consulted using the upper-cased module name. This is the knob to reach for when the provider lives on a different host.
4. **Automatic spawn** -- jac-scale brings up the provider as a sibling inside the consumer process. This is the path that lets `jac start consumer.jac` run the whole cluster from one command.

Automatically-spawned siblings are bound to `127.0.0.1` -- they are reachable from inside the consumer process but not from outside. This makes single-command mode a supported deployment for **single-host** setups, but you cannot reach a sibling from another machine. For multi-host deployments, wire the consumer with `JAC_SV_<MODULE>_URL` pointing at the provider running elsewhere.

Siblings are assigned ports in the range `18000-18999`. Pick ports outside this range (e.g. in the 8000s) for your own `jac start --port` flags so a manual port does not collide with a future automatic spawn.

### Production Patterns

#### Kubernetes

Each service is its own `Deployment` + `Service`. Wire the consumer with an env var pointing at the provider's cluster DNS name:

```yaml
# order-service deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
spec:
  template:
    spec:
      containers:
      - name: order-service
        image: my-registry/order-service:latest
        env:
        - name: JAC_SV_INVENTORY_SERVICE_URL
          value: "http://inventory-service.default.svc.cluster.local:8000"
```

The convention is `JAC_SV_<UPPERCASED_MODULE_NAME>_URL`. Module name is the value used in `sv import from <module_name>`.

#### Local Development

For multi-service local dev, the simplest pattern is `JAC_SV_*_URL` env vars in a `.env` file or your shell:

```bash
export JAC_SV_INVENTORY_SERVICE_URL=http://localhost:8001
export JAC_SV_MATH_SERVICE_URL=http://localhost:8002
jac start order_service.jac --port 8000
```

Alternatively, omit the env vars entirely and run `jac start order_service.jac` on its own. The consumer will find every service it `sv import`s from and bring them all up automatically (including transitive dependencies) before serving the first request. This is a supported deployment mode for **single-host** setups -- one process, many logical services. For **multi-host** deployments use the `JAC_SV_*_URL` path instead: automatically-started services bind `127.0.0.1` only and cannot serve traffic to other hosts.

#### Troubleshooting

- **`{"detail":"Invalid anchor id ..."}` 500s.** Stale anchors persisted from a previous run with a different schema. Stop the server, `rm -rf .jac/data/`, and restart. Not specific to sv-to-sv; any `def:pub` call can hit this after a schema change.
- **Consumer crashes at startup with `ModuleNotFoundError: No module named '<provider>'`.** Automatic startup could not find the provider source in the directory you ran `jac start` from. Either move all services into the same project directory, or set `JAC_SV_<MODULE>_URL` to point the consumer at a provider running elsewhere.
- **Cross-service call returns 404.** The provider function is not declared `def:pub`. Walkers similarly need `walker:pub`.

### Testing

To test cross-service behavior without real network I/O, wire each provider up as an in-process `TestClient` before constructing the consumer. `sv_client.register_test_client(module_name, client)` routes the consumer's calls through the registered client directly; no sockets, no port allocation, no background threads.

```jac
import from jaclang.runtimelib { sv_client }
import from starlette.testclient { TestClient }

test "consumer reaches provider" {
    sv_client.clear_test_clients();

    prov_client: TestClient = ...;  # build a TestClient over the provider app
    cons_client: TestClient = ...;  # build a TestClient over the consumer app
    sv_client.register_test_client("inventory_service", prov_client);

    # Calls from the consumer into inventory_service now route through prov_client
    resp = cons_client.post(
        "/function/create_order",
        json={"items": [{"sku": "W", "quantity": 2}]}
    ).json();
    assert resp["data"]["result"]["success"] is True;
}
```

The two builder steps marked `...` are the boilerplate of standing up a consumer and provider in-process and wrapping each one in a `starlette.testclient.TestClient`. That scaffolding currently leans on hands-on use of jac-scale's server-construction APIs. The sv-to-sv test suite in the jac-scale source tree has a worked example that copies fixture files into a temp directory and brings both services up end-to-end; start there if you need a runnable harness.

Always call `sv_client.clear_test_clients()` between tests to avoid bleed-over from a previous test's registrations.

### sv_client API Reference

`jaclang.runtimelib.sv_client` exposes a small control surface for telling the runtime where to find providers. You rarely need it under normal use -- `JAC_SV_<MODULE>_URL` covers most production wiring, and automatic startup covers single-host setups. Reach for these functions when you are writing tests or a custom orchestrator.

| Function | Purpose |
|---|---|
| `register(module_name: str, url: str)` | Point a provider name at a URL programmatically. Takes precedence over the env var path. |
| `unregister(module_name: str)` | Remove a registration made via `register`. |
| `register_test_client(module_name, client)` | Route calls to a provider through an in-process `TestClient` (tests only). See [Testing](#testing). |
| `unregister_test_client(module_name: str)` | Remove a test-client registration. |
| `clear_test_clients()` | Drop all test-client registrations. Call between tests to avoid bleed-over. |
| `resolve_url(module_name: str) -> str` | Look up the URL the consumer would use for a provider (either from `register` or from `JAC_SV_<MOD>_URL`). Returns a string or raises if nothing is registered. |

### Plugin Override: Custom Service Spawning

`JacAPIServer.ensure_sv_service(module_name: str, base_path: str) -> None` is the hook a plugin overrides to change **how** services come up. Default jac-scale behavior spawns a sibling inside the consumer process; a plugin override can launch the service anywhere it wants -- Docker containers, Kubernetes Jobs, systemd units, remote VMs -- as long as it ends by calling `sv_client.register(module_name, <url>)` so subsequent calls skip the hook.

The hook is called during automatic startup, once per provider, in parallel up to 8 at a time. Overrides must be idempotent and safe to run concurrently. Both properties were already true of the pre-existing lazy contract (concurrent first-call requests could race into the same hook), so a plugin written against any prior version continues to work without modification.

The default jac-scale implementation at a high level: pick a free loopback port in `18000-18999`, start an HTTP listener on a daemon thread serving the module's `def:pub` endpoints, wait until the listener responds to an HTTP probe, then register the URL. Consult the jac-scale source if you need the exact details; the contract plugin authors should rely on is the `ensure_sv_service` signature and the requirement to call `sv_client.register` before returning.

### Plugin Override: RPC Transport

Two parallel hooks let a plugin own the wire-level transport for sv-to-sv calls:

| Hook | Used by | Default transport |
|---|---|---|
| `JacAPIServer.sv_service_call(module_name, func_name, args)` | sv-imported `def:pub` functions | `POST /function/<name>` |
| `JacAPIServer.sv_walker_call(module_name, walker_name, args, stub_cls)` | sv-imported `walker:pub` archetypes | `POST /walker/<name>` + `stub_cls._from_wire` rehydration |

Plugins typically override both with the same auth-forwarding, tracing, retry, and circuit-breaker policy. The jac-scale plugin does exactly that: walker calls share the per-provider circuit breaker with function calls (both express provider liveness, so a tripped breaker should protect either kind), forward the inbound `Authorization` header, propagate `X-Trace-Id` across the hop, retry transport-level failures with exponential backoff, and respect the per-service `rpc_timeout` config.

Overrides for `sv_walker_call` must end by returning the rehydrated walker instance: call `stub_cls._from_wire(envelope.data.result)` and attach `envelope.data.reports` to the resulting instance's `reports` attribute. The default implementation is a useful reference and reusing `_unwrap_sv_envelope` / `_hydrate_walker_envelope` from the jac-scale source keeps error semantics consistent with the function path.

## CLI Commands

| Command | Description |
|---------|-------------|
| `jac start app.jac` | Start local API server |
| `jac start app.jac --scale` | Deploy to Kubernetes |
| `jac start app.jac --scale --dry-run` | Print the manifests that would be applied; change nothing |
| `jac start app.jac --scale --target kubernetes` | Explicit deployment target (default) |
| `jac start app.jac --scale --enable-tls` | Enable HTTPS on a live deployment (no redeploy) |
| `jac scale status app.jac` | Show live deployment status |
| `jac scale status app.jac --target kubernetes` | Status for a specific target |
| `jac scale destroy app.jac` | Remove Kubernetes deployment (prompts for confirmation) |
| `jac scale destroy app.jac --target kubernetes` | Destroy a specific target |

---

## API Documentation

When server is running:

- **Swagger UI:** `http://localhost:8000/docs`
- **ReDoc:** `http://localhost:8000/redoc`
- **OpenAPI JSON:** `http://localhost:8000/openapi.json`

---

## Graph Visualization

Navigate to `http://localhost:8000/graph` to view an interactive visualization of your application's graph directly in the browser.

- **Without authentication** - displays the public graph (super root), useful for applications with public endpoints
- **With authentication** - click the **Login** button in the header to sign in and view your user-specific graph

The visualizer uses a force-directed layout with color-coded node types, edge labels, tooltips on hover, and controls for refresh, fit-to-view, and physics toggle. If a user has previously logged in (via a jac-client app or the login modal), the existing `jac_token` in localStorage is picked up automatically.

| Endpoint | Description |
|---|---|
| `GET /graph` | Serves the graph visualization UI |
| `GET /graph/data` | Returns graph nodes and edges as JSON (optional `Authorization` header) |

---
