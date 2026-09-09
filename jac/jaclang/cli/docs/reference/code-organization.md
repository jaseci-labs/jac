# Code Organization

In most programming languages, the *interface* of a module -- what it exposes -- is interleaved with its *implementation* -- how it works. Jac takes a fundamentally different approach. Through its `impl` system, Jac allows you to cleanly separate **declarations** (the interfaces, types, and signatures that define a module's contract) from **implementations** (the method bodies and private helpers that fulfill that contract). As we will see throughout this guide, this distinction is far more than syntactic convenience -- it reshapes how both humans and AI models read, navigate, and reason about code.

In this guide, we will walk through the five organizational patterns used in the Jac compiler itself. For each pattern, we will examine when it is most appropriate, study real-world examples drawn from the compiler codebase, and discuss best practices for maintaining clarity and consistency as your projects grow.

!!! note "Examples from the real compiler"
    Every example in this guide is drawn from the [Jac compiler repository](https://github.com/Jaseci-Labs/jaseci). These are not toy snippets -- they are the actual patterns used to build the language itself. Links point to the relevant source files so you can explore the full context on your own.

!!! tip "Prerequisites"
    This guide assumes you are already familiar with `impl` blocks and `.impl.jac` files. If you need a refresher, please review [Implementations and Forward Declarations](language/functions-objects.md#implementations-and-forward-declarations) before continuing.

---

## Why Separate Declarations from Implementations?

Before diving into the patterns themselves, let us first understand *why* this separation matters. There are four key benefits worth examining closely.

### Architecture at a glance

When declarations live in their own files, every `.jac` file in a package reads like an **API specification**. You can open any declaration file and immediately see: what types exist, what fields they carry, what methods they expose, and what signatures those methods have -- all without wading through hundreds of lines of logic. The *architecture* of a system becomes visible from the file tree alone.

To illustrate this, consider the Jac compiler's [type system](https://github.com/jaseci-labs/jac/tree/main/jac/jaclang/compiler/types):

```
compiler/types/
├── types.jac                  # What types exist in the type system
├── type_utils.jac             # What utility operations are available
├── type_evaluator.jac         # What the evaluator can do (256 lines of signatures)
├── operations.jac             # What type operations are supported
├── enum_utils.jac             # What enum helpers exist
└── impl/                      # How all of the above actually work
```

Notice what happens here: a new contributor can read the five declaration files and understand the *entire shape* of the type system without ever opening a single impl file. The architecture is not buried inside method bodies -- it is the first thing you see. This is a powerful property for any codebase, and it becomes increasingly valuable as systems grow in complexity.

### Readable by humans and AI models alike

Declaration files are naturally **high signal, low noise**. They contain type signatures, docstrings, field definitions, and method groupings -- precisely the information needed to understand a module's role. This property benefits two distinct audiences:

- **Human readers** skimming a codebase: declaration files function as self-maintaining documentation. Unlike comments or external docs that can drift out of sync, the declarations *are* the interface -- they are always accurate because the compiler enforces them.
- **AI models** analyzing code: Large language models operate within limited context windows. Feeding a model a 250-line declaration file gives it a complete understanding of a module's capabilities without spending tokens on implementation details. When an AI needs to generate code that interacts with a module, the declaration file provides exactly the right level of abstraction.

This dual benefit is worth keeping in mind as you design your own modules. Ask yourself: *"Could someone -- human or machine -- understand what this module does by reading its declaration file alone?"* If the answer is yes, you have achieved a good separation.

### Granular separation of concerns

The `impl` system enables decomposition at a finer grain than files or classes alone can provide. Consider this: a single object with 80 methods does not need to live in one monolithic file. Its implementations can be split by *feature domain*:

```
type_evaluator.jac                  # One object, 200+ method signatures
type_evaluator.impl/
    construct_types.impl.jac        # Just the type-construction methods
    parameter_type_check.impl.jac   # Just the parameter-checking methods
    jsx_type_check.impl.jac         # Just the JSX-checking methods
    ...7 files total
```

([Browse this example on GitHub](https://github.com/jaseci-labs/jac/tree/main/jac/jaclang/compiler/types))

Each impl file becomes a focused, self-contained unit. A developer working on tuple code generation opens `tuples.impl.jac` and nothing else. They do not need to scroll past 2,000 lines of unrelated code, and their changes will not produce merge conflicts with a colleague working on exception handling in a different file. In a collaborative setting, this kind of isolation is invaluable.

### Cleaner folder architecture

Without separation, large packages tend to devolve into a flat list of large files where understanding the system requires opening each one and reading deeply. With separation, the folder structure itself communicates the architecture:

- **Declaration files at the package root** answer the question: *"What does this package contain?"*
- **The `impl/` directory** answers: *"Where is the logic?"* -- without cluttering the root
- **Feature-named impl files** answer: *"What concerns does this module address?"*

The result is a codebase where running `ls *.jac` in any directory gives you an architectural overview, while the `impl/` directory is where you go when you need the details. Think of it like a well-organized textbook: the table of contents (declarations) tells you what topics are covered, while the chapters (implementations) contain the full exposition.

---

## Overview of Patterns

Now that we understand the motivation, let us survey the five organizational patterns available to you. The table below provides a quick reference; we will examine each pattern in detail in the sections that follow.

| Pattern | File Layout | When to Use | Compiler Example |
|---------|-------------|-------------|------------------|
| **Inline** | Single `.jac` file, declarations + `impl` blocks together | Small modules (<100 lines) | [`lsp/server/rwlock.jac`](https://github.com/jaseci-labs/jac/blob/main/jac/jaclang/lsp/server/rwlock.jac) |
| **Side-by-Side** | `mod.jac` + `impl/mod.impl.jac` | Medium modules, clean interface/impl split | [`cli/command.jac`](https://github.com/Jaseci-Labs/jaseci/blob/7b0f5297ac87d7bf2cc06922d7e77cd979c3c7f2/jac/jaclang/cli/command.jac) |
| **Shared impl/ Directory** | Multiple `.jac` files + one `impl/` directory | Package-level organization | [`cli/commands/`](https://github.com/Jaseci-Labs/jaseci/tree/7b0f5297ac87d7bf2cc06922d7e77cd979c3c7f2/jac/jaclang/cli/commands) |
| **`.impl/` Directory** | `mod.jac` + `mod.impl/*.impl.jac` | Very large modules, many concerns | [`type_evaluator.jac`](https://github.com/jaseci-labs/jac/blob/main/jac/jaclang/compiler/types/type_evaluator.jac) |
| **Pure Declarations** | `.jac` file with only type/object definitions | Data models, re-exports | [`estree.jac`](https://github.com/jaseci-labs/jac/blob/main/jac/jaclang/compiler/backends/es/estree.jac) |

---

## Inline (All-in-One)

The simplest pattern: declarations and implementations live together in a single file. This is the natural starting point for any small, self-contained module where introducing a separate impl file would add overhead without improving clarity.

### What it looks like

```jac
obj ReadWriteLock {
    has _cond: threading.Condition postinit,
        _readers: int = 0,
        _writer: bool = False;

    def postinit -> None;
    def acquire_read -> None;
    def release_read -> None;
    def acquire_write -> None;
    def release_write -> None;
}

impl ReadWriteLock.postinit -> None {
    self._cond = threading.Condition(threading.Lock());
}

impl ReadWriteLock.acquire_read -> None {
    with self._cond {
        while self._writer {
            self._cond.`wait();
        }
        self._readers += 1;
    }
}

# ... remaining impls in the same file
```

Notice how the declaration block at the top still reads like a concise API summary, while the `impl` blocks below provide the full details. Even within a single file, the logical separation between *what* and *how* remains clear.

### Real example

**[`jaclang/lsp/server/rwlock.jac`](https://github.com/jaseci-labs/jac/blob/main/jac/jaclang/lsp/server/rwlock.jac)** -- A read-write lock in 94 lines. The declaration block (lines 1-29) reads like an API summary, and the `impl` blocks follow immediately. At this size, introducing a second file would be unnecessary overhead.

### When to use

- The module totals fewer than ~100 lines
- The type has few methods with short implementations
- The module is self-contained, with no external consumers who would benefit from reading the interface in isolation

---

## Side-by-Side Impl File (1:1)

As a module grows beyond the inline threshold, the next natural step is to split it into two files: one for declarations and one for implementations. The compiler auto-discovers `mod.impl.jac` as the annex for `mod.jac`, or finds `impl/mod.impl.jac` in a sibling `impl/` directory.

### What it looks like

**`command.jac`** -- declarations only:

<!-- jac-skip -->
```jac
"""CLI command model and argument definitions."""

enum ArgKind {
    POSITIONAL,
    OPTIONAL,
    FLAG,
    REMAINDER
}

obj Arg {
    has name: str,
        kind: ArgKind = ArgKind.OPTIONAL,
        typ: type = str,
        default: object = None,
        help: str = "";

    static def create(name: str, ...) -> Arg;
}

obj Command {
    has name: str,
        func: Callable,
        args: list[Arg] = [],
        help: str = "";

    def execute(parsed_args: dict) -> int;
}
```

**`impl/command.impl.jac`** -- all logic:

<!-- jac-skip -->
```jac
impl Arg.create(name: str, ...) -> Arg {
    # ... construction logic
}

impl Command.execute(parsed_args: dict) -> int {
    # ... execution logic
}
```

Observe how the declaration file reads almost like a specification document: you can see every type, every field, and every method signature at a glance. The impl file, meanwhile, contains only the method bodies -- the "how" behind the "what."

### Real example

**[`jaclang/cli/command.jac`](https://github.com/Jaseci-Labs/jaseci/blob/7b0f5297ac87d7bf2cc06922d7e77cd979c3c7f2/jac/jaclang/cli/command.jac)** + **[`jaclang/cli/impl/command.impl.jac`](https://github.com/Jaseci-Labs/jaseci/blob/7b0f5297ac87d7bf2cc06922d7e77cd979c3c7f2/jac/jaclang/cli/impl/command.impl.jac)** -- The declaration file defines the `Arg`, `ArgKind`, and `Command` types that the entire CLI system depends on. The impl file provides the method bodies. Anyone reading `command.jac` instantly grasps the full API without scrolling through implementation details.

### When to use

- The module has a clear interface that benefits from being readable on its own
- Implementation is substantial (100+ lines of method bodies)
- Other modules import from this one and their authors only need to understand the interface

---

## Shared impl/ Directory (Many:Many)

When a package contains multiple related modules, each of medium size, a shared `impl/` directory provides an elegant and consistent layout. Each declaration file has a corresponding `impl/name.impl.jac`. This is the **dominant pattern** throughout the Jac compiler codebase, and for good reason -- it scales naturally as packages grow.

### What it looks like

```
cli/commands/
├── analysis.jac
├── config.jac
├── execution.jac
├── project.jac
├── tools.jac
├── transform.jac
└── impl/
    ├── analysis.impl.jac
    ├── config.impl.jac
    ├── execution.impl.jac
    ├── project.impl.jac
    ├── tools.impl.jac
    └── transform.impl.jac
```

### Real example

**[`jaclang/cli/commands/`](https://github.com/Jaseci-Labs/jaseci/tree/7b0f5297ac87d7bf2cc06922d7e77cd979c3c7f2/jac/jaclang/cli/commands)** -- The command group files, each declaring functions next to a `comptime` command spec (command name, argument specs, help text, usage examples). The [`impl/`](https://github.com/Jaseci-Labs/jaseci/tree/7b0f5297ac87d7bf2cc06922d7e77cd979c3c7f2/jac/jaclang/cli/commands/impl) directory holds the actual command logic.

The declaration file functions as a **command catalog** -- study this example carefully:

```jac
"""Execution commands: run, enter, serve, debug."""

import from jaclang.cli.command { Arg, ArgKind, CommandSpec }
import from jaclang.comptime { name as ct_name }

comptime SPEC_RUN: CommandSpec = CommandSpec(
    name="run",
    help="Run a Jac program",
    args=[
        Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .jac file"),
        Arg.create("cache", typ=bool, `default=True, help="Enable compilation cache"),
    ],
    examples=[
        ("jac run hello.jac", "Run a simple program"),
    ],
    group="execution",
    handler_name=ct_name(run)
);
def run(filename: str, main: bool = True, cache: bool = True) -> int;
```

The spec is a compile-time value: `jaclang/cli/manifest.jac` imports every `SPEC_*` binding with `comptime import` and folds them into one `ROUTES` table, so the CLI's help, completions, and dispatch all read a table that was computed while the manifest compiled.

The impl file then provides the body:

```jac
impl run(filename: str, main: bool = True, cache: bool = True) -> int {
    _ensure_jac_runtime();
    _discover_config_from_file(filename);
    (base, mod, mach) = _proc_file(filename);
    # ... full implementation
}
```

Notice how the declaration file alone tells you everything you need to know about *what* the command does, *what* arguments it accepts, and *how* it should be invoked. The impl file is only needed when you want to understand or modify the internal logic.

### Where it's used in the compiler

To appreciate how pervasive this pattern is, here is a sampling from across the compiler codebase:

| Package | Declaration Files | impl/ Contents |
|---------|-------------------|----------------|
| [`cli/commands/`](https://github.com/jaseci-labs/jac/tree/main/jac/jaclang/cli/commands) | Command group files (`execution.jac`, `build.jac`, `project.jac`, etc.) | Matching impl files |
| [`compiler/passes/`](https://github.com/jaseci-labs/jac/tree/main/jac/jaclang/compiler/passes) | The shared analysis passes (`sym_tab_build_pass.jac`, `semantic_analysis_pass.jac`, etc.) | Matching impl files |
| [`compiler/tools/`](https://github.com/jaseci-labs/jac/tree/main/jac/jaclang/compiler/tools) | Formatter, linter, and doc tooling passes | Matching impl files |
| [`compiler/frontend/`](https://github.com/jaseci-labs/jac/tree/main/jac/jaclang/compiler/frontend) | `unitree.jac`, `diagnostics.jac`, etc. | Matching impl files |
| [`compiler/driver/`](https://github.com/jaseci-labs/jac/tree/main/jac/jaclang/compiler/driver) | `program.jac`, `compiler.jac`, etc. | Matching impl files |
| [`lsp/server/`](https://github.com/jaseci-labs/jac/tree/main/jac/jaclang/lsp/server) | `server.jac`, `engine.jac`, `utils.jac`, etc. | Matching impl files |
| [`runtime/`](https://github.com/jaseci-labs/jac/tree/main/jac/jaclang/runtime) | `context.jac`, `archetype.jac`, `runtime.jac`, etc. | Matching impl files |
| [`project/`](https://github.com/jaseci-labs/jac/tree/main/jac/jaclang/project) | `config.jac`, `capabilities.jac`, etc. | Matching impl files |

### When to use

- A package contains multiple related modules
- You want a consistent, predictable layout across the entire package
- Each module is medium-sized (not large enough to warrant its own impl directory)

---

## `.impl/` Directory (1:Many)

When a single class grows to contain dozens of methods spanning many distinct concerns, the side-by-side pattern is no longer sufficient. The `.impl/` directory pattern addresses this by splitting one declaration file's implementations across multiple feature-focused files.

This is, in a sense, the most powerful pattern -- it allows a single type's implementation to be decomposed along conceptual boundaries rather than being forced into a single monolithic file.

### What it looks like

```
compiler/types/
├── type_evaluator.jac                    # All declarations (739 lines)
└── type_evaluator.impl/
    ├── type_evaluator.impl.jac           # Core evaluation entry points
    ├── evaluator_util_methods.impl.jac   # Shared evaluator helpers
    ├── parameter_type_check.impl.jac     # Call-site parameter checking
    ├── construct_types.impl.jac          # Type construction from decls
    ├── ts_declarations.impl.jac          # TypeScript-style declarations
    ├── imported.impl.jac                 # Imported-symbol resolution
    └── jsx_type_check.impl.jac           # JSX element type checking
```

### Real example

**[`jaclang/compiler/types/type_evaluator.jac`](https://github.com/jaseci-labs/jac/blob/main/jac/jaclang/compiler/types/type_evaluator.jac)** -- The type evaluator. Let us examine how the declaration file defines a single `TypeEvaluator` object with 200+ method signatures, carefully organized by concern:

```jac
obj TypeEvaluator {
    def postinit -> None;
    def _read_dunder_all(path: str) -> (set[str] | None);
    def _extract_type_params(node_: Archetype) -> list[TypeVarType];
    def _is_class_scoped_type_param(node_: TypeParam) -> bool;
    def _is_mobui_module(nd: UniNode) -> bool;
    def _get_intrinsic_props_type(tag_name: str) -> ClassType | None;
}
```

Each impl file then handles one domain. Here, for instance, is how the JSX-related methods are isolated:

<!-- jac-skip -->
```jac
impl TypeEvaluator._is_mobui_module(nd: UniNode) -> bool {
}

impl TypeEvaluator._get_intrinsic_props_type(tag_name: str) -> ClassType | None {
}

impl TypeEvaluator._resolve_intrinsic_jsx_tag(part: Name, tag_name: str) -> None {
}
```

**Also worth studying:** [`jaclang/compiler/backends/native/na_ir_gen/`](https://github.com/jaseci-labs/jac/tree/main/jac/jaclang/compiler/backends/native/na_ir_gen) -- the native backend takes the next step past this pattern, splitting one 764-method object into 43 sibling modules that a composing `obj NaIRGenPass(...)` inherits, so each concern is its own compilation unit rather than one woven module.

### When to use

- A single class has dozens of methods spanning many distinct concerns
- The combined implementation would exceed 1,000 lines in a single file
- Different developers may work on different feature areas simultaneously
- The declaration file alone should serve as a complete API reference for the type

---

## Pure Declarations (Data Modules)

Some modules are primarily -- or entirely -- composed of declarations: type definitions, data classes, enums, constants, or re-exports. These modules need little or no implementation logic, and that is perfectly fine. Recognizing when a module fits this pattern helps you avoid creating unnecessary impl files.

### What it looks like

**[`estree.jac`](https://github.com/jaseci-labs/jac/blob/main/jac/jaclang/compiler/backends/es/estree.jac)** -- 580 lines of ESTree AST node type definitions:

```jac
"""ESTree AST Node Definitions for ECMAScript."""

obj SourceLocation {
    has source: (str | None) = None,
        start: (Position | None) = None,
        end: (Position | None) = None;
}

obj Position {
    has line: int = 0,
        column: int = 0;
}

obj Identifier(Node) {
    has name: str = '',
        `type: TypingLiteral['Identifier'] = 'Identifier';
}

# ... 60+ more node types
```

Its impl file ([`impl/estree.impl.jac`](https://github.com/jaseci-labs/jac/blob/main/jac/jaclang/compiler/backends/es/impl/estree.impl.jac)) is only 33 lines -- a single utility function. The vast majority of the module's value is in the declarations themselves.

**[`constructs.jac`](https://github.com/jaseci-labs/jac/blob/main/jac/jaclang/runtime/constructs.jac)** -- A 35-line re-export barrel:

<!-- jac-skip -->
```jac
"""Core constructs for Jac Language - re-exports."""

import from jaclang.runtime.archetype {
    AccessLevel, Anchor, Archetype, Root, ...
}

glob __all__ = ['AccessLevel', 'Anchor', ...];
```

### When to use

- The module is primarily a data model (types, enums, constants)
- Objects have `has` fields but few or no methods
- The file serves as a public API barrel that re-exports from internal modules

---

## Choosing a Pattern

With five patterns at your disposal, how do you decide which one to use? The following decision guide will help you navigate the choice based on your module's characteristics:

```
Is the module mostly data types with few methods?
  └─ Yes → Pure Declarations
  └─ No ↓

Is the total code (decl + impl) under ~100 lines?
  └─ Yes → Inline
  └─ No ↓

Does one class have 20+ methods spanning multiple concerns?
  └─ Yes → .impl/ Directory (1:Many)
  └─ No ↓

Are there multiple related modules in this package?
  └─ Yes → Shared impl/ Directory
  └─ No → Side-by-Side Impl File (1:1)
```

Work through this decision tree from top to bottom, and you will arrive at the appropriate pattern for your situation.

!!! note "No wrong answer"
    These patterns are conventions, not rigid rules. The compiler codebase uses all five, sometimes in adjacent directories. The goal is always the same: pick the pattern that makes your declaration files most readable as standalone documentation of your module's API. When in doubt, start with the simpler pattern and refactor to a more structured one as the module grows.

---

## Apps and Shared Code

The patterns above organize one module. A project that ships more than one
thing (a site, a mobile client, a command-line tool, a service or two) is
organized one level up as a [workspace](apps.md): each deliverable is an app
with its own root, and everything under no app's root is shared code.

```
acme/
  jac.toml           [apps.web] path = "web"; [apps.cli] path = "cli"; ...
  core/              shared: domain types, walkers, pure logic; no JSX, no DOM
    social_graph.jac     claimed by a file-rooted [apps.social_graph] service app
    scoring.jac
    impl/                the impl/ folder works the same for shared modules
  web/               the web app: pages/, components/, main.jac
  cli/               the command-line app: main.jac, commands/
```

Two rules keep the layering honest, and the compiler checks both:
dependencies point from apps toward `core/` and never back (a shared module
importing from an app is `E2040`), and one app reaches another only through
its walkers and `def:pub` functions (`E2039`). Declaration and implementation
files split exactly as described above inside every app and inside shared
code; the annex rules do not change at an app boundary.

---

## Packages and `__init__.jac`

A **package** in Jac is simply a directory that contains `.jac` files. Unlike Python, Jac does **not** require an `__init__.jac` file to recognize a directory as a package -- any directory containing `.jac` files is automatically treated as an importable package.

### Implicit packages (no `__init__.jac`)

Most packages in the Jac compiler use this approach. As long as a directory contains `.jac` files, you can import from it directly:

```
myapp/
├── main.jac
└── utils/              # No __init__.jac needed
    ├── math_utils.jac
    └── string_utils.jac
```

```jac
import from utils.math_utils { add, multiply }
import from utils.string_utils { greet }
```

This is the recommended default -- don't create an `__init__.jac` unless you have a reason to.

### Explicit packages (with `__init__.jac`)

An `__init__.jac` file is useful when you want to:

- **Re-export** symbols from submodules to create a clean public API
- **Run initialization code** when the package is first imported
- **Define package-level constants** or globals

```
mathlib/
├── __init__.jac         # Re-exports for convenience
├── operations.jac
├── constants.jac
└── calculator.jac
```

**`mathlib/__init__.jac`:**

<!-- jac-skip -->
```jac
import from .operations { add, subtract, multiply, divide }
import from .constants { PI, E, GOLDEN_RATIO }
import from .calculator { Calculator }
```

This lets consumers import directly from the package:

<!-- jac-skip -->
```jac
import from mathlib { add, PI, Calculator }
```

Instead of reaching into submodules:

<!-- jac-skip -->
```jac
import from mathlib.operations { add }
import from mathlib.constants { PI }
import from mathlib.calculator { Calculator }
```

### When to use `__init__.jac`

| Scenario | `__init__.jac` needed? |
|----------|----------------------|
| Directory with `.jac` files, imported by submodule path | No |
| Package that re-exports a curated public API | Yes |
| Package with initialization logic or globals | Yes |
| Most internal packages in a project | No |

!!! tip "Start without it"
    Begin without an `__init__.jac`. If you later find yourself wanting a cleaner import API for consumers, add one then. This keeps your project lean and avoids unnecessary boilerplate.

---

## Best Practices

Let us conclude with a set of best practices distilled from the compiler codebase. These guidelines will help you get the most out of Jac's `impl` system regardless of which pattern you choose.

!!! tip "Declaration files are your API docs"
    Write declaration files as if they are the first thing a new team member will read. Include docstrings, organize methods by concern, and use comments to create logical groupings among related declarations. A well-written declaration file should make its module's purpose and capabilities immediately apparent.

!!! tip "Name impl files to match declarations"
    Always name impl files after their declaration file: `server.jac` → `impl/server.impl.jac` or `server.impl.jac`. This naming convention makes the relationship between declaration and implementation immediately obvious, and it allows the compiler to auto-discover impl files without explicit configuration.

!!! tip "Split impl files by feature, not by class"
    When using a `.impl/` directory, organize files by what they *do* (`tuples.impl.jac`, `exceptions.impl.jac`) rather than by which class they belong to. A single class's methods naturally span multiple feature domains, and grouping by feature makes each file a cohesive, focused unit of work.

!!! tip "Be consistent within a package"
    If one module in a package uses `impl/`, all modules in that package should too. Mixing patterns within the same directory creates confusion and makes the project harder to navigate. The compiler codebase follows this principle consistently -- for instance, every module in `cli/commands/` uses the shared `impl/` pattern.

!!! tip "Private helpers go in the impl file"
    Helper functions (those prefixed with `_`) that exist solely to support implementations should live in the impl file, not the declaration file. Keep the declaration file focused on the public API -- it should answer the question *"What can this module do?"* without revealing *"How does it do it internally?"*

Here is a concrete example from [`cli/commands/impl/execution.impl.jac`](https://github.com/Jaseci-Labs/jaseci/blob/7b0f5297ac87d7bf2cc06922d7e77cd979c3c7f2/jac/jaclang/cli/commands/impl/execution.impl.jac):

<!-- jac-skip -->
```jac
# Private helpers alongside impls

def _ensure_jac_runtime -> None {
    # ... helper logic
}

def _proc_file(filename: str) -> tuple {
    # ... helper logic
}

impl run(filename: str, ...) -> int {
    _ensure_jac_runtime();
    (base, mod, mach) = _proc_file(filename);
    # ...
}
```

Notice how the private helpers `_ensure_jac_runtime` and `_proc_file` live alongside the implementations that use them. They are implementation details -- they belong with the implementation, not in the declaration file where they would clutter the public interface.
