# jac-mcp Release Notes

## jac-mcp 0.1.24 (Latest Release)

### New Features

- **`run_snippet` executes in a child process**: Replaced the in-process thread runner with a dedicated subprocess worker (`_run_worker.py`). Global Jac runtime state (`mod.hub`, loaded modules, native caches, `sys.modules`) is now reclaimed by process exit instead of accumulating in the long-lived MCP server. Timeouts are enforced via `SIGKILL` on the child's process group, the only reliable way to stop a runaway snippet (CPython cannot interrupt an in-process thread).

### Bug Fixes

- **Fix: `run_snippet` worker no longer drops results on `close()` failure**: The worker now builds its result dict before calling `mach.close()` and makes `close()` best-effort via `_close_mach()`. Previously a `close()` failure (e.g. a broken plugin context in the host env) re-raised into the outer try, escaping before the result file was written, so the parent reported a "Worker produced no result" crash and discarded the snippet's real stdout/stderr/exit_code. The parent also now branches process teardown on `os.name` -- POSIX keeps `start_new_session` + `killpg(SIGKILL)`, Windows uses `CREATE_NEW_PROCESS_GROUP` + `taskkill /T /F` to tear down the child and its descendants.
- **Fix: `run_snippet` no longer crashes on a corrupt result file or leaks worker pipes**: The parent's `json.load` of the worker's result file is now guarded -- a result file that exists but is truncated or malformed (e.g. the worker was `SIGKILL`ed mid-write) is treated as no result and falls through to the diagnostic path instead of raising an uncaught `JSONDecodeError` into the MCP server. The worker `Popen` is also wrapped in a `with` block so the child's stdout/stderr pipes are closed on every exit path, including the early timeout return that previously leaked two file descriptors per hung snippet.
- **Fix: `find_repo_root` no longer trusts the bundled jaclang copy**: under the single `jac` binary, `jaclang` (and its `jac.spec`) live in the extracted runtime payload rather than the checkout, so resolving the docs root from `jaclang.__file__` returned a bogus temp directory and the doc-mapping test reported every doc file as missing. It now walks up from the working directory (and the `jac_mcp` package) for the monorepo markers `docs/docs` + `jac/jaclang`, returning `None` in standalone installs so callers fall back to bundled content.

## jac-mcp 0.1.23

### Bug Fixes

- **Fix: MCP `create_project` default template**: The MCP compiler bridge's `create_project` (and `list_templates` test) defaulted to the `default` template, which the kind-aware `jac create` work renamed to `cli`. The bridge now defaults to the `cli` core template so MCP-driven project creation works again.

## jac-mcp 0.1.17

### Refactors

- **Refactor: read base path via `Jac.get_base_path_dir()`**: Migrated to the new accessor; the prior `Jac.base_path_dir` class attribute has been removed.
- **Refactor: drop redundant `Jac.setup()` calls**: The compiler bridge no longer calls the removed `Jac.setup()` no-op before each command.

## jac-mcp 0.1.16

### New Features

- **MCP: Serve reference guides from the shared store**: The MCP server now serves the Jac reference guides from jaclang's bundled guide store (`jac://guide/*`) instead of vendoring its own copy, keeping one source of truth.

## jac-mcp 0.1.12

### New Features

- **Add: `mode` setting for tool/prompt surface (lite/standard/full)**: The MCP server now reads a `mode` field from `[plugins.mcp]` in `jac.toml` and exposes a `--mode` CLI flag on `jac mcp` that writes the choice into the in-memory plugin config. Resolution order is CLI > `jac.toml` > default (`full`). `full` preserves existing behavior; `lite` and `standard` are reserved tiers for smaller models and currently expose the same surface as `full`. Per-mode exclusion sets will be populated in follow-up releases. Unknown values fall back to `full` with a logged warning.

## jac-mcp 0.1.11

- 1 small refactor/change.

## jac-mcp 0.1.10

