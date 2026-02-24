# Jaclang Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of **Jaclang**. For details on changes that might require updates to your existing code, please refer to the [Breaking Changes](../breaking-changes.md) page.

## jaclang 0.11.1 (Unreleased)

- **Native Codegen: C Library Import Syntax (`import from "lib" { def ...; }`)**: Added first-class parser and IR generation support for importing C shared libraries. Declarations inside the braces are parsed as extern function signatures (no body), producing LLVM `declare` statements that MCJIT resolves from the loaded `.so`/`.dylib`. Includes fixed-width C-compatible types (`i8`, `u8`, `i16`, `u16`, `i32`, `u32`, `i64`, `u64`, `f32`, `f64`, `c_void`) and automatic type coercion (i64↔i32, f64↔f32) at call boundaries.
- **Native Codegen: C Struct Value-Type Coercion**: C structs declared inside `import from "lib" { obj Color { has r: u8, g: u8, b: u8, a: u8; } }` blocks are used as normal Jac objects (heap-allocated, pointer semantics) but automatically coerced to C value semantics at call boundaries. Small integer-only structs (<=64 bits) are ABI-coerced to register-sized integers (e.g., `Color` to `i32`), matching the x86_64 SysV calling convention.
- **Fix: `jac format` Unicode Error on Windows**: Fixed `'charmap' codec can't encode character` error when formatting files with emojis or non-ASCII text on Windows.
- **Remove Vendored pluggy and interegular**: Replaced the vendored `pluggy` library (~1,700 lines) with a lightweight custom plugin system (`jaclang/plugin.py`, ~200 lines) that provides the same hook spec/impl/dispatch API. Removed the unused vendored `interegular` library (~2,200 lines).
- **Enhanced jac check output**: The `jac check` command now provides a more detailed and user-friendly output format, including file progress, failure details, and timing information.
- 1 Minor refactor
- 2 Minor refactor

## jaclang 0.11.0 (Latest Release)

