# Jaclang Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of **Jaclang**. For details on changes that might require updates to your existing code, please refer to the [Breaking Changes](../breaking-changes.md) page.

## jaclang 0.9.15 (Unreleased)

- **First-Run Progress Messages**: The first time `jac` is run after installation, it now prints clear progress messages to stderr showing each internal compiler module being compiled and cached, so users understand why the first launch is slower and don't think the process is hanging.
- **LSP Responsiveness During Rapid Typing**: Improved editor responsiveness when typing quickly by properly cancelling outdated type-check operations.
- **Native Compiler: Dictionaries and Sets**: The native backend now supports `dict` and `set` types with full codegen for literals, `len()`, key/value access, subscript assignment, `in` membership testing, `set.add()`, and iteration over dict keys. Both integer and string keyed dictionaries are supported. Global-scope dict and set declarations are also handled. Validated with a comprehensive `dicts_sets.na.jac` test suite.
- **Native Compiler: Comprehensions**: Added code generation for list, dict, and set comprehensions including nested `for` clauses and `if` filters. List comprehensions with conditions, dict comprehensions mapping positions to pieces, and set comprehensions collecting move targets all compile to native LLVM IR.
- **Native Compiler: Tuples**: Tuples are now a first-class type in the native backend. Supports tuple literals, tuple indexing, tuple unpacking assignments (e.g., `(row, col) = pos;`), and tuples as dict keys and set elements. Positions throughout the chess test case are now represented as `tuple[int, int]`.
- **Native Compiler: Inherited Method Wrappers**: The native backend now generates wrapper functions for inherited methods, enabling vtable-based virtual dispatch to correctly resolve methods defined on base classes when called through subclass instances.
- **Native Compiler: Bitwise and Extended Operators**: Full support for bitwise operators (`&`, `|`, `^`, `~`, `<<`, `>>`), power operator (`**`), and all augmented assignment variants (`&=`, `|=`, `^=`, `<<=`, `>>=`, `**=`, `//=`, `%=`). Hex (`0x`), octal (`0o`), and binary (`0b`) integer literals are also handled.
- **Native Compiler: Dict/Set Comprehensions and Iteration**: Dict comprehensions, set comprehensions, and `for`-over-dict iteration (iterating keys of a dictionary) now compile to native code. Tuple membership testing in sets (`target in attacked_set`) is also supported.
- **Native Compiler: Exception Handling**: Full `try`/`except`/`else`/`finally` support in the native backend. Includes `raise` with exception type and message, multiple `except` clauses with type matching, bare `except` catch-all, `as` binding for caught exceptions, and nested try blocks. Exceptions use a lightweight stack-based handler model with `setjmp`/`longjmp` under the hood.
- **Native Compiler: File I/O**: The `open()` builtin now compiles to native code, returning a `File` struct backed by C `fopen`. File methods `read()`, `write()`, `readline()`, `close()`, and `flush()` are all supported. NULL handle checks are generated for failed opens.
- **Native Compiler: Context Managers**: `with` statements compile to native LLVM IR. `__enter__` is called on entry, `__exit__` on exit (including when exceptions occur). The `as` binding form (`with open(path) as f`) is supported. File objects implement the context manager protocol for automatic resource cleanup.
- **Native Compiler: Runtime Error Checks**: The native backend now generates runtime safety checks that raise structured exceptions: `ZeroDivisionError` for integer and float division/modulo by zero, `IndexError` for list index out of bounds, `KeyError` for missing dictionary keys, `OverflowError` for integer arithmetic overflow, `AttributeError` for null pointer dereference, `ValueError` for invalid `int()` parsing, and `AssertionError` for failed assertions.

## jaclang 0.9.14 (Latest Release)

- **Fix: `jac format` No Longer Deletes Files with Syntax Errors**: Fixed a bug where `jac format` would overwrite a file's contents with an empty string when the file contained syntax errors. The formatter now checks for parse errors before writing and leaves the original file untouched.
- **`jac lint` Command**: Added a dedicated `jac lint` command that reports all lint violations as errors with file, line, and column info. Use `jac lint --fix` to auto-fix violations. Lint rules are configured via `[check.lint]` in `jac.toml`. All enabled rules are treated as errors (not warnings). The `--fix` flag has been removed from `jac format`, which is now pure formatting only.
- **CLI Autocompletion**: Added `jac completions` command for shell auto completion. Run `jac completions --install` to enable autocompletion for subcommands, options, and file paths. Supports bash, zsh, and fish (auto-install), plus PowerShell and tcsh (manual).
- **Centralized project URLs**: Project URLs (docs, Discord, GitHub, issues) are now defined as constants in `banners.jac` and reused across the CLI banner, server error messages, and help epilog instead of being hardcoded in multiple places.
- **Client bundle error help message**: When the client bundle build fails during `jac start`, the server now prints a troubleshooting suggestion to run `jac clean --all` and a link to the Discord community for support.
- **Native Compiler Buildout**: Major expansion of the native binary compilation pipeline for `.na.jac` files. The native backend now supports enums, boolean short-circuit evaluation, break/continue, for loops, ternary expressions, string literals and f-strings, objects with fields/methods/postinit, GC-managed lists, single inheritance with vtable-based virtual dispatch, complex access chains, indexed field assignment, string methods (strip, split, indexing), builtins (ord, int, input), augmented assignment operators (`+=`, `-=`, `*=`, `//=`, `%=`), and `with entry { ... }` blocks. All heap allocations use Boehm GC. Validated end-to-end with a fully native chess game.
- **`jac run` for `.na.jac` Files**: Running `jac run file.na.jac` now compiles the file to native machine code and executes the `jac_entry` function directly, bypassing the Python import machinery entirely. Native execution runs as pure machine code with zero Python interpreter overhead at runtime.
- **LSP Semantic Token Manager Refactor**: Refactored the language server's `SemTokManager` for production robustness. Deduplicated ~170 lines of shared symbol resolution logic.
- **Configuration Profiles**: Added multi-file configuration support with profile-based overrides. Projects can now use `jac.<profile>.toml` files (e.g., `jac.prod.toml`, `jac.staging.toml`) for environment-specific settings and `jac.local.toml` for developer-specific overrides that are automatically gitignored. Files are merged in priority order: `jac.toml` (base) < `jac.<profile>.toml` < `[environments.<profile>]` in-file overrides < `jac.local.toml`. Activate a profile via `--profile` flag on execution commands (e.g., `jac run app.jac --profile prod`, `jac start --profile staging`), the `JAC_PROFILE` environment variable, or `[environment].default_profile` in `jac.toml`. The `jac config path` command now displays all loaded config files with their priority labels. The `JAC_ENV` environment variable is deprecated in favor of `JAC_PROFILE`.
- **Configuration Profile Bug Fixes**: Fixed several issues in the multi-profile config implementation: `storage.type` key now correctly maps to the `storage_type` field during profile merges, nested plugin configs use deep merge instead of shallow overwrite (preserving nested keys), `apply_profile` now handles all config sections (build, format, dot, cache, storage, check, project, dependencies, scripts -- previously only run, serve, test, and plugins), circular profile inheritance is detected and short-circuited instead of causing `RecursionError`, mutable default `config_files` field replaced with `None` sentinel to prevent cross-instance sharing, and config-to-CLI-args bridging added so profile values (e.g., `serve.port`) correctly override argparse defaults at runtime.
- **JsxElement Builtin Type**: Added `JsxElement` builtin type for strict type checking of JSX expressions for client-side UI components.
- **1 Small Refactors**

