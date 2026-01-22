# Jac-Client Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of **Jac-Client**. For details on changes that might require updates to your existing code, please refer to the [Breaking Changes](../breaking_changes.md) page.

## jac-client 0.2.10 (Unreleased)

## jac-client 0.2.9 (Latest Release)

- **Generic Config File Generation from jac.toml**: Added support for generating JavaScript config files (e.g., `postcss.config.js`, `tailwind.config.js`) directly from `jac.toml` configuration. Define configs under `[plugins.client.configs.<name>]` and they are automatically converted to `<name>.config.js` files in `.jac/client/configs/`. This eliminates the need for standalone JavaScript config files in the project root for tools like PostCSS, Tailwind (v3), ESLint, and other npm packages that use the `*.config.js` convention.
- **Error Handling with JacClientErrorBoundary**: Introduced  error boundary handling in Jac Client apps. The new `JacClientErrorBoundary` component allows you to wrap specific parts of your component tree to catch and display errors gracefully, without affecting the entire application.

## jac-client 0.2.8

- **Vite Dev Server Integration for HMR**: Added support for Hot Module Replacement during development. When using `jac start --dev`, the Vite dev server runs alongside the Jac API server with automatic proxy configuration for `/walker`, `/function`, `/user`, and `/introspect` routes. This enables instant frontend updates without full page reloads while maintaining seamless backend communication.

## jac-client 0.2.7

- **Reactive State Variables**: The `jac create --use client` template now uses the new `has` keyword for React state management. Instead of `[count, setCount] = useState(0);`, you can write `has count: int = 0;` and use direct assignment `count = count + 1;`. The compiler automatically generates the `useState` destructuring and transforms assignments to setter calls, providing cleaner and more intuitive state management syntax.
- **Simplified Project Structure**: Reorganized the default project structure created by `jac create --use client`. The entry point is now `main.jac` at the project root instead of `src/app.jac`, and the `components/` directory is now at the project root instead of `src/components/`. This flatter structure reduces nesting and aligns with modern frontend project conventions. Existing projects using the `src/` structure continue to work but new projects use the simplified layout.

- **Configurable Client Route Prefix**: Changed the default URL path for client-side apps from `/page/<app>` to `/cl/<app>`. The route prefix is now configurable via `cl_route_prefix` in the `[serve]` section of `jac.toml`. This allows customizing the URL structure for client apps (e.g., `/pages/MyApp` instead of `/cl/MyApp`). [Documentation](https://docs.jaseci.org/learn/tools/jac_serve/#routing-configuration)

- **Base Route App Configuration**: Added `base_route_app` option in `jac.toml` `[serve]` section to serve a client app directly at the root `/` path. When configured, visiting `/` renders the specified client app instead of the API info page, making it easy to create single-page applications with clean URLs. Projects created with `jac create --use client` now default to `base_route_app = "app"`, so the app is served at `/` out of the box. [Documentation](https://docs.jaseci.org/learn/tools/project_config/#serve-section)

## jac-client 0.2.4

- **`jac-client-node` and `@jac-client/dev-deps` npm packages**: Introduced the new npm libraries  to centralize and abstract default dependencies for Jac client applications. These two package includes React, Vite, Babel, TypeScript, and other essential dependencies.

- **Explicit Export Requirement**: Functions and variables must now be explicitly exported using the `:pub` modifier to be available for import. In previous versions (< 0.2.4), all `def` functions were automatically exported and variables (globals) could not be exported. Starting with 0.2.4, functions and variables are private by default and must be marked with `:pub` to be importable. This provides better control over module APIs and prevents accidental exports. The `app()` function in your entry file must be exported as `def:pub app()`. [Breaking Change - See Migration Guide]

- **Authentication API Update**: Updated authentication functions (`jacLogin` and `jacSignup`) to use `email` instead of `username` for user identification. This change aligns with standard authentication practices and improves security. All authentication examples and documentation have been updated to reflect this change. The `/user/register` and `/user/login` endpoints now accept `email` in the request payload. End-to-end tests have been added to verify authentication endpoint functionality. [Breaking Change - See Migration Guide]

- **Centralized Configuration Management**: Introduced a unified configuration system through `config.json` that serves as the single source of truth for all project settings. The system automatically creates `config.json` when you run `jac create_jac_app`, eliminating the need for manual setup. All build configurations (Vite plugins, build options, server settings) and package dependencies are managed through this centralized file. The system automatically generates `vite.config.js` and `package.json` in `.jac-client.configs/` directory, keeping the project root clean while preserving all essential defaults. [Documentation](https://docs.jaseci.org/jac-client/advance/configuration-overview/)

- **Package Management Through config.json**: Implemented configuration-first package management where all npm dependencies are managed through `config.json` instead of `package.json`. Use `jac add --npm <package>` to add packages and `jac remove --npm <package>` to remove them. Running `jac add --npm` without a package name installs all packages listed in `config.json`. The system automatically regenerates `package.json` from `config.json` and runs npm install, ensuring consistency between configuration and installed packages. Supports both regular and scoped packages with version specification. [Documentation](https://docs.jaseci.org/jac-client/advance/package-management/)

- **CLI Command for Config Generation**: Added `jac generate_client_config` command for legacy projects (pre-0.2.4) to create a default `config.json` file with the proper structure. For new projects, `config.json` is automatically created with `jac create_jac_app`. The command prevents accidental overwrites of existing config files.

- **Centralized Babel Configuration**: Moved Babel configuration from separate `.babelrc` files into `package.json`, centralizing project configuration and reducing file clutter in the project root.

- **TypeScript Support (Enabled by Default)**: TypeScript is now automatically supported in all Jac projects by default. No configuration or prompts needed - TypeScript dependencies are automatically included in `package.json` during build time, and `tsconfig.json` is automatically generated during the first build. TypeScript files (`.ts`, `.tsx`) are automatically processed by Vite bundling, enabling seamless integration of TypeScript/TSX components alongside Jac code. The `components/` directory with a sample `Button.tsx` component is created automatically during project setup. [Documentation](https://docs.jaseci.org/jac-client/working-with-ts/)

## jac-client 0.2.3

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
