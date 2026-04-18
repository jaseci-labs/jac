# jac-scale Reference

jac-scale generates REST endpoints from your Jac walkers and functions. Running `jac start` with this plugin turns every `:pub` or `:priv` walker into an API endpoint backed by FastAPI, with automatic Swagger docs, SQLite persistence, and built-in authentication.

For production, the `--scale` flag automates Docker image builds and Kubernetes deployment -- generating Dockerfiles, manifests, and service configurations from your code. This reference covers server startup options, endpoint generation, authentication, database persistence, Kubernetes deployment, and the CLI flags for each mode.

---

## Installation

jac-scale is lightweight by default. Install only the extras you need:

```bash
# Core only - FastAPI server, auth, CLI (no heavy dependencies)
pip install jac-scale

# Add MongoDB + Redis for persistent storage and distributed cache
pip install jac-scale[data]

# Add Prometheus metrics and observability
pip install jac-scale[monitoring]

# Add APScheduler for cron and background task scheduling
pip install jac-scale[scheduler]

# Add Kubernetes + Docker for deployment and image building
pip install jac-scale[deploy]

# Everything - recommended for production or if unsure
pip install jac-scale[all]
```

Groups are combinable: `pip install jac-scale[data,monitoring]`

After installing, enable the plugin:

```bash
jac plugins enable scale
```

!!! note
    When a feature is used without its dependency installed, you get a clear error with the exact install command:
    `ImportError: 'pymongo' is required for this feature. Install it with: pip install jac-scale[data]`

| Group | What it adds | When you need it |
|-------|-------------|-----------------|
| _(core)_ | FastAPI, uvicorn, JWT auth, CLI | Always included |
| `[data]` | pymongo, redis | Using MongoDB/Redis for storage (`jac start` with database config) |
| `[monitoring]` | prometheus-client | Prometheus `/metrics` endpoint |
| `[scheduler]` | apscheduler | `@schedule(trigger=...)` on walkers/functions |
| `[deploy]` | kubernetes, docker | `jac start --scale` or `jac start --build` |
| `[all]` | All of the above | Production, or when you want everything |

---

## Starting a Server

### Basic Server

```bash
jac start app.jac
```

### Server Options

| Option | Description | Default |
|--------|-------------|---------|
| `--port` `-p` | Server port (auto-fallback if in use) | 8000 |
| `--main` `-m` | Treat as `__main__` | false |
| `--faux` `-f` | Print generated API docs only (no server) | false |
| `--dev` `-d` | Enable HMR (Hot Module Replacement) mode | false |
| `--api_port` `-a` | Separate API port for HMR mode (0=same as port) | 0 |
| `--no_client` `-n` | Skip client bundling/serving (API only) | false |
| `--profile` | Configuration profile to load (e.g. prod, staging) | - |
| `--client` | Client build target for dev server (web, desktop, pwa) | - |
| `--scale` | Deploy to a target platform instead of running locally | false |
| `--build` `-b` | Build and push Docker image (with --scale) | false |
| `--experimental` `-e` | Use experimental mode (install from repo instead of PyPI) | false |
| `--target` | Deployment target (kubernetes, aws, gcp) | kubernetes |
| `--registry` | Image registry (dockerhub, ecr, gcr) | dockerhub |
| `--enable-tls` | Enable HTTPS via Let's Encrypt (run after pointing your domain CNAME to the NLB) | false |

### Examples

```bash
# Custom port
jac start app.jac --port 3000

# Development with HMR (requires jac-client)
jac start app.jac --dev

# API only -- skip client bundling
jac start app.jac --dev --no_client

# Preview generated API endpoints without starting
jac start app.jac --faux

# Production with profile
jac start app.jac --port 8000 --profile prod
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
[plugins.scale.server]
port = 8000
host = "0.0.0.0"
docs_enabled = true   # Enable /docs, /redoc, /openapi.json (default: true)
```

Set `docs_enabled = false` to disable Swagger UI, ReDoc, and the OpenAPI JSON endpoint in production.

### CORS Configuration

```toml
[plugins.scale.cors]
allow_origins = ["https://example.com"]
allow_methods = ["GET", "POST", "PUT", "DELETE"]
allow_headers = ["*"]
```

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

jac-scale uses an **identity-based authentication system**. Instead of a flat username/password pair, each user has an array of _identities_ (username, email, SSO) and an array of _credentials_ (password). This allows users to log in with any of their identities and enables SSO accounts to coexist alongside password-based credentials without schema changes.

### Identity Model

A user document has this shape:

```
user_id        UUID (primary key)
status         "active" | "disabled"
role           "admin" | "system" | "user"
identities     [{type, value_raw, value_normalized, verified, is_recovery}, ...]
credentials    [{type, password_hash}, ...]
root_id        hex ID of the user's Jac graph root node
created_at     ISO 8601 timestamp
updated_at     ISO 8601 timestamp
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
[plugins.scale.database]
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
    "credential": {"type": "password", "password": "secret"}
  }'
```

Returns on success (HTTP 201):

```json
{
  "ok": true,
  "data": {
    "user_id": "550e8400-...",
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
[plugins.scale.jwt]
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
3. jac-scale exchanges the code for user info (email, external ID)
4. If a user with that email exists, the SSO identity is linked and a JWT is returned
5. If no user exists, a new account is created with a verified email identity, the SSO identity is linked, and a JWT is returned

**Configuration via `jac.toml`:**

```toml
[plugins.scale.sso]
host = "http://localhost:8000"  # Your server's public URL
client_auth_callback_url = ""   # Optional: redirect to frontend after SSO

[plugins.scale.sso.google]
client_id = "your-google-client-id"
client_secret = "your-google-client-secret"

[plugins.scale.sso.apple]
client_id = "your-apple-client-id"
client_secret = "your-apple-client-secret"

[plugins.scale.sso.github]
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
[plugins.scale.sso]
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

### Auth Endpoint Summary

| Method | Path | Auth Required | Description |
|--------|------|--------------|-------------|
| POST | `/user/register` | No | Create a new user |
| POST | `/user/login` | No | Authenticate and get JWT |
| POST | `/user/refresh-token` | No (token in body) | Refresh an existing JWT |
| PUT | `/user/password` | Yes (Bearer) | Update password |
| GET | `/sso/{platform}/{operation}` | No | Initiate SSO flow |
| GET/POST | `/sso/{platform}/callback` | No | SSO callback handler |
| POST | `/api-key/create` | Yes (Bearer) | Create an API key |
| GET | `/api-key/list` | Yes (Bearer) | List API keys |
| DELETE | `/api-key/{api_key_id}` | Yes (Bearer) | Revoke an API key |

---

## Admin Portal

jac-scale includes a built-in admin portal for managing users, roles, and SSO configurations.

### Accessing the Admin Portal

Navigate to `http://localhost:8000/admin` to access the admin dashboard. On first server start, an admin user is automatically bootstrapped.

### Configuration

```toml
[plugins.scale.admin]
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
# Protected (default) -- requires JWT token
walker get_profile {
    can fetch with Root entry { report [-->]; }
}

# Public -- no authentication required
walker :pub health_check {
    can check with Root entry { report {"status": "ok"}; }
}

# Private -- requires authentication, per-user isolated
walker :priv internal_process {
    can run with Root entry { }
}
```

### Walker Access Levels

Walkers have three access levels when served as API endpoints:

| Access | Description |
|--------|-------------|
| Public (`:pub`) | Accessible without authentication |
| Protected (default) | Requires JWT authentication |
| Private (`:priv`) | Requires JWT authentication; per-user isolated (each user operates on their own graph) |

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
[plugins.scale.webhook]
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

What doesn't:

- **Walkers, anchors, closures** -- not wire-friendly. Pass identifiers (e.g. `jid`) and re-resolve on the other side.
- **Live database handles, file handles** -- service-local resources only.

Failures (network errors, missing service, error envelope from the provider) raise `RuntimeError` with a message of the form `sv-to-sv RPC '{module}.{func}' failed: {msg}`.

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

## Storage

Jac provides a built-in storage abstraction for file and blob operations. The core runtime ships with a local filesystem implementation, and jac-scale can override it with cloud storage backends -- all through the same `store()` builtin.

### The `store()` Builtin

The recommended way to get a storage instance is the `store()` builtin. It requires no imports and is automatically hookable by plugins:

```jac
# Get a storage instance (no imports needed)
glob storage = store();

# With custom base path
glob storage = store(base_path="./uploads");

# With all options
glob storage = store(base_path="./uploads", create_dirs=True);
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `base_path` | `str` | `"./storage"` | Root directory for all files |
| `create_dirs` | `bool` | `True` | Create base directory if it doesn't exist |

Without jac-scale, `store()` returns a `LocalStorage` instance. With jac-scale installed, it returns a configuration-driven backend (reading from `jac.toml` and environment variables).

### Storage Interface

All storage instances provide these methods:

| Method | Signature | Description |
|--------|-----------|-------------|
| `upload` | `upload(source, destination, metadata=None) -> str` | Upload a file (from path or file object) |
| `download` | `download(source, destination=None) -> bytes\|None` | Download a file (returns bytes if no destination) |
| `delete` | `delete(path) -> bool` | Delete a file or directory |
| `exists` | `exists(path) -> bool` | Check if a path exists |
| `list_files` | `list_files(prefix="", recursive=False)` | List files (yields paths) |
| `get_metadata` | `get_metadata(path) -> dict` | Get file metadata (size, modified, created, is_dir, name) |
| `copy` | `copy(source, destination) -> bool` | Copy a file within storage |
| `move` | `move(source, destination) -> bool` | Move a file within storage |

### Usage Example

```jac
import from http { UploadFile }
import from uuid { uuid4 }

glob storage = store(base_path="./uploads");

walker :pub upload_file {
    has file: UploadFile;
    has folder: str = "documents";

    can process with Root entry {
        unique_name = f"{uuid4()}.dat";
        path = f"{self.folder}/{unique_name}";

        # Upload file
        storage.upload(self.file.file, path);

        # Get metadata
        metadata = storage.get_metadata(path);

        report {
            "success": True,
            "storage_path": path,
            "size": metadata["size"]
        };
    }
}

walker :pub list_files {
    has folder: str = "documents";
    has recursive: bool = False;

    can process with Root entry {
        files = [];
        for path in storage.list_files(self.folder, self.recursive) {
            metadata = storage.get_metadata(path);
            files.append({
                "path": path,
                "size": metadata["size"],
                "name": metadata["name"]
            });
        }
        report {"files": files};
    }
}

walker :pub download_file {
    has path: str;

    can process with Root entry {
        if not storage.exists(self.path) {
            report {"error": "File not found"};
            return;
        }
        content = storage.download(self.path);
        report {"content": content, "size": len(content)};
    }
}
```

### Configuration

Configure storage in `jac.toml`:

```toml
[storage]
storage_type = "local"       # Storage backend type
base_path = "./storage"      # Base directory for files
create_dirs = true           # Auto-create directories
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `storage_type` | string | `"local"` | Storage backend (`local`) |
| `base_path` | string | `"./storage"` | Base path for file storage |
| `create_dirs` | boolean | `true` | Automatically create directories |

**Environment Variables:**

| Variable | Description |
|----------|-------------|
| `JAC_STORAGE_TYPE` | Storage type (overrides jac.toml) |
| `JAC_STORAGE_PATH` | Base directory (overrides jac.toml) |
| `JAC_STORAGE_CREATE_DIRS` | Auto-create directories (`"true"`/`"false"`) |

Configuration priority: `jac.toml` > environment variables > defaults.

### StorageFactory (Advanced)

For advanced use cases, you can use `StorageFactory` directly instead of the `store()` builtin:

```jac
import from jac_scale.factories.storage_factory { StorageFactory }

# Create with explicit type and config
glob config = {"base_path": "./my-files", "create_dirs": True};
glob storage = StorageFactory.create("local", config);

# Create using jac.toml / env var / defaults
glob default_storage = StorageFactory.get_default();
```

---

## Graph Traversal API

### Traverse Endpoint

```bash
POST /traverse
```

### Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `source` | str | Starting node/edge ID | root |
| `depth` | int | Traversal depth | 1 |
| `detailed` | bool | Include archetype context | false |
| `node_types` | list | Filter by node types | all |
| `edge_types` | list | Filter by edge types | all |

### Example

```bash
curl -X POST http://localhost:8000/traverse \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "depth": 3,
    "node_types": ["User", "Post"],
    "detailed": true
  }'
```

---

## Async Walkers

```jac
walker async_processor {
    has items: list;

    async can process with Root entry {
        results = [];
        for item in self.items {
            result = await process_item(item);
            results.append(result);
        }
        report results;
    }
}
```

---

## Direct Database Access (kvstore)

Direct database operations without graph layer abstraction. Supports MongoDB (document queries) and Redis (key-value with TTL/atomic ops).

```jac
import from jac_scale.lib { kvstore }

with entry {
    mongo_db = kvstore(db_name='my_app', db_type='mongodb');
    redis_db = kvstore(db_name='cache', db_type='redis');
}
```

**Parameters:** `db_name` (str), `db_type` ('mongodb'|'redis'), `uri` (str|None - priority: explicit → `MONGODB_URI`/`REDIS_URL` env vars → jac.toml)

---

## MongoDB Operations

**Common Methods:** `get()`, `set()`, `delete()`, `exists()`
**Query Methods:** `find_one()`, `find()`, `insert_one()`, `insert_many()`, `update_one()`, `update_many()`, `delete_one()`, `delete_many()`, `find_by_id()`, `update_by_id()`, `delete_by_id()`, `find_nodes()`

**Example:**

```jac
import from jac_scale.lib { kvstore }

with entry {
    db = kvstore(db_name='my_app', db_type='mongodb');

    db.insert_one('users', {'name': 'Alice', 'role': 'admin', 'age': 30});
    alice = db.find_one('users', {'name': 'Alice'});
    admins = list(db.find('users', {'role': 'admin'}));
    older = list(db.find('users', {'age': {'$gt': 28}}));

    db.update_one('users', {'name': 'Alice'}, {'$set': {'age': 31}});
    db.delete_one('users', {'name': 'Bob'});

    db.set('user:123', {'status': 'active'}, 'sessions');
}
```

**Query Operators:** `$eq`, `$gt`, `$gte`, `$lt`, `$lte`, `$in`, `$ne`, `$and`, `$or`

### Querying Persisted Nodes (`find_nodes`)

Query persisted graph nodes by type with MongoDB filters. Returns deserialized node instances.

```jac
with entry{
    db = kvstore(db_name='jac_db', db_type='mongodb');
    young_users = list(db.find_nodes('User', {'age': {'$lt': 30}}));
    admins = list(db.find_nodes('User', {'role': 'admin'}));
}
```

**Parameters:** `node_type` (str), `filter` (dict, default `{}`), `col_name` (str, default `'_anchors'`)

---

## Redis Operations

**Common Methods:** `get()`, `set()`, `delete()`, `exists()`
**Redis Methods:** `set_with_ttl()`, `expire()`, `incr()`, `scan_keys()`

**Example:**

```jac
import from jac_scale.lib { kvstore }

with entry {
    cache = kvstore(db_name='cache', db_type='redis');

    cache.set('session:user123', {'user_id': '123', 'username': 'alice'});
    cache.set_with_ttl('temp:token', {'token': 'xyz'}, ttl=60);
    cache.set_with_ttl('cache:profile', {'name': 'Alice'}, ttl=3600);

    cache.incr('stats:views');
    sessions = cache.scan_keys('session:*');
    cache.expire('session:user123', 1800);
}
```

**Note:** Database-specific methods raise `NotImplementedError` on wrong database type.

---

## Database and Dashboards

### Auto-Provisioning

On the first `jac start app.jac --scale`, jac-scale automatically deploys Redis and MongoDB as Kubernetes StatefulSets with persistent storage. Subsequent deployments only update the application - databases remain untouched.

**What gets provisioned:**

- **MongoDB** - StatefulSet with PersistentVolumeClaim (graph persistence, `kvstore` backend)
- **Redis** - Deployment with persistent storage (cache layer, session management)
- **Application Deployment** - Your Jac app pod(s)
- **NGINX Ingress Controller** - Single NodePort entry point; routes traffic to ClusterIP services by path
- **Services** - ClusterIP services for all components (all traffic goes through the Ingress)
- **ConfigMaps** - Application configuration

