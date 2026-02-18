# Jac-Client Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of **Jac-Client**. For details on changes that might require updates to your existing code, please refer to the [Breaking Changes](../breaking-changes.md) page.

## jac-client 0.2.19 (Unreleased)

- **Target System Refactoring**: Refactored the client target system for improved scalability and maintainability. Introduced `TargetFactory` singleton with lazy loading for non-web targets (Desktop, PWA), reducing startup overhead when only the default web target is used. Resolved circular import issues by deferring imports to function scope. Extracted magic numbers to named constants (`VITE_DEV_SERVER_PORT`, `DEFAULT_FUNCTION_NAME`) and decomposed `_generate_index_html` into focused helper functions. Added robust process termination with graceful shutdown fallback and safe attribute access chains for module introspection.

## jac-client 0.2.18 (Latest Release)

- 2 Minor internal refactors
- **Standardize Jac idioms in examples and runtime**: Replaced JS-style method calls with Jac-idiomatic equivalents across all examples, test fixtures, and the client runtime plugin (`.trim()` → `.strip()`, `.push()` → `.append()`, `.length` → `len()`, `.toUpperCase()/.toLowerCase()` → `.upper()/.lower()`, `console.log()` → `print()`, etc.). These are now translated to the correct JS equivalents at compile time via the primitive emitter infrastructure.

## jac-client 0.2.17

- **Structured Build Error Diagnostics**: Build errors now display formatted diagnostic output with error codes (JAC_CLIENT_XXX), source code snippets pointing to the error location, actionable hints, and quick fix commands. The diagnostic engine maps Vite/npm errors back to original `.jac` files, hiding internal JavaScript paths from developers. Detectors identify common issues: missing npm dependencies (JAC_CLIENT_001), syntax errors (JAC_CLIENT_003), and unresolved imports (JAC_CLIENT_004). Enable `debug = true` under `[plugins.client]` in `jac.toml` or set `JAC_DEBUG=1` to see raw error output alongside formatted diagnostics.

- Various refactors
- **Improved `jac start` Output Ordering**: Fixed misleading output timing where "Server ready" and localhost URLs appeared before compilation completed. The Vite dev server now captures its initial output and waits for the ready signal before displaying status messages, ensuring users see compilation progress first and server URLs only when the server is actually ready to accept connections.
- **PWA Target Support**: Added a new `pwa` target for creating Progressive Web Apps. Run `jac setup pwa` to configure your project with PWA support-this copies default icons to `pwa_icons/` and adds the `[plugins.client.pwa]` config section to `jac.toml`. Then use `jac build --client pwa` to build or `jac start --client pwa` to build and serve. The build generates a web bundle with `manifest.json`, a service worker (`sw.js`) for offline caching, and automatic HTML injection. The service worker implements cache-first for static assets and network-first for API calls (`/api/*`). Configure `theme_color`, `background_color`, `cache_name`, and custom `manifest` overrides in `[plugins.client.pwa]`.
- **Code refactors**: Backtick escape, etc.
- **Environment Variable Support**: Fixed `.env` file loading by configuring Vite's `envDir` to point to the project root instead of the build directory. Variables prefixed with `VITE_` in `.env` files are now properly loaded and available via `import.meta.env` in client code. Added `.env.example` template to the all-in-one example demonstrating standard environment variable patterns.
- **Build-time Constants via jac.toml**: Added support for custom build-time constants through the `[plugins.client.vite.define]` configuration section. Define global variables that are replaced at build time, useful for feature flags, build timestamps, or configuration values. Example: `"globalThis.FEATURE_ENABLED" = true` in `jac.toml` makes `globalThis.FEATURE_ENABLED` available in client code. String values are automatically JSON-escaped to handle special characters safely.
- Updated all-in-one example `jac.toml` to include `[plugins.scale.secrets]` test config.
- **Improved API Error Handling**: Walker and function API calls now check `response.ok` and throw descriptive exceptions on HTTP errors. The `Authorization` header is only sent when a token is present, avoiding empty `Bearer` headers.
- **Better Error Diagnostics**: Silent `except Exception {}` blocks in `jacLogin` and `__jacCallFunction` now log warnings via `console.warn` for easier debugging.
- Docs update: return type `any` -> `JsxElement`

## jac-client 0.2.16

 **Fix: ESM Script Loading**: Added `type="module"` to generated `<script>` tags in the client HTML output. The Vite bundler already produces ES module output, but the script tags were missing the module attribute, causing browsers to reject ESM syntax (e.g., `import`/`export`) from newer npm packages. Affects both the server-rendered page and the `jac build --target web` static output.

- **KWESC_NAME syntax changed from `<>` to backtick**: Updated keyword-escaped names from `<>` prefix to backtick prefix to match the jaclang grammar change.
- **Update syntax for TYPE_OP removal**: Replaced backtick type operator syntax (`` `root ``) with `Root` and filter syntax (`` (`?Type) ``) with `(?:Type)` across all examples, docs, tests, and templates.
- **Support custom Vite Configurations to `dev` mode**: Added support for custom Vite configuration from `jac.toml`.
- **Watchdog auto-install test**: Added test coverage for automatic watchdog installation in dev mode.
- **Updated tests for CLI dependency command redesign**: New `jac add` behavior (errors on missing `jac.toml` instead of silently succeeding). Verify `jac add --npm` works in projects with both pypi and npm dependencies.

## jac-client 0.2.14

## jac-client 0.2.15

## jac-client 0.2.14