## jaclang 0.9.13

- **Configurable Lint Rules**: Auto-lint rules are now individually configurable via `jac.toml` `[check.lint]` section using a select/ignore model. A `LintRule` enum defines all 12 rules with kebab-case names. Use `select = ["default"]` for code-transforming rules only, `select = ["all"]` to enable every rule including warning-only rules, `ignore = ["rule-name"]` to disable specific ones, or `select = ["rule1", "rule2"]` to enable only listed rules.
- **No-Print Lint Rule**: Added a `no-print` lint rule that errors on bare `print()` calls in `.jac` files, encouraging use of the console abstraction instead. Included in the `"all"` group; enable via `select = ["all"]` or `select = ["default", "no-print"]` in `[check.lint]`.
- **Format Command Lint Errors**: `jac format --fix` now reports lint errors (e.g., `[no-print]`) with file, line, and column info, and returns exit code 1 when violations are found.
- **ES Module Export Generation**: Exports now generated at compiler level via ESTree nodes instead of regex post-processing. Only `:pub` declarations are exported.
- **Hot fix: call state**: Normal spawn calls inside API spawn calls supported.
- **`--no_client` flag for `jac start`**: Added `--no_client` CLI flag that skips eager client bundling on server startup. Useful when we need to run server only.
- **Enhanced Client Compilation for Development**: Improved the `jac start --dev` command to perform initial client compilation for HMR.

## jaclang 0.9.12

- **Native Binary Compilation via `na {}` Blocks and `.na.jac` Files**: Added a third compilation target to Jac using `na {}` context blocks and `.na.jac` file conventions. Code within the `na` context compiles to native LLVM IR via llvmlite and is JIT-compiled to machine code at runtime. Functions defined in `na {}` blocks are callable via ctypes function pointers. Supports integer, float, and boolean types, arithmetic and comparison operators, if/else and while control flow, recursive function calls, local variables with type inference, and `print()` mapped to native `printf`. Native code is fully isolated from Python (`sv`) and JavaScript (`cl`) codegen -- `na` functions are excluded from both `py_ast` and `es_ast` output, and vice versa. The `llvmlite` package is now a core dependency.
- **SPA Catch-All for BrowserRouter Support**: The `jac start` HTTP server now serves SPA HTML for unmatched extensionless paths when `base_route_app` is configured in `jac.toml`. This enables BrowserRouter-style client-side routing where direct navigation to `/about` or page refresh on `/dashboard/settings` serves the app shell instead of returning 404. API paths (`/functions`, `/walkers`, `/walker/`, `/function/`, `/user/`), `/cl/` routes, and static file paths are excluded from the catch-all. The vanilla (non-React) client runtime (`createRouter`, `navigate`, `Link`) has also been updated to use `pushState` navigation and `window.location.pathname` instead of hash-based routing.
- **Startup error handling improvements:** Aggregates initialization errors and displays concise, formatted Vite/Bun bundling failures after the API endpoint list.
- **Venv-Based Dependency Management**: Migrated `jac add`/`jac remove`/`jac install` from `pip install --target` to stdlib `venv` at `.jac/venv/`. This eliminates manual RECORD-based uninstall logic and metadata cleanup workarounds, delegating all package management to the venv's own pip. No third-party dependencies added.
- **GET Method Support**: Added full support for HTTP GET requests for both walkers and functions, including correct mapping of query parameters, support for both dynamic (HMR) and static endpoints, and customization via `@restspec(method=HTTPMethod.GET)`.
- **Enhanced Hot Module Replacement**: Improved client code recompilation to handle exports comprehensively, ensuring all exported symbols are properly updated during hot reloads.
- **Rest API Specifications Supported**: Rest api specifications supported from jaclang. Developers can utilize it using `@restspec()` decorator.
- **Ensurepip Error Handling**: Added a clear error message when venv creation fails due to missing `ensurepip` (common on Debian/Ubuntu where `python3-venv` is a separate package), with platform-specific install instructions.
- **Suppress Warnings in `jac check`**: Added `--nowarn` flag to `jac check` command to suppress warning output while still counting warnings in the summary.
- **Rest API Specifications Supported**: The `@restspec` decorator now supports custom HTTP methods and custom endpoint paths for both walkers and functions.
  - **Custom Methods**: Use `method=HTTPMethod.GET`, `method=HTTPMethod.PUT`, etc.
  - **Custom Paths**: Use `path="/my/custom/path"` to override the default routing.