- **Automatic Endpoint Caching**: The compiler now statically analyzes walker and server function bodies to classify endpoints as readers or writers, and propagates this metadata (`endpoint_effects`) through the `ClientManifest` to the client runtime. Reader endpoints are automatically cached on the client side, and writer endpoints auto-invalidate overlapping reader caches based on shared node types -- zero developer configuration required.
- **HMR Server-Side Reloading Refactor**: Improved HMR functionality with better handling of `.impl.jac` files and optimized caching to avoid unnecessary recompilations during development
- **Builtin `llm` Name**: `llm` is now a builtin name in the Jac runtime, enabling `by llm()` syntax without requiring an explicit import or `glob llm` declaration. The runtime provides a stub default that plugins (e.g. byllm) override with a fully configured LLM model.
- **Fix: Impl Block Variables Lose Type Info Across Files**: Fixed a bug where variables declared with `has` (e.g., `has tasks: list = []`) in a component lost their type annotation when referenced from a separate `.impl.jac` file. The shadowed symbol fixup was also optimized from O(N*M) to O(N+M) by batching lookups and traversing impl body nodes in a single pass.
- **Fix: Duplicate `__jacCallFunction` Import in `.cl.jac` with `.impl.jac`**: Fixed the ES codegen emitting duplicate `import { __jacCallFunction } from "@jac/runtime"` when both a `.cl.jac` file and its `.impl.jac` annex use `sv import`. Child module imports are now deduplicated by source path during merge.
- **Variant Module Annexing (`.sv.jac`, `.cl.jac`, `.na.jac`)**: A module can now be split across variant files that are automatically discovered, compiled, and merged. Given `main.jac`, any sibling `main.sv.jac`, `main.cl.jac`, or `main.na.jac` files are annexed as variant modules with their respective code contexts (SERVER, CLIENT, NATIVE).
- **Fix: Bare Impl Files Not Matched to Variant Modules**: Fixed `discover_annex_files` rejecting bare annex files (e.g., `foo.impl.jac`) when the source is a variant (e.g., `foo.cl.jac`) with no plain `foo.jac` head. Bare annex files now match any variant source unless a bare `.jac` head exists that would claim them.
- **Fix: Bare-Dot Relative Import (`from . import x`) Not Resolved**: Fixed `import from . { x }` silently resolving to `UnknownType`. The import path is now computed directly from the current file's directory, ensuring sibling modules are correctly found and type-checked.
- **Fix:**: update the jac-check command to print the file names of the files that failed to have clean error message.
- **ES Codegen: Near-Complete Primitive Test Coverage (92%)**: Added cross-backend equivalence tests for 110 additional primitive emitter interfaces (275/299 total), covering float operators, complex arithmetic, bytes methods (with full `_jac.bytes` runtime namespace), set/frozenset algebra and operators, and extra builtins. Fixed column-aware `expandtabs` for str and bytes, `complex.pow`/`complex.eq` mixed-type handling, and `ascii()` quoting to match Python semantics.
- **Refactor: Native Jac Generics in Primitives**: Replaced Python-style `Generic[(V, C)]` with native Jac bracket syntax `[V, C]` across all emitter classes in `primitives.jac` and removed unused `TypeVar`/`Generic` imports.
- **Fix: `jac format` Misplaces Comments Around Generic Type Params**: Fixed `jac format` moving section comments (e.g., `# === String Types ===`) into the `[V, C]` brackets of the preceding class. The parser was generating synthetic comma tokens between type parameters with incorrect source locations; `parse_type_params` now preserves the real comma tokens from the source.
- 4 Minor refactors/chages
- **Native Codegen: Expanded Primitive Coverage**: Added 45 new LLVM IR emitter implementations and inline codegen across 8 emitters.
- **Native Codegen: Expanded Primitive Coverage**: Added 17 new LLVM IR emitter implementations across 6 emitters: IntEmitter (`conjugate`, `bit_length`, `bit_count`), FloatEmitter (`conjugate`, `is_integer`, `op_floordiv`), StrEmitter (`title`, `rfind`, `ljust`, `rjust`, `zfill`), SetEmitter (`clear`, `discard`, `copy`), ListEmitter (`extend`, `insert`), and BuiltinEmitter (`bool`). Fixed string comparison operators (`<`, `>`, `<=`, `>=`) via `strcmp` and added float floor division (`fdiv` + `floor`). Fixed `rfind` infinite loop on empty substring. 108/299 implemented (36%), 105/299 tested (35%).
- **ES Codegen: Comprehension Support (Set, Dict, Nested Loops)**: Added `SetCompr` → `new Set(...)`, `DictCompr` → `Object.fromEntries(...)`, and nested loop → `.flatMap()` chain support to the ES transpile pass. Fixed arrow function parenthesization for destructuring params (`([k, v]) => ...`). Includes 17 new test cases covering all comprehension types.
- **Fix: Walker `result.reports` in CLI Mode**: Fixed `report` keyword not populating `result.reports` when running walkers via `jac run` or `jac test`.
- **`jac format` Support for Generic Syntax**: `jac format` now correctly handles native generic type parameters (`class Foo[V, C]`) and type aliases (`type Result[T, E] = T | E;`). Previously, formatting would lose type parameter names and produce broken output.
- **Bootstrap Compiler (jac0) Native Generic Support**: Extended the jac0 bootstrap transpiler to parse and emit PEP 695 generic class syntax (`class Foo[T, V](Base)`) and type alias statements (`type Alias[T] = Expr`), enabling jac0core infrastructure files to use native Jac generics instead of Python-style `Generic[T]`/`TypeVar` patterns.
- **Migrate jac0core and Compiler Passes to Native Generics**: Replaced `Generic[(T, V)]` inheritance and `TypeVar` declarations with native `[T, V]` syntax across `transform.jac`, `unitree.jac`, `base_ast_gen_pass.jac`, and all `Transform[(X, Y)]` subscription sites in the compiler pipeline.

## jaclang 0.10.5

- **Fix: `sv import` of `def:pub` Functions Generates RPC Stubs**: Fixed `sv import from module { func }` in `.cl.jac` files not generating for `def:pub` server functions.
- **Fix: Type Narrowing Infinite Loop on Large Files**: Fixed `jac check` hanging indefinitely on large `.jac` files (e.g. standalone `.impl.jac` modules). The backward CFG walk in `_compute_narrowed_at` had no depth bound, causing combinatorial explosion when the module-level CFG contained hundreds of basic blocks. Added a depth limit to the walk; narrowing beyond the limit conservatively returns the declared type.