- **Content QA fixes**: Updated `root` to `root()` in pitfalls and knowledge map to match current deprecation (W0062). Fixed invalid graph filter syntax `` [-->](`?B) `` → `[-->][?:B]` in pitfalls. Updated `root spawn` → `root() spawn` in client-side examples.
- **New doc mappings**: Added `jac://docs/tutorial-fullstack-npm`, `jac://docs/tutorial-fullstack-advanced`, and `jac://docs/diagnostics` to DOC_MAPPINGS and knowledge map. Bundled docs updated.

## jac-mcp 0.1.9

- 1 small refactor/change.
- **Knowledge map tools**: `understand_jac_and_jaseci` and `get_resource` tools for on-demand doc fetching with size-tagged URIs, expanded fullstack coverage, enum-validated example categories, and leaner tool/server descriptions.
- **Client-side and full-stack pitfalls**: Added new pitfalls documentation covering client-side `.cl.jac` and full-stack gotchas.

## jac-mcp 0.1.8

- **Full CLI access over MCP**: AI models can now discover and run any `jac` CLI command (including plugin-provided ones) directly from the MCP session. `list_commands` returns a lightweight summary; `get_command(name)` returns full argument details; `execute_command` runs them. Replaces the narrower `start_server`, `create_project`, and `list_templates` tools.

## jac-mcp 0.1.7

- 2 small changes.
- **8 new tools**: AI models can now run Jac code, lint files, convert Jac to Python or JavaScript, visualize graphs, list project templates, scaffold new projects, and start a local server - all from within the MCP session.
- **`jac_to_js` fix**: Client-side transpilation now correctly targets `.cl.jac` files; previously produced no output.
- **`start_server` fix**: Server startup now runs from the project's directory so `jac.toml` is discovered correctly.
- **Expanded test coverage**: 35 new tests covering all new tools at both the `CompilerBridge` and `ToolProvider` levels.
- **Richer example descriptions**: `list_examples` now returns a meaningful one-line description per example (fullstack, OSP, native/lib mode, etc.) so AI models can pick the right one without fetching its contents first.

## jac-mcp 0.1.6

- **Fix SSE transport method issue**
- **Fix `prompts/get` failing with Pydantic validation error**: System instructions now correctly use `role: "assistant"`
- **Fix CompilerBridge tools returning incorrect results**: `check_syntax`, `validate_jac`, and `get_ast` now use the compiler's structured diagnostics and parse API to correctly detect errors and return real AST output
- **Fix error reporting and example loading**: Syntax errors now report accurate line/column numbers. `list_examples` now correctly falls back to GitHub API when installed from PyPI, instead of returning an empty list
- **Fix jac-mcp configuration issue in `jac.toml`***: Respect [plugins.mcp] config from jac.toml in jac mcp, using it as fallback when CLI args are not explicitly provided.
- **Lazy GitHub-based example fetching**: Examples are now fetched on-demand from GitHub instead of being bundled in the PyPI package, reducing package size and ensuring examples are always up-to-date. Local repo examples are used when available, with GitHub as a fallback

## jac-mcp 0.1.5

## jac-mcp 0.1.4

- **Fix streamable HTTP transport method issue**: Refactors the server initialization logic for the `streamable-http` transport method.
- 1 small change/refactor.

## jac-mcp 0.1.3

- **Updated token definitions path**: Grammar resource now references `tokens.na.jac` (renamed from `tokens.jac`)
- **Added backtick escaping pitfall**: New section documenting when keywords need backtick escaping and clarifying that special variable references (`self`, `super`, `root`, `here`, `visitor`, `init`, `postinit`) are used directly without backticks

## jac-mcp 0.1.2

- **Compiler-validated MCP content**: Cross-validated all code snippets in pitfalls.md and patterns.md against the Jac compiler, fixing critical issues where the server was teaching syntax the compiler rejects
- **Fixed `can` vs `def` guidance**: `can` is only for event-driven abilities (`can X with Y entry`); `def` is correct for regular methods. Updated pitfalls, patterns, and SERVER_INSTRUCTIONS accordingly
- **Fixed `enumerate()` pitfall**: Corrected documentation that wrongly said `enumerate()` is unsupported in Jac
- **Removed invalid `<>` ByRef pitfall**: This syntax does not exist in current Jac
- **Fixed `class` vs `obj` pitfall**: `class` is valid Jac syntax alongside `obj`
- **Fixed match/case syntax in patterns**: Uses colon syntax, not braces
- **Enhanced SERVER_INSTRUCTIONS**: Corrected `can`/`def` guidance sent to AI clients during MCP initialization
- **Enhanced tool descriptions**: Added workflow guidance (MUST validate, use before writing, etc.)
- **System/user role separation**: All 9 prompt templates now use proper role separation
- **QA test suite**: Added 149-test `qa_server.jac` covering resources, tools, prompts, server instructions, and compiler validation

## jac-mcp 0.1.1

- **Expanded documentation resources**: DOC_MAPPINGS now covers all 42 mkdocs pages (up from 12), including tutorials, developer workflow, and quick-start guides
- **Auto-generated doc bundling**: New `scripts/bundle_docs.jac` script replaces hardcoded CI copy commands, using DOC_MAPPINGS as the single source of truth for PyPI release bundling

## jac-mcp 0.1.0

Initial release of jac-mcp, the MCP (Model Context Protocol) server plugin for Jac.

### Features

- **MCP Server**: Full MCP server with stdio, SSE, and streamable-http transport support
- **Resources (24+)**: Grammar spec, token definitions, 11 documentation sections, example index, bundled pitfalls/patterns guides
- **Tools (9)**: validate_jac, check_syntax, format_jac, py_to_jac, explain_error, list_examples, get_example, search_docs, get_ast
- **Prompts (9)**: write_module, write_impl, write_walker, write_node, write_test, write_ability, debug_error, fix_type_error, migrate_python
- **Compiler Bridge**: Parse, typecheck, format, and py2jac operations with timeout protection and input size limits
- **CLI Integration**: `jac mcp` command with --transport, --port, --host, --inspect flags
- **Plugin System**: Full Jac plugin with JacCmd and JacPluginConfig hooks