- **Storage Abstraction**: Added pluggable `Storage` interface with `LocalStorage` default implementation. Use `store()` builtin to get a configured storage instance. Configure via `jac.toml [storage]` or environment variables.
- **Static files support HMR**: Added infrastructure for Hot Module Replacement during development. The file watcher now supports static assets files such as `.css` and images (`.png`, `.jpg`, `.jpeg`) in addition to `.jac` files, enabling automatic reloading of client-side code changes.
- **Internal**: Explicitly declared all postinit fields across the codebase.
- **Build (jacpack)**: `.jac/.gitignore` now contains only a comment (not `*`), so compiled assets (e.g., `compiled/`) aren't ignored and Tailwind builds correctly.
- **Support Go to Definition for Nested Unpacking Assignments**: Fixed symbol table generation to support recursive nested unpacking (e.g., `[a, [b, c]] = val`) ensuring all inner variables are registered.
- **Fix: Module Name Truncation in MTIR Scope Resolution**: Fixed a bug where module names ending with 'j', 'a', or 'c' were incorrectly truncated due to using `.rstrip(".jac")` instead of `.removesuffix(".jac")`. This caused MTIR lookup failures and degraded functionality when the runtime tried to fetch metadata with the correct module name but found truncated keys (e.g., `test_schema` → `test_schem`).

## jaclang 0.9.11

- **MTIR Generation Pass**: Added `MTIRGenPass` compiler pass that extracts semantic type information from GenAI `by` call sites at compile time. The pass captures parameter types, return types, semstrings, tool schemas, and class structures into `Info` dataclasses (`FunctionInfo`, `MethodInfo`, `ClassInfo`, `ParamInfo`, `FieldInfo`). MTIR is stored in `JacProgram.mtir_map` keyed by scope path.

- **MTIR Bytecode Caching**: Extended `DiskBytecodeCache` to cache MTIR maps alongside bytecode (`.mtir.pkl` files). MTIR is automatically saved after compilation and restored from cache on subsequent runs, avoiding redundant extraction.

- **Reactive Effects with `can with entry/exit`**: The `can with entry` and `can with exit` syntax now automatically generates React `useEffect` hooks in client-side code. When used inside a `cl` codespace, `async can with entry { items = await fetch(); }` generates `useEffect(() => { (async () => { setItems(await fetch()); })(); }, []);`. Supports dependency arrays using list or tuple syntax: `can with (userId, count) entry { ... }` generates effects that re-run when dependencies change. The `can with exit` variant generates cleanup functions via `return () => { ... }` inside the effect. This provides a declarative, Jac-native way to handle component lifecycle without manual `useEffect` boilerplate.

- **`@jac/runtime` Import Syntax**: Client-side runtime imports now use the npm-style `@jac/runtime` scoped package syntax instead of the previous `jac:client_runtime` prefix notation. Write `cl import from "@jac/runtime" { useState, useEffect, createSignal, ... }` in place of the old `cl import from jac:client_runtime { ... }`. The grammar no longer supports the `NAME:` prefix on import paths. The core bundler inlines `@jac/runtime` into the client bundle automatically, so no external dependencies are needed for basic fullstack apps.
- **JSX Comprehension Syntax**: List and set comprehensions containing JSX elements now compile to JavaScript `.map()` and `.filter().map()` chains. Instead of verbose `{items.map(lambda item: dict -> any { return <li>{item}</li>; })}`, you can now write `{[<li key={item.id}>{item.title}</li> for item in items]}` or use double-brace syntax `{{ <li>{item}</li> for item in items }}`. Filtered comprehensions like `{[<li>{item}</li> for item in items if item.active]}` generate `.filter(item => item.active).map(item => ...)`. This brings Python-style comprehension elegance to JSX rendering.

- **Type Checking Improvements**:
  - **Permissive Type Check for Node Collections in Connections**: The type checker now accepts collections (list, tuple, set, frozenset) on the right side of connection operators (`++>`, `<++>`, etc.). Previously, code like `root ++> [Node1(), Node2(), Node3()];` was incorrectly rejected. This is a temporary workaround until element type inference for list literals is fully implemented.
  - **Exclude `by postinit` Fields from Required Constructor Parameters**: Fields declared with `by postinit` are now correctly excluded from required constructor parameters during type checking. Previously, instantiating an object like `SomeObj()` with `by postinit` fields would incorrectly report missing required arguments, even though these fields are initialized via the `postinit` method.

## jaclang 0.9.10

- **Formatter Spacing Fixes**: Fixed extra spaces before semicolons in `report` and `del` statements, and corrected semantic definition formatting to properly handle dot notation and `=` operator spacing.

## jaclang 0.9.9

### Breaking Changes

- **Removed `jac build` Command and JIR File Support**: The `jac build` command and `.jir` (Jac Intermediate Representation) file format have been removed. Users should run `.jac` files directly with `jac run`. The bytecode cache (`.jbc` files in `.jac/cache/`) continues to provide compilation caching automatically. If you have existing `.jir` files, simply delete them and run the `.jac` source files directly.

### Features and Improvements

- **Console Plugin Architecture**: Refactored console system to use a plugin-based architecture, removing the `rich` dependency from core jaclang. The base `JacConsole` now uses pure Python `print()` for all output, keeping jaclang dependency-free. Plugins (like `jac-super`) can override the console implementation via the `get_console()` hook to provide Rich-enhanced output with themes, panels, tables, and spinners. This maintains backward compatibility while allowing optional aesthetic enhancements through plugins.