| TOML Key | Default | Description |
|----------|---------|-------------|
| `mongodb_enabled` | `true` | Auto-provision MongoDB StatefulSet |
| `redis_enabled` | `true` | Auto-provision Redis Deployment |
| `mongodb_root_username` | `admin` | MongoDB root username - stored as a K8s Secret, injected via `secretKeyRef` |
| `mongodb_root_password` | `password` | MongoDB root password - stored as a K8s Secret, injected via `secretKeyRef` |
| `redis_username` | `admin` | Redis auth username - stored as a K8s Secret, injected via `secretKeyRef` |
| `redis_password` | `password` | Redis auth password - stored as a K8s Secret, injected via `secretKeyRef` |

Credentials are never hardcoded in pod specs. They are stored as Kubernetes `Secret` resources (`{app}-mongodb-secret`, `{app}-redis-secret`) and referenced via `valueFrom.secretKeyRef` - `kubectl describe pod` shows the secret name and key, not the actual value.

**To disable (use an external database instead):**

```toml
[plugins.scale.kubernetes]
mongodb_enabled = false   # Don't deploy MongoDB - use MONGODB_URI instead
redis_enabled = false     # Don't deploy Redis - use REDIS_URL instead

[plugins.scale.database]
mongodb_uri = "mongodb://user:pass@external-host:27017"
redis_url = "redis://external-redis:6379"
```

---

### Connection Configuration

Configure database connection URIs via environment variables or `jac.toml`. **Environment variables take priority over `jac.toml`.**

**Option 1 - Environment variables (recommended for secrets):**

| Variable | Description |
|----------|-------------|
| `MONGODB_URI` | MongoDB connection URI |
| `REDIS_URL` | Redis connection URL |

```env
# .env
MONGODB_URI=mongodb://user:password@host:27017/mydb
REDIS_URL=redis://host:6379/0
```

**Option 2 - `jac.toml`:**

```toml
[plugins.scale.database]
mongodb_uri = "mongodb://localhost:27017"   # External MongoDB URI (skip auto-provisioning)
redis_url = "redis://localhost:6379"        # External Redis URL (skip auto-provisioning)
shelf_db_path = ".jac/data/anchor_store.db"  # SQLite/shelf path for local dev
```

> `MONGODB_URI` and `REDIS_URL` environment variables take precedence over the `jac.toml` values when both are set.

| TOML Key | Default | Description |
|----------|---------|-------------|
| `mongodb_uri`| None | External MongoDB URI. When set, K8s MongoDB StatefulSet is not provisioned. |
| `redis_url`  | None | External Redis URL. When set, K8s Redis is not provisioned. |
| `shelf_db_path` | `.jac/data/anchor_store.db` | Local shelf/SQLite storage path for `jac start` (no K8s) |

---

### Dashboard Configuration

Dashboards are **off by default** and must be explicitly enabled in `jac.toml`:

```toml
[plugins.scale.kubernetes]
redis_dashboard  = true   # Deploy RedisInsight UI (default: false)
mongodb_dashboard = true  # Deploy Mongo Express UI (default: false)
```

| `jac.toml` key | Description | Default |
|----------------|-------------|---------|
| `redis_dashboard` | Deploy RedisInsight dashboard UI | `false` |
| `mongodb_dashboard` | Deploy Mongo Express dashboard UI | `false` |

#### Dashboard Credentials

When dashboards are enabled, they are served through the NGINX Ingress at fixed subpaths. No separate NodePorts are needed.

| `jac.toml` key | Description | Default |
|----------------|-------------|---------|
| `redis_insight_username` | RedisInsight basic-auth username | `admin` |
| `redis_insight_password` | RedisInsight basic-auth password | `admin` |
| `mongo_express_username` | Mongo Express login username | `admin` |
| `mongo_express_password` | Mongo Express login password | `admin` |

> **Note:** When `redis_dashboard = true`, the `/cache-dashboard` route is always protected by HTTP basic authentication using the credentials above. Change the defaults before deploying to a shared or public cluster.

**Access URLs:**

| Dashboard | URL |
|-----------|-----|
| Redis Insight | `http://localhost:<ingress_node_port>/cache-dashboard/` |
| Mongo Express | `http://localhost:<ingress_node_port>/db-dashboard` |

**Enable dashboards with custom credentials** (RedisInsight + Mongo Express):

```toml
# jac.toml
[plugins.scale.kubernetes]
redis_dashboard          = true
redis_insight_username   = "admin"
redis_insight_password   = "strongpassword"

mongodb_dashboard        = true
mongo_express_username   = "admin"
mongo_express_password   = "strongpassword"
```

---

### Memory Hierarchy

jac-scale uses a tiered memory system:

| Tier | Backend | Purpose |
|------|---------|---------|
| L1 | In-memory | Volatile runtime state |
| L2 | Redis | Cache layer |
| L3 | MongoDB | Persistent storage |

```mermaid
graph TD
    App["Application"] --- L1["L1: Volatile (in-memory)"]
    L1 --- L2["L2: Redis (cache)"]
    L2 --- L3["L3: MongoDB (persistent)"]
```

---

## Kubernetes Deployment

### Deployment Modes

| Mode | Command | Description |
|------|---------|-------------|
| **Development** | `jac start app.jac --scale` | Deploy without building a Docker image - fast iteration |
| **Production** | `jac start app.jac --scale --build` | Build and push Docker image to registry, then deploy |
| **Enable HTTPS** | `jac start app.jac --scale --enable-tls` | Enable TLS on a live deployment (no redeploy, run after CNAME propagates) |

**Production mode** requires Docker credentials in `.env`:

```env
DOCKER_USERNAME=your-dockerhub-username
DOCKER_PASSWORD=your-dockerhub-password-or-token
```

---

### Naming & Namespace

Controls the application name used for all Kubernetes resource names and the namespace resources are created in.

**Defaults:**

| TOML Key  | Default | Description |
|-----------|---------|-------------|
| `app_name` | `jaseci` | Prefix for all K8s resource names (deployments, services, secrets, etc.) |
| `namespace`| `default` | Kubernetes namespace to deploy into |

**To change in `jac.toml`:**

```toml
[plugins.scale.kubernetes]
app_name = "myapp"
namespace = "production"
```

---

### Ports

Controls how the application is exposed inside the cluster and externally.

All traffic flows through a single **NGINX Ingress controller** deployed per app. The Ingress controller listens on one NodePort and routes requests to the correct ClusterIP service based on path. Individual services (app, Grafana, dashboards) are all ClusterIP and not directly reachable from outside the cluster.

**Defaults:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `container_port`| `8000` | Port your app listens on inside the pod |
| `ingress_node_port` | `30080` | NodePort for the NGINX Ingress controller (all external traffic enters here) |

**Access URLs (local cluster):**

| Path | Destination |
|------|-------------|
| `http://localhost:30080/` | Jaseci application |
| `http://localhost:30080/grafana` | Grafana dashboard (if monitoring enabled) |
| `http://localhost:30080/cache-dashboard/` | Redis Insight (if `redis_dashboard = true`) |
| `http://localhost:30080/db-dashboard` | Mongo Express (if `mongodb_dashboard = true`) |

**To change in `jac.toml`:**

```toml
[plugins.scale.kubernetes]
container_port = 8000
ingress_node_port = 30080
```

---

### Rate Limiting (DDoS Protection)

jac-scale applies NGINX rate limiting annotations to the Ingress to protect against abuse and DDoS traffic. Limits are enforced **per client IP**.

**How it works (leaky bucket algorithm):**

- **`ingress_limit_rps`** - sustained requests per second allowed per IP.
- **`ingress_limit_burst_multiplier`** - burst = `limit_rps x burst_multiplier`. Requests within the burst are queued; requests beyond it are dropped with `429`.
- **`ingress_limit_connections`** - maximum number of concurrent open connections per IP. Excess connections are rejected immediately.

**Defaults:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `ingress_limit_rps` | `20` | Sustained requests per second per client IP |
| `ingress_limit_burst_multiplier` | `5` | Burst headroom multiplier (burst = rps × multiplier) |
| `ingress_limit_connections` | `20` | Max concurrent connections per client IP |

Requests that exceed the limits receive `429 Too Many Requests`.

**To customize in `jac.toml`:**

```toml
[plugins.scale.kubernetes]
ingress_limit_rps = 50              # allow more sustained traffic
ingress_limit_burst_multiplier = 3  # tighter burst control
ingress_limit_connections = 30      # more concurrent connections
```

