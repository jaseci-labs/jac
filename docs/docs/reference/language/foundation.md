# Foundation

**On this page:**

- [Introduction](#introduction) - What is Jac, principles, comparison to Python
- [Getting Started](#getting-started) - Installation, first program, CLI basics
- [Language Basics](#language-basics) - Syntax, comments, code structure

**The language core continues in:**

- [Types and Values](types-and-values.md) - Type system, generics, literals
- [Variables and Scope](variables-and-scope.md) - Locals, `has` fields, `glob`, scoping rules
- [Operators](operators.md) - Arithmetic, comparison, logical, graph operators
- [Control Flow](control-flow.md) - Conditionals, loops, pattern matching

---

## Introduction

### 1 What is Jac?

Jac is a full-stack programming language with Python-like syntax that compiles to Python bytecode, JavaScript, and native machine code (C-ABI compatible). It is *synechic* (one continuous, compiler-checked medium across tiers, ecosystems, and toolchains) and *topokinetic* (computation moves through a topology of data, realized as Object-Spatial Programming), with meaning-typed constructs for AI-integrated programming (such as `by llm()`). One language serves backend, frontend, native, and AI development with full access to the PyPI, npm, and native ecosystems. The two properties are defined in [The Two Ideas](../../quick-guide/ideas-behind-jac.md).

```jac
with entry {
    print("Hello, Jac!");
}
```

### 2 The Six Principles

| Principle | Description |
|-----------|-------------|
| **Meaning-Typed** | LLMs as first-class citizens: prompts derived from names, types, and `sem` |
| **Synechic** | Backend, frontend, and native code in one continuous, compiler-checked medium |
| **Multi-Ecosystem** | Compiles to Python bytecode, JS, and native machine code -- full PyPI, npm, and native ecosystem access |
| **Object-Spatial** | Graph-based domain modeling with mobile walkers |
| **Scale-Invariant** | Same program text at every deployment scale, one-command deployment |
| **Human & AI Friendly** | Readable structure for both humans and AI models |

### 3 Designed for Humans and AI

Jac is built for clarity and architectural transparency:

- `has` declarations for clean attribute definitions
- `impl` separation keeps interfaces distinct from implementations
- Structure that humans can reason about AND models can reliably generate

### 4 When to Use Jac

Jac excels at:

- Graph-structured applications (social networks, knowledge graphs)
- AI-powered applications with LLM integration
- Full-stack web applications
- Agentic AI systems
- Rapid prototyping

### 5 Jac vs Python

```jac
obj Person {
    has name: str;
    has age: int;

    def greet() -> str {
        return f"Hi, I'm {self.name}";
    }
}
```

**Key differences from Python:**

| Feature | Python | Jac |
|---------|--------|-----|
| Blocks | Indentation | Braces `{}` |
| Statements | Newline-terminated | Semicolons required |
| Fields | `self.x = x` | `has x: Type;` |
| Methods | `def method():` | `def method() { }` |
| Abilities | N/A | `can` (walker entry/exit only) |
| Types | Optional | Mandatory |

---

## Getting Started

### 1 Installation

```bash
# Install the Jac toolchain
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash

# Individual plugins
jac install byllm        # LLM integration
# (Production deployment & scaling and full-stack web + native-desktop app
#  building ship with the jac binary -- no separate install)
```

This installs the self-contained `jac` binary -- no Python, pip, or uv required.

### 2 Your First Program

Create a file `hello.jac`:

```jac
def greet(name: str) -> str {
    return f"Hello, {name}!";
}

with entry {
    print(greet("World"));
}
```

Run it:

```bash
jac hello.jac
```

Note: `jac` is shorthand for `jac run`.

### 3 Project Structure

```
my_project/
├── jac.toml           # Project configuration
├── main.jac           # Entry point
├── app.jac            # Full-stack entry (jac-client)
├── models/
│   ├── __init__.jac
│   └── user.jac
└── tests/
    └── test_models.jac
```

**File Extensions:**

| Extension | Purpose |
|-----------|---------|
| `.jac` | Universal Jac code (head module) |
| `.sv.jac` | Server-variant code |
| `.cl.jac` | Client-variant code |
| `.na.jac` | Native-variant code (compiles to LLVM IR, JIT-executed) |
| `.impl.jac` | Implementation file (annex) |
| `.test.jac` | Test file (annex) |

Files sharing the same base name form a single logical module. For example, `mymod.jac`, `mymod.sv.jac`, `mymod.cl.jac`, `mymod.impl.jac`, and `mymod.test.jac` are all part of the `mymod` module. Variant files (`.sv.jac`, `.cl.jac`, `.na.jac`) are automatically discovered and merged during compilation -- see [Variant Modules](functions-objects.md#4-variant-modules) for details. Note that variant extensions are explicit placement pins: plain `.jac` files work for client code too, since the compiler infers client placement from JSX and npm imports.

### 4 Editor Setup

Install the VS Code extension for Jac language support:

```bash
# Start the language server
jac lsp
```

---

## Language Basics

### 1 Source Code Encoding

Jac source files are UTF-8 encoded. Unicode is fully supported in strings and comments.

### 2 Comments

```jac
# Single-line comment

#* Multi-line
   comment *#

"""Docstring for modules, classes, and functions"""
```

!!! tip "Coming from Python"
    The biggest syntactic differences: Jac uses **braces** `{ }` instead of indentation for blocks, and **semicolons** `;` to terminate statements. Everything else -- variables, control flow, imports -- is very similar to Python.

### 3 Statements and Expressions

All statements end with semicolons:

```jac
with entry {
    x = 5;
    print(x);
    result = compute(x) + 10;
}
```

### 4 Code Blocks

Code blocks use braces:

```jac
with entry {
    if condition {
        statement1;
        statement2;
    }
}
```

### 5 Keywords

Jac keywords are reserved and cannot be used as identifiers:

| Category | Keywords |
|----------|----------|
| **Archetypes** | `obj`, `node`, `edge`, `walker`, `class`, `enum` |
| **Abilities** | `can`, `def`, `init`, `postinit` |
| **Access** | `pub`, `priv`, `protect`, `static`, `override`, `abst`, `Self` |
| **Control** | `if`, `elif`, `else`, `while`, `for`, `match`, `case`, `switch`, `default` |
| **Loop** | `break`, `continue` |
| **Return** | `return`, `yield`, `report`, `skip` |
| **Exception** | `try`, `except`, `finally`, `raise`, `assert` |
| **OSP** | `visit`, `disengage`, `spawn`, `here`, `root`, `visitor` |
| **Module** | `import`, `include`, `from`, `as`, `glob` |
| **Blocks** | `cl` (client), `sv` (server), `na` (native) |
| **Other** | `with`, `test`, `impl`, `sem`, `by`, `del`, `in`, `is`, `and`, `or`, `not`, `async`, `await`, `flow`, `wait`, `lambda`, `props` |

**Note:** The abstract modifier keyword is `abst`, not `abstract` (and not `abs`, which is the built-in absolute-value function).

**Note:** `entry` and `exit` are *contextual* keywords -- they have special meaning only in entry/exit clauses (`with entry`, `can ... with Root exit`) and remain valid as ordinary identifiers (`entry = 5;` is fine).

### 6 Identifiers

Valid identifiers start with a letter or underscore, followed by letters, digits, or underscores.

To use a reserved keyword as an identifier, escape it with a backtick prefix:

```jac
obj Example {
    has `edge: str;  # Backtick-escaped Jac keyword used as identifier
}
```

!!! note "The `any` Special Case"
    Because `any` is a built-in type in Jac, the backtick escape is used as a convention to refer to the Python/Jac built-in **`any()` function**. Always use `` `any `` when you want to call the function and `any` (without a backtick) when referring to the type.

!!! danger
    Backtick escaping cannot smuggle **Python reserved words** (`class`, `lambda`, `import`, `def`, ...) into `has`-field or parameter names -- the compiler rejects them with error **E0067**, because they would break the generated Python underneath. Choose a non-keyword identifier instead (e.g., `has cls: str;` or `has kind: str;`).

!!! note "Special variable references don't need backtick escaping"
    The following are **built-in references**, not regular identifiers. Use them directly without backticks: `self`, `Self`, `super`, `root`, `here`, `visitor`, `init`, `postinit`. `self` is the current instance; `Self` is the enclosing type. For example, write `self.name`, `root ++> node`, and `def init()` -- never `` `self ``, `` `root ``, or `` `init ``.

### 7 Entry Point Variants

Entry points define where code execution begins. Unlike Python's `if __name__ == "__main__"` pattern, Jac provides explicit entry block syntax. Use `entry` for code that always runs, `entry:__main__` for main-module-only code (like tests or CLI scripts), and named entries for exposing multiple entry points from a single file.

!!! tip "Coming from Python"
    Python's `if __name__ == "__main__":` becomes `with entry:__main__ { }`. Plain `with entry { }` runs every time the module loads (like top-level Python code).

```jac
# Default entry - always runs when this module loads
with entry {
    print("Always runs");
}

# Main entry - only runs when this file is executed directly
# Similar to Python's if __name__ == "__main__"
with entry:__main__ {
    print("Only when this file is main");
}
```

---

## Common Gotchas

### 1. Semicolons Required

```jac
# Wrong - missing semicolons
# x = 5
# print(x)

# Correct
with entry {
    x = 5;
    print(x);
}
```

### 2. Braces Required for Blocks

```jac
# Wrong (Python style) - won't parse
# if condition:
#     do_something()

# Correct
def do_something() -> None {
    print("done");
}

with entry {
    condition = True;
    if condition {
        do_something();
    }
}
```

### 3. Type Annotations Required

```jac
# Wrong - missing type annotations
# def add(a, b) {
#     return a + b;
# }

# Correct
def add(a: int, b: int) -> int {
    return a + b;
}
```

### 4. `has` vs Local Variables

```jac
obj Example {
    has field: int = 0;  # Instance variable (with 'has')

    def method() {
        local = 5;  # Local variable (no 'has')
        self.field = local;
    }
}
```

### 5. Walker `visit` is Queued

```jac
node Item { has name: str = ""; }

walker Example {
    can traverse with Item entry {
        print("Visiting");
        visit [-->];  # Nodes queued, visited AFTER this method
        print("This prints before visiting children");
    }
}
```

To match every node regardless of type, use the anonymous form `can traverse with entry { ... }` -- there is no built-in `Node` catch-all trigger.

### 6. `report` vs `return`

```jac
node Item { has value: int = 0; }

walker Example {
    can collect with Item entry {
        report here.value;  # Continues execution
        visit [-->];        # Still runs

        return;             # Would stop the walker here
    }
}
```

Walker abilities don't carry an arrow-return type annotation -- `report` accumulates results on the walker's `reports` list, and `return` (with no value) ends the current ability.

### 7. Assignment to a `glob` Rebinds It

There is no `global`/`nonlocal` statement -- a bare assignment (including `+=`) inside a function binds to the nearest enclosing binding, so it modifies a module-level `glob` directly. Shadow with a typed declaration when you want a fresh local instead:

```jac
glob counter: int = 0;

def increment -> None {
    counter += 1;  # Rebinds the glob -- no declaration needed
}

def local_count -> None {
    counter: int = 100;  # Typed declaration = new local; the glob is untouched
    counter += 1;
}
```

---

## Learn More

**Tutorials:**

- [Jac Basics](../../tutorials/language/basics.md) - Step-by-step introduction to Jac syntax
- [Installation](../../quick-guide/install.md) - Setup and your first Jac program

**Related Reference:**

- [Types and Values](types-and-values.md) - Type system, generics, literals
- [Variables and Scope](variables-and-scope.md) - Scoping, rebinding, and shadowing rules
- [Operators](operators.md) - Full operator reference and precedence
- [Control Flow](control-flow.md) - Conditionals, loops, pattern matching
- [Functions & Objects](functions-objects.md) - Classes, methods, inheritance
- [Native Compilation](native-pathway.md) - Compile Jac to native machine code via LLVM