## jaclang 0.10.4

- **`jac check/lint --ignore` Multi-Arg & Wildcard Support**: Enhanced `--ignore` flag to accept multiple space-separated patterns (`--ignore dir1 dir2 dir3`) instead of comma-separated strings. Added wildcard support using glob patterns (e.g., `--ignore "jac-*" test`) for flexible directory matching.
- **CI: Type Check All Jac Files**: Updated CI workflow to run `jac check` on all `.jac` files (excluding test fixtures and error cases) in preparation for removing `.jacignore`.
- **Fix: `_jac` ES Runtime Correctness**: Fixed `str.split` with `maxsplit` to keep the remainder (matching Python behavior), `dict.eq` to compare key-by-key instead of order-dependent `JSON.stringify`, and builtin dispatch (e.g., `sorted(key=lambda...)`) to correctly pass keyword arguments to the runtime.
- **Fix: Remove Dead `abs` Prefix Modifier**: Removed the unused `abs` prefix on archetypes (`abs obj Foo { }`) from the grammar and parser. The prefix was parsed but silently discarded; archetype abstractness is computed from contained abstract abilities. The `abs` keyword remains valid only as an ability body terminator (`can foo() abs;`).
- **ES Codegen: Expanded Primitive Coverage**: Added `bool()` with Python truthiness semantics (empty list/dict/set are falsy), `range()` builtin (supports `for i in range(n)`), `slice()` constructor, `bytearray()` constructor, dedicated `BoolEmitter` for correct `&`/`|`/`^` bool-returning bitwise ops, enhanced `format()` with format-spec support (`f`, `d`, `b`, `o`, `x`, `e`, `%`, width, alignment), and fixed `int()` to handle booleans and floats correctly via `Math.trunc(Number(x))`.
- **Fix: Lexer Infinite Loop on Malformed JSX**: Fixed three infinite-loop scenarios where the lexer would hang forever when hitting EOF inside a non-NORMAL mode (JSX content, JSX tag, or f-string). Added a stuck detector in `tokenize()` that forces EOF when the lexer stops advancing or overshoots the source, preventing `jac run`, `jac start`, and `jac js` from hanging on malformed input (e.g., unterminated JSX like `<div>hello` with no closing tag).
- **Fix: Bare `<` in JSX Content No Longer Hangs Lexer**: A `<` character in JSX content that does not start a valid tag (e.g., `<--`) is now consumed as text instead of causing an infinite loop. The text scanner only breaks on `<` when the next character forms a real JSX construct (`</`, `<>`, or `<` + identifier).
- **Fix: Grammar Extraction Accuracy**: Fixed multiple issues in `jac grammar` output: `atomic_chain` and `jsx_attributes` now show `*` repetition, `compare` no longer duplicates operators, `assignment_with_target` correctly extracts ternary expressions, excessive top-level `?` wrapping is stripped from multi-branch rules, f-string tokens use proper quoting, and added `GPlus` (one-or-more `+`) grammar expression type.
- 1 Minor refactors/chages

## jaclang 0.10.3

