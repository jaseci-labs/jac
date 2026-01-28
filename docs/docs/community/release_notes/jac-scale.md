# Jac-Scale Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of **Jac-Scale**. For details on changes that might require updates to your existing code, please refer to the [Breaking Changes](../breaking-changes.md) page.

## jac-scale 0.1.3 (Unreleased)

- **Streaming Response Support**: Streaming responses are supported with walker spawn calls and function calls.

- **Storage Abstraction**: Introduced a pluggable storage abstraction layer for file operations. Includes an abstract `Storage` interface defining standard operations (upload, download, delete, list, copy, move, get_metadata), a default `LocalStorage` implementation in `jaclang.runtimelib.storage`, and a hookable `store()` builtin that returns a configured `Storage` instance. Configure via `jac.toml [storage]` section or `JAC_STORAGE_PATH` / `JAC_STORAGE_CREATE_DIRS` environment variables.

- **PyPI Installation by Default**: Kubernetes deployments now install Jaseci packages from PyPI by default instead of cloning the entire repository. This provides faster startup times and more reproducible deployments. Use `jac start app.jac --scale` for default behavior, or `jac start app.jac --scale --experimental` to fall back to repo clone.

- **New CLI Flag `--experimental`**: Added `--experimental` (`-e`) flag to `jac start --scale` command. When enabled, falls back to the previous behavior of cloning the Jaseci repository and installing packages in editable mode. Useful for testing unreleased changes.

- **Version Pinning via `plugin_versions` Configuration**: Added `plugin_versions` configuration in `jac.toml` to pin specific package versions. Configure under `[plugins.scale.kubernetes.plugin_versions]` with keys like `jaclang`, `jac_scale`, `jac_client`, `jac_byllm`. Values can be version strings (e.g., `"0.1.5"`), `"latest"`, or `"none"` to skip installation. Defaults to `"latest"` for all packages.

- **Internal**: Explicitly declared all postinit fields across the codebase.

## jac-scale 0.1.1 (Latest Release)

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
