# jac-scale Reference

jac-scale generates REST endpoints from your Jac walkers and functions. Running `jac start` with this plugin turns every `:pub` or `:priv` walker into an API endpoint backed by FastAPI, with automatic Swagger docs, SQLite persistence, and built-in authentication.

For production, the `--scale` flag automates Docker image builds and Kubernetes deployment -- generating Dockerfiles, manifests, and service configurations from your code. This reference covers server startup options, endpoint generation, authentication, database persistence, Kubernetes deployment, and the CLI flags for each mode.

---

## Installation

```bash
pip install jac-scale
jac plugins enable scale
```

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

### User Registration

```bash
curl -X POST http://localhost:8000/user/register \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "secret"}'
```

### User Login

```bash
curl -X POST http://localhost:8000/user/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "secret"}'
```

Returns:

```json
{
  "access_token": "eyJ...",
  "token_type": "bearer"
}
```

### Authenticated Requests

```bash
curl -X POST http://localhost:8000/walker/my_walker \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### JWT Configuration

Configure JWT authentication via environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `JWT_SECRET` | Secret key for JWT signing | `supersecretkey` |
| `JWT_ALGORITHM` | JWT algorithm | `HS256` |
| `JWT_EXP_DELTA_DAYS` | Token expiration in days | `7` |

### SSO (Single Sign-On)

jac-scale supports SSO with external identity providers. Currently supported: Google.

**Configuration:**

| Variable | Description |
|----------|-------------|
| `SSO_HOST` | SSO callback host URL (default: `http://localhost:8000/sso`) |
| `SSO_GOOGLE_CLIENT_ID` | Google OAuth client ID |
| `SSO_GOOGLE_CLIENT_SECRET` | Google OAuth client secret |

**SSO Endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| GET | `/sso/{platform}/login` | Redirect to provider login page |
| GET | `/sso/{platform}/register` | Redirect to provider registration |
| GET | `/sso/{platform}/login/callback` | OAuth callback handler |

**Frontend Callback Redirect:**

For browser-based OAuth flows, configure `client_auth_callback_url` in `jac.toml` to redirect the SSO callback to your frontend application instead of returning JSON:

```toml
[plugins.scale.sso]
client_auth_callback_url = "http://localhost:3000/auth/callback"
```

When set, the callback endpoint redirects to the configured URL with query parameters:

- On success: `{client_auth_callback_url}?token={jwt_token}`
- On failure: `{client_auth_callback_url}?error={error_message}`

This enables seamless browser-based OAuth flows where the frontend receives the token via URL parameters.

**Example:**

```bash
# Redirect user to Google login
curl http://localhost:8000/sso/google/login
```

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
| `MODERATOR` | `moderator` | Limited administrative access |
| `USER` | `user` | Standard user access |

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

## Related Resources

- [Local API Server Tutorial](../../tutorials/production/local.md)
- [Kubernetes Deployment Tutorial](../../tutorials/production/kubernetes.md)
- [Backend Integration Tutorial](../../tutorials/fullstack/backend.md)