- **User Management Endpoints**:  Added new user management endpoints to the `jac start` API server:
  - `GET /user/info` - Retrieve authenticated user's information (username, token, root_id)
  - `PUT /user/username` - Update the authenticated user's username
  - `PUT /user/password` - Update the authenticated user's password
  All endpoints require authentication via Bearer token and include proper validation to prevent unauthorized access.

- **Unified User and Application Database**: The `jac start` basic user authentication system now stores users in the same SQLite database (`main.db`) as application data, instead of a separate `users.json` file. This provides ACID transactions for user data, better concurrency with WAL mode, and simplified backup/restore with a single database file as a reference (overridden for production jac-scale).

- **Improved JSX Formatter**: The JSX formatter now uses soft line breaks with automatic line-length detection instead of forcing multiline formatting. Attributes stay on the same line when they fit within the line width limit (88 characters), producing more compact and readable output. For example, `<button id="submit" disabled />` now stays on one line instead of breaking each attribute onto separate lines.

- **Template Bundling Infrastructure**: Added `jac jacpack pack` command to bundle project templates into distributable `.jacpack` files. Templates are defined by adding a `[jacpack]` section to `jac.toml` with metadata and options, alongside template source files with `{{name}}` placeholders. The bundled JSON format embeds all file contents for easy distribution, and templates can be loaded from either directories or `.jacpack` files for use with `jac create --use`.

- **Secure by Default API Endpoints**: Walkers and functions exposed as API endpoints via `jac start` now **require authentication by default**. Previously, endpoints without an explicit access modifier were treated as public. Now, only endpoints explicitly marked with `: pub` are publicly accessible without authentication. This "secure by default" approach prevents accidental exposure of sensitive endpoints. Use `: pub` to make endpoints public (e.g., `walker : pub MyPublicWalker { ... }`).

- **Default `main.jac` for `jac start`**: The `jac start` command now defaults to `main.jac` when no filename is provided, making it easier to start applications in standard project structures. You can still specify a different file explicitly (e.g., `jac start app.jac`), and the command provides helpful error messages if `main.jac` is not found.

- **Renamed Template Flags for `jac create`**: The `--template`/`-t` flag has been renamed to `--use`/`-u`, and `--list-templates`/`-l` has been renamed to `--list-jacpacks`/`-l`. This aligns the CLI with jacpack terminology for clearer naming (e.g., `jac create myapp --use client`, `jac create --list-jacpacks`).

- **Flexible Template Sources for `jac create`**: The `--use` flag now supports local file paths to `.jacpack` files, template directories, and URLs for downloading remote templates (e.g., `jac create --use ./my.jacpack` or `jac create --use https://example.com/template.jacpack`).

## jaclang 0.9.8

- **Recursive DFS Walker Traversal with Deferred Exits**: Walker traversal semantics have been fundamentally changed to use recursive post-order exit execution. Entry abilities now execute when entering a node, while exit abilities are deferred until all descendants are visited. This means exits execute in LIFO order (last visited node exits first), similar to function call stack unwinding. The `walker.path` field is now actively populated during traversal, tracking visited nodes in order.
- **Imported Functions and Walkers as API Endpoints**: The `jac start` command now automatically convert imported functions and walkers to API endpoints, in addition to locally defined ones. Previously, only functions and walkers defined directly in the target file were exposed as endpoints. Now, any function or walker explicitly imported into the file will also be available as an API endpoint.
- **Hot Module Replacement (HMR)**: Added `--dev` flag to `jac start` for live development with automatic reload on `.jac` file changes. When enabled, the file watcher detects changes and automatically recompiles backend code while Vite handles frontend hot-reloading. New options include `-d/--dev` to enable HMR mode, `--api-port` to set a separate API port, and `--no-client` for API-only mode without frontend bundling. Example usage: `jac start --dev`.
- **Default Watchdog Dependency**: The `jac create` command now includes `watchdog` in `[dev-dependencies]` by default, enabling HMR support out of the box. Install with `jac install --dev`.
- **Simplified `.jac` Directory Gitignore**: The `jac create` command now creates a `.gitignore` file inside the `.jac/` directory containing `*` to ignore all build artifacts, instead of modifying the project root `.gitignore`. This keeps project roots cleaner and makes the `.jac` directory self-contained.
- **Ignore Patterns for Type Checking**: Added `--ignore` flag to the `jac check` command, allowing users to exclude specific files or folders from type checking. The flag accepts a comma-separated list of patterns (e.g., `--ignore fixtures,tests,__pycache__`). Patterns are matched against path components, so `--ignore tests` will exclude any file or folder named `tests` at any depth in the directory tree.
- **Project Clean Command**: Added `jac clean` command to remove build artifacts from the `.jac/` directory. By default, it cleans the data directory (`.jac/data`). Use `--all` to clean all artifacts (data, cache, packages, client), or specify individual directories with `--data`, `--cache`, or `--packages` flags. The `--force` flag skips the confirmation prompt.

## jaclang 0.9.7

