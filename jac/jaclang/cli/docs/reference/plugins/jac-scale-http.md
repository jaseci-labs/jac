# Scale -- HTTP API & Walkers

> Part of the [Scale subsystem](jac-scale.md).

## Starting a Server

### Basic Server

!!! note
    `main.jac` is the default entry point. If your entry point has a different name (e.g., `app.jac`), pass it explicitly: `jac run app.jac`.

```bash
jac run
```

### Server Options

| Option | Description | Default |
|--------|-------------|---------|
| `--port` `-p` | Server port (auto-fallback if in use) | 8000 |
| `--main` `-m` | Treat as `__main__` | true |
| `--faux` `-f` | Print generated API docs only (no server) | false |
| `--dev` `-d` | Enable HMR (Hot Module Replacement) mode | false |
| `--api_port` `-a` | Separate API port for HMR mode (0=same as port) | 0 |
| `--no-client` `-n` | Skip client bundling/serving (API only) | false |
| `--profile` | Configuration profile to load (e.g. prod, staging) | - |
| `--host` | Mobile dev: host/IP the device reaches this machine on (a LAN address is auto-selected when omitted) | - |
| `--platform` | Mobile apps: `android` or `ios` runs on a device or simulator, `web` runs the same app in a browser via react-native-web (`auto` uses the app's `[apps.<name>] platform`, or android) | auto |
| `--fleet` | Run the workspace's service apps as separate local processes instead of colocating them in this server | false |
| `--target` | Deployment target (kubernetes, aws, gcp) | kubernetes |
| `--enable-tls` | Enable HTTPS via Let's Encrypt (run after pointing your domain CNAME to the NLB) | false |
| `--dry-run` | Print the manifests that would be applied; change nothing | false |
| `--show-yaml` | With `--dry-run`: dump the raw YAML stream | false |

### Examples

```bash
# Custom port
jac run --port 3000

# Development with HMR (client framework built into jaclang core)
jac run --dev

# API only -- skip client bundling
jac run --dev --no-client

# Preview generated API endpoints without starting
jac run --faux

# Production with profile
jac run --port 8000 --profile prod
```

### Default Persistence

When running locally (that is, not deployed with `jac scale deploy`), Jac uses the **embedded Postgres** store by default: it boots lazily on first graph access, keeping one database per project in the shared embedded cluster under the machine-wide jac cache (`~/.cache/jac/pg/main`). No external database setup is required for development; set `JAC_DB_URL` (or `[scale.database] url`) to point at an external Postgres instead.

Persistence is Postgres-native everywhere: the same store serves local `jac run`, served projects, and `jac scale deploy` deployments, with full schema-migration support (fingerprints, drift repair, and the quarantine sidecar). See [CLI -> Database Operations](../cli/index.md#database-operations) and [Persistence & Schema Migration](../persistence.md) for the full model.

```bash
# Inspect a live deployment's database.
jac db inspect --app app.jac

# Operator rescue: register a class-rename alias in production without redeploying.
jac db alias add "old.module.LegacyName" "new.module.NewName" --app app.jac
jac db recover-all --app app.jac
```

### Server Configuration

The listener, worker fleet, limits, timeouts, TLS, proxy trust, access log
and compression are all `[serve]` settings, shared by every server this
runtime starts; see [Configuration -> [serve]](../config/index.md#serve).
The only `[scale.server]` key left is logging shape:

```toml
[scale.server]
structured_logs = true               # JSON log handler on the root logger at boot
```

Set `[serve] docs_enabled = false` to turn off Swagger UI and the OpenAPI
document in production, and `[serve.access_log] suppress_health_checks = true`
to keep probe traffic out of the access log.

### CORS Configuration

In single-process `jac run` mode the server installs a permissive
CORS middleware (`allow_origins=['*']`, methods `GET`/`POST`/`PUT`/`OPTIONS`,
headers `Content-Type`/`Authorization`); there is
no `[scale.cors]` knob to tune it.

When a workspace's service apps run as a **fleet** (`jac run <app> --fleet`,
`[scale.gateway] colocate = false`, or any deploy), the gateway that fronts
them exposes a configurable CORS section:

```toml
[scale.gateway.cors]
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

Responses are wrapped in a JSON envelope. Walker `report` values arrive in
`data.reports`; a function's return value arrives in `data.result`:

```json
{
  "ok": true,
  "type": "response",
  "data": { "result": null, "reports": [ ... ] },
  "error": null,
  "meta": { }
}
```

Failures keep the same shape with `"ok": false` and an `error` object:

```json
{ "ok": false, "error": { "code": "EXECUTION_ERROR", "message": "..." } }
```

Generated client stubs unwrap this for you. When calling from outside Jac,
read `data.reports` for walkers and `data.result` for functions.

Functions can opt out of the envelope entirely with
`@restspec(envelope=False)` when the caller needs the raw bytes -- see
[Raw Response Bodies](#raw-response-bodies).

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
| `produces` | `str` | `""` (`text/plain`) | `Content-Type` of the response body. Only meaningful with `envelope=False` |
| `envelope` | `bool` | `True` | When `False`, the function's return value becomes the response body verbatim instead of being wrapped in the JSON envelope. **Functions only** |

The first four options shape the **request** (how the endpoint is reached);
`produces` and `envelope` shape the **response** (what comes back).

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

### Raw Response Bodies

By default every response is wrapped in the JSON transport envelope (see
[Response Format](#response-format)). Some endpoints cannot be: a shell
installer served for `curl | bash`, a `robots.txt`, an RSS feed, a
`.well-known` document. `envelope=False` returns the function's value as the
response body verbatim, and `produces` types it:

```jac
import from http { HTTPMethod }

@restspec(
    method=HTTPMethod.GET,
    path="/install.sh",
    produces="text/x-shellscript",
    envelope=False
)
def :pub install_sh() -> str {
    return "#!/usr/bin/env bash\necho installing...\n";
}
```

```bash
$ curl -sS -D- http://localhost:8000/install.sh
HTTP/1.1 200 OK
content-type: text/x-shellscript; charset=utf-8

#!/usr/bin/env bash
echo installing...
```

So `curl -fsSL http://localhost:8000/install.sh | bash` works. Without
`envelope=False` the shell would instead receive
`{"ok":true,"data":{"result":"#!/usr/bin/env bash\n..."}}`.

The HTTP concerns stay on the declaration, so the body remains an ordinary
`-> str` with no transport types in it.

!!! note "Root paths are available"
    Function endpoints are registered ahead of the static-asset catch-all, so
    a `path` like `/install.sh` or `/robots.txt` binds to your function and
    never reaches asset resolution.

#### Limits

- **Functions only.** A walker can `report` any number of times, so there is
  no single value to project onto a raw body. `envelope=False` on a walker
  has no effect.
- **Text only.** A `bytes` return is stringified by `Serializer` before the
  response layer sees it, so binary payloads are not yet expressible. Serve
  those as static assets.
- **Errors keep the envelope.** A failing call still returns the JSON error
  envelope with its usual status code, so a 500 is never mistaken for a valid
  payload of the declared content type. Callers should check the status, and
  `curl -f` does this for you.

Omitting `produces` yields `text/plain; charset=utf-8`. A non-`str` return is
JSON-encoded into the body, but still without the envelope around it -- useful
when a third-party client expects a bare JSON document:

```jac
@restspec(method=HTTPMethod.GET, path="/.well-known/jac.json",
          produces="application/json", envelope=False)
def :pub well_known() -> dict {
    return {"version": "1.0"};   # body is exactly {"version": "1.0"}
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

Passwords are hashed with [scrypt](https://en.wikipedia.org/wiki/Scrypt) (random salt per password, stdlib `hashlib.scrypt`). Plain-text passwords never leave the request handler.

### Storage

Identity data lives in the same Postgres database as the graph -- the project's database in the machine's shared embedded cluster locally, or whatever `[scale.database].url` / `JAC_DB_URL` points at:

```toml
# jac.toml -- use an external Postgres server
[scale.database]
url = "postgresql://user:pass@host:5432/jac"
```

```bash
# Or via environment variable
export JAC_DB_URL="postgresql://user:pass@host:5432/jac"
```

With nothing configured, the embedded server provisions automatically with no additional setup. Serving without any reachable database fails loudly at startup rather than silently opening a second credential store.

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

The key pattern blocks operator-style key injection (`$where`), dot-path traversal, and JS prototype pollution (`__proto__`). Profile is stored under the `profile` key of the user document, never spread into the document root, so a profile key cannot collide with `role` / `user_id` / etc.

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

Configure signing via `jac.toml` or environment variables:

```toml
[serve.auth]
secret = "your-secret-key-here"
algorithm = "HS256"
token_ttl_days = 7
```

| Variable | `jac.toml` key | Description | Default |
|----------|---------------|-------------|---------|
| `JAC_SERVE_AUTH_SECRET` | `secret` | Secret key for JWT signing | unset: a dev server mints one per project into `.jac/data/jwt_secret` |
| `JAC_SERVE_AUTH_ALGORITHM` | `algorithm` | JWT signing algorithm | `HS256` |
| `JAC_SERVE_AUTH_TOKEN_TTL_DAYS` | `token_ttl_days` | Token expiration in days | `7` |

!!! warning "Production: set the JWT secret"
    Left unset, the secret is minted per project into `.jac/data/jwt_secret` -- fine for a dev server, wrong for a cluster, where it would be per-replica. A cluster with none configured refuses to start rather than signing with a placeholder; `jac scale deploy` mints a random secret into the app Secret as `JAC_SERVE_AUTH_SECRET` when neither `[serve.auth] secret` nor `[scale.secrets]` provides one.

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

### Legacy Credentials

User records live in the Postgres identity store in the identity + credential format from the start -- there is no automatic startup migration. Passwords are **scrypt**-hashed; a stored hash in the older bcrypt format can never verify, and a login attempt against one logs a warning telling the operator what to do.

The recovery path is an admin action: `POST /admin/users/expire-legacy-credentials` (admin-token-gated; pass `username` to target one user, omit it to sweep everyone) flags every user whose password hash predates the scrypt scheme with `requires_password_reset`. Affected users then go through the normal [password reset](#forgot-password) flow; `root_id`, `role`, and all other fields are preserved.

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
- Stored in the Postgres `kv_state` table with a row expiry (`expires_at`) when the store is reachable, in-process otherwise.

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
jac run
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
jac run
```

Run `jac run` from the directory containing `myapp/` so the package is importable. The factory verifies `issubclass(SendGridEmailer, Emailer)` at startup; on a typo or wrong base class it logs an error and disables email (the server keeps running).

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

Levels are members of the ambient `AccessLevel` enum (no import needed):

| Level | Value | Description |
|-------|-------|-------------|
| `AccessLevel.NO_ACCESS` | `-1` | No access to the object |
| `AccessLevel.READ` | `0` | Read-only access |
| `AccessLevel.CONNECT` | `1` | Can traverse edges to/from this object |
| `AccessLevel.WRITE` | `2` | Full read/write access |

### Granting Permissions

#### To Everyone

Use `perm_grant` to allow all users to access an object at a given level:

```jac
with entry {
    # Allow everyone to read this node
    perm_grant(node, AccessLevel.READ);

    # Allow everyone to write
    perm_grant(node, AccessLevel.WRITE);
}
```

#### To a Specific Root

Use `allow_root` to grant access to a specific user's root graph:

```jac
with entry {
    # Allow a specific user to read this node
    allow_root(node, target_root_id, AccessLevel.READ);

    # Allow write access
    allow_root(node, target_root_id, AccessLevel.WRITE);
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
    disallow_root(node, target_root_id, AccessLevel.READ);
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
| `github_secret` | string | `""` | Secret that `scheme="github"` walkers verify `X-Hub-Signature-256` against (the GitHub App's webhook secret). Boot fails if a github-scheme walker exists and this is empty. |
| `github_signature_header` | string | `"X-Hub-Signature-256"` | Header carrying the GitHub-style signature for `scheme="github"` walkers. |

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

> **Note:** API key metadata is stored persistently in the Postgres store (in the `jac_docs` table under the `webhook_api_keys` collection), so keys survive server restarts. If the store is unreachable, keys fall back to in-memory only.

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

#### GitHub-Signed Webhooks (`scheme="github"`)

Providers such as GitHub sign the raw body with a shared secret and cannot send an API key. Declare the scheme on the walker and the endpoint switches verification:

```jac
@restspec(protocol=APIProtocol.WEBHOOK, scheme="github")
walker GithubEvent {
    has event: str = "",      # copied from X-GitHub-Event
        delivery: str = "",   # copied from X-GitHub-Delivery
        action: str = "",
        installation: dict[str, any] = {};

    can handle with Root entry {
        report {"event": self.event, "action": self.action};
    }
}
```

- No `X-API-Key`. The runtime verifies `X-Hub-Signature-256` (`sha256=` plus HMAC-SHA256 of the raw body, keyed by `[scale.webhook].github_secret`; the prefix is optional).
- No timestamp window: GitHub sends none, and only the body is signed, so `X-GitHub-Event` and `X-GitHub-Delivery` are not authenticated. Deduping on `X-GitHub-Delivery` absorbs GitHub's own redeliveries, not a captured body replayed with a new delivery id.
- Deliveries must be `application/json`. GitHub's default content type (`application/x-www-form-urlencoded`, the JSON inside a `payload=` field) is refused with 415, so a misconfigured webhook shows up in the delivery log instead of running the walker with every field at its default.
- The walker runs as the system identity (the user the scheduler runs jobs as, created at boot) and resolves its own tenant from the payload. Boot fails when `[scale.webhook].github_secret` is empty or that identity is missing.
- `X-GitHub-Event` and `X-GitHub-Delivery` are copied into `event` and `delivery` when the walker declares them, and win over same-named body keys.
- The body size cap and the per-minute rate limit apply; the rate limit is keyed by walker name.
- The default scheme (`scheme` omitted or `"jac"`) is unchanged, and both kinds of walker can coexist in one app.

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

## Service Apps (cross-app bridging)

A Jac workspace splits one codebase into **apps** (`[apps.<name>]` tables in `jac.toml`; see [Workspaces & Apps](../apps.md)). Every app boundary compiles as a cut: when server-side code in one app imports a walker or `def:pub` function that **another app owns**, the import generates a typed-async bridge stub at compile time, so the call becomes an RPC you `await` -- with no import form, no routes table, and no change at the call site whether the provider runs in the same process or on another machine.

### Overview

A plain import bridges the boundary in two flavors depending on where the importer lives:

- **client-to-server**: client code calls server functions or spawns server walkers. Calls go over HTTP from browser to server.
- **app-to-app (server-to-server)**: server code in one app calls into another app of the workspace. Calls go to the provider app -- in-process when it is colocated, over HTTP when it runs as its own process.

In the app-to-app flavor, `orders/main.jac` (the `orders` app) doing `import from core.inventory { check_stock }` -- with `core/inventory.jac` the entry file of `[apps.inventory]` -- does not load the inventory code into its own process as an ordinary import would. Calling `await check_stock(sku)` issues `POST /function/check_stock` against the inventory app (or invokes it directly when colocated) and returns the typed result. The same source runs unchanged colocated (`jac run orders`), as a local fleet (`jac run orders --fleet`), or deployed (`jac scale deploy`).

Both `def:pub` functions and walkers can cross the boundary. Function imports POST to `/function/<name>` and return the function's value. Walker imports POST to `/walker/<name>` and return the rehydrated walker instance with its `has` fields populated and `reports` attached, so call sites read the result the same way they would after a local spawn. See [Walker Imports](#walker-imports) for the wire shape and ergonomics.

For a step-by-step walkthrough that covers project setup, running both apps, and watching the round-trip, see the [Service Apps tutorial](../../tutorials/production/microservices.md). The rest of this section is a reference for the ownership and discovery rules, the wire contract, and the `sv_client` surface.

### Requirements

A few preconditions for cross-app calls to work:

- **The provider is another app.** The imported element must be owned by a different `[apps.<name>]` entry than the importing module -- a file-rooted `service` app (`entry-point = "<file>"`), or a server-placed shared module whose single serving owner is another app. An import within one app, or of shared code with no server placement, is an ordinary in-process import.
- **`pub` on the bridge surface.** An app's bridge surface is its walkers and its `def:pub` functions; a call to anything else is `E5106` at compile time. Non-public functions are not endpoints on the provider either.
- **`await` the call.** Bridge stubs are coroutines in every context; a missing `await` is `E1042` from `jac check`.
- **No cycles.** The app graph (consumer → provider edges) must be a DAG; `E5104` names a cycle.
- **jac-scale for a fleet.** Colocation, explicit URLs and env vars work with any jaclang install. Running service apps as separate local processes (`--fleet`) and deploying them is provided by the built-in `scale` subsystem.

### Boundary Types

Types that cross the app boundary use the same wire contract as client-to-server interop. The compiler emits a matching wrapper on the consumer side for every type referenced in a bridged import, so values serialize transparently into JSON on the way out and deserialize back into the declared type on the way in.

What works:

- **`obj` types** -- fields hydrated recursively, including inherited fields, objects inside lists and dictionaries, optional fields, and recursive type declarations. Nested types are included even when the consumer imports only the function or the outer type. Import aliases on either side refer to the same consumer-side type.
- **`enum` types** -- serialized by name.
- **Primitives** -- `int`, `float`, `str`, `bool`, `None`, `list[T]`, `dict[K, V]`.
- **Bidirectional** -- typed function arguments are wrapped on the way out and unwrapped on the way in.
- **walkers** -- when imported by name. The consumer-side stub mirrors the provider's `has` fields, and the round-trip rehydrates the walker into a real instance with `reports` populated. See [Walker Imports](#walker-imports).

Reconstruction uses the `_jac_type_id` identity in API responses and the boundary
types collected by the compiler. An identity names the declaring module, and the
app as well when that module is an app's entry file, so unrelated types with the
same name remain distinct while aliases of one declaration share a consumer-side
type, whichever app compiled the module. It applies to function results, walker fields,
and reports, including when services run in separate processes. Ordinary
dictionaries stay dictionaries. Forwarding a reconstructed value preserves its
nested type markers and inherited fields, including when passed to a typed
service parameter. Reconstruction only uses the declared boundary types; it
does not import or execute the provider module.

Browser stubs resolve field and function-signature types in their declaring
modules too. Imports and re-exported aliases retain the matching boundary class,
even when several providers declare types with the same name.

What doesn't:

- **Anchors, closures** -- not wire-friendly. Pass identifiers (e.g. `jid`) and re-resolve on the other side.
- **Live database handles, file handles** -- app-local resources only.

### Failures: the `BridgeError` family

An awaited cross-app call fails the way an in-process spawn fails -- with an exception at the call site -- and the exception says what went wrong on the wire. All four classes live in `jaclang.server.bridge` and carry `app`, `name`, `detail` and `status`:

| Exception | When |
|---|---|
| `BridgeUnavailable` | No route to the provider app: not registered, not colocated, connection refused, no `JAC_APP_<APP>_URL` |
| `BridgeTimeout` | The provider did not answer within the RPC timeout |
| `BridgeRejected` | The provider answered 4xx: unknown or non-`pub` element, unauthorized, bad arguments |
| `BridgeError` | Any other failure (5xx, malformed envelope); the base class of the three above |

```jac
import from jaclang.server.bridge { BridgeError, BridgeUnavailable }
import from core.inventory { check_stock }

async def:pub reserve(sku: str) -> str {
    try {
        stock = await check_stock(sku);
    } except BridgeUnavailable {
        return "inventory offline";
    } except BridgeError as e {
        return f"inventory error: {e.detail}";
    }
    return "ok" if stock.available else "sold out";
}
```

Client code gets the same four classes from `@jac/runtime` (`import from "@jac/runtime" { BridgeError, BridgeUnavailable, BridgeTimeout, BridgeRejected }`); `__jacCallFunction` / `__jacSpawn` throw them for fetch failures, aborts, 401/403/404, and other non-2xx responses respectively.

### Walker Imports

A consumer can import a walker from another app the same way it imports a function. The compiler generates a stub class on the consumer side whose name and `has` field shape mirror the provider's walker, so type identity is preserved and the call site reads like a local construction -- awaited.

```jac
# core/notify.jac -- the entry file of [apps.notify] (provider)
walker Greet {
    has name: str;
    can greet with Root entry {
        report f"hello, {self.name}";
    }
}

# dispatcher/main.jac -- the [apps.dispatcher] app (consumer)
import from core.notify { Greet }        # owned by the notify app -> bridge stub

walker:pub TriggerGreet {
    has who: str;
    async can run with Root entry {
        rg = await Greet(name=self.who);   # POST /walker/Greet on the notify app
        report rg.reports[0];              # "hello, <who>"
    }
}
```

What happens when the consumer evaluates `await Greet(name=self.who)`:

1. The stub class collects the keyword arguments into a JSON dict (boundary-typed values are serialized via `_to_wire` first).
2. The runtime spawns the walker on the provider app through `sv_client.spawn_walker("notify", "Greet", kwargs, cls)`, using the dispatch chain below (local registration → test client → registered URL → `JAC_APP_NOTIFY_URL`).
3. The provider spawns and runs the walker, then returns a `TransportResponse` envelope whose `data.result` is the executed walker as a dict and whose `data.reports` is the list of values it emitted via `report`.
4. The consumer rehydrates `data.result` into an instance of the local stub class, attaches `data.reports` as the instance's `reports` attribute, and returns it.

The result is a normal walker instance on the consumer: `rg.name`, `rg.reports[0]`, and `isinstance(rg, Greet)` all work. Boundary-typed values inside the walker's `has` fields and inside the `reports` list are unwrapped recursively, so a walker that emits an `obj` type comes back as that type, not as a raw dict.

A few notes:

- **Spawn semantics, not construction.** Locally, `Greet(name="x")` only constructs a walker; you still need `spawn` to run it. Across the boundary, instantiating a bridged walker is **spawn-and-execute** -- there is no useful concept of an unexecuted remote walker. The consumer-side class accepts only the `has` fields as keyword arguments and, awaited, always yields a post-execution instance.
- **Un-awaited = deferred.** A bridged walker spawn in statement position that is not awaited is not a bug the runtime ignores: it lowers to `Greet._deferred(**kwargs)`, an [outbox](#deferred-delivery-the-outbox) enqueue that never raises at the call site.
- **Boundary types travel with the walker.** Types used in `has` fields or `report` arguments need to be imported alongside the walker.
- **Same retry, breaker, auth, and tracing as functions.** Walker and function calls share the per-provider circuit breaker and `rpc_timeout`; the inbound `Authorization` header and `X-Trace-Id` are forwarded across the hop.

Walker spawns also cross the **client-to-server** boundary (`root spawn Greet(...)` from a page or a mobUI screen), through the same stub shape on the JS side.

### Deferred delivery: the outbox

An un-awaited cross-app walker spawn is a message, not a call. It is written to the **outbox** inside the caller's request -- in the same transaction where the store allows it -- and delivered to the owner app by a background worker that the server (core or scale, colocated or a fleet member) starts as soon as a bridging consumer is loaded:

- **Idempotency key.** Every entry carries one, sent on the wire as `X-Jac-Idempotency-Key` on every transport (in-process, plain HTTP and the scale RPC path alike); the receiving app remembers recent keys (an in-memory LRU plus the store) and answers a duplicate with the original result, so delivery is **at-least-once with idempotent receipt**. The default key is a hash of the app, walker and canonical arguments; `outbox.enqueue(app, walker, kwargs, idempotency_key=...)` sets an explicit one when the arguments alone are not identity (e.g. a retryable "charge card" whose amount could legitimately repeat).
- **Dedupe window.** The key also dedupes the _sender_: within `DELIVERED_TTL_S` (24h) an identical un-awaited spawn -- same app, walker and arguments, hence the same default key -- is the same message and is dropped, whether the first copy is still pending or already delivered. To spawn twice on purpose, pass a distinct `idempotency_key=`. Delivered rows older than the TTL and expired receiver keys are pruned by every worker pass, after which the same spawn is a new message.
- **Receiver scoping.** The receiving endpoint scopes a key by the authenticated caller, the provider app and the walker or function before it looks the key up or remembers it, so one client cannot replay another client's cached response by sending its key. The wire header is the raw key; scoping is internal.
- **Retries and leases.** Exponential backoff per attempt, capped; after `DEFAULT_MAX_ATTEMPTS` (8) the entry is marked `dead`. A worker claims a row with a `LEASE_S` (60s) lease; if the process dies mid-delivery the lease expires and the row is retried, with `attempts` counting the lost try. `outbox.dead_letters()` lists dead rows, which are kept for inspection until `outbox.purge_dead(older_than_s=...)` removes them; `outbox.deliver_pending()` runs one delivery pass by hand (tests, cron) and `outbox.prune()` one pruning pass.
- **Storage.** The project's Postgres store when one is configured (tables `jac_outbox`, `jac_outbox_seen`), else `.jac/data/outbox.sqlite`. Enqueue rides the caller's request transaction; the worker and the receiver's key bookkeeping use their own connection, committed on their own, so a remember that happens after the walker's scope has closed never leaves a request transaction open.

```jac
import from jaclang.server { outbox }

def ship_later(oid: str) -> str {
    # explicit key: two requests for the same order must not double-ship
    return outbox.enqueue(
        "fulfillment", "Ship", {"order_id": oid}, idempotency_key=f"ship:{oid}"
    );
}
```

**Read policy.** Bridged reads always go to the owner app (owner-read); a consumer never reads another app's store. `[apps.<consumer>.scale] read_cache = true` opts a consumer into an in-process cache of bridged calls whose provider endpoint declares no effects, invalidated whenever an effectful call to that provider app goes through.

### Colocation and the Fleet

Serving an app (`jac run <app>`) also brings up every service app it bridges to, transitively, in provider-first order:

- **Colocated** (default): each service app's entry module is loaded into the served app's process and registered with `sv_client.register_local(app, module)`. Bridged calls invoke the provider's function or spawn its walker in-process -- still awaited, no sockets. One process, the boundary still compiled as a cut.
- **Fleet**: `jac run <app> --fleet`, or `[scale.gateway] colocate = false`, runs each service app as its own local process behind the served app's gateway (one public port, one `/docs`, one `/metrics`, `X-Trace-Id` threaded through every hop). Peers are wired with `JAC_APP_<APP>_URL`. `jac scale status` / `logs` / `restart` / `stop` manage the members.
- **Peer URLs are used as given.** A fleet member (and a deployed pod) mounts its endpoints at its root -- `/walker/<name>`, `/function/<name>` -- and the gateway strips the app's public route (`/api/<app>`) before forwarding. A consumer therefore never appends the route it compiled against to a peer URL: `JAC_APP_<APP>_URL=http://127.0.0.1:8011` is called at `http://127.0.0.1:8011/walker/<name>`. Only a route registered _together with_ a URL is appended -- `JAC_APP_<APP>_ROUTE`, or `sv_client.register(app, url, route)` -- which is how a consumer is pointed at a public gateway instead of a member.
- **Service identity between members.** Set `JAC_BRIDGE_TOKEN` on every member: consumers send it as a bearer on bridged calls (when no end-user `Authorization` is being forwarded), and a provider whose own `JAC_BRIDGE_TOKEN` matches the presented bearer runs the walker or function as the fixed service user `__bridge__`, which satisfies `requires_auth` endpoints and owns its own root. A mismatching bearer is still a 401; a provider without the variable set never honors it.
- **Deployed**: `jac scale deploy` is always a fleet; see [Service Apps in Kubernetes](jac-scale-kubernetes.md#service-apps-in-kubernetes).

Startup is **fail-fast**: if any service app fails to come up (missing entry file, syntax error, port in use), the served app exits at startup with the underlying error.

### Service Discovery

For each provider app the consumer resolves it in this order. The first match wins:

1. **Local registration** -- the app is colocated (`sv_client.register_local`). Calls go in-process.
2. **Test client** -- tests have wired up an in-process `JacTestClient` for the app. See [Testing](#testing).
3. **Registered URL** -- a URL the consumer was handed programmatically (`sv_client.register`), e.g. by the fleet orchestrator or a custom one.
4. **`JAC_APP_<APP>_URL` environment variable** -- the app name upper-cased, non-alphanumerics as `_` (`social_graph` → `JAC_APP_SOCIAL_GRAPH_URL`). The URL is used as given (a member's root); add `JAC_APP_<APP>_ROUTE` only when the URL is a gateway that expects the app's public route prefix. This is the knob for a provider on another host.

Nothing found is `BridgeUnavailable` at the first awaited call.

### Production Patterns

#### Kubernetes

`jac scale deploy` turns every serving app into its own `Deployment` + `Service` and injects each pod's peer URLs -- you write nothing by hand. For a provider that lives _outside_ the cluster, set the env var on the consumer's Deployment:

```yaml
# orders app: consumer, points at an inventory app hosted elsewhere
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders
spec:
  template:
    spec:
      containers:
      - name: orders
        env:
        - name: JAC_APP_INVENTORY_URL
          value: "https://inventory.example.com"
```

#### Local Development

Colocation is the default and needs nothing. To run the apps apart on one machine, `--fleet`; to run them apart across machines, start each app on its own host and point consumers at providers:

```bash
# host A
jac run inventory --port 8001

# host B
JAC_APP_INVENTORY_URL=http://host-a:8001 jac run orders --port 8000
```

#### Troubleshooting

If an endpoint reports an invalid anchor, check its ID, the selected app and store, and recent schema changes. Run `jac guide jac-debugging --section diagnose-state-and-cache-errors` for the diagnostic sequence. Preserve existing data until you have identified the cause and chosen a repair.

- **`BridgeUnavailable: app 'x' is not registered`.** The provider app is neither colocated nor reachable: the served app has no `[apps.x]` table to colocate, or in a fleet/multi-host setup `JAC_APP_X_URL` is unset.
- **`BridgeRejected` with status 404 / 401.** The element is not on the provider's bridge surface (`jac check` reports `E5106` for the compile-time half), or the hop carried no usable `Authorization` for a `:priv` endpoint.
- **`E1042` at a call you did not think was remote.** The imported element is owned by another app; add `await` (and make the enclosing function `async`).

### Testing

To test cross-app behavior without real network I/O, wire each provider app up as an in-process test client before constructing the consumer. `sv_client.register_test_client(app, client)` routes the consumer's bridged calls through the registered client directly; no sockets, no port allocation, no background threads.

`JacTestClient.from_file` (see [Testing -> JacTestClient](../testing.md#jactestclient)) builds a whole app in-process from its entry file:

```jac
import from jaclang.server { sv_client }
import from jaclang.testing.testing { JacTestClient }

test "orders reaches inventory" {
    sv_client.clear_test_clients();

    prov_client = JacTestClient.from_file("core/inventory.jac");
    cons_client = JacTestClient.from_file("orders/main.jac");
    sv_client.register_test_client("inventory", prov_client);

    # Bridged calls from orders into the inventory app now route through prov_client
    resp = cons_client.post(
        "/function/create_order",
        json={"items": [{"sku": "W", "quantity": 2}]}
    ).json();
    assert resp["data"]["result"]["success"] is True;
}
```

Always call `sv_client.clear_test_clients()` between tests to avoid bleed-over from a previous test's registrations. `sv_client.clear_local_providers()` does the same for colocated registrations.

### sv_client API Reference

`jaclang.server.sv_client` is keyed by **app name** and exposes a small control surface for telling the runtime where each provider app is. You rarely need it under normal use -- colocation covers `jac run`, the fleet orchestrator and `jac scale deploy` register their members, and `JAC_APP_<APP>_URL` covers hand-wired hosts. Reach for these functions when you are writing tests or a custom orchestrator.

| Function | Purpose |
|---|---|
| `register_local(app: str, module)` | Serve a provider app from an already-loaded module in this process (what colocation does). |
| `unregister_local(app: str)` / `is_local(app) -> bool` / `clear_local_providers()` | Manage local registrations. |
| `register(app: str, url: str, route: str = "")` | Point a provider app at a URL programmatically. Takes precedence over the env var path. `route` is appended to the URL only when given here (a gateway base); the route a compiled consumer declared is never appended to a peer URL. |
| `unregister(app: str)` | Remove a registration made via `register`. |
| `register_test_client(app, client)` / `clear_test_clients()` | Route calls to a provider through an in-process `JacTestClient` (tests only). See [Testing](#testing). |
| `resolve_url(app: str) -> str` | The URL the consumer would use for a provider (from `register` or `JAC_APP_<APP>_URL`, plus a route registered with it). Raises `BridgeUnavailable` if nothing is registered. |
| `provider_route(app: str) -> str` / `registered_route(app: str) -> str` | The route a compiled consumer declared for a provider (what the gateway and colocated mounts serve it under), and the route bound to an explicit registration (the only one `resolve_url` appends). |
| `peer_url_env_key(app: str) -> str` | The `JAC_APP_<APP>_URL` name for an app. |
| `async call(app, fn, kwargs)` / `async spawn_walker(app, walker, kwargs, cls)` | What the generated stubs call. |
| `spawn_deferred(app, walker, kwargs, idempotency_key = "") -> str` | Enqueue a deferred spawn; returns the outbox entry id. |
| `get_consumer_providers(consumer_app: str) -> list[str]` | The provider apps a consumer declared (the app DAG's edges out of it). |

## CLI Commands

| Command | Description |
|---------|-------------|
| `jac run app.jac` | Start local API server |
| `jac scale deploy app.jac` | Deploy to Kubernetes |
| `jac scale deploy app.jac --dry-run` | Print the manifests that would be applied; change nothing |
| `jac scale deploy app.jac --target kubernetes` | Explicit deployment target (default) |
| `jac scale deploy app.jac --enable-tls` | Enable HTTPS on a live deployment (no redeploy) |
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

### OAuth sessions for browser and native clients

`jaclang.scale.sso.oauth_session.OAuthSession` is the shared authorization-code
flow used by Scale and available to application callback facades. Construct it
with a `UserManager`, an `OAuth2CodeProvider`, and the provider name. The
provider supplies its registered `redirect_uri`; application facades must
choose that URL from server configuration, never from arbitrary request input.

`begin(challenge, mode="web", link_user="")` issues expiring random state and
an S256 PKCE authorization URL. `finish(code, state, verifier)` validates the
client/app binding and consumes state before exchanging the code. The verifier
must be a cryptographically random 43–128-character value. Keep it on the
originating client. A supplied `link_user` must already have been authenticated
by the server; it is not an untrusted request parameter.

Scale exposes `POST /sso/{platform}/begin`, `/finish`, and `/poll`. Begin accepts
`challenge` and `mode`; an authenticated Bearer session requests account
linking, while an anonymous request requests sign-in. Finish accepts `code`,
`state`, and `verifier`. For client-managed web flows configure
`[scale.sso] client_auth_callback_url`: the provider callback forwards the
short-lived code and state there for the client to finish. It does not forward
a session token in this flow.

For native clients, `begin(..., mode="native")` also returns a random `poll`
secret that must stay on the initiating device. Open the authorization URL in
the system browser. The server callback calls `complete_native(code, state)`;
`poll(poll_secret)` atomically redeems the result on the device. Results expire
after two minutes and contain the application's session token, never the
provider access token. Cancellation and timeout should return the user to the
sign-in screen. The begin/session state expires after ten minutes.

Existing `/sso/{platform}/login` and `/register` browser routes use the same
session implementation with a per-attempt HttpOnly state cookie. Callback
requests without that browser binding are rejected before token exchange.
Loopback destinations are stored in server-side state, not trusted from the
callback query string. HTTPS flows use Secure cookies.

Users are resolved by `(provider, external_id)`. Matching email addresses no
longer automatically merge accounts. Existing password users must sign in and
explicitly connect the provider; existing linked SSO users keep their accounts
when their email or provider username changes. GitHub sign-in requires only
public identity and does not request email or repository access permissions.