---

### Sticky Sessions (Cookie-Based Affinity)

When your pods hold per-user state (e.g. running user processes), you need requests from the same user to always reach the same pod. jac-scale supports opt-in cookie-based session affinity via NGINX.

**Enabled by default.** Disable it in `jac.toml` if not needed:

```toml
[plugins.scale.kubernetes]
ingress_session_affinity = false
```

**How it works:**

On the first response, NGINX sets a `route` cookie in the browser. Every subsequent request includes that cookie and NGINX uses it to route back to the same pod, regardless of IP changes (mobile networks, NAT, VPN, proxies). The cookie never expires in the browser.

| Behaviour | Detail |
|-----------|--------|
| Cookie name | `route` |
| Cookie lifetime | Never expires (`max-age` ~68 years) |
| On pod failure | NGINX re-routes to a healthy pod and rewrites the cookie automatically |
| IP changes (mobile/NAT) | Handled correctly - routing is cookie-based, not IP-based |

**When to use:**

- Your pods run stateful per-user processes (e.g. sandbox environments, background workers per user)
- You need a user to consistently land on the pod that owns their session

**Limitations:**

Sticky sessions ensure routing **while a pod is alive**. If a pod is deleted (e.g. during a rolling deployment), in-flight user processes on that pod are lost. The user is automatically re-routed to a new pod, but any in-memory state is gone. For true resilience, externalize per-user state to Redis or a database so any pod can serve any user.

---

### Domain & TLS (HTTPS)