- **Fix: Type Narrowing in Loops**: Fixed type narrowing loss in loops and also improved CFG accuracy.
- **Fix: Config Discovery from Target File Path**: Fixed `jac start` commands to discover `jac.toml` from the target file's directory instead of the current working directory when using absolute/relative paths.
- **Fix: Unbound Method Call Type Checking**: Fixed "Parameter already matched" error when calling parent class methods with explicit `self` in inheritance patterns (e.g., `ParentClass.init(self, name=name)`). The type checker now correctly handles unbound method calls on `obj`/`node`/`walker`/`edge` types where `self` is implicit.
- **Enhanced Type Narrowing**: Extended CFG-based type narrowing to support additional patterns: parenthesized isinstance `(isinstance(x, T))`, NOT expressions `not isinstance(x, T)`, compound AND/OR conditions, isinstance with tuple of types `isinstance(x, (A, B))`, truthiness narrowing `if x:` (excludes None), literal equality `x == "lit"`, and inheritance-aware isinstance that correctly narrows to subclasses in unions.
- **Fix: Bare Callable Type Annotation**: Using `Callable` without type parameters (e.g., `fn: Callable`) no longer causes type errors.
- **Type Inference for Tuple Unpacking**: The type evaluator now infers element types for variables in tuple/list unpacking assignments (e.g., `(row, col) = pos;` where `pos: tuple[int, int]`), eliminating the need for explicit pre-declarations before unpacking. Types that cannot be inferred still require explicit annotations.
- **Fix: Display detailed syntax error messages**: Display detailed syntax error messages in `jac run` and `jac start` commands instead of generic import errors.
- **Enum Type Checking**: Enums now have proper type checking. Accessing `.name` returns `str`, `.value` returns the correct type based on your enum values (int or str). Passing wrong types to functions expecting enums now shows type errors.
- **Fix: False type errors on class-based enums**: Classes inheriting from `StrEnum`, `IntEnum`, or `IntFlag` no longer produce false type errors.
- **Fix: LSP features in nested impl blocks**: Go-to-definition, hover, and syntax highlighting now work correctly for symbols inside if/while/for statements within impl blocks.
- **Fix: JS useState scope bug**: Fixed `has` vars incorrectly triggering `setState()` in sibling functions with same variable name.
- **Fix: Inherited field default override**: Fixed false "missing required parameter" error when a child class provides a default for a parent's required field.
- **`parametrize()` Test Helper**: Added a `parametrize(base_name, params, test_func, id_fn=None)` runtime helper that registers one test per parameter via `JacTestCheck.add_test()`.
- **Generic Primitive Emitter Interface**: Refactored the primitive codegen emitter contracts. Emitters are now stateless singletons with per-call context, and dispatch uses typed instance methods instead of static class-as-namespace calls.
- **Human-Readable Tokens in Errors and Grammar Spec**: Parser error messages and `jac grammar` output now display actual token text (`"{"`, `"if"`, `";"`) instead of internal names (`LBRACE`, `KW_IF`, `SEMI`), making syntax errors and the grammar specification much more readable.
- **Support Bare `type` Parameter Assignment**: Functions with `type` parameter annotations now correctly accept class types as arguments (e.g., `process(cls: type)` can be called with `process(MyClass)`).
- **Operator Primitive Dispatch for ES Codegen**: Wired type-aware operator dispatch into the JavaScript code generation pass. Binary, comparison, unary, and augmented assignment operators now query the type evaluator and delegate to the appropriate primitive emitter, producing correct JS semantics for Python-style operators (e.g., `list + list` emits spread concatenation `[...a, ...b]`, `str * n` emits `.repeat(n)`, `x in list` emits `.includes(x)`).
- 3 Minor refactors/changes.
- **Fix: Lexer `<` Comparison vs JSX Tag Disambiguation**: Fixed an infinite loop where `i<points` in a for-loop caused the lexer to enter JSX tag mode. The lexer now tracks the previous token to distinguish `<` as a comparison operator (after values) from a JSX opening tag (after keywords like `return`, operators, or delimiters).
- **Fix: Quoted JSX Text Produces Invalid JS**: Fixed JSX text containing quote characters (e.g., `<p>"text"</p>`) generating invalid double-double-quoted JavaScript (`""text""`). Inner quotes are now properly escaped in the emitted JS string literals.
- **Fix: `unittest.mock.patch` Compatibility in Jac Tests**: Fixed `unittest.mock.patch` not intercepting calls in Jac test blocks.
- **Modern Generics: `type` Aliases & Inline Type Parameters**: Added PEP 695-style `type` alias statements (`type JsonPrimitive = str | int | float | bool | None;`) and inline generic type parameters on archetypes (`obj Result[T, E = Exception] { ... }`). Supports bounded type vars (`T: Comparable`), default type values, and recursive type aliases. Compiles to native Python 3.12 `ast.TypeAlias` and `ast.TypeVar` nodes.
- **Perf: Precompiled Bytecode for Zero Cold Start**: Ship precompiled `.jbc` bytecode per Python version (3.12, 3.13, 3.14) inside each Jac package wheel. Cold start (`jac purge && jac --help`) drops from ~29s to <1s.
- **`jac run` Script Arguments**: `jac run` now passes arguments to the script using Python-like semantics - everything after the filename goes to the script (e.g., `jac run script.jac arg1 arg2`), accessible via `sys.argv[1:]`. Jac flags like `--no-cache` must come before the filename, just like `python -O script.py`.
- **Fix: Operator Precedence for Bitwise vs Logical Operators**: Fixed operator precedence so bitwise operators (`|`, `^`, `&`, `<<`, `>>`) bind tighter than logical operators (`or`, `and`, `not`), matching Python's semantics. Previously `3 & 1 == 1` was parsed as `3 & (1 == 1)` instead of `(3 & 1) == 1`.
- **Fix: `_jac` Primitive Runtime for ES Codegen**: Fixed unification of compiled JavaScript that uses Python-like primitive operations (`list.sort(key=...)`, `list.count()`, `str.capitalize()`, `int % int`, etc.).
- 2 Minor refactors/changes.