- **Unified `jac start` Command**: The `jac serve` command has been renamed to `jac start`. The `jac scale` command (from jac-scale plugin) now uses `jac start --scale` instead of a separate command. This provides a unified interface for running Jac applications locally or deploying to Kubernetes.
- **Eager Client Bundle Loading**: The `jac start` command now builds the client bundle at server startup instead of lazily on first request.
- **Configuration Management CLI**: Added `jac config` command for viewing and modifying `jac.toml` project settings. Supports actions: `show` (display explicitly set values), `list` (display all settings including defaults), `get`/`set`/`unset` (manage individual settings), `path` (show config file location), and `groups` (list available configuration sections). Output formats include table, JSON, and TOML. Filter by configuration group with `-g` flag.
- **Reactive State Variables in Client Context**: The `has` keyword now supports reactive state in client-side code. When used inside a `cl {}` block, `has count: int = 0;` automatically generates `const [count, setCount] = useState(0);`, and assignments like `count = count + 1;` are transformed to `setCount(count + 1);`. This provides a cleaner, more declarative syntax for React state management without explicit `useState` destructuring.
- **Consolidated Build Artifacts Directory**: All Jac project build artifacts are now organized under a single `.jac/` directory instead of being scattered across the project root. This includes bytecode cache (`.jac/cache/`), Python packages (`.jac/packages/`), client build artifacts (`.jac/client/`), and runtime data like ShelfDB (`.jac/data/`). The base directory is configurable via `[build].dir` in `jac.toml`. This simplifies `.gitignore` to a single entry and provides cleaner project structures.
- **Format Command Auto-Formats Related Files**: The `jac format` command now automatically formats all associated annex files (`.impl.jac` and `.cl.jac`) when formatting a main `.jac` file. The format passes traverse impl modules in a single pass, and all related files are written together, ensuring consistent formatting across module boundaries.
- **Auto-Lint: Empty Parentheses Removal for Impl Blocks**: The `jac format --fix` command now removes unnecessary empty parentheses from `impl` block signatures, matching the existing behavior for function declarations. For example, `impl Foo.bar() -> int` becomes `impl Foo.bar -> int`.
- **Enhanced Plugin Management CLI**: The `jac plugins` command now provides comprehensive plugin management with `list`, `disable`, `enable`, and `disabled` subcommands. Plugins are displayed organized by PyPI package with fully qualified names (`package:plugin`) for unambiguous identification. Plugin settings persist in `jac.toml` under `[plugins].disabled`, and the `JAC_DISABLED_PLUGINS` environment variable provides runtime override support. Use `*` to disable all external plugins, or `package:*` to disable all plugins from a specific package.
- **Simplified NonGPT Implementation**: NonGPT is now a native default that activates automatically when no LLM plugin is installed. The implementation no longer fakes the `byllm` import, providing cleaner behavior out of the box.

## jaclang 0.9.4

- **`let` Keyword Removed**: The `let` keyword has been removed from Jaclang. Variable declarations now use direct assignment syntax (e.g., `x = 10` instead of `let x = 10`), aligning with Python's approach to variable binding.
- **Py2Jac Robustness Improvements**: Improved reliability of Python-to-Jac conversion with better handling of f-strings (smart quote switching, no keyword escaping in interpolations), match pattern class names, attribute access formatting (no extra spaces around dots), and nested docstrings in classes and functions.
- **Format Command Enhancements**: The `jac format` command now tracks and reports which files were actually changed during formatting. The summary output shows both total files processed and the count of files that were modified (e.g., `Formatted 10/12 '.jac' files (3 changed).`). Additionally, syntax errors encountered during formatting are now printed with full error details.
- **Py2Jac Stability**: Fixed conversion of Python code with augmented assignments and nested docstrings so generated Jac no longer redeclares targets or merges docstrings into following defs.
- **Support JS Switch Statement**: Javascript transpilation for switch statement is supported.
- **F-String Escape Sequence Fix**: Fixed a bug where escape sequences like `\n`, `\t`, etc. inside f-strings were not being properly decoded, causing literal backslash-n to appear in output instead of actual newlines. The fix correctly decodes escape sequences for f-string literal fragments in `unitree.py`.
- **Python `-m` Module Execution Support**: Added ability for Jac modules to be executed directly via `python -m module_name`. When jaclang is auto-imported at Python startup (via a `.pth` file like `jaclang_hook.pth`), both single-file Jac modules and Jac packages (with `__main__.jac`) can be run using Python's standard `-m` flag.
- **Use Keywords as variable**: Developers can now use any jaclang keywords as variable by using escape character `<>`. Example: `<>from`.
- **Props support**: Support Component props system with Python kwargs style with `props` keyword. Ex: `props.children`.
- **Standalone `.cl.jac` Module Detection**: `.cl.jac` files are now recognized as Jac modules both as standalone import targets (when no `.jac` exists) and as attachable client annexes.
- **Use Keywords as variable**: Developers can now use any jaclang keywords as variable by using escape character `<>`. Example: `<>from`.
- **Strings supported without escaping within jsx**: Strings supported without escaping within jsx. Example usage: `<h1> "Authentication" App </h1>`
- **Support output format for dot command**: Output format for dot command is supported. Example Usage: `jac dot filename.jac --format json`
- **Shared `impl/` Folder for Annex Discovery**: Impl files can now be organized in a shared `impl/` folder within the same directory as the target module. For example, `impl/foo.impl.jac` will be discovered and attached to `foo.jac`, alongside the existing discovery methods (same directory and module-specific `.impl/` folders).
- **Type Checking Enhancements**: Added type checking support for `Final` type hint.
- **Unified Plugin Configuration System**: Introduced a standardized configuration interface for Jac plugins through `jac.toml`. Plugins can now register configuration schemas via `get_plugin_metadata()` and `get_config_schema()` hooks, with settings defined under `[plugins.<plugin_name>]` sections. This replaces environment variable-based configuration with a centralized, type-safe approach. Applied to jac-client, jac-scale and jac-byllm plugins.
- **Auto-Lint: hasattr to Null-Safe Conversion**: The `jac format --fix` command now automatically converts `hasattr(obj, "attr")` patterns to null-safe access syntax (`obj?.attr`). This applies to hasattr calls in conditionals, boolean expressions (`and`/`or`), and ternary expressions. Additionally, patterns like `obj.attr if hasattr(obj, "attr") else default` are fully converted to `obj?.attr if obj?.attr else default`, ensuring consistent null-safe access throughout the expression.
- **Auto-Lint: Ternary to Or Expression Simplification**: The auto-lint pass now simplifies redundant ternary expressions where the value and condition are identical. Patterns like `x if x else default` are automatically converted to the more concise `x or default`. This works with any expression type including null-safe access (e.g., `obj?.attr if obj?.attr else fallback` becomes `obj?.attr or fallback`).
- **Improved Null-Safe Subscript Operator `?[]`**: The null-safe subscript operator now safely handles invalid subscripts in addition to None containers (e.g., `list?[10]` returns `None` instead of raising an error; `dict?["missing"]` returns `None` for missing keys). This applies to all subscriptable types and makes `?[]` a fully safe access operator, preventing index and key errors.
- **Support cl File without Main File**: Developers can write only cl file without main jac files whenever main file is not required.
- **Support Custom headers to Response**: Custom headers can be added by using an enviornmental variable `[environments.response.headers]` and mentioning the custom headers (Ex: `"Cross-Origin-Opener-Policy" = "same-origin"`).

