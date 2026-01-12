# Jac-Scale Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of **Jac-Scale**. For details on changes that might require updates to your existing code, please refer to the [Breaking Changes](../breaking_changes.md) page.

## jaclang 0.9.0 / jac-scale 0.1.0 (Unreleased)

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
