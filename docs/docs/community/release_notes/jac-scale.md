# Jac-Scale Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of **Jac-Scale**. For details on changes that might require updates to your existing code, please refer to the [Breaking Changes](../breaking-changes.md) page.

## jac-scale 0.1.2 (Unreleased)

### New Features

#### Storage Abstraction

Introduced a flexible storage abstraction layer with factory pattern for file operations.

- **Abstract Storage Interface**: Base `Storage` class defining standard file operations (upload, download, delete, list, copy, move, etc.)
- **StorageFactory**: Factory class for creating storage instances with `create()` and `get_default()` methods
- **LocalStorage Provider**: Full implementation for local filesystem storage
- **Configuration Support**: `LocalStorageConfig` with `from_dict()` and `from_env()` static methods
- **Environment Variables**: Configure storage via `JAC_STORAGE_TYPE` and `JAC_LOCAL_STORAGE_BASE_PATH`
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