## jaclang 0.9.3

- **Fixed JSX Text Parsing for Keywords**: Fixed a parser issue where keywords like `to`, `as`, `in`, `is`, `for`, `if`, etc. appearing as text content within JSX elements would cause parse errors. The grammar now correctly recognizes these common English words as valid JSX text content.
- **Support iter for statement**: Iter for statement is supported in order to utilize traditional for loop in javascript.
- **JavaScript Export Semantics for Public Declarations**: Declarations explicitly annotated with `:pub` now generate JavaScript `export` statements. This applies to classes (`obj :pub`), functions (`def :pub`), enums (`enum :pub`), and global variables (`glob :pub`), enabling proper ES module exports in generated JavaScript code.
- **Cross-Language Type Checking for JS/TS Dependencies**: The type checker now supports loading and analyzing JavaScript (`.js`) and TypeScript (`.ts`, `.jsx`, `.tsx`) file dependencies when used with client-side (`cl`) imports. This enables type checking across language boundaries for files with client-language elements, allowing the compiler to parse and include JS/TS modules in the module hub for proper type resolution.
- **Formatter Improvements and Standardization**: Enhanced the Jac code formatter with improved consistency and standardization across formatting rules.

## jaclang 0.9.1

-**Side effect imports supported**: side effect imports supported which will help to inject css.

- **Plugin for sending static files**: Added extensible plugin system for sending static files, enabling custom static file serving strategies and integration with various storage backends.
- **Type Checking Enhancements**:
  - Added type checking support for object spatial codes including the connect operator
  - Added type checking support for assign comprehensions and filter comprehensions
  - Improved type inference from return statements
  - Fixed inheritance-based member lookup in type system by properly iterating through MRO (Method Resolution Order) chain
  - Improved synthesized `__init__` method generation for dataclasses to correctly collect parameters from all base classes in inheritance hierarchy
- **LSP Improvements**: Added "Go to Definition" support for `here` and `visitor` keywords in the language server

## jaclang 0.9.0

- **Generics TypeChecking**: Type checking for generics in vscode extension has implemented, i.e. `dict[int, str]` can be now checked by the lsp.
- **Plugin Architecture for Server Rendering**: Added extensible plugin system for server-side page rendering, allowing custom rendering engines and third-party templating integration with transform, cache, and customization capabilities.
- **Improvements to Runtime Error reporting**: Made various improvements to runtime error CLI reporting.
- **Node Spawn Walker supported**: Spawning walker on a node with `jac start` (formerly `jac serve`) is supported.

## jaclang 0.8.10

- **Frontend + Backend with `cl` Keyword (Experimental)**: Introduced a major experimental feature enabling unified frontend and backend development in a single Jac codebase. The new `cl` (client) keyword marks declarations for client-side compilation, creating a dual compilation pipeline that generates both Python (server) and pure JavaScript (client) code. Includes full JSX language integration for building modern web UIs, allowing developers to write React-style components directly in Jac with seamless interoperability between server and client code.
- **Optional Ability Names**: Ability declarations now support optional names, enabling anonymous abilities with event clauses (e.g., `can with entry { ... }`). When a name is not provided, the compiler automatically generates a unique internal name based on the event type and source location. This feature simplifies walker definitions by reducing boilerplate for simple entry/exit abilities.
- **LSP Threading Performance Improvements**: Updated the Language Server Protocol (LSP) implementation with improved threading architecture for better performance and responsiveness in the VS Code extension.
- **Parser Performance Optimization**: Refactored parser node tracking to use O(N) complexity instead of O(N²), drastically reducing parsing time for large files by replacing list membership checks with set-based ID lookups.
- **OPath Designation for Object Spatial Paths**: Moved Path designation for object spatial paths to OPath to avoid conflicts with Python's standard library `pathlib.Path`. This change ensures better interoperability when using Python's path utilities alongside Jac's object-spatial programming features.
- **Import System Refactoring**: Refactored and simplified the Jac import system to better leverage Python's PEP 302 and PEP 451 import protocols. Removed over-engineered custom import logic in favor of standard Python meta path finders and module loaders, improving reliability and compatibility.
- **Module Cache Synchronization Fix**: Fixed module cache synchronization issues between `JacMachine.loaded_modules` and `sys.modules` that caused test failures and module loading inconsistencies. The machine now properly manages module lifecycles while preserving special Python modules like `__main__`.
- **Formatted String Literals (f-strings)**: Added improved and comprehensive support for Python-style formatted string literals in Jac with full feature parity.
- **Switch Case Statement**: Switch statement is introduced and javascript style fallthrough behavior is also supported.

## jaclang 0.8.9

