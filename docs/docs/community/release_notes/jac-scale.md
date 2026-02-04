# Jac-Scale Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of **Jac-Scale**. For details on changes that might require updates to your existing code, please refer to the [Breaking Changes](../breaking-changes.md) page.

## jac-scale 0.1.6 (Unreleased)

- **fix: Exclude `jac.local.toml` during K8s code sync**: The local dev override file (`jac.local.toml`) is now excluded when syncing application code to the Kubernetes PVC. Previously, this file could override deployment settings such as the serve port, causing health check failures.

## jac-scale 0.1.5 (Latest Release)

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

- Distributed runtime with load balancing and service discovery
- Intelligent walker scheduling across multiple nodes
- Auto-partitioned graph storage
- Performance monitoring and auto-scaling
- YAML-based configuration
- Username-based user management for authentication
- **Custom Response Headers**: Configure custom HTTP response headers via `[environments.response.headers]` in `jac.toml`. Useful for security headers like COOP/COEP (required for `SharedArrayBuffer` support in libraries like monaco-editor).

### Installation

```bash
pip install jac-scale
```
