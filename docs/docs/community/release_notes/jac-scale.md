# Jac-Scale Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of **Jac-Scale**. For details on changes that might require updates to your existing code, please refer to the [Breaking Changes](../breaking-changes.md) page.

## jac-scale 0.2.1 (Unreleased)

- Internal: refactor jac-scale k8s loadbalancer/service to support other vendors
- Before deploying to the local Kubernetes cluster, check whether the required NodePorts are already in use in any namespace; if they are, throw an error.
- jac destroy command deletes non default namespace

## jac-scale 0.2.0 (Latest Release)

- **SSO Frontend Callback Redirect**: SSO callback endpoints now support automatic redirection to frontend applications. Configure `client_auth_callback_url` in `jac.toml` to redirect with token/error parameters instead of returning JSON, enabling seamless browser-based OAuth flows.
- **Graph Visualization Tests**: Added tests for `/graph` and `/graph/data` endpoints.

## jac-scale 0.1.6

## jac-scale 0.1.9

- **Refactor: Modular JacAPIServer Architecture**: Split the monolithic `serve.impl.jac` into three focused impl files using mixin composition:
  - `serve.core.impl.jac`: Auth, user management, JWT, API keys, server start/postinit
  - `serve.endpoints.impl.jac`: Walker, function, webhook, WebSocket endpoint registration
  - `serve.static.impl.jac`: Static files, pages, client JS, graph visualization
- **Fix: `@restspec` Path Parameters**: Resolved a critical bug where using `@restspec` with URL path parameters (e.g. `path="/items/{item_id}"`) caused the server to crash on startup with `Cannot use 'Query' for path param 'id'`. Both functions and walkers with `@restspec` path templates now correctly annotate matching parameters as `Path()` instead of `Query()`. Mixed usage (path params alongside query params or body params) works correctly across GET and POST methods. Starlette converter syntax (e.g. `{file_path:path}`) is also handled.

## jac-scale 0.1.11

- **Graph Visualization Endpoint (`/graph`)**: Added a built-in `/graph` endpoint that serves an interactive graph visualization UI in the browser.

## jac-scale 0.1.10

- **support horizontal scaling**:  based on average cpu usage k8s pods are horizontally scaled
- **Client Build Error Diagnostics**: Build errors now display formatted diagnostic output with error codes, source snippets, and quick fix suggestions instead of raw Vite/Rollup output. Uses the `jac-client` diagnostic engine for consistent error formatting across `jac start` and `jac build`.

## jac-scale 0.1.9

- **Remove Authorization header input from Swagger UI**: The `Authorization` header is no longer exposed as a visible text input field in Swagger UI for walker, function, and API key endpoints. Authentication tokens are now read transparently from the standard `Authorization` request header (accessible via the lock icon), consistent with the `update_username` and `update_password` endpoints.
- 1 Minor refactors/changes.

## jac-scale 0.1.8

- Internal: K8s integration tests now install jac plugins from fork PRs instead of always using main
- **.jac folder is excluded when creating the zip folder that is uploaded into jaseci deployment pods.Fasten up deployment**
- **Fix: `jac start` Startup Banner**: Server now displays the startup banner (URLs, network IPs, mode info) correctly via `on_ready` callback, consistent with stdlib server behavior.
- Various refactors
- **PWA Build Detection**: Server startup now detects existing PWA builds (via `manifest.json`) and skips redundant client bundling. The `/static/client.js` endpoint serves Vite-hashed files (`client.*.js`) in PWA mode.
- **Prometheus Metrics Integration**: Added `/metrics` endpoint with HTTP request metrics, configurable via `[plugins.scale.metrics]
` in `jac.toml`.
- Update jaseci scale k8s pipeline to support parellel test cases.
- **early exit from k8s deployment if container restarted**
- **Direct Database Access (`kvstore`)**: Added `kvstore()` function for direct MongoDB and Redis operations without graph layer. Supports database-specific methods (MongoDB: `find_one`, `insert_one`, `update_one`; Redis: `set_with_ttl`, `incr`, `scan_keys`) with common methods (`get`, `set`, `delete`, `exists`) working across both. Import from `jac_scale.lib` with URI-based connection pooling and configuration fallback (explicit URI → env vars → jac.toml).
- **Code refactors**: Backtick escape, etc.
- **Persistent Webhook API Keys**: Webhook API key metadata is now stored in MongoDB (`webhook_api_keys` collection) instead of in-memory dictionaries. API keys now survive server restarts.
- **Native Kubernetes Secret support**: New `[plugins.scale.secrets]` config section. Declare secrets with `${ENV_VAR}` syntax, auto-resolved at deploy time into a K8s Secret with `envFrom.secretRef`.
- **Minor Internal Refactor in Tests**: Minor internal refactoring in test_direct.py to improve test structure
- **fix**: Return 401 instead of 500 for deleted users with valid JWT tokens.
- Docs update: return type `any` -> `JsxElement`
- **1 Small Refactors**
- **promethius and grafana deployment**: Jac-scale automatically deploys promethius and grafana and connect with metrics endpoint.

## jac-scale 0.1.7

- **KWESC_NAME syntax changed from `<>` to backtick**: Updated keyword-escaped names from `<>` prefix to backtick prefix to match the jaclang grammar change.
- **Update syntax for TYPE_OP removal**: Replaced backtick type operator syntax (`` `root ``) with `Root` and filter syntax (``(`?Type)``) with `(?:Type)` across all docs, tests, examples, and README.