- **Typed Context Blocks (OSP)**: Fully implemented typed context blocks (`-> NodeType { }` and `-> WalkerType { }`) for Object-Spatial Programming, enabling conditional code execution based on runtime types.
- **Parser Infinite Loop Fix**: Fixed a major parser bug that caused infinite recursion when encountering malformed tuple assignments (e.g., `with entry { a, b = 1, 2; }`), preventing the parser from hanging.
- **Triple Quoted F-String Support**: Added support for triple quoted f-strings in the language, enabling multi-line formatted strings with embedded expressions (e.g., `f"""Hello {name}"""`).
- **Library Mode Interface**: Added new `jaclang.lib` module that provides a clean, user-friendly interface for accessing JacMachine functionality. This module auto-exposes all static methods from `JacMachineInterface` as module-level functions, making it easier to use Jac as a Python library.
- **Enhanced `jac2py` CLI Command**: The `jac2py` command now generates cleaner Python code suitable for library use with direct imports from `jaclang.lib` (e.g., `from jaclang.lib import Walker`), producing more readable and maintainable Python output.
- **Clean generator expression within function calls**: Enhanced the grammar to support generator expressions without braces in a function call. And python to jac conversion will also make it clean.
- **Support attribute pattern in Match Case**: With the latest bug fix, attribute pattern in match case is supported. Therefore developers use match case pattern like `case a.b.c`.
- **Py2Jac Empty File Support**: Added support for converting empty Python files to Jac code, ensuring the Py2Jac handles files with no content.
- **Formatter Enhancements**: Improved the Jac code formatter with several fixes and enhancements, including:
  - Corrected indentation issues in nested blocks and after comments
  - Removed extra spaces in statements like `assert`
  - Preserved docstrings without unintended modifications
  - Enhanced handling of long expressions and line breaks for better readability
- **VSCE Improvements**: Improved environment management and autocompletion in the Jac VS Code extension, enhancing developer experience and productivity.

## jaclang 0.8.8

- **Better Syntax Error Messages**: Initial improvements to syntax error diagnostics, providing clearer and more descriptive messages that highlight the location and cause of errors (e.g., `Missing semicolon`).
- **Check Statements Removed**: The `check` keyword has been removed from Jaclang. All testing functionality previously provided by `check` statements is now handled by `assert` statements within test blocks. Assert statements now behave differently depending on context: in regular code they raise `AssertionError` exceptions, while within `test` blocks they integrate with Jac's testing framework to report test failures. This unification simplifies the language by using a single construct for both validation and testing purposes.
- **Jac Import of Python Files**: This upgrade allows Python files in the current working directory to be imported using the Jac import system by running `export JAC_PYFILE_RAISE=true`. To extend Jac import functionality to all Python files, including those in site-packages, developers can enable it by running `export JAC_PYFILE_RAISE_ALL=true`.
- **Consistent Jac Code Execution**: Fixed an issue allowing Jac code to be executed both as a standalone program and as an application. Running `jac run` now executes the `main()` function, while `jac start` (formerly `jac serve`) launches the application without invoking `main()`.
- **Run transformed pytorch codes**: With `export JAC_PREDYNAMO_PASS=true`, pytorch breaking if statements will be transformed into non breaking torch.where statements. It improves the efficiency of pytorch programs.
- **Complete Python Function Parameter Syntax Support**: Added full support for advanced Python function parameter patterns including positional-only parameters (`/` separator), keyword-only parameters (`*` separator without type hints), and complex parameter combinations (e.g., `def foo(a, b, /, *, c, d=1, **kwargs): ...`). This enhancement enables seamless Python-to-Jac conversion (`py2jac`) by supporting the complete Python function signature syntax.
- **Type Checking Enhancements**:
  - Added support for `Self` type resolution
  - Enabled method type checking for tools
  - Improved inherited symbol resolution (e.g., `Cat` recognized as subtype of `Animal`)
  - Added float type validation
  - Implemented parameter–argument matching in function calls
  - Enhanced call expression parameter type checking
  - Enhanced import symbol type resolution for better type inference and error detection
- **VSCE Improvements**:
  - Language Server can now be restarted without requiring a full VS Code window reload
  - Improved environment handling: prompts users to select a valid Jac environment instead of showing long error messages
- **Formatter Bug Fixes**:
  - Fixed `if/elif/else` expression formatting
  - Improved comprehension formatting (list/dict/set/gen)
  - Corrected decorator and boolean operator formatting
  - Fixed function args/calls formatting (removed extra commas/spaces)
  - Fixed index slice spacing and redundant atom units

## jaclang 0.8.7

- **Fix `jac run same_name_of_jac.py`**- there was a bug which only runs jac file if both jac and python files were having same name. It was fixed so that developers run python files which has same name as jac with `jac run` command. (Ex: `jac run example.jac`, `jac run example.py`)
- **Fix `jac run pythonfile.py` bugs**: Few bugs such as `init` is not found, `SubTag` ast node issue, are fixed. So that developers can run `jac run` of python files without these issues.
- **Fix `lambda self injection in abilities`**: Removed unintended `self` parameter in lambdas declared inside abilities/methods.
- **Fix `jac2py lambda annotations`**: Stripped type annotations from lambda parameters during jac2py conversion to ensure valid Python output while keeping them in Jac AST for type checking.

- **TypeChecker Diagnostics**: Introduced type checking capabilities to catch errors early and improve code quality! The new type checker pass provides static analysis including:
  - **Type Annotation Validation**: Checks explicit type annotations in variable assignments for type mismatches
  - **Type Inference**: Simple type inference for assignments with validation against declared types
  - **Member Access Type Checking**: Type checking for member access patterns (e.g., `obj.field.subfield`)
  - **Import Symbol Type Checking**: Type inference for imported symbols (Basic support)
  - **Function Call Return Type Validation**: Return type checking for function calls (parameter validation not yet supported)
  - **Magic Method Support**: Type checking for special methods like `__call__`, `__add__`, `__mul__`
  - **Binary Operation Type Checking**: Operator type validation with simple custom operator support
  - **Class Instantiation**: Type checking for class constructor calls and member access
  - **Cyclic Symbol Detection**: Detection of self-referencing variable assignments
  - **Missing Import Detection**: Detection of imports from non-existent modules

  Type errors now appear in the Jac VS Code extension (VSCE) with error highlighting during editing.

- **VSCE Semantic Token Refresh Optimization**: Introduced a debounce mechanism for semantic token refresh in the Jac Language Server, significantly improving editor responsiveness:
  - Reduces redundant deep checks during rapid file changes
  - Optimizes semantic token updates for smoother editing experience