## jaclang 0.10.2

- **Unified Primitive Codegen Interface**: Added abstract emitter contracts (`primitives.jac`) for all Jac primitive type methods and builtin functions. Each compilation backend (Python, ECMAScript, Native) must implement these interfaces, ensuring consistent primitive support across all code generation pathways. Python, JS, and Native backend implementations provided.
- **Pytest Plugin for Native Jac Tests**: Added a `pytest11` entry-point plugin (`jaclang.pytest_plugin`) that discovers and runs `test` blocks in `.jac` files alongside Python tests with zero configuration. Migrated ~79 language integration tests and 8 compilation tests from Python to native Jac `test` keyword.
- **Perf: Bootstrap Bytecode Cache**: Cache the jac0-transpiled bytecode for jac0core modules on disk, eliminating ~200ms of repeated transpilation on every invocation. `jac purge -f` clears both caches.
- **Perf: Cache `len()` in Lexer/Parser Hot Paths**: Cached source and token list lengths in the jac0 bootstrap transpiler and the RD parser/lexer, eliminating ~1.8M redundant `len()` calls per startup.
- 3 Minor refactors/changes.
- **Fix: `jac grammar` Command Broken Path**: Fixed the `jac grammar` CLI command.
- **Grammar Extraction Pass Improvements & Spec Snapshot Test**: Improved `jac grammar` extraction accuracy for negated-check loops, optional dispatch branches, `while True` parse-and-break patterns, and standalone `match_tok` calls. Added a golden-file snapshot test (`jac.spec`) that validates extracted grammar rules against a checked-in spec, catching unintended grammar drift on every CI run.
- **Black-style Grammar Formatting**: Replaced alignment-based `jac grammar` formatting with Black-style fixed 4-space indentation, blank lines between rules, and 88-char line width. Uses a recursive tree-based formatter instead of the previous string-based wrapping.
- **RD Parser Spec Convergence**: Improved strictness of jac parser and specification.
- 4 Minor refactors/changes.

## jaclang 0.10.1