jac-scale supports custom domain names and automatic HTTPS via [cert-manager](https://cert-manager.io) + Let's Encrypt. TLS is a two-step process to avoid the chicken-and-egg problem (NLB hostname is unknown until after the first deploy).

#### Step 1 - Deploy (HTTP)

Set your domain in `jac.toml` and deploy normally:

```toml
[plugins.scale.kubernetes]
domain = "app.example.com"
cert_manager_email = "you@example.com"
```

```bash
jac start app.jac --scale
```

After deploy, the NLB hostname is printed:

```
Deployment complete! Service available at: http://k8s-default-...elb.amazonaws.com
Point your domain CNAME to: k8s-default-...elb.amazonaws.com
```

#### Step 2 - Add CNAME record

In your DNS registrar (Namecheap, Route 53, Cloudflare, etc.) add:

| Type | Host | Value |
|------|------|-------|
| CNAME | `app` (or `@`) | `k8s-default-...elb.amazonaws.com` |

Wait for DNS propagation (usually 1–15 minutes). Verify with `dig app.example.com`.

#### Step 3 - Enable TLS

```bash
jac start app.jac --scale --enable-tls
```

This installs cert-manager, creates a Let's Encrypt `Issuer`, patches the live Ingress with TLS annotations, and updates all service URLs to HTTPS. No redeployment of your application occurs.

Output:

```
TLS enabled. App is now live at:
  App URL:        https://app.example.com
  Grafana:        https://app.example.com/grafana
  Mongo Express:  https://app.example.com/db-dashboard
  RedisInsight:   https://app.example.com/cache-dashboard
```

> **Note:** `--enable-tls` requires `domain` to be set in `jac.toml`. It will error if no domain is configured.

**Configuration options:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `domain` | `""` | Custom domain name (e.g. `app.example.com`). Leave empty for NLB-only access. |
| `cert_manager_email` | `""` | Email for Let's Encrypt certificate registration and expiry notices. |

**Certificate renewal** is automatic - cert-manager renews ~30 days before expiry.

---

### Resource Limits

Controls CPU and memory requests/limits for the application container. Kubernetes uses requests for scheduling and limits for enforcement (OOM-kill).

**Defaults:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `cpu_request`  | None | CPU units reserved for scheduling (e.g. `"250m"`) |
| `cpu_limit`  | None | Maximum CPU the container may use (e.g. `"1000m"`) |
| `memory_request`  | None | Memory reserved for scheduling (e.g. `"256Mi"`) |
| `memory_limit` | None | Memory ceiling - container is OOM-killed if exceeded |

Accepted suffixes: `Ki`, `Mi`, `Gi` (binary) or `K`, `M`, `G` (decimal).

**To change in `jac.toml`:**

```toml
[plugins.scale.kubernetes]
cpu_request = "250m"
cpu_limit = "1000m"
memory_request = "256Mi"
memory_limit = "2Gi"
```

---

### Health Probes

Kubernetes uses readiness and liveness probes to decide when a pod is ready to serve traffic and when to restart it. Both probes hit `GET <health_check_path>` on the container.

**Defaults:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `health_check_path` | Endpoint probed by both readiness and liveness checks |
| `readiness_initial_delay` | `10` | Seconds to wait before first readiness check |
| `readiness_period` | `20` | Seconds between readiness checks |
| `liveness_initial_delay`  | `10` | Seconds to wait before first liveness check |
| `liveness_period`  | `20` | Seconds between liveness checks |
| `liveness_failure_threshold` | `80` | Consecutive failures before the pod is restarted |

**To change in `jac.toml`:**

```toml
[plugins.scale.kubernetes]
health_check_path = "/health"
readiness_initial_delay = 15
readiness_period = 10
liveness_initial_delay = 30
liveness_period = 30
liveness_failure_threshold = 5
```

> **Tip:** Set `health_check_path = "/health"` to use the built-in liveness and readiness endpoints - see [Health Checks](#health-checks).

---

### Horizontal Pod Autoscaling (HPA)

jac-scale creates a Kubernetes HPA that scales the application pod count up or down based on average CPU utilization across all pods.

**Defaults:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `min_replicas` | `1` | Minimum number of pods (HPA lower bound) |
| `max_replicas` | `3` | Maximum number of pods (HPA upper bound) |
| `cpu_utilization_target`  | `50` | Average CPU % across pods that triggers scale-out |

**To change in `jac.toml`:**

```toml
[plugins.scale.kubernetes]
min_replicas = 2
max_replicas = 10
cpu_utilization_target = 70   # Scale out when average CPU exceeds 70%
```

> HPA requires `cpu_request` to be set. Without a CPU request, Kubernetes cannot compute a utilization percentage.

---

### Persistent Storage

Controls the PersistentVolumeClaim (PVC) size for MongoDB and Redis StatefulSets. The same size applies to both.

**Default:**

| TOML Key  | Default | Description |
|----------|---------|-------------|
| `pvc_size` | `5Gi` | Storage size for each database PVC |

**To change in `jac.toml`:**

```toml
[plugins.scale.kubernetes]
pvc_size = "20Gi"
```

> **Note:** PVC size cannot be reduced after creation. Increasing it requires deleting and recreating the StatefulSet (data loss). Plan accordingly.

---

### Container Images

Controls the base images used for the application pod and init containers. Override these when you need a specific Python version or when operating in air-gapped environments.

**Defaults:**

| TOML Key  | Default | Description |
|----------|---------|-------------|
| `python_image` | `python:3.12-slim` | Base image for the application pod |
| `busybox_image` | `busybox:1.36` | Init container image used for dependency health checks |

**To change in `jac.toml`:**

```toml
[plugins.scale.kubernetes]
python_image = "python:3.11-slim"
busybox_image = "busybox:1.35"
```

---

### Additional Packages

Install extra pip packages into the pod at startup, alongside the standard Jaseci stack.

**Default:** `[]` (none)

**To add in `jac.toml`:**

```toml
[plugins.scale.kubernetes]
additional_packages = ["pandas", "scikit-learn", "python-dotenv"]
```

Packages are installed at pod startup before the application starts. For frequently-updated packages, prefer building a custom Docker image with `--build` instead to keep startup times short.

---

### Jaseci Source Pinning (Experimental)

When using `--experimental` mode, Jaseci packages are installed from the GitHub repository instead of PyPI. Pin a specific branch or commit for reproducible builds.

**Defaults:**

| TOML Key  | Default | Description |
|-----------|---------|-------------|
| `jaseci_repo_url` | `https://github.com/jaseci-labs/jaseci.git` | GitHub repository to install Jaseci packages from |
| `jaseci_branch` | `main` | Repository branch to install from |
| `jaseci_commit` | None | Specific commit SHA - leave empty for latest of the branch |

**To change in `jac.toml`:**

```toml
[plugins.scale.kubernetes]
jaseci_branch = "develop"
jaseci_commit = "a1b2c3d4"
```

---

### Package Version Pinning

Pin specific PyPI versions for Jaseci packages installed inside the pod. Use `"none"` to skip a package entirely.

**Defaults:** all packages default to `"latest"` from PyPI.

**To configure in `jac.toml`:**

```toml
[plugins.scale.kubernetes.plugin_versions]
jaclang = "0.1.5"      # Pin to a specific version
jac_scale = "latest"   # Latest from PyPI (default)
jac_client = "0.1.0"   # Specific version
jac_byllm = "none"     # Skip installation entirely
```

| Package | Description |
|---------|-------------|
| `jaclang` | Core Jac language runtime |
| `jac_scale` | This scaling plugin |
| `jac_client` | Frontend/client support |
| `jac_byllm` | LLM integration (set to `"none"` to exclude) |

---

### Monitoring Stack

jac-scale can deploy a full observability stack (Prometheus + Grafana + kube-state-metrics + node-exporter) into the same namespace as your application.

| Component | Purpose |
|-----------|---------|
| **Prometheus** | Collects and stores metrics (ClusterIP - internal only, scraped by Grafana) |
| **Grafana** | Dashboard UI - served via NGINX Ingress at `/grafana` (NodePort locally, NLB on AWS) |
| **kube-state-metrics** | K8s object state: pod counts, replica health, restart counts |
| **node-exporter** | Host-level metrics: CPU, memory, disk, network per node |

**Defaults:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `enabled` | `false` | Deploy the monitoring stack and expose the app's `/metrics` endpoint |
| `k8s_metrics_enabled` | `true` | Include kube-state-metrics and node-exporter exporters |
| `prometheus_admin_password` | `Adminpassword123` | Grafana `admin` login password |

**To enable in `jac.toml`:**

```toml
[plugins.scale.monitoring]
enabled = true
k8s_metrics_enabled = true
prometheus_admin_password = "StrongPassword123!"
```

After deployment, access:

- **Grafana:** `http://localhost:<ingress_node_port>/grafana` - log in with `admin` / `<prometheus_admin_password>`

On AWS clusters, the NGINX Ingress controller is exposed via a Network Load Balancer (NLB). Grafana is accessible at `<nlb-url>/grafana`.

**Prometheus scrape targets:**

- Jaseci application `/metrics` endpoint
- kube-state-metrics (pod, deployment, replica, restart state)
- node-exporter (CPU, memory, disk, network per node)

> To collect application metrics, also enable `[plugins.scale.metrics] enabled = true` - see [Prometheus Metrics](#prometheus-metrics).

---

### Deployment Status

Check the live health of all deployed components:

```bash
jac status app.jac
```

Displays a table with:

- **Component health** - Jaseci App, Redis, MongoDB, Prometheus, Grafana
- **Pod readiness** - `ready/total` replica count per component
- **Service URLs** - application endpoint and Grafana URL

Status values:

| Value | Meaning |
|-------|---------|
| `Running` | All pods ready |
| `Degraded` | Some pods ready, others not |
| `Pending` | Pods are starting up |
| `Restarting` | One or more pods are crash-looping |
| `Failed` | No pods are running |
| `Not Deployed` | Component was never provisioned |

---

### Resource Tagging

All Kubernetes resources created by jac-scale are labeled `managed: jac-scale` for easy auditing:

```bash
# List all jac-scale managed resources across all namespaces
kubectl get all -l managed=jac-scale -A
```

Tagged resource types: Deployments, StatefulSets, Services, ConfigMaps, Secrets, PersistentVolumeClaims, HorizontalPodAutoscalers.

---

### Remove Deployment

```bash
jac destroy app.jac
```

!!! warning
    You will be prompted to confirm with `y` before deletion proceeds. The command deletes the entire namespace and **all** its resources - including persistent volumes and database data.

Removes:

- Application Deployment and pods
- Redis and MongoDB StatefulSets
- PersistentVolumeClaims (data is lost)
- Services, ConfigMaps, Secrets, and HPA

---

## Health Checks

Built-in endpoints are available for Kubernetes probes:

- `/health` -- Liveness probe
- `/ready` -- Readiness probe

You can also create custom health walkers:

### Health Endpoint

Create a health walker:

```jac
walker health {
    can check with Root entry {
        report {"status": "healthy"};
    }
}
```

Access at: `POST /walker/health`

### Readiness Check

```jac
walker ready {
    can check with Root entry {
        db_ok = check_database();
        cache_ok = check_cache();

        if db_ok and cache_ok {
            report {"status": "ready"};
        } else {
            report {
                "status": "not_ready",
                "db": db_ok,
                "cache": cache_ok
            };
        }
    }
}
```

---

## Builtins

### Root Access

```jac
with entry {
    # Get all roots in memory/database
    roots = allroots();
}
```

### Memory Commit

```jac
with entry {
    # Commit memory to database
    commit();
}
```

---

## CLI Commands

| Command | Description |
|---------|-------------|
| `jac start app.jac` | Start local API server |
| `jac start app.jac --scale` | Deploy to Kubernetes |
| `jac start app.jac --scale --build` | Build image and deploy |
| `jac start app.jac --scale --target kubernetes` | Explicit deployment target (default) |
| `jac start app.jac --scale --enable-tls` | Enable HTTPS on a live deployment (no redeploy) |
| `jac status app.jac` | Show live deployment status |
| `jac status app.jac --target kubernetes` | Status for a specific target |
| `jac destroy app.jac` | Remove Kubernetes deployment (prompts for confirmation) |
| `jac destroy app.jac --target kubernetes` | Destroy a specific target |

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

## Prometheus Metrics

jac-scale provides built-in Prometheus metrics collection for monitoring HTTP requests and walker execution. When enabled, a `/metrics` endpoint is automatically registered for Prometheus to scrape.

### Configuration

Configure metrics in `jac.toml`:

```toml
[plugins.scale.metrics]
enabled = true                  # Enable metrics collection and /metrics endpoint
endpoint = "/metrics"           # Prometheus scrape endpoint path
namespace = "myapp"             # Metrics namespace prefix
walker_metrics = true           # Enable per-walker execution timing
histogram_buckets = [0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 10.0]
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | `false` | Enable Prometheus metrics collection and `/metrics` endpoint |
| `endpoint` | string | `"/metrics"` | Path for the Prometheus scrape endpoint |
| `namespace` | string | `"jac_scale"` | Metrics namespace prefix |
| `walker_metrics` | bool | `false` | Enable walker execution timing metrics |
| `histogram_buckets` | list | `[0.005, ..., 10.0]` | Histogram bucket boundaries in seconds |

> **Note:** If `namespace` is not set, it is derived from the Kubernetes namespace config (sanitized) or defaults to `"jac_scale"`.

### Exposed Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `{namespace}_http_requests_total` | Counter | `method`, `path`, `status_code` | Total HTTP requests processed |
| `{namespace}_http_request_duration_seconds` | Histogram | `method`, `path` | HTTP request latency in seconds |
| `{namespace}_http_requests_in_progress` | Gauge | -- | Concurrent HTTP requests |
| `{namespace}_walker_duration_seconds` | Histogram | `walker_name`, `success` | Walker execution duration (only when `walker_metrics=true`) |

### Authentication

The `/metrics` endpoint requires admin authentication. Include the admin token in the `Authorization` header:

```bash
# Scrape metrics (admin token required)
curl -H "Authorization: Bearer <admin_token>" http://localhost:8000/metrics
```

Unauthenticated requests receive a 403 Forbidden response. This protects sensitive server performance data from unauthorized access.

### Admin Metrics Dashboard

The admin portal includes a monitoring page that displays metrics in a visual dashboard. Access it at `/admin` and navigate to the Monitoring section.

Additionally, the `/admin/metrics` endpoint returns parsed metrics as structured JSON:

```bash
curl -H "Authorization: Bearer <admin_token>" http://localhost:8000/admin/metrics
```

Response format:

```json
{
  "status": "success",
  "data": {
    "metrics": [
      {
        "name": "jac_scale_http_requests_total",
        "type": "counter",
        "help": "Total HTTP requests processed",
        "values": [
          {"labels": {"method": "GET", "path": "/", "status_code": "200"}, "value": 42}
        ]
      }
    ],
    "summary": {
      "total_requests": 156,
      "avg_latency_ms": 45.2,
      "error_rate_percent": 0.5,
      "active_requests": 2
    }
  }
}
```

The admin dashboard monitoring page displays:

- HTTP traffic breakdown by method and status code
- Request latency statistics
- Active requests gauge
- System metrics (GC collections, memory usage, CPU time, file descriptors)

Requests to the metrics endpoint itself are excluded from tracking.

---

## Kubernetes Secrets

Manage sensitive environment variables securely in Kubernetes deployments using the `[plugins.scale.secrets]` section.

### Configuration

```toml
[plugins.scale.secrets]
OPENAI_API_KEY = "${OPENAI_API_KEY}"
DATABASE_PASSWORD = "${DB_PASS}"
STATIC_VALUE = "hardcoded-value"
```

Values using `${ENV_VAR}` syntax are resolved from the local environment at deploy time. The resolved key-value pairs are created as a proper Kubernetes Secret (`{app_name}-secrets`) and injected into pods via `envFrom.secretRef`.

### How It Works

1. At `jac start app.jac --scale`, environment variable references (`${...}`) are resolved
2. A Kubernetes `Opaque` Secret named `{app_name}-secrets` is created (or updated if it already exists)
3. The Secret is attached to the deployment pod spec via `envFrom.secretRef`
4. All keys become environment variables inside the container
5. On `jac destroy`, the Secret is automatically cleaned up

### Example

```toml
# jac.toml
[plugins.scale.secrets]
OPENAI_API_KEY = "${OPENAI_API_KEY}"
MONGO_PASSWORD = "${MONGO_PASSWORD}"
JWT_SECRET = "${JWT_SECRET}"
```

```bash
# Set local env vars, then deploy
export OPENAI_API_KEY="sk-..."
export MONGO_PASSWORD="secret123"
export JWT_SECRET="my-jwt-key"

jac start app.jac --scale --build
```

This eliminates the need for manual `kubectl create secret` commands after deployment.

---

## Setting Up Kubernetes

### Docker Desktop (Easiest)

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Open Settings > Kubernetes
3. Check "Enable Kubernetes"
4. Click "Apply & Restart"

### Minikube

```bash
# Install
brew install minikube  # macOS
# or see https://minikube.sigs.k8s.io/docs/start/

# Start cluster
minikube start

# Access your app via minikube service
minikube service jaseci -n default
```

### MicroK8s (Linux)

```bash
sudo snap install microk8s --classic
microk8s enable dns storage
alias kubectl='microk8s kubectl'
```

---

## Troubleshooting

### Application Not Accessible

```bash
# Check pod status
kubectl get pods

# Check service
kubectl get svc

# For minikube, use tunnel
minikube service jaseci
```

### Database Connection Issues

```bash
# Check StatefulSets
kubectl get statefulsets

# Check persistent volumes
kubectl get pvc

# View database logs
kubectl logs -l app=mongodb
kubectl logs -l app=redis
```

### Build Failures (--build mode)

- Ensure Docker daemon is running
- Verify `.env` has correct `DOCKER_USERNAME` and `DOCKER_PASSWORD`
- Check disk space for image building

### General Debugging

```bash
# Describe a pod for events
kubectl describe pod <pod-name>

# Get all resources
kubectl get all

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

---

## Library Mode

For teams preferring pure Python syntax or integrating Jac into existing Python codebases, Library Mode provides an alternative deployment approach. Instead of `.jac` files, you use Python files with Jac's runtime as a library.

> **Complete Guide:** See [Library Mode](../language/library-mode.md) for the full API reference, code examples, and migration guide.

**Key Features:**

- All Jac features accessible through `jaclang.lib` imports
- Pure Python syntax with decorators (`@on_entry`, `@on_exit`)
- Full IDE/tooling support (autocomplete, type checking, debugging)
- Zero migration friction for existing Python projects

**Quick Example:**

```python
from jaclang.lib import Node, Walker, spawn, root, on_entry

class Task(Node):
    title: str
    done: bool = False

class TaskFinder(Walker):
    @on_entry
    def find(self, here: Task) -> None:
        print(f"Found: {here.title}")

spawn(TaskFinder(), root())
```

---

## Sandbox Environments

jac-scale includes a **sandbox system** for creating isolated, ephemeral preview environments. Each sandbox runs a user's Jac application in its own container or pod with resource limits, network isolation, and automatic cleanup -- ideal for live preview, collaborative editing, or CI/CD preview deployments.

### Overview

The sandbox system follows jac-scale's factory pattern: an abstract `SandboxEnvironment` interface with three provider implementations. You choose the provider via configuration, and the factory handles instantiation.

| Provider | Isolation | Use Case |
|----------|-----------|----------|
| `local` | Subprocess | Local development, no container runtime needed |
| `docker` | Container | Staging, basic isolation with Docker |
| `kubernetes` | Pod | Production, full isolation with resource limits and RBAC |

### Configuration

Enable and configure sandboxes in `jac.toml`:

```toml
[plugins.scale.sandbox]
enabled = true
type = "kubernetes"              # "kubernetes", "docker", or "local"
namespace = "jac-sandboxes"      # K8s namespace for sandbox pods
max_per_user = 3                 # Maximum concurrent sandboxes per user
ttl_seconds = 3600               # Auto-cleanup after this many seconds (1 hour)
cpu_limit = "500m"               # CPU limit per sandbox
memory_limit = "512Mi"           # Memory limit per sandbox
base_image = "python:3.12-slim"  # Base Docker/K8s image
storage_limit = "256Mi"          # Scratch storage (/tmp) limit
domain_template = "{sandbox_id}.preview.example.com"  # URL template
security_context = true          # Run as non-root, no privilege escalation
network_isolation = true         # Isolate sandboxes from each other
ingress_class = "nginx"          # K8s Ingress class (nginx, alb, traefik)
tls_enabled = false              # Enable TLS via cert-manager
tls_issuer = "letsencrypt-prod"  # cert-manager ClusterIssuer name
proxy_mode = false               # Use shared proxy instead of per-sandbox Ingress
warm_pool_size = 0               # Pre-initialized pods for instant startup (K8s only)
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | `false` | Enable the sandbox system |
| `type` | string | `"local"` | Provider: `"kubernetes"`, `"docker"`, or `"local"` |
| `namespace` | string | `"jac-sandboxes"` | Kubernetes namespace for sandbox resources |
| `max_per_user` | int | `3` | Maximum concurrent sandboxes per user |
| `ttl_seconds` | int | `3600` | Time-to-live before automatic cleanup (seconds) |
| `cpu_limit` | string | `"500m"` | CPU limit per sandbox (K8s format) |
| `memory_limit` | string | `"512Mi"` | Memory limit per sandbox (K8s format) |
| `base_image` | string | `"python:3.12-slim"` | Base container image for sandboxes |
| `storage_limit` | string | `"256Mi"` | Ephemeral storage limit for `/tmp` |
| `domain_template` | string | `"{sandbox_id}.preview.example.com"` | URL template (`{sandbox_id}` is replaced) |
| `security_context` | bool | `true` | Enable security context (non-root, no privilege escalation) |
| `network_isolation` | bool | `true` | Isolate sandboxes from each other |
| `ingress_class` | string | `"nginx"` | Kubernetes Ingress class name |
| `tls_enabled` | bool | `false` | Enable TLS via cert-manager |
| `tls_issuer` | string | `"letsencrypt-prod"` | cert-manager ClusterIssuer name |
| `proxy_mode` | bool | `false` | Use shared routing proxy (see [Proxy Mode](#proxy-mode)) |
| `warm_pool_size` | int | `0` | Number of pre-initialized warm pods (see [Warm Pool](#warm-pool)) |

**Environment Variables (override jac.toml):**

| Variable | Description |
|----------|-------------|
| `JAC_SANDBOX_TYPE` | Provider type (`"kubernetes"`, `"docker"`, `"local"`) |
| `JAC_SANDBOX_NAMESPACE` | Kubernetes namespace |
| `JAC_SANDBOX_DOMAIN` | Domain template |

Configuration priority: `jac.toml` > environment variables > defaults.

---

### Programmatic Usage

Use `SandboxFactory` to create and manage sandboxes in your Jac code:

```jac
import from jac_scale.factories.sandbox_factory { SandboxFactory }

# Create sandbox using jac.toml config
glob sandbox = SandboxFactory.get_default();

# Or create with explicit type and config
glob sandbox = SandboxFactory.create("kubernetes", {
    "namespace": "jac-sandboxes",
    "base_image": "python:3.12-slim",
    "memory_limit": "1Gi",
    "ttl_seconds": 1800,
    "domain_template": "{sandbox_id}.preview.example.com"
});
```

#### Creating a Sandbox

```jac
with entry {
    result = sandbox.create(
        user_id="user-123",
        project_id="my-project",
        code_path="/path/to/project/files"
    );

    if result.success {
        print(f"Sandbox ready at: {result.url}");
        print(f"Sandbox ID: {result.sandbox_id}");
    }
}
```

#### Sandbox Lifecycle

```jac
with entry {
    # Check status
    status = sandbox.status("jac-sbx-abc123");
    print(f"State: {status.state}");  # pending, starting, running, stopped, error

    # List user's sandboxes
    sandboxes = sandbox.list_sandboxes("user-123");
    for s in sandboxes {
        print(f"{s.sandbox_id}: {s.state} - {s.url}");
    }

    # Stop a sandbox
    sandbox.stop("jac-sbx-abc123");

    # Destroy and clean up all resources
    sandbox.destroy("jac-sbx-abc123");

    # Clean up expired sandboxes (beyond TTL)
    cleaned = sandbox.cleanup_expired();
    print(f"Cleaned {cleaned} expired sandboxes");
}
```

#### File Operations

Read, write, and manage files inside a running sandbox:

```jac
with entry {
    # Write a file
    sandbox.write_file("jac-sbx-abc123", "main.jac", "with entry { print('hello'); }");

    # Read a file
    result = sandbox.read_file("jac-sbx-abc123", "main.jac");
    print(result["content"]);

    # Read binary files (images) -- returned as base64
    result = sandbox.read_file("jac-sbx-abc123", "assets/logo.png");
    # result = {"success": True, "content": "<base64>", "is_binary": True, "mime_type": "image/png"}

    # Delete a file
    sandbox.delete_file("jac-sbx-abc123", "old_file.jac");

    # List files
    result = sandbox.list_files("jac-sbx-abc123");
    for f in result["files"] {
        print(f);
    }
}
```

**Path Security:** All file paths are validated against directory traversal, absolute paths, and shell metacharacters. Paths like `../`, `/etc/passwd`, or strings containing `;`, `|`, `&`, `` ` `` are rejected.

**Excluded Directories:** File listing automatically skips `.jac/`, `node_modules/`, `__pycache__/`, `dist/`, and `.git/`.

#### Command Execution

```jac
with entry {
    result = sandbox.exec_command("jac-sbx-abc123", "ls -la /app", timeout=30);
    print(result["stdout"]);
}
```

#### Log Retrieval

```jac
with entry {
    result = sandbox.logs("jac-sbx-abc123", offset=0);
    print(result["content"]);
    # result["offset"] contains the byte offset for the next read (streaming)
}
```

---

### Sandbox States

| State | Description |
|-------|-------------|
| `pending` | Pod/container created, waiting to start |
| `starting` | Container starting, installing dependencies |
| `running` | Application fully ready and serving traffic |
| `stopping` | Shutdown in progress |
| `stopped` | Container stopped |
| `error` | Error or crash state |

---

### Local Sandbox Provider

The `local` provider runs each sandbox as a subprocess on the host machine. No container runtime required.

```toml
[plugins.scale.sandbox]
enabled = true
type = "local"
```

**How it works:**

- Allocates a port pair from a pool (base ports 5180-5200, stride of 2)
- Runs `jac start main.jac --dev -p {port}` as a child process
- Checks for readiness by scanning process output for `"Server ready"`
- Returns `http://localhost:{port}` as the preview URL

**Environment sourcing:**

- Global: `~/.jac-ide/global.env` (if it exists)
- Project: `.env` in the project directory (if it exists)

**Limitations:**

- No isolation between sandboxes
- No resource limits
- Port pool limits concurrent sandboxes (10 by default)
- Development and testing only

---

### Docker Sandbox Provider

The `docker` provider runs each sandbox in an isolated Docker container with resource limits.

```toml
[plugins.scale.sandbox]
enabled = true
type = "docker"
base_image = "python:3.12-slim"
memory_limit = "512Mi"
cpu_limit = "500m"
network_isolation = true
```

**How it works:**

- Creates a Docker container from `base_image`
- Copies project files into `/app` via tarball injection
- Runs `jac install && jac start main.jac --dev -p 8000`
- Applies resource limits (memory, CPU, storage)
- Optionally creates an isolated Docker bridge network per sandbox
- Polls container health via HTTP until ready (120s timeout)

**Container labels:**

| Label | Value |
|-------|-------|
| `jac-sandbox` | `true` |
| `jac-sandbox-id` | `{sandbox_id}` |
| `jac-sandbox-user` | `{user_id}` |
| `jac-sandbox-project` | `{project_id}` |

**Requirements:** Docker daemon must be running on the host.

---

### Kubernetes Sandbox Provider

The `kubernetes` provider creates isolated pods in a dedicated namespace with RBAC, resource limits, and automatic cleanup. This is the recommended provider for production.

```toml
[plugins.scale.sandbox]
enabled = true
type = "kubernetes"
namespace = "jac-sandboxes"
base_image = "python:3.12-slim"
memory_limit = "2Gi"
cpu_limit = "500m"
ttl_seconds = 3600
max_per_user = 3
security_context = true
```

**How it works:**

1. Ensures namespace exists with label `jac-sandbox: namespace`
2. Provisions RBAC (ServiceAccount, Role, RoleBinding) for pod management
3. Packages project files into a ConfigMap (text files in `data`, binary files in `binaryData` as base64)
4. Creates a pod with an init container that unpacks the ConfigMap into `/app`
5. Main container runs `jac install && jac start main.jac --dev -p 8000`
6. Creates a Service and Ingress (unless `proxy_mode = true`)
7. Polls pod readiness (container ready + "Server ready" in logs, 120s timeout)
8. Returns the preview URL

**Pod naming:** `jac-sbx-{user}-{project}-{uuid}` (lowercase, max 63 chars per K8s requirements)

**Pod labels:**

| Label | Value |
|-------|-------|
| `jac-sandbox` | `true` |
| `jac-sandbox-id` | `{sandbox_id}` |
| `jac-sandbox-user` | `{user_id}` |
| `jac-sandbox-project` | `{project_id}` |

**Environment variables injected into sandbox pods:**

| Variable | Value | Purpose |
|----------|-------|---------|
| `JAC_SANDBOX_ID` | `{sandbox_id}` | Sandbox identifier |
| `JAC_SANDBOX_USER` | `{user_id}` | Owner user ID |
| `JAC_SANDBOX_PROJECT` | `{project_id}` | Project ID |
| `CHOKIDAR_USEPOLLING` | `1` | Force file watcher to use polling (for HMR) |
| `WATCHPACK_POLLING` | `true` | Webpack polling fallback (for HMR) |

**Resource configuration:**

- Limits: `cpu_limit`, `memory_limit` from config
- Requests: 100m CPU, 64Mi memory (fixed)
- Scratch storage: `storage_limit` as tmpfs on `/tmp`
- Active deadline: `ttl_seconds` (K8s kills the pod after this)
- Graceful shutdown: 10 seconds

**Security context (when enabled):**

- `runAsNonRoot: true`
- `runAsUser: 1000`
- `allowPrivilegeEscalation: false`

**ConfigMap limits:** Project files are packed into a single ConfigMap with a 1MB size limit. Binary files (images, fonts, etc.) are stored in the `binaryData` field using base64 encoding. Files in `.jac/`, `node_modules/`, `__pycache__/`, `dist/`, and `.git/` directories are excluded.

**RBAC auto-provisioning:** On first use, the provider creates a Role (`jac-sandbox-manager`) and RoleBinding in the sandbox namespace with permissions for pods, services, configmaps, and ingresses. If running inside a K8s cluster, it binds the role to the pod's ServiceAccount (via `POD_SERVICE_ACCOUNT` and `POD_NAMESPACE` environment variables).

**Automatic cleanup:** A background thread runs every 60 seconds and:

1. Lists all sandbox pods in the namespace
2. Deletes pods older than `ttl_seconds`
3. Deletes pods in terminal states (Failed, Succeeded)
4. Purges stale registry entries for pods that no longer exist

---

### Ingress Routing

When using `type = "kubernetes"`, sandboxes need to be accessible from the browser. There are two routing modes:

#### Per-Sandbox Ingress (default)

Each sandbox gets its own Kubernetes Ingress resource:

```toml
[plugins.scale.sandbox]
proxy_mode = false              # default
ingress_class = "nginx"         # or "alb", "traefik"
domain_template = "{sandbox_id}.preview.example.com"
tls_enabled = true
tls_issuer = "letsencrypt-prod"
```

**Traffic flow:**

```
Browser → Load Balancer → Ingress ({sandbox_id}.preview.example.com) → Service → Pod
```

Each sandbox creates:

- A `ClusterIP` Service: `{sandbox_id}-svc`
- An Ingress resource: `{sandbox_id}-ingress` with the configured hostname

**Custom Ingress annotations:**

```toml
[plugins.scale.sandbox.ingress_annotations]
"nginx.ingress.kubernetes.io/proxy-read-timeout" = "3600"
"nginx.ingress.kubernetes.io/proxy-send-timeout" = "3600"
```

**TLS:** When `tls_enabled = true`, cert-manager is used to automatically provision TLS certificates. Requires a `ClusterIssuer` named `tls_issuer` to be deployed in the cluster.

**Drawback:** Creating per-sandbox Ingress resources is slow on some cloud providers (e.g., AWS ALB target group registration takes 30-60 seconds).

#### Proxy Mode

A single shared proxy service routes traffic to all sandboxes by pod IP. No per-sandbox Ingress or Service is created.

```toml
[plugins.scale.sandbox]
proxy_mode = true
domain_template = "{sandbox_id}.preview.example.com"
```

**Traffic flow:**

```
Browser → Load Balancer → Wildcard Ingress (*.preview.example.com) → Proxy Service → Pod IP
```

**How it works:**

1. A single proxy deployment runs in the sandbox namespace (2 replicas recommended)
2. The proxy watches all pods labeled `jac-sandbox=true` via the Kubernetes Watch API
3. It maintains an in-memory routing table: `sandbox_id → {ip, phase, ready}`
4. Incoming requests have their `Host` header parsed to extract the `sandbox_id` (e.g., `jac-sbx-abc.preview.example.com → jac-sbx-abc`)
5. HTTP requests are forwarded to `http://{pod_ip}:8000{path}`
6. WebSocket connections are bidirectionally relayed (supports Vite HMR with `vite-hmr` sub-protocol)

**Loading page:** When a sandbox pod isn't ready yet, the proxy returns an auto-refreshing HTML page with a loading spinner. The page refreshes every 2 seconds until the pod is ready, then serves the actual application. This only applies to browser navigation requests (`Accept: text/html`); API calls receive proper 502/503 status codes.

**Advantages over per-sandbox Ingress:**

- Instant routing (no Ingress provisioning delay)
- No per-sandbox K8s resources (Service, Ingress)
- Scales to hundreds of concurrent sandboxes
- Native WebSocket support for HMR

**Proxy environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `SANDBOX_NAMESPACE` | `jac-sandboxes` | Namespace to watch for sandbox pods |
| `SANDBOX_LABEL` | `jac-sandbox=true` | Label selector for sandbox pods |
| `INTERNAL_PORT` | `8000` | Port on sandbox pods |
| `PROXY_PORT` | `8080` | Port the proxy listens on |

**Deploying the proxy:** K8s manifest templates are included in `jac-scale/targets/kubernetes/templates/sandbox-proxy/`:

- `rbac.yaml` -- ServiceAccount + Role (get/list/watch pods) + RoleBinding
- `deployment.yaml` -- 2-replica Deployment (replace `REPLACE_WITH_IMAGE` with your built proxy image)
- `service.yaml` -- ClusterIP Service on port 8080
- `ingress.yaml` -- Wildcard Ingress (replace `*.example.com` with your domain)

The proxy itself is a Jac application at `jac-scale/providers/proxy/sandbox_proxy.jac`. Build it with the provided Dockerfile at `jac-scale/targets/kubernetes/templates/sandbox-proxy.Dockerfile`:

```dockerfile
FROM python:3.12-slim
RUN pip install --no-cache-dir aiohttp kubernetes_asyncio jaclang "jac-scale[all]"
COPY sandbox_proxy.jac /app/sandbox_proxy.jac
WORKDIR /app
EXPOSE 8080
CMD ["jac", "run", "sandbox_proxy.jac"]
```

**Health check endpoint:** `GET /_proxy/health` returns `ok (N routes)` where N is the number of tracked sandbox pods.

---

### Warm Pool

The warm pool pre-creates idle pods that are ready to accept code instantly, eliminating pod scheduling and image pull delays.

```toml
[plugins.scale.sandbox]
type = "kubernetes"
warm_pool_size = 3    # Keep 3 idle pods ready
```

**How it works:**

1. On startup, the provider creates `warm_pool_size` pods using `base_image`
2. Warm pods run a wait loop: `while [ ! -f /app/.jac-start ]; do sleep 0.5; done`
3. When a sandbox is requested, a warm pod is claimed and relabeled with the user's sandbox ID
4. Project code is injected via `kubectl exec` (tar stream piped into the pod)
5. A signal file (`/app/.jac-start`) is touched, triggering `jac install && jac start`
6. The pool automatically replenishes in the background

**Warm pod labels:**

| Label | Value |
|-------|-------|
| `jac-sandbox` | `true` |
| `jac-sandbox-pool` | `warm` (idle) or `active` (claimed) |

**Benefits:**

- Eliminates ~10 seconds of pod scheduling + image pull time
- No ConfigMap creation needed (code is injected directly)
- Pool replenishes automatically after each claim

**Fallback:** If no warm pod is available (pool exhausted), the provider falls back to the standard cold-start path (ConfigMap + new pod creation).

---

### HMR (Hot Module Replacement) Support

When using `proxy_mode = true`, Vite HMR works through the proxy:

```
Browser (Vite client) ←→ Proxy (WebSocket relay) ←→ Pod (Vite dev server)
```

The proxy:

- Detects WebSocket upgrade requests via the `Upgrade: websocket` header
- Forwards the `Sec-WebSocket-Protocol` header (e.g., `vite-hmr`) to the backend
- Uses a separate session with no timeout for long-lived WebSocket connections
- Bidirectionally relays `TEXT` and `BINARY` messages
- Properly propagates close events between both sides

**File watcher polling:** Sandbox pods have `CHOKIDAR_USEPOLLING=1` and `WATCHPACK_POLLING=true` environment variables set. This forces Vite's file watcher to use polling instead of `inotify`, which is necessary because files written via `kubectl exec` don't trigger filesystem notification events.

---

### Troubleshooting

#### Sandbox pod stuck in Pending

```bash
kubectl describe pod <pod-name> -n jac-sandboxes
```

Check events for scheduling failures, insufficient resources, or image pull errors.

#### Preview shows loading page indefinitely

```bash
# Check if pod is running
kubectl get pods -n jac-sandboxes -l jac-sandbox-id=<sandbox-id>

# Check pod logs
kubectl logs <pod-name> -n jac-sandboxes -c sandbox
```

Common causes: `jac install` failing (missing dependencies), port conflict, application crash.

#### ConfigMap too large

If your project exceeds the 1MB ConfigMap limit, consider:

- Using `warm_pool_size > 0` (warm pools inject code via tar, no size limit)
- Adding large files to the base image instead
- Excluding unnecessary files from the project directory

#### HMR not updating the preview

Verify the proxy is forwarding WebSocket traffic:

```bash
# Check proxy logs
kubectl logs -l app=sandbox-proxy -n jac-sandboxes

# Verify proxy health
curl http://<proxy-service>:8080/_proxy/health
```

#### Cleaning up stuck sandboxes

```bash
# List all sandbox pods
kubectl get pods -n jac-sandboxes -l jac-sandbox=true

# Delete a specific sandbox
kubectl delete pod <pod-name> -n jac-sandboxes

# Delete all sandboxes
kubectl delete pods -n jac-sandboxes -l jac-sandbox=true
```

---

## Related Resources

- [Local API Server Tutorial](../../tutorials/production/local.md)
- [Kubernetes Deployment Tutorial](../../tutorials/production/kubernetes.md)
- [Backend Integration Tutorial](../../tutorials/fullstack/backend.md)