- **Windows LSP Improvements**: Fixed an issue where outdated syntax and type errors persisted on Windows. Now, only current errors are displayed

## jaclang 0.8.6

## jaclang 0.8.5

- **Removed LLM Override**: `function_call() by llm()` has been removed as it was introduce ambiguity in the grammer with LALR(1) shift/reduce error. This feature will be reintroduced in a future release with a different syntax.
- **Enhanced Python File Support**: The `jac run` command now supports direct execution of `.py` files, expanding interoperability between Python and Jac environments.
- **Jac-Streamlit Plugin**: Introduced comprehensive Streamlit integration for Jac applications with two new CLI commands:
  - `jac streamlit` - Run Streamlit applications written in Jac directly from `.jac` files
  - `jac dot_view` - Visualize Jac graph structures in interactive Streamlit applications with both static (pygraphviz)
- **Improved Windows Compatibility**: Fixed file encoding issues that previously caused `UnicodeDecodeError` on Windows systems, ensuring seamless cross-platform development.
- **Fixed CFG inaccuracies**: Fixed issues when handling If statements with no Else body where the else edge was not captured in the CFG (as a NOOP) causing a missing branch on the CFG of the UniiR. Also fixed inaccuracies when terminating CFG branches where return statements and HasVariables had unexpected outgoing edges which are now being removed. However, the return still keeps connected to following code which are in the same scope(body) which are dead-code.

- **CFG print tool for CLI**: The CFG for a given program can be printed as a dot graph by running `jac tool ir cfg. filename.jac` CLI command.

## jaclang 0.8.4

- **Support Spawning a Walker with List of Nodes and Edges**: Introduced the ability to spawn a walker on a list of nodes and edges. This feature enables initiating traversal across multiple graph elements simultaneously, providing greater flexibility and efficiency in handling complex graph structures.
- **Bug fix on supporting while loop with else part**: Now we are supporting while loop with else part.

## jaclang 0.8.3

- **JacMachine Interface Reorganization**: The machine and interface have been refactored to maintain a shared global state(similar to Python's `sys.modules`) removing the need to explicitly pass execution context and dramatically improving performance.
- **Native Jac Imports**: Native import statements can now be used to import Jac modules seamlessly into python code, eliminating the need to use `_.jac_import()`.
- **Unicode String Literal Support**: Fixed unicode character handling in string literals. Unicode characters like "", "○", emojis, and other international characters are now properly preserved during compilation instead of being corrupted into byte sequences.
- **Removed Ignore Statements**: The `ignore` keyword and ignore statements have been removed as this functionality can be achieved more elegantly by modifying path collection expressions directly in visit statements.

## jaclang 0.8.1

- **Function Renaming**: The `dotgen` built-in function has been renamed to `printgraph`. This change aims to make the function's purpose clearer, as `printgraph` more accurately reflects its action of outputting graph data. It can output in DOT format and also supports JSON output via the `as_json=True` parameter. Future enhancements may include support for other formats like Mermaid.
- **Queue Insertion Index for Visit Statements**: Visit statements now support queue insertion indices (e.g., `visit:0: [-->]` for depth-first, `visit:-1: [-->]` for breadth-first) that control where new destinations are inserted in the walker's traversal queue. Any positive or negative index can be used, enabling fine-grained control over traversal patterns and supporting complex graph algorithms beyond simple depth-first or breadth-first strategies.
- **Edge Ability Execution Semantics**: Enhanced edge traversal behavior with explicit edge references. By default, `[-->]` returns connected nodes, while `[edge -->]` returns edge objects. When walkers visit edges explicitly using `visit [edge -->]`, abilities are executed on both the edge and its connected node. Additionally, spawning a walker on an edge automatically queues both the edge and its target node for processing, ensuring complete traversal of the topological structure.
- **Jac Imports Execution**: Jac imports (`Jac.jac_import`) now run in a Python-like interpreter mode by default. Full compilation with dependency inclusion can only occur when explicitly calling `compile` from the `JacProgram` object.
- **Concurrent Execution with `flow` and `wait`**: Introduced `flow` and `wait` keywords for concurrent expressions. `flow` initiates parallel execution of expressions, and `wait` synchronizes these parallel operations. This enables efficient parallel processing and asynchronous operations directly within Jac with separate (and better) semantics than python's async/await.

## Version 0.8.0

- **`impl` Keyword for Implementation**: Introduced the `impl` keyword for a simpler, more explicit way to implement abilities and methods for objects, nodes, edges, and other types, replacing the previous colon-based syntax.
- **Updated Inheritance Syntax**: Changed the syntax for specifying inheritance from colons to parentheses (e.g., `obj Car(Vehicle)`) for better alignment with common object-oriented programming languages.
- **`def` Keyword for Functions**: The `def` keyword is now used for traditional Python-like functions and methods, while `can` is reserved for object-spatial abilities.
- **`visitor` Keyword**: Introduced the `visitor` keyword to reference the walker context within nodes/edges, replacing the ambiguous use of `here` in such contexts. `here` is now used only in walker abilities to reference the current node/edge.
- **Lambda Syntax Update**: The lambda syntax has been updated from `with x: int can x;` to `lambda x: int: x * x;`, aligning it more closely with Python's lambda syntax.
- **Object-Spatial Arrow Notation Update**: Typed arrow notations `-:MyEdge:->` and `+:MyEdge:+>` are now `->:MyEdge:->` and `+>:MyEdge:+>` respectively, to avoid conflicts with Python-style list slicing.
- **Import `from` Syntax Update**: The syntax for importing specific modules from a package now uses curly braces (e.g., `import from utils { helper, math_utils }`) for improved clarity.
- **Auto-Resolved Imports**: Removed the need for explicit language annotations (`:py`, `:jac`) in import statements; the compiler now automatically resolves imports.