- **`jac purge` Command**: Added `jac purge` to clear the bytecode cache. Works even when the cache is corrupted.
- **`format_build_error` Plugin Hook**: Added `format_build_error(error_output, project_dir, config)` hook to `JacMachineInterface`, allowing plugins to provide custom error formatting for client bundle build failures. The default implementation returns raw error output; plugins like `jac-client` can override to display structured diagnostics.
- **Fix: MTIR scope key uses file stem for portability**: Fixed MTIR scope key generation to use only the file stem (filename without extension) instead of path-relative module names. This ensures consistent scope keys across different execution environments (local vs Docker) and enables compiled bytecode to be portable across different directory structures.
- **Fix: False Type Errors in Nested Functions**: Fixed incorrect type checking errors when using nested functions inside `impl` blocks. Nested functions now correctly validate their return statements against their own return type instead of the outer function's return type.
- **Fix: `jac start` Output Ordering**: Server startup messages now appear after compilation completes instead of before, ensuring users see build progress first and "Server ready" only when the server is actually accepting connections. Added `on_ready` callback parameter to `JacAPIServer.start()` for consistent startup message handling across stdlib and jac-scale servers.
- **`jac format --check` Mode**: Added a `--check` flag to validate formatting without modifying files. Exits with status 1 if files need formatting or have syntax errors.
- **Fix: `jac start` Output Ordering**: Server startup messages now appear after compilation completes instead of before, ensuring users see build progress first and "Server ready" only when the server is actually accepting connections.
- **PWA Build Detection**: The stdlib server now detects existing PWA builds and serves Vite-hashed client files (`client.*.js`) correctly.
- **Fix: Serve JSON and JS files as static assets**: Added `.json` and `.js` to the list of recognized asset extensions, fixing PWA `manifest.json` and `sw.js` serving.
- **Code refactors**: Backtick escape, TS cleanup, etc.
- **Bootstrap Compiler (`jac0`)**: Added a single-file Python transpiler (`jac0.py`, ~1900 lines) that compiles the Jac subset produced by `py2jac` into equivalent Python source code. This closes the bootstrap loop.
- **RD Parser: Broad Grammar Parity Fixes**: Fixed 16 grammar gaps in the recursive descent parser, raising walk-check match rate from 95.3% to 98.7%.
- **`jac --version` Shows Installed Plugins**: The version banner now lists all installed Jac plugins with their versions, making it easy to see the full environment at a glance.
- **Support Go to Definition for Inherited Members**: "Go to Definition" now works correctly for inherited methods and attributes on classes without an explicit parent class.
- **Type Checker Improvements**:
  - **Callable Type Annotation Support**: Added full support for `Callable[[ParamTypes], ReturnType]` type annotations. Includes gradual callable form (`Callable[..., T]`), parameter contravariance, return type covariance, automatic self/cls filtering for methods and classmethods, and validation that extra source parameters have defaults.
  - **Fix: Type Checker Crashes**: Fixed crashes when type-checking default/star imports (`import from mod { default as X }`) and walker entry/exit handlers.
  - **Fix: LiteralString Type Support**: Added `LiteralString` class to the type checker, improving binary operator chain handling and ensuring type compatibility between `LiteralString` and `str` types.
  - **Type Checking for `super.init()` Calls**: Added validation for `super.init()` calls, catching argument errors against parent class initializers with proper MRO resolution.
- **Fix: Native Code Cache False Positive**: Fixed a bug where "Setting up Jac for first use" appeared on every run instead of only the first time.
- **Fix: LiteralString String type Compatibility**: LiteralStrings and Strings are now type compatible with type checker.
- **Lark Parser Removal**: Replaced the Lark-based parser with a hand-written recursive descent parser as the default. Deleted `jac_parser.py`, `jac.lark`, `lark_jac_parser.py`, and the vendored `lark/` directory. All 110 language tests, 438 format tests, and 15 LSP server tests pass with the new parser.
- **1 Small Refactors**
- Docs update: return type `any` -> `JsxElement`
- **Fix:** Spurious Write Access Warning on System Root During Sync
- **3 Small Refactors**

## jaclang 0.10.0

