# Jac-Client Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of **Jac-Client**. For details on changes that might require updates to your existing code, please refer to the [Breaking Changes](../breaking_changes.md) page.


## jac-client 0.2.4 (Unreleased)

- **JSON-Based Configuration System**: Introduced a flexible JSON-based configuration system that allows developers to customize Vite build settings, add plugins, and override build options through a simple `config.json` file in the project root. The system automatically generates `vite.config.js` in `.jac-client.configs/` directory, keeping the project root clean while preserving all essential defaults. Supports custom plugins (e.g., Tailwind CSS), build options, server configuration, and resolve options. [Documentation](https://docs.jaseci.org/jac-client/advance/custom-config/)

- **CLI Command for Config Generation**: Added `jac generate_client_config` command to create a default `config.json` file with the proper structure, making it easy for developers to start customizing their build configuration. The command prevents accidental overwrites of existing config files.

- **Centralized Babel Configuration**: Moved Babel configuration from separate `.babelrc` files into `package.json`, centralizing project configuration and reducing file clutter in the project root.

- **TypeScript Support**: Added comprehensive TypeScript support for Jac client projects, enabling integration of TypeScript/TSX components alongside Jac code. TypeScript files (`.ts`, `.tsx`) are now automatically copied during the build process and properly handled by Vite bundling. The `jac create_jac_app` CLI now includes an interactive prompt to set up TypeScript support during project creation, automatically configuring `tsconfig.json`, `vite.config.js`, and `package.json` with necessary TypeScript dependencies. [Documentation](https://docs.jaseci.org/jac-client/working-with-ts/)

## jac-client 0.2.3 (Latest Release)

- **Nested Folder Structure Preservation**: Implemented folder structure preservation during compilation, similar to TypeScript transpilation. Files in nested directories now maintain their relative paths in the compiled output, enabling proper relative imports across multiple directory levels and preventing file name conflicts. This allows developers to organize code in nested folders just like in modern JavaScript/TypeScript projects.

- **File System Organization Documentation**: Added comprehensive documentation for organizing Jac client projects, including guides for the `app.jac` entry point requirement, backend/frontend code separation patterns, and nested folder import syntax. [Documentation](https://docs.jaseci.org/jac-client/file-system/intro/)

## jac-client 0.2.1

- **CSS File Support**: Added full support for CSS in separate files, enabling cleaner styling structure. Expanded styling options with documented approaches for flexible UI customization. [Documentation](https://docs.jaseci.org/jac-client/styling/intro/)

- **Static Asset Serving**: Introduced static asset serving, allowing images, fonts, and other files to be hosted easily. Updated documentation with step-by-step guides for implementation. [Documentation](https://docs.jaseci.org/jac-client/asset-serving/intro/)

- **Architecture Documentation**: Added comprehensive architecture documentation explaining jac-client's internal design and structure. [View Architecture](https://github.com/jaseci-labs/jaseci/blob/main/jac-client/architecture.md)

- **.cl File Support**: Added support for `.cl` files to separate client code from Jac code. Files with the `.cl.jac` extension can now be used to define client-side logic, improving organization and maintainability of Jac projects.

## jac-client 0.2.0

- **Constructor Calls Supported**: Constructor calls properly supported by automatically generating `new` keyword.

## jac-client 0.1.0

- **Client Bundler Plugin Support**: Extended the existing `pluggy`-based plugin architecture to support custom client bundling implementations. Two static methods were added to `JacMachineInterface` to enable client bundler plugins:
  - `get_client_bundle_builder()`: Returns the client bundle builder instance, allowing plugins to provide custom bundler implementations
  - `build_client_bundle()`: Builds client bundles for modules, can be overridden by plugins to use custom bundling strategies

- **ViteBundlerPlugin (jac-client)**: Official Vite-based bundler plugin providing production-ready JavaScript bundling with HMR, tree shaking, code splitting, TypeScript support, and asset optimization. Implements the `build_client_bundle()` hook to replace default bundling with Vite's optimized build system. Install `jac-client` library from the source and use it for automatic Vite-powered client bundle generation.

- **Import System Fix**: Fixed relative imports in client bundles, added support for third-party npm modules, and implemented validation for pure JavaScript file imports.

- **PYPI Package Release**: First stable release (v0.1.0) now available on PyPI. Install via `pip install jac-client` to get started with Vite-powered client bundling for your Jac projects.


## jaclang 0.8.10 / jac-cloud 0.2.10 / byllm 0.4.5

## jaclang 0.8.9 / jac-cloud 0.2.9 / byllm 0.4.4

## jaclang 0.8.8 / jac-cloud 0.2.8 / byllm 0.4.3

## jaclang 0.8.7 / jac-cloud 0.2.7 / byllm 0.4.2

## jaclang 0.8.6 / jac-cloud 0.2.6 / byllm 0.4.1

## jaclang 0.8.5 / jac-cloud 0.2.5 / mtllm 0.4.0

## jaclang 0.8.4 / jac-cloud 0.2.4 / mtllm 0.3.9

## jaclang 0.8.3 / jac-cloud 0.2.3 / mtllm 0.3.8

## jaclang 0.8.1 / jac-cloud 0.2.1 / mtllm 0.3.6


## Version 0.8.0
