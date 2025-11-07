# Jac-Client Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of **Jac-Client**. For details on changes that might require updates to your existing code, please refer to the [Breaking Changes](../breaking_changes.md) page.

## jac-client 0.1.0 (Unreleased)

- **Client Bundler Plugin Support**: Extended the existing `pluggy`-based plugin architecture to support custom client bundling implementations. Two static methods were added to `JacMachineInterface` to enable client bundler plugins:
  - `get_client_bundle_builder()`: Returns the client bundle builder instance, allowing plugins to provide custom bundler implementations
  - `build_client_bundle()`: Builds client bundles for modules, can be overridden by plugins to use custom bundling strategies

- **ViteBundlerPlugin (jac-client)**: Official Vite-based bundler plugin providing production-ready JavaScript bundling with HMR, tree shaking, code splitting, TypeScript support, and asset optimization. Implements the `build_client_bundle()` hook to replace default bundling with Vite's optimized build system. Install `jac-client` library from the source and use it for automatic Vite-powered client bundle generation.

- **Import System Fix**: Fixed relative imports in client bundles, added support for third-party npm modules, and implemented validation for pure JavaScript file imports.

- **PYPI Package Release**: First stable release (v0.1.0) now available on PyPI. Install via `pip install jac-client` to get started with Vite-powered client bundling for your Jac projects.


## Version 0.8.0
