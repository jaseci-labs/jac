# Codebase Orientation for New Contributors

This repository builds the **Jac programming language** -- a Python-superset with a multi-target compiler (Python bytecode, LLVM native, JavaScript), a graph-native runtime, and an ecosystem of plugins for AI, full-stack web, and cloud deployment. If you're looking to contribute, this guide gives you the mental model and the map you need to navigate the codebase.

For setup instructions and PR workflow, see the [Contributing](contributing.md) page.

---

## Key Concepts

Before you open any files, these five ideas will save you a lot of confusion:

**Jac is written in Jac.** Most of the compiler and runtime are `.jac` files, not Python. A small bootstrap transpiler (`jac0.py`) is pure Python -- it compiles just enough of the compiler infrastructure (`jac0core/`) so the full compiler can take over and compile itself. Once bootstrapped, the full compiler handles everything else. If you're wondering "how does a Jac compiler compile itself?" -- that's the answer.

**Declaration and implementation are separate.** You'll see pairs like `foo.jac` (declarations/interfaces) and `foo.impl.jac` or `impl/foo.impl.jac` (implementations). This is a first-class Jac language feature, similar to header/source separation. When you're looking for where something is *defined*, check the `.jac` file; for how it *works*, check the `.impl.jac` file.

**The unified AST (`unitree`) is central.** All three compilation targets -- Python, native, and JavaScript -- operate on the same AST. A change to the AST potentially affects all backends, so treat `unitree.jac` edits with care.

**The compiler is a pass pipeline.** Compilation is a sequence of passes, each transforming or annotating the AST. The orchestrator in `compiler.jac` defines which passes run and in what order. Understanding which pass does what is the key to working on the compiler.

**Plugins register via entry points.** You don't need to modify core code to add a plugin -- each plugin declares a `[project.entry-points."jac"]` section in its `pyproject.toml`, and the core runtime discovers and loads it automatically.

If you're new to Jac syntax, skim the [Syntax Cheatsheet](../quick-guide/syntax-cheatsheet.md) or work through [Jac Fundamentals](../tutorials/language/basics.md) before diving into compiler code. Jac reads like Python in most places, but the declaration/implementation split and some other features will look unfamiliar without that primer.

---

## Where to Start

Here's a quick map from contribution type to the right part of the codebase:

| I want to... | Look at... |
|--------------|-----------|
| Fix a compiler bug | `jac/jaclang/compiler/passes/main/` (Python target) |
| Add a language feature | `jac/jaclang/jac0core/` (AST) + `compiler/passes/` (all targets) |
| Fix type checking | `jac/jaclang/compiler/type_system/` + `passes/main/type_checker_pass.jac` |
| Work on native compilation | `jac/jaclang/compiler/passes/native/na_ir_gen_pass.impl/` |
| Work on JS compilation | `jac/jaclang/compiler/passes/ecmascript/` |
| Improve the CLI | `jac/jaclang/cli/commands/` |
| Fix a runtime bug | `jac/jaclang/runtimelib/` |
| Improve the formatter/linter | `jac/jaclang/compiler/passes/tool/` |
| Improve IDE support | `jac/jaclang/lsp/` + `langserve/` |
| Work on a plugin | `jac-byllm/`, `jac-client/`, `jac-scale/`, etc. |
| Write or fix docs | `docs/docs/reference/` (most features go here) |
| Add a test | `jac/tests/` (mirror the directory of the code you're testing) |

---

## Repository Layout

The repo is a **monorepo** with the core language and a family of plugins:

```
jaseci/
├── jac/                  # Core language: compiler, runtime, CLI, LSP
├── jac-byllm/            # Plugin: LLM integration (Meaning Typed Programming)
├── jac-client/           # Plugin: full-stack web apps (JSX, server, auth)
├── jac-scale/            # Plugin: cloud deployment (FastAPI, Kubernetes, Docker)
├── jac-mcp/              # Plugin: MCP server for AI-assisted development
├── jac-super/            # Plugin: enhanced console output (Rich)
├── jac-plugins/          # Additional community plugins
├── jaseci-package/       # Meta-package that bundles everything for pip install
├── docs/                 # MkDocs documentation site
└── scripts/              # Release, CI, and utility scripts
```

---

## The Core: `jac/jaclang/`

This is the heart of the project -- the compiler, runtime, CLI, and language server. Everything below is relative to `jac/jaclang/`.

### `jac0core/` -- Compiler Infrastructure

This layer defines the data structures and front-end passes that every compilation target depends on. The compiler orchestrator (`compiler.jac`) lives here and controls which passes run and in what order.

The most important files to know:

- **`unitree.jac`** -- The unified AST that all backends share. If you're adding or changing syntax, you'll touch this.
- **`compiler.jac`** -- The pass pipeline orchestrator. It defines schedules like `get_ir_gen_sched()` and `get_py_code_gen()` that chain passes together. This is the authoritative source for pass ordering.
- **`jir.jac` / `jir_registry.jac`** -- The Jac Intermediate Representation and its node type registry. JIR is the serializable form of compiled modules.
- **`diagnostics.jac`** -- Error and warning reporting infrastructure.
- **`modresolver.jac`** -- Module import and dependency resolution.
- **`passes/`** -- Front-end passes: parsing (via Lark grammar), AST validation, symbol table construction, and declaration-implementation matching.
- **`parser/`** -- The Lark grammar definition and lexer that parse Jac source into the initial AST.

### `compiler/` -- Multi-Target Compilation

Jac compiles to **three targets** from the same unified AST:

```
                            ┌─→ Python bytecode  (passes/main/)
Jac Source → unitree AST  ──┼─→ LLVM IR / native (passes/native/)
                            └─→ JavaScript        (passes/ecmascript/)
```

This means a single language change may need updates in up to three backends. The Python target is the default and most mature; the native and JavaScript targets are actively developed.

The `type_system/` directory houses the type inference engine, type compatibility rules, and type operations shared across targets. The `primitives.jac` file defines core type primitives.

A fourth category -- `passes/tool/` -- contains non-compilation passes for the formatter, linter, doc generator, and grammar extractor.

### Compilation Pass Ordering

The compiler orchestrator in `jac0core/compiler.jac` defines several pass schedules. For the default Python target, the full pipeline runs roughly as follows:

**IR generation** (`get_ir_gen_sched`):

1. `ASTValidationPass` -- Validate AST structure after parsing
2. `SymTabBuildPass` -- Build the symbol table (scopes, bindings)
3. `DeclImplMatchPass` -- Pair declarations with their implementations
4. `SemanticAnalysisPass` -- Resolve names, check imports, validate semantics
5. `SemDefMatchPass` -- Link semantic definitions across modules
6. `CFGBuildPass` -- Build control flow graphs for reachability and flow analysis
7. `MTIRGenPass` -- Generate the mid-tier IR used by downstream passes
8. `UniTreeEnrichPass` -- Annotate the AST with computed semantic information

**Type checking** (`get_type_check_sched`, when enabled):

1. `TypeCheckPass` -- Infer and validate types
2. `StaticAnalysisPass` -- Detect unreachable code, unused variables, etc.
3. `UniTreeEnrichPass` -- Final enrichment with type information

**Code generation** (`get_py_code_gen`):

1. `InteropAnalysisPass` -- Analyze Python interop requirements
2. `EsastGenPass` -- Generate JavaScript AST (for JS target)
3. `NaIRGenPass` -- Generate LLVM IR (for native target)
4. `NativeCompilePass` -- JIT-compile LLVM IR to machine code
5. `PyastGenPass` -- Convert the unitree to a Python AST
6. `PyJacAstLinkPass` -- Link the generated Python AST back to Jac source nodes
7. `PyBytecodeGenPass` -- Compile the Python AST to bytecode

See `jac0core/compiler.jac` for the authoritative ordering -- it uses re-entrancy guards during bootstrap that slightly alter the schedule when the compiler is compiling itself.

### `compiler/passes/native/` -- Native Compilation

The native backend generates LLVM IR via `llvmlite`. The main pass (`na_ir_gen_pass.jac`) delegates to implementation files in `na_ir_gen_pass.impl/`, each handling a different part of the language:

| File | What it covers |
|------|---------------|
| `core.impl.jac` | Module setup, entry points, target triple configuration |
| `stmt.impl.jac` | Statements -- if/else, for/while loops, assignments, returns |
| `expr.impl.jac` | Expressions -- binary/unary ops, comparisons, attribute access |
| `func.impl.jac` | Function definitions, closures, parameter handling |
| `calls.impl.jac` | Function call codegen, argument passing |
| `objects.impl.jac` | Class/struct layout, field access, inheritance chains |
| `types.impl.jac` | Mapping Jac types to LLVM types (i64, double, pointers, etc.) |
| `comprehensions.impl.jac` | List, dict, and set comprehension codegen |
| `builtins.impl.jac` | Builtin function implementations (print, len, range, etc.) |
| `lists.impl.jac`, `dicts.impl.jac`, `sets.impl.jac`, `tuples.impl.jac` | Collection type operations |
| `vtable.impl.jac` | Virtual method dispatch tables for dynamic dispatch |
| `refcount.impl.jac` | Reference counting for memory management |
| `exceptions.impl.jac` | Try/catch/finally, exception propagation |

### `cli/` -- Command-Line Interface

The CLI is organized as a command abstraction in `command.jac` with individual commands (`run`, `start`, `compile`, `format`, `check`, `create`, `plugins`) each in their own directory under `commands/`. The core execution logic -- how `jac run` actually invokes the compiler and runs the result -- lives in `impl/execution.impl.jac`.

### `runtimelib/` -- Runtime Library

This is what Jac programs depend on at execution time. The key modules:

- **`builtin.jac`** -- Builtin functions and types available in every Jac program.
- **`memory.jac`** -- Memory management, including the shelved object store for graph persistence.
- **`server.jac`** -- FastAPI-based HTTP server used by `jac start` to serve walkers as API endpoints.
- **`context.jac`** -- Execution context -- tracks the current graph root, walker state, and runtime configuration.
- **`scheduler.jac`** -- Async task scheduling for concurrent walker execution.
- **`testing.jac`** -- Test runner integration (works with pytest via a custom plugin in `pytest_plugin.py`).
- **`hmr.jac`** -- Hot module reloading -- watches `.jac` files and recompiles on change during development.

### `lsp/` and `langserve/`

These two modules power IDE support. `lsp/` implements the Language Server Protocol (completions, diagnostics, go-to-definition, hover). `langserve/` is the engine underneath -- it manages open modules, coordinates incremental recompilation, and feeds semantic data to the LSP layer. If you're working on IDE features, you'll usually start in `lsp/` for the protocol handling and drop into `langserve/` for the semantic logic.

### `project/`

Handles `jac.toml` configuration parsing, dependency resolution, plugin configuration, and project scaffolding templates.

---

## Plugin Architecture

Each plugin is a standalone Python package that follows this structure:

```
jac-<name>/
├── <package_name>/
│   ├── plugin.py           # Registers with the Jac runtime
│   ├── plugin_config.py    # Configuration schema
│   └── [implementation]
├── pyproject.toml          # Entry point registration
└── tests/
```

Registration happens in `pyproject.toml`:

```toml
[project.entry-points."jac"]
<feature> = "<module>:<Class>"
```

| Plugin | What it adds |
|--------|-------------|
| `jac-byllm` | LLM-powered functions -- annotate a function signature with a docstring and byLLM calls an LLM to implement it at runtime. Depends on `litellm`. |
| `jac-client` | Full-stack web app framework -- JSX components, client-side state, server rendering. Uses a Node.js toolchain under the hood. |
| `jac-scale` | Cloud deployment -- wraps `jac start` with FastAPI, adds Kubernetes deployment, Docker builds, MongoDB/Redis storage backends. |
| `jac-mcp` | Exposes the Jac project as an MCP server so AI coding assistants can query it. |
| `jac-super` | Pretty-printed console output via `rich`. |

For the full how-to on writing your own plugin -- CLI extension, runtime hook overrides, jac.toml schemas, project templates, and the entry-point setup -- see the [Plugin Authoring Guide](../reference/plugin-authoring.md).

---

## Tests

Tests are organized in a parallel directory structure under `jac/tests/`, mirroring the source layout:

```
tests/
├── compiler/          # Compiler pass tests
│   └── passes/        # Tests for individual passes
├── language/          # Language feature tests (fixture-based)
├── runtimelib/        # Runtime library tests
├── langserve/         # Language server tests
├── project/           # Project system tests
├── utils/             # Utility tests
└── fixtures_list.jac  # Registry of all test fixtures
```

**Running tests:**

```bash
# All tests (parallel)
pytest jac -n auto

# Specific area
pytest jac/tests/compiler -n auto
pytest jac/tests/language -n auto

# Single test file
pytest jac/tests/compiler/passes/test_type_checker.py -v
```

Many language tests use **fixture files** -- small `.jac` programs in `fixtures/` directories that exercise specific features. The `fixtures_list.jac` file registers them. When you add a new language feature or fix a bug, adding a fixture test is usually the right move.

---

## Documentation

The docs use [MkDocs Material](https://squidfunk.github.io/mkdocs-material/) and live in `docs/`:

```
docs/
├── mkdocs.yml              # Site configuration and navigation
├── docs/
│   ├── quick-guide/        # Getting-started content
│   ├── reference/          # Comprehensive language & API reference
│   ├── tutorials/          # Step-by-step learning content
│   └── community/          # Contributor resources, release notes
└── scripts/                # Doc generation and build scripts
```

There are three documentation tiers with different contributor expectations:

1. **Quick Guide** -- First experience with Jac. Most features don't need to touch this.
2. **Full Reference** -- Must cover everything. **Every feature or change should update the reference docs.**
3. **Tutorials** -- Hands-on learning guides for specific workflows.

**Building docs locally:**

```bash
pip install -e docs
python docs/scripts/mkdocs_serve.py
```

---

## CI/CD

GitHub Actions workflows in `.github/workflows/`:

| Workflow | What it checks |
|----------|---------------|
| `test-jaseci.yml` | Full test suite across Python versions |
| `jac-check.yml` | Lint and format enforcement |
| `docs-validation.yml` | Documentation builds without errors |
| `test-installer.yml` | Clean install from scratch works |
| `build-standalone.yml` | Standalone binary packaging |
| `create-release-pr.yml` | Automated version bump PRs |
| `release-*.yml` | Per-package PyPI publishing (one per package) |
| `deploy-docs.yml` | Deploy docs site to production |

Pre-commit hooks run formatting and linting on every commit locally. See `.pre-commit-config.yaml` for the full hook list.

---

## Getting Help

- **Discord:** [discord.gg/6j3QNdtcN6](https://discord.gg/6j3QNdtcN6) -- the main community channel for questions and discussion
- **Issues:** [github.com/Jaseci-Labs/jaseci/issues](https://github.com/Jaseci-Labs/jaseci/issues) -- check for unassigned issues to pick up
- **Internals docs:** See the [Internals](../internals/abstractions.md) section for deeper dives into specific subsystems