- **KWESC_NAME syntax changed from `<>` to backtick**: Keyword-escaped names now use a backtick prefix (`` `node ``) instead of the angle-bracket prefix (`<>node`). All `.jac` source files, the lexer, parser, unparse/DocIR passes, and auto-lint rules have been updated accordingly.
- **Remove Backtick Type Operator**: Removed the backtick (`` ` ``) `TYPE_OP` token and `TypeRef` AST node from the language. The `Root` type is now referenced directly by name (e.g., `with Root entry` instead of `` with `root entry ``). Filter comprehension syntax changed from `` (`?Type:field==val) `` to `(?:Type, field==val)`. `Root` is automatically imported from `jaclib` when used in walker event signatures.
- **`APIProtocol` Builtin Enum**: Added `APIProtocol` enum (`HTTP`, `WEBHOOK`, `WEBSOCKET`) as a builtin, replacing the boolean `webhook` flag in `RestSpecs` with a typed `protocol` field. Use `@restspec(protocol=APIProtocol.WEBSOCKET)` directly without imports.
- **Native Compiler: Cross-Module Linking**: Native `.na.jac` modules can now import and call functions from other `.na.jac` modules. The compiler performs LLVM IR-level linking enabling modular native code organization with `import from module { func1, func2 }` syntax.
- **LSP Debounced Type Checking**: The language server now waits for a brief pause in typing (300ms) before starting analysis, eliminating lag during rapid edits.
- **Fix: LSP Multi-File Race Condition**: Fixed a race condition when switching between files that could cause stale diagnostics.
- **`jac grammar` Command**: Added a `jac grammar` CLI command that extracts the Jac grammar directly from the recursive descent parser's AST and prints it in EBNF or Lark format. Use `jac grammar` for EBNF output, `jac grammar --lark` for Lark format, and `-o <file>` to write to a file. Powered by a new `GrammarExtractPass` compiler pass that analyzes `parse_*` method implementations to reconstruct grammar rules from token-consumption patterns and control-flow structures.
- **Type Checker Improvements**: Fixed several systemic issues in the type checker: `UnionType` operands are now handled correctly in connection operations (`++>`, `-->`) and instance conversion; the `_get_enclosing_class` helper no longer silently crashes due to a variable name bug; unannotated functions no longer produce false return-type errors; and a new rule requires return type annotations on top-level functions that return a value (bare `return` and `return None` remain annotation-free).
- **Support custom Vite Configurations to `dev` mode**: Added support for custom Vite configuration from `jac.toml`.
- **Fix: HMR server-side `sys.modules` refresh**: Imported modules now correctly reload in `--dev` mode by clearing stale `sys.modules` entries across the project.
- **Auto-install watchdog for `--dev` mode**: `jac start --dev` automatically installs `watchdog` if missing, eliminating the manual `jac install --dev` step.
- **Trim Redundant Parser Test Fixtures**: Removed 46 redundant entries from the micro parser test suite by eliminating exact duplicates across directories, near-identical examples, and files that add no unique syntax coverage, reducing the fixture list from 481 to 435 files.
- **RD Parser Grammar Gap Fixes**: Fixed 9 coverage gaps in the recursive descent parser to match the Lark grammar spec: `skip` statement, `@=` operator, `na` context blocks, typed context blocks (`-> Type { ... }`), `is` separator in `sem` definitions, `impl` inside archetype bodies, raw f-strings (`rf"..."`), parenthesized yield expressions, and `*args`/`**kwargs` in lambda parameters.
- **Refactor: Centralized NormalizePass**: Extracted the ~104 `normalize()` methods from individual AST node classes in `unitree.py` into a dedicated `NormalizePass` implemented in Jac (`normalize_pass.jac` + `impl/normalize_pass.impl.jac`). This keeps AST classes purely structural and follows the same self-hosted pass pattern used by `UnparsePass` and other tool passes.
- **RD Parser: Yield in Assignments & Grammar Extraction Improvements**: The RD parser now correctly handles `x = yield expr` in assignments. The `jac grammar` extraction pass was improved to accurately display binary operator rules (e.g., `logical_or` now shows `logical_and (KW_OR logical_and)*` instead of the incorrect `logical_and KW_OR*`).
- **RD Parser: Async, Impl & F-String Gap Fixes**: Fixed 6 more coverage gaps in the recursive descent parser: `async with` statements, async comprehensions (list/set/gen), `async for` token in AST kid lists, `impl` with event clause missing `with` token, `impl` by-expression extra `by` token, and nested `{expr}` inside f-string format specs (e.g., `f"{value:{width}}"`).
- **RD Parser: Enum & Match Pattern Gap Fixes**: Fixed 3 more coverage gaps: multistring (concatenated string literals) in match literal patterns, `py_code_block` (inline Python) in enum blocks, and `free_code` (`with entry` blocks) in enum blocks.
- **Fix: `IsADirectoryError` on dotted imports**: Fixed a crash where the compiler attempted to read directory paths as files when resolving dotted module imports (e.g., `include impl.imps`).
- **CLI Dependency Command Refactor**: Redesigned the `jac install`, `jac add`, `jac remove`, and new `jac update` commands for cleaner, more consistent behavior. `jac install` now syncs all dependency types including plugin-provided ones (npm, etc.). `jac add` requires package arguments (no longer silently falls through to install) and errors on missing `jac.toml`. When no version is specified, `jac add` queries the installed version and records a `~=X.Y` compatible-release spec instead of `>=0.0.0`. The new `jac update [pkg]` command updates all or specific dependencies to their latest compatible versions and writes `~=X.Y` specs back to `jac.toml`.
- **Fix:** Fixed `config.save()` to correctly persist dependency removals and git dependencies to disk.
- **RD Parser: Strictness Parity with Lark**: Tightened the RD parser to reject constructs that the Lark grammar also rejects, closing 7 permissiveness gaps.