## jac-scale 0.1.6

- **WebSocket Support**: Added WebSocket transport for walkers via `@restspec(protocol=APIProtocol.WEBSOCKET)` with persistent bidirectional connections at `ws://host/ws/{walker_name}`. The `APIProtocol` enum (`HTTP`, `WEBHOOK`, `WEBSOCKET`) replaces the previous `webhook=True` flag-migrate by changing `@restspec(webhook=True)` to `@restspec(protocol=APIProtocol.WEBHOOK)`.

- **fix: Exclude `jac.local.toml` during K8s code sync**: The local dev override file (`jac.local.toml`) is now excluded when syncing application code to the Kubernetes PVC. Previously, this file could override deployment settings such as the serve port, causing health check failures.

## jac-scale 0.1.5

- **JsxElement Return Types**: Updated all JSX component return types from `any` to `JsxElement` for compile-time type safety.
- **Client bundle error help message**: When the client bundle build fails during `jac start`, the server now prints a troubleshooting suggestion to run `jac clean --all` and a link to the Discord community for support.

## jac-scale 0.1.4

- **Console infrastructure**: Replaced bare `print()` calls with `console` abstraction for consistent output formatting.
- **Hot fix: call state**: Normal spawn calls inside API spawn calls supported.
- **`--no_client` flag support**: Server startup now honors the `--no_client` flag, skipping eager client bundling when the client bundle is built separately, adn we need server only.
- **PyJWT version pinned**: Pinned `pyjwt` to `>=2.10.1,<2.11.0` and updated default JWT secret to meet minimum key length requirements.

## jac-scale 0.1.3

- **GET Method Support**: Added full support for HTTP GET requests for both walkers and functions, including correct mapping of query parameters, support for both dynamic (HMR) and static endpoints, and customization via `@restspec(method=HTTPMethod.GET)`.

- **Streaming Response Support**: Streaming responses are supported with walker spawn calls and function calls.
- **Webhook Support**: Added webhook transport for walkers with HMAC-SHA256 signature verification. Walkers can be configured with `@restspec(webhook=True)` to receive webhook requests at `/webhook/{walker_name}` endpoints with API key authentication and signature verification.

- **Storage Abstraction**: Introduced a pluggable storage abstraction layer for file operations.
  - Abstract `Storage` interface with standard operations: `upload`, `download`, `delete`, `list`, `copy`, `move`, `get_metadata`
  - Default `LocalStorage` implementation in `jaclang.runtimelib.storage`
  - Hookable `store(base_path, create_dirs)` builtin that returns a configured `Storage` instance
  - Configure via `jac.toml [storage]` section or `JAC_STORAGE_PATH` / `JAC_STORAGE_CREATE_DIRS` environment variables

- **jac destroy** command wait till fully removal of resources

- **SPA Catch-All for BrowserRouter Support**: The FastAPI server's `serve_root_asset` endpoint now falls back to rendering SPA HTML for extensionless paths when `base_route_app` is configured. API prefix paths (`cl/`, `walker/`, `function/`, `user/`, `static/`) are excluded from the catch-all. This matches the built-in HTTP server's behavior for BrowserRouter support.

- **Internal**: Explicitly declared all postinit fields across the codebase.

### PyPI Installation by Default

Kubernetes deployments now install Jaseci packages from PyPI by default instead of cloning the entire repository. This provides faster startup times and more reproducible deployments.

**Default behavior (PyPI installation):**

```bash
jac start app.jac --scale
```

**Experimental mode (repo clone - previous behavior):**

```bash
jac start app.jac --scale --experimental
```

### New CLI Flag: `--experimental`

Added `--experimental` (`-e`) flag to `jac start --scale` command. When enabled, falls back to the previous behavior of cloning the Jaseci repository and installing packages in editable mode. Useful for testing unreleased changes.

### Version Pinning via `plugin_versions` Configuration

Added `plugin_versions` configuration in `jac.toml` to pin specific package versions:

```toml
[plugins.scale.kubernetes.plugin_versions]
jaclang = "0.1.5"      # or "latest"
jac_scale = "0.1.1"    # or "latest"
jac_client = "0.1.0"   # or "latest"
jac_byllm = "none"     # use "none" to skip installation (will insall elvant byllm version)
```

When not specified, defaults to `"latest"` for all packages.

### Enhanced `restspec` Decorator

The `@restspec` decorator now supports custom HTTP methods and custom endpoint paths for both walkers and functions.

- **Custom Methods**: Use `method=HTTPMethod.GET`, `method=HTTPMethod.PUT`, etc.
- **Custom Paths**: Use `path="/my/custom/path"` to override the default routing.

## jac-scale 0.1.1

## jac-scale 0.1.0

### Initial Release

First release of **Jac-Scale** - a scalable runtime framework for distributed Jac applications.

### Key Features

- Conversion of walker to fastapi endpoints
- Multi memory hierachy implementation
- Support for Mongodb (persistance storage) and Redis (cache storage) in k8s
- Deployment of app code directly to k8s cluster
- k8s support for local deployment and aws k8s deployment
- SSO support for google

- **Custom Response Headers**: Configure custom HTTP response headers via `[environments.response.headers]` in `jac.toml`. Useful for security headers like COOP/COEP (required for `SharedArrayBuffer` support in libraries like monaco-editor).

### Installation

```bash
pip install jac-scale
```