- **JsxElement Return Types**: Updated all JSX component return types from `any` to `JsxElement` for compile-time type safety.
- **Updated Fullstack Template**: Modernized the `fullstack` jacpack template to use idiomatic Jac patterns -- `can with entry` lifecycle effects instead of `useEffect`, JSX comprehensions instead of `.map()`, and impl separation (`frontend.impl.jac`) for cleaner code organization. Updated template README with project structure and pattern documentation.
- **E2E Tests**: Now use jacpack workflow for testing.
- **Multi-Profile Config Support**: Added integration test coverage for `--profile` flag to verify profile-specific settings propagate through the client bundling pipeline.
- **File-Based Routing**: Added Next.js-style file-based routing via a `pages/` directory convention. Place `.jac` files under `pages/` and routes are generated automatically -- `pages/index.jac` maps to `/`, `pages/about.jac` to `/about`, `pages/users/[id].jac` to `/users/:id`, and `pages/[...slug].jac` to a catch-all `*` route. Organize routes with parenthesized group directories: `pages/(auth)/` marks enclosed pages as requiring authentication, while `pages/(public)/` keeps them open -- groups control auth without adding URL segments. Add `layout.jac` files at any level for shared layout wrappers rendered via React Router `<Outlet/>`. The compiler detects `pages/`, generates a route manifest (`_routes.js`) with lazy imports, and produces an `_entry.js` that wires up `BrowserRouter`, `Routes`, layout nesting, and an `AuthGuard` component that checks `jacIsLoggedIn()` and redirects unauthenticated users (configurable via `auth_redirect` in `jac.toml` routing config). Duplicate route paths and duplicate layouts at the same level raise `ClientBundleError` at compile time. Projects without a `pages/` directory continue to use explicit routing unchanged.

## jac-client 0.2.13

- **Console infrastructure**: Replaced bare `print()` calls with `console` abstraction for consistent output formatting.
- **Desktop App Auto-Start & Port Discovery**: Running `jac start` or `jac dev` for a desktop (Tauri) target now automatically launches the backend API server and connects the app to it -- no manual setup needed. The backend port is dynamically allocated and injected into the webview before any page JavaScript runs, so API calls just work out of the box. Configure a fixed backend URL via `base_url` in `jac.toml` if needed.
- **Bug fixes**: Fixed a sidecar crash caused by writing to a closed stdout pipe, and fixed an environment variable leak during desktop builds.
- **Enhanced Compilation for Hot Module Replacement**: Added initial module compilation for HMR without bundling'.

## jac-client 0.2.12

- **Configurable API Base URL**: Added `[plugins.client.api]` config section with `base_url` option. By default (empty), API calls use same-origin relative URLs. Set `base_url = "http://localhost:8000"` for cross-origin setups.
- **Improved client bundling error handling and reliability:** Captures Vite/Bun output and displays concise, formatted errors after the API endpoint list; fixed the Bun install invocation to improve build reliability.
- **BrowserRouter Migration**: Migrated client-side routing from `HashRouter` to `BrowserRouter`. URLs now use clean paths (`/about`, `/user/123`) instead of hash-based URLs (`#/about`, `#/user/123`). The `navigate()` helper uses `window.history.pushState` with synthetic `PopStateEvent` dispatch instead of setting `window.location.hash`. The Vite dev server config includes `appType: 'spa'` for history API fallback during development. [Breaking Change - See Migration Guide](../breaking-changes.md)
- **Auto-Prompt for Missing Client Dependencies**: When running `jac start` on a project without npm dependencies configured (no `jac.toml` or empty `[dependencies.npm]`), the CLI now detects the missing dependencies and interactively prompts the user to install the default jac-client packages (react, vite, etc.). Accepting writes the defaults to `jac.toml` and proceeds with the build. This follows the same pattern as the existing Bun auto-install prompt and eliminates the cryptic "Cannot find package 'vite'" error that previously occurred. Additionally, stale `node_modules` directories from prior failed installs are now automatically detected and cleaned up before reinstalling.

## jac-client 0.2.11

- **Bun Runtime Migration**: Replaced npm/npx with Bun for package management and JavaScript bundling. Bun provides significantly faster dependency installation and build times. When Bun is not installed, the CLI prompts users to install it automatically via the official installer script.

- **Reactive Effects with `can with entry/exit`**: Similar to how `has` variables automatically generate `useState`, the `can with entry` and `can with exit` syntax now automatically generates React `useEffect` hooks. Use `async can with entry { }` for mount effects (async bodies are automatically wrapped in IIFE), `can with exit { }` for cleanup on unmount, and `can with [dep] entry { }` or `can with (dep1, dep2) entry { }` for effects with dependency arrays. This provides a cleaner, more declarative syntax for React lifecycle management without manual `useEffect` boilerplate.
- **Source Mapping for Vite Errors**: Added source mapping to trace Vite build errors back to original `.jac` files. Compiled JavaScript files now include source file header comments, and a custom `jacSourceMapper` Vite plugin maps error locations to the original Jac source. Source maps are enabled by default for both development and production builds, improving the debugging experience when build errors occur.
- **`@jac/runtime` Canonical Import Path**: Migrated the client runtime import path from `@jac-client/utils` to `@jac/runtime`, aligning with the new `@jac/` scoped package syntax in Jac source code. The jac-client Vite plugin now maps `@jac/runtime` to its own compiled runtime via a resolve alias. Compiled modules include ES module `export` statements so Vite can resolve named imports between modules. All examples, docs, and templates have been updated.
- **Various Refactors**: Including supporting new useEffect primitives, example updates, etc

## jac-client 0.2.10

## jac-client 0.2.9

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