## jaclang 0.9.15

- **Fix: Type Errors in Impl Files Now Show Correct Location**: Type errors in `.impl.jac` files now point to the actual error location instead of the declaration in the main file.
- **First-Run Progress Messages**: The first time `jac` is run after installation, it now prints clear progress messages to stderr showing each internal compiler module being compiled and cached, so users understand why the first launch is slower and don't think the process is hanging.
- **`jac add` Dependency Resolution**: `jac add` now installs all Python dependencies in a single batch, allowing `pip` to resolve compatible versions across interdependent packages and preventing runtime errors caused by version mismatches.
- **Self-Hosted Recursive Descent Parser**: Added a hand-written recursive descent parser and lexer implemented entirely in Jac (`jac/jaclang/compiler/parser/`). The parser is designed for native compilation with no runtime reflection - grammar rules are encoded directly in AST type definitions. Features include a 28-level expression precedence chain matching the Lark grammar, contextual lexing for f-strings and JSX, and comprehensive pattern matching support. This lays the groundwork for a fully self-hosted Jac compiler.
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
- **Native Compiler: Python↔Native Interop**: Added cross-boundary function call support between Python (`sv`) and native (`na`) codespaces within the same module. Native functions can now call Python functions via LLVM extern declarations backed by ctypes callbacks, and Python code can call native functions via auto-generated ctypes stubs.
- **Fix:** `sv import` Lost During Unparse in `.cl.jac` Files
- **Fix: ESM Script Loading in Legacy Runtime**: Added `type="module"` to the generated `<script>` tag in the legacy runtime HTML renderer, matching the same fix applied in jac-client.

## jaclang 0.9.14

- **Fix: `jac format` No Longer Deletes Files with Syntax Errors**: Fixed a bug where `jac format` would overwrite a file's contents with an empty string when the file contained syntax errors. The formatter now checks for parse errors before writing and leaves the original file untouched.
- **`jac lint` Command**: Added a dedicated `jac lint` command that reports all lint violations as errors with file, line, and column info. Use `jac lint --fix` to auto-fix violations. Lint rules are configured via `[check.lint]` in `jac.toml`. All enabled rules are treated as errors (not warnings). The `--fix` flag has been removed from `jac format`, which is now pure formatting only.
- **CLI Autocompletion**: Added `jac completions` command for shell auto completion. Run `jac completions --install` to enable autocompletion for subcommands, options, and file paths. Supports bash, zsh, and fish (auto-install), plus PowerShell and tcsh (manual).
- **Centralized project URLs**: Project URLs (docs, Discord, GitHub, issues) are now defined as constants in `banners.jac` and reused across the CLI banner, server error messages, and help epilog instead of being hardcoded in multiple places.
- **Client bundle error help message**: When the client bundle build fails during `jac start`, the server now prints a troubleshooting suggestion to run `jac clean --all` and a link to the Discord community for support.
- **Native Compiler Buildout**: Major expansion of the native binary compilation pipeline for `.na.jac` files. The native backend now supports enums, boolean short-circuit evaluation, break/continue, for loops, ternary expressions, string literals and f-strings, objects with fields/methods/postinit, GC-managed lists, single inheritance with vtable-based virtual dispatch, complex access chains, indexed field assignment, string methods (strip, split, indexing), builtins (ord, int, input), augmented assignment operators (`+=`, `-=`, `*=`, `//=`, `%=`), and `with entry { ... }` blocks. All heap allocations use Boehm GC. Validated end-to-end with a fully native chess game.
- **`jac run` for `.na.jac` Files**: Running `jac run file.na.jac` now compiles the file to native machine code and executes the `jac_entry` function directly, bypassing the Python import machinery entirely. Native execution runs as pure machine code with zero Python interpreter overhead at runtime.
- **LSP Semantic Token Manager Refactor**: Refactored the language server's `SemTokManager` for production robustness. Deduplicated ~170 lines of shared symbol resolution logic.
- - **Automatic Version Pinning in `jac.toml`**: When running `jac add <package_name>` without specifying a version, the detected installed version is automatically added to `jac.toml`, falling back to `>=0.0.0` if detection fails.
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
