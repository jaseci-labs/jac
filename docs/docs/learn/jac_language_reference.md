# Jac Language Reference

> **The AI-Native Full-Stack Programming Language**
>
> *One Language for Backend, Frontend, and AI*

---

## How to Use This Document

This is a single-page reference for the Jac programming language. Use browser search (Ctrl+F / Cmd+F) to find topics quickly.

**Conventions:**

- `monospace` -- Keywords, types, operators, and code
- **Bold** -- Key terms and concepts
- Code blocks are verified, executable examples
- Sections marked **(OSP)** are Object-Spatial Programming features

---

## Table of Contents

**[Part I: Foundation](#part-i-foundation)**

1. [Introduction](#1-introduction)
2. [Getting Started](#2-getting-started)
3. [Language Basics](#3-language-basics)
4. [Types and Values](#4-types-and-values)
5. [Variables and Scope](#5-variables-and-scope)
6. [Operators](#6-operators)
7. [Control Flow](#7-control-flow)

**[Part II: Functions and Objects](#part-ii-functions-and-objects)**

1. [Functions and Abilities](#8-functions-and-abilities)
2. [Object-Oriented Programming](#9-object-oriented-programming)
3. [Implementations and Forward Declarations](#10-implementations-and-forward-declarations)

**[Part III: Object-Spatial Programming](#part-iii-object-spatial-programming-osp)**

1. [Introduction to OSP](#11-introduction-to-osp)
2. [Nodes](#12-nodes)
3. [Edges](#13-edges)
4. [Walkers](#14-walkers)
5. [Graph Construction](#15-graph-construction)
6. [Graph Traversal](#16-graph-traversal)
7. [Data Spatial Queries](#17-data-spatial-queries)
8. [Typed Context Blocks](#18-typed-context-blocks)

**[Part IV: Full-Stack Development](#part-iv-full-stack-development)**

1. [Module System](#19-module-system)
2. [Server-Side Development](#20-server-side-development)
3. [Client-Side Development (JSX)](#21-client-side-development-jsx)
4. [Server-Client Communication](#22-server-client-communication)
5. [Authentication & Users](#23-authentication--users)
6. [Memory & Persistence](#24-memory--persistence)
7. [Development Tools](#25-development-tools)

**[Part V: AI Integration](#part-v-ai-integration)**

1. [Meaning Typed Programming](#26-meaning-typed-programming)
2. [Semantic Strings](#27-semantic-strings)
3. [The `by` Operator and LLM Delegation](#28-the-by-operator-and-llm-delegation)
4. [Agentic AI Patterns](#29-agentic-ai-patterns)

**[Part VI: Concurrency](#part-vi-concurrency)**

1. [Async/Await](#30-asyncawait)
2. [Concurrent Expressions](#31-concurrent-expressions)

**[Part VII: Advanced Features](#part-vii-advanced-features)**

1. [Error Handling](#32-error-handling)
2. [Testing](#33-testing)
3. [Filter and Assign Comprehensions](#34-filter-and-assign-comprehensions)
4. [Pipe Operators](#35-pipe-operators)

**[Part VIII: Ecosystem](#part-viii-ecosystem)**

1. [CLI Reference](#36-cli-reference)
2. [Plugin System](#37-plugin-system)
3. [Project Configuration](#38-project-configuration)
4. [Python Interoperability](#39-python-interoperability)
5. [JavaScript/TypeScript Interoperability](#40-javascripttypescript-interoperability)

**[Part IX: Deployment and Scaling](#part-ix-deployment-and-scaling)**

1. [jac-scale Plugin](#41-jac-scale-plugin)
2. [Kubernetes Deployment](#42-kubernetes-deployment)
3. [Production Architecture](#43-production-architecture)

**[Appendices](#appendices)**

- [A. Complete Keyword Reference](#appendix-a-complete-keyword-reference)
- [B. Operator Quick Reference](#appendix-b-operator-quick-reference)
- [C. Grammar Summary](#appendix-c-grammar-summary)
- [D. Common Gotchas](#appendix-d-common-gotchas)
- [E. Migration from Python](#appendix-e-migration-from-python)
- [F. LLM Provider Reference](#appendix-f-llm-provider-reference)

---

# Part I: Foundation

## 1. Introduction

### 1.1 What is Jac?

Jac is an AI-native full-stack programming language that extends Python with Object-Spatial Programming (OSP). It provides a unified language for backend, frontend, and AI development.

```jac
with entry {
    print("Hello, Jac!");
}
```

### 1.2 The Six Principles

| Principle | Description |
|-----------|-------------|
| **AI-Native** | LLMs as first-class citizens through Meaning Typed Programming |
| **Full-Stack** | Backend and frontend in one unified language |
| **Superset** | Full access to PyPI and npm ecosystems |
| **Object-Spatial** | Graph-based domain modeling with mobile walkers |
| **Cloud-Native** | One-command deployment with automatic scaling |
| **Human & AI Friendly** | Readable structure for both humans and AI models |

### 1.3 Designed for Humans and AI

Jac is built for clarity and architectural transparency:

- `has` declarations for clean attribute definitions
- `impl` separation keeps interfaces distinct from implementations
- Structure that humans can reason about AND models can reliably generate

### 1.4 When to Use Jac

Jac excels at:

- Graph-structured applications (social networks, knowledge graphs)
- AI-powered applications with LLM integration
- Full-stack web applications
- Agentic AI systems
- Rapid prototyping

### 1.5 Jac vs Python

```jac
obj Person {
    has name: str;
    has age: int;

    can greet -> str {
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
| Methods | `def` | `can` (for abilities) |
| Types | Optional | Mandatory |

---

## 2. Getting Started

### 2.1 Installation

```bash
# Full installation with all plugins
pip install jaclang[all]

# Minimal installation
pip install jaclang

# Individual plugins
pip install byllm        # LLM integration
pip install jac-client   # Full-stack web
pip install jac-scale    # Production deployment
```

### 2.2 Your First Program

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
jac run hello.jac
```

### 2.3 Project Structure

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
| `.jac` | Universal Jac code |
| `.sv.jac` | Server-side only |
| `.cl.jac` | Client-side only |
| `.impl.jac` | Implementation file |

### 2.4 Editor Setup

Install the VS Code extension for Jac language support:

```bash
# Start the language server
jac lsp
```

---

## 3. Language Basics

### 3.1 Source Code Encoding

Jac source files are UTF-8 encoded. Unicode is fully supported in strings and comments.

### 3.2 Comments

```jac
# Single-line comment

#* Multi-line
   comment *#

"""Docstring for modules, classes, and functions"""
```

### 3.3 Statements and Expressions

All statements end with semicolons:

```jac
x = 5;
print(x);
result = compute(x) + 10;
```

### 3.4 Code Blocks

Code blocks use braces:

```jac
if condition {
    statement1;
    statement2;
}
```

### 3.5 Keywords

Jac keywords are reserved and cannot be used as identifiers:

| Category | Keywords |
|----------|----------|
| **Archetypes** | `obj`, `node`, `edge`, `walker`, `class`, `enum` |
| **Abilities** | `can`, `def`, `init`, `postinit` |
| **Access** | `pub`, `priv`, `protect`, `static`, `override`, `abs` |
| **Control** | `if`, `elif`, `else`, `while`, `for`, `match`, `case`, `switch`, `default` |
| **Loop** | `break`, `continue`, `skip` |
| **Return** | `return`, `yield`, `report` |
| **Exception** | `try`, `except`, `finally`, `raise`, `assert` |
| **OSP** | `visit`, `disengage`, `spawn`, `here`, `root`, `visitor`, `entry`, `exit` |
| **Module** | `import`, `include`, `from`, `as`, `glob` |
| **Blocks** | `cl` (client), `sv` (server) |
| **Other** | `with`, `test`, `impl`, `sem`, `by`, `del`, `in`, `is`, `and`, `or`, `not`, `async`, `await`, `flow`, `wait`, `lambda`, `props` |

**Note:** The abstract modifier keyword is `abs`, not `abstract`.

### 3.6 Identifiers

Valid identifiers start with a letter or underscore, followed by letters, digits, or underscores.

To use a reserved keyword as an identifier, escape it with angle brackets:

```jac
has <class>: str;  # Uses 'class' as field name
```

### 3.7 Entry Point Variants

```jac
# Default entry - always runs
with entry {
    print("Always runs");
}

# Main entry - only when file is the main module
with entry:__main__ {
    print("Only when this file is main");
}

# Named entry - run with: jac enter file.jac setup
with entry:setup {
    print("Named entry point");
}
```

---

## 4. Types and Values

### 4.1 Builtin Types

| Type | Description | Example |
|------|-------------|---------|
| `int` | Integer | `42`, `-17`, `0x1F` |
| `float` | Floating point | `3.14`, `1e-10` |
| `str` | String | `"hello"`, `'world'` |
| `bool` | Boolean | `True`, `False` |
| `bytes` | Byte sequence | `b"data"` |
| `list` | Mutable sequence | `[1, 2, 3]` |
| `tuple` | Immutable sequence | `(1, 2, 3)` |
| `set` | Unique values | `{1, 2, 3}` |
| `dict` | Key-value mapping | `{"a": 1}` |
| `any` | Any type | -- |
| `type` | Type object | -- |
| `None` | Null value | `None` |

### 4.2 Type Annotations

Type annotations are required for fields and function signatures:

```jac
has name: str;
has count: int = 0;
has items: list[str] = [];
has mapping: dict[str, int] = {};
```

### 4.3 Generic Types

```jac
def first[T](items: list[T]) -> T {
    return items[0];
}

obj Container[T] {
    has value: T;
}
```

### 4.4 Union Types

```jac
has value: int | str | None;

def process(data: list[int] | dict[str, int]) -> None {
    # Handle either type
}
```

### 4.5 Type References (Backtick)

The backtick creates a type reference:

```jac
`TypeName       # Reference to TypeName type
`root           # Reference to root node

# In edge references
[-->(`?Person)]  # Filter nodes by Person type
```

### 4.6 Literals

**Numbers:**

```jac
decimal = 42;
hex = 0x2A;
octal = 0o52;
binary = 0b101010;
floating = 3.14159;
scientific = 1.5e-10;
```

**Strings:**

```jac
regular = "hello\nworld";
raw = r"no\escape";
bytes_lit = b"binary data";
f_string = f"Value: {x}";
multiline = """
    Multiple
    lines
""";
```

### 4.7 F-String Format Specifications

F-strings support powerful formatting with the syntax `{expression:format_spec}`.

**Basic formatting:**

```jac
name = "Alice";
age = 30;

# Simple interpolation
greeting = f"Hello, {name}!";

# With expressions
message = f"In 5 years: {age + 5}";
```

**Width and alignment:**

```jac
# Width specification
f"{name:10}";           # "Alice     " (10 chars, left-aligned)
f"{name:>10}";          # "     Alice" (right-aligned)
f"{name:^10}";          # "  Alice   " (centered)
f"{name:<10}";          # "Alice     " (left-aligned, explicit)

# Fill character
f"{name:*>10}";         # "*****Alice" (fill with *)
f"{name:-^10}";         # "--Alice---" (centered with -)
```

**Number formatting:**

```jac
n = 42;
pi = 3.14159265;

# Integer formats
f"{n:d}";               # "42" (decimal)
f"{n:b}";               # "101010" (binary)
f"{n:o}";               # "52" (octal)
f"{n:x}";               # "2a" (hex lowercase)
f"{n:X}";               # "2A" (hex uppercase)
f"{n:05d}";             # "00042" (zero-padded, width 5)

# Float formats
f"{pi:f}";              # "3.141593" (fixed-point, 6 decimals default)
f"{pi:.2f}";            # "3.14" (2 decimal places)
f"{pi:10.2f}";          # "      3.14" (width 10, 2 decimals)
f"{pi:e}";              # "3.141593e+00" (scientific notation)
f"{pi:.2e}";            # "3.14e+00" (scientific, 2 decimals)
f"{pi:g}";              # "3.14159" (general format)

# Percentage
ratio = 0.756;
f"{ratio:.1%}";         # "75.6%"

# Thousands separator
big = 1234567;
f"{big:,}";             # "1,234,567"
f"{big:_}";             # "1_234_567" (underscore separator)
```

**Sign and padding:**

```jac
x = 42;
y = -42;

f"{x:+d}";              # "+42" (always show sign)
f"{y:+d}";              # "-42"
f"{x: d}";              # " 42" (space for positive)
f"{x:=+5d}";            # "+  42" (pad after sign)
```

**Conversions (`!r`, `!s`, `!a`):**

```jac
text = "hello\nworld";

f"{text}";              # "hello
                        #  world" (default str())
f"{text!s}";            # "hello
                        #  world" (explicit str())
f"{text!r}";            # "'hello\\nworld'" (repr())
f"{text!a}";            # "'hello\\nworld'" (ascii())
```

**Nested expressions:**

```jac
width = 10;
precision = 2;

# Dynamic width and precision
f"{pi:{width}.{precision}f}";   # "      3.14"

# Expression in format spec
f"{value:{'>10' if right else '<10'}}";
```

**Format specification grammar:**

```
[[fill]align][sign][#][0][width][grouping][.precision][type]

fill      : any character
align     : '<' (left) | '>' (right) | '^' (center) | '=' (pad after sign)
sign      : '+' | '-' | ' '
#         : alternate form (0x for hex, etc.)
0         : zero-pad
width     : minimum width
grouping  : ',' or '_' for thousands
precision : digits after decimal
type      : 's' 'd' 'f' 'e' 'g' 'b' 'o' 'x' 'X' '%'
```

**Collections:**

```jac
list_lit = [1, 2, 3];
tuple_lit = (1, 2, 3);
set_lit = {1, 2, 3};
dict_lit = {"key": "value", "num": 42};
empty_dict = {};
empty_list = [];
```

---

## 5. Variables and Scope

### 5.1 Local Variables

```jac
# Type inferred
x = 42;
name = "Alice";

# Explicit type
count: int = 0;
items: list[str] = [];
```

### 5.2 Instance Variables (has)

The `has` keyword declares instance variables:

```jac
obj Person {
    has name: str;                    # Required
    has age: int = 0;                 # With default
    static has count: int = 0;        # Static (class-level)
    has computed: int by postinit;    # Deferred initialization
}
```

**Deferred Initialization:**

Use `by postinit` when a field depends on other fields:

```jac
obj Rectangle {
    has width: float;
    has height: float;
    has area: float by postinit;

    def postinit {
        self.area = self.width * self.height;
    }
}
```

### 5.3 Global Variables (glob)

```jac
glob PI: float = 3.14159;
glob config: dict = {};

with entry {
    global PI;
    print(PI);
}
```

### 5.4 Scope Rules

**Scope Resolution Order (LEGB):**

When Jac looks up a name, it searches in this order:

1. **L**ocal: Names in the current function/block
2. **E**nclosing: Names in enclosing functions (for nested functions)
3. **G**lobal: Names at module level (`glob` declarations)
4. **B**uilt-in: Pre-defined names (`print`, `len`, `range`, etc.)

```jac
glob x = "global";

def outer -> None {
    x = "enclosing";

    def inner -> None {
        x = "local";
        print(x);  # "local" - found in Local scope
    }

    inner();
    print(x);  # "enclosing" - found in Enclosing scope
}
```

**Modifying outer scope variables:**

```jac
glob counter: int = 0;

def increment -> None {
    global counter;    # Declares intent to modify global
    counter += 1;
}

def outer -> None {
    x = 10;
    def inner -> None {
        nonlocal x;    # Declares intent to modify enclosing
        x += 1;
    }
    inner();
    print(x);  # 11
}
```

**Block scope behavior:**

```jac
if True {
    block_var = 42;    # Created in block
}
# block_var is still accessible here in Jac (unlike some languages)

for i in range(3) {
    loop_var = i;
}
# loop_var and i are accessible here
```

### 5.5 Truthiness

Values are evaluated as boolean in conditions. The following are **falsy** (evaluate to `False`):

| Type | Falsy Values |
|------|--------------|
| `bool` | `False` |
| `None` | `None` |
| `int` | `0` |
| `float` | `0.0` |
| `str` | `""` (empty string) |
| `list` | `[]` (empty list) |
| `tuple` | `()` (empty tuple) |
| `dict` | `{}` (empty dict) |
| `set` | `set()` (empty set) |

All other values are **truthy**.

**Examples:**

```jac
# Falsy values
if not 0 { print("0 is falsy"); }
if not "" { print("empty string is falsy"); }
if not [] { print("empty list is falsy"); }
if not None { print("None is falsy"); }

# Truthy values
if 1 { print("non-zero is truthy"); }
if "hello" { print("non-empty string is truthy"); }
if [1, 2] { print("non-empty list is truthy"); }

# Common patterns
items = get_items();
if items {
    process(items);
} else {
    print("No items to process");
}

# Default value pattern
name = user_input or "Anonymous";

# Guard pattern
user and user.is_active and process(user);
```

---

## 6. Operators

### 6.1 Arithmetic Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `+` | Addition | `a + b` |
| `-` | Subtraction | `a - b` |
| `*` | Multiplication | `a * b` |
| `/` | Division | `a / b` |
| `//` | Floor division | `a // b` |
| `%` | Modulo | `a % b` |
| `**` | Exponentiation | `a ** b` |
| `@` | Matrix multiplication | `a @ b` |

### 6.2 Comparison Operators

| Operator | Description |
|----------|-------------|
| `==` | Equal |
| `!=` | Not equal |
| `<` | Less than |
| `>` | Greater than |
| `<=` | Less than or equal |
| `>=` | Greater than or equal |
| `is` | Identity |
| `is not` | Not identity |
| `in` | Membership |
| `not in` | Not membership |

### 6.3 Logical Operators

```jac
# Word form (preferred)
result = a and b;
result = a or b;
result = not a;

# Symbol form (also valid)
result = a && b;
result = a || b;
```

### 6.4 Bitwise Operators

| Operator | Name | Description |
|----------|------|-------------|
| `&` | AND | 1 if both bits are 1 |
| `\|` | OR | 1 if either bit is 1 |
| `^` | XOR | 1 if bits are different |
| `~` | NOT | Inverts all bits |
| `<<` | Left shift | Shifts bits left, fills with 0 |
| `>>` | Right shift | Shifts bits right |

**Examples:**

```jac
# Bitwise AND - check if bit is set
has_flag = (flags & FLAG_MASK) != 0;

# Bitwise OR - set a bit
flags = flags | NEW_FLAG;

# Bitwise XOR - toggle a bit
flags = flags ^ TOGGLE_FLAG;

# Bitwise NOT - invert all bits
inverted = ~value;

# Left shift - multiply by 2^n
doubled = value << 1;      # value * 2
quadrupled = value << 2;   # value * 4

# Right shift - divide by 2^n
halved = value >> 1;       # value // 2
quartered = value >> 2;    # value // 4
```

**Common bit manipulation patterns:**

```jac
# Check if nth bit is set
def is_bit_set(value: int, n: int) -> bool {
    return (value & (1 << n)) != 0;
}

# Set nth bit
def set_bit(value: int, n: int) -> int {
    return value | (1 << n);
}

# Clear nth bit
def clear_bit(value: int, n: int) -> int {
    return value & ~(1 << n);
}

# Toggle nth bit
def toggle_bit(value: int, n: int) -> int {
    return value ^ (1 << n);
}

# Check if power of 2
def is_power_of_two(n: int) -> bool {
    return n > 0 and (n & (n - 1)) == 0;
}
```

### 6.5 Assignment Operators

**Simple Assignment:**

```jac
x = 5;
name = "Alice";
a = b = c = 0;  # Chained assignment
```

**Walrus Operator (`:=`):**

The walrus operator assigns a value and returns it in a single expression:

```jac
# In conditionals - assign and test
if (n := len(items)) > 10 {
    print(f"List has {n} items, too many!");
}

# In while loops - assign and check
while (line := file.readline()) {
    process(line);
}

# In comprehensions - avoid redundant computation
results = [y for x in data if (y := expensive(x)) > threshold];

# In function calls
print(f"Length: {(n := len(text))}, doubled: {n * 2}");
```

**Augmented Assignment Operators:**

All augmented assignments modify the variable in place:

| Operator | Equivalent | Description |
|----------|------------|-------------|
| `x += y` | `x = x + y` | Add and assign |
| `x -= y` | `x = x - y` | Subtract and assign |
| `x *= y` | `x = x * y` | Multiply and assign |
| `x /= y` | `x = x / y` | Divide and assign |
| `x //= y` | `x = x // y` | Floor divide and assign |
| `x %= y` | `x = x % y` | Modulo and assign |
| `x **= y` | `x = x ** y` | Exponentiate and assign |
| `x @= y` | `x = x @ y` | Matrix multiply and assign |
| `x &= y` | `x = x & y` | Bitwise AND and assign |
| `x \|= y` | `x = x \| y` | Bitwise OR and assign |
| `x ^= y` | `x = x ^ y` | Bitwise XOR and assign |
| `x <<= y` | `x = x << y` | Left shift and assign |
| `x >>= y` | `x = x >> y` | Right shift and assign |

```jac
# Numeric augmented assignment
count += 1;
total *= tax_rate;
value **= 2;

# Bitwise augmented assignment
flags |= NEW_FLAG;      # Set a flag
flags &= ~OLD_FLAG;     # Clear a flag
bits ^= mask;           # Toggle bits
register <<= 4;         # Shift left
```

### 6.6 Null-Safe Operators

The `?` operator provides safe access to potentially null values, returning `None` instead of raising an error.

**Safe attribute access (`?.`):**

```jac
# Without null-safe: raises AttributeError if obj is None
value = obj.field;

# With null-safe: returns None if obj is None
value = obj?.field;

# Chained - stops at first None
result = user?.profile?.settings?.theme;
```

**Safe index access (`?[]`):**

```jac
# Without null-safe: raises TypeError if list is None
item = my_list[0];

# With null-safe: returns None if list is None
item = my_list?[0];

# Works with dictionaries too
value = config?["key"];
```

**Safe method calls:**

```jac
# Returns None if obj is None, doesn't call method
result = obj?.method();

# Chained with arguments
output = data?.transform(param)?.format();
```

**Combining with default values:**

```jac
# Null-safe with fallback using or
name = user?.name or "Anonymous";

# In conditionals
if user?.is_active {
    process(user);
}
```

**In filter comprehensions:**

```jac
# The ? in filter comprehensions
valid_items = items(?value > 0);  # Filter where value > 0
```

**Behavior summary:**

| Expression | When `obj` is `None` | When `obj` is valid |
|------------|---------------------|---------------------|
| `obj?.attr` | `None` | `obj.attr` |
| `obj?[key]` | `None` | `obj[key]` |
| `obj?.method()` | `None` | `obj.method()` |
| `obj?.a?.b` | `None` | `obj.a.b` (or `None` if `a` is `None`) |

### 6.7 Graph Operators (OSP)

**Connection Operators:**

```jac
# Untyped connections
node1 ++> node2;         # Forward
node1 <++ node2;         # Backward
node1 <++> node2;        # Bidirectional

# Typed connections
node1 +>: Edge :+> node2;         # Forward typed
node1 <+: Edge :<+ node2;         # Backward typed
node1 <+: Edge :+> node2;         # Bidirectional typed

# With edge attributes
alice +>: Friend(since=2020) :+> bob;
```

**Edge Reference Operators:**

```jac
[-->]                    # All outgoing edges
[<--]                    # All incoming edges
[<-->]                   # Bidirectional (both)

[->:Type:->]            # Typed outgoing
[<-:Type:<-]            # Typed incoming
[<-:Type:->]            # Typed bidirectional

[->:Edge:attr > 5:->]   # Filtered by edge attribute
[-->(`?NodeType)]        # Filtered by node type
```

### 6.8 Pipe Operators

Jac provides multiple pipe operators for functional-style data flow:

**Standard Pipes (`|>`, `<|`):**

```jac
# Forward pipe - data flows left to right
result = data |> transform |> filter |> format;

# Equivalent to:
result = format(filter(transform(data)));

# Backward pipe - data flows right to left
result = output <| filter <| transform <| data;

# Equivalent to:
result = output(filter(transform(data)));
```

**Atomic Pipes (`:>`, `<:`):**

Atomic pipes are used with spawn operations and affect traversal order:

```jac
# Atomic pipe forward - depth-first traversal
result = node spawn :> Walker();

# Atomic pipe backward
result = Walker() <: spawn node;

# Standard pipe with spawn - breadth-first traversal
result = node spawn |> Walker();
```

**Dot Pipes (`.>`, `<.`):**

Dot pipes chain method calls:

```jac
# Dot forward pipe
result = data .> method1 .> method2 .> method3;

# Equivalent to:
result = data.method1().method2().method3();

# Dot backward pipe
result = method3 <. method2 <. method1 <. data;
```

**Pipe with lambdas:**

```jac
# Using lambdas in pipe chains
result = numbers
    |> (lambda x: list : [i * 2 for i in x])
    |> (lambda x: list : [i for i in x if i > 10])
    |> sum;
```

**Comparison of pipe operators:**

| Operator | Name | Direction | Use Case |
|----------|------|-----------|----------|
| `\|>` | Forward pipe | Left to right | Function composition |
| `<\|` | Backward pipe | Right to left | Reverse composition |
| `:>` | Atomic forward | Left to right | Depth-first spawn |
| `<:` | Atomic backward | Right to left | Reverse atomic |
| `.>` | Dot forward | Left to right | Method chaining |
| `<.` | Dot backward | Right to left | Reverse method chain |

### 6.9 The `by` Operator

The `by` operator is a general-purpose right-associative operator. At the syntax level, it connects two expressions. The semantics depend on how plugins interpret it.

**General Syntax:**

```jac
# Basic by expression
result = "hello" by "world";

# Chained by expressions (right-associative)
result = "a" by "b" by "c";  # Parsed as: "a" by ("b" by "c")

# With expressions
result = (1 + 2) by (3 * 4);
```

**With byllm Plugin (LLM Delegation):**

When the `byllm` plugin is installed, `by` enables LLM delegation:

```jac
# Expression processed by LLM
response = "Explain quantum computing" by llm;

# Function implementation delegated to LLM
def summarize(text: str) -> str by llm;

# With specific model
def translate(text: str) -> str by llm(model_name="gpt-4");
```

See [Part V: AI Integration](#part-v-ai-integration) for detailed LLM usage.

### 6.10 Operator Precedence

Complete precedence table from **lowest** (evaluated last) to **highest** (evaluated first):

| Precedence | Operators | Associativity | Description |
|------------|-----------|---------------|-------------|
| 1 (lowest) | `lambda` | - | Lambda expression |
| 2 | `if else` | Right | Ternary conditional |
| 3 | `by` | Right | By operator (LLM delegation) |
| 4 | `:=` | Right | Walrus operator |
| 5 | `or`, `\|\|` | Left | Logical OR |
| 6 | `and`, `&&` | Left | Logical AND |
| 7 | `not` | - | Logical NOT (unary) |
| 8 | `in`, `not in`, `is`, `is not`, `<`, `<=`, `>`, `>=`, `!=`, `==` | Left | Comparison/membership |
| 9 | `\|` | Left | Bitwise OR |
| 10 | `^` | Left | Bitwise XOR |
| 11 | `&` | Left | Bitwise AND |
| 12 | `<<`, `>>` | Left | Bit shifts |
| 13 | `\|>`, `<\|` | Left | Pipe operators |
| 14 | `+`, `-` | Left | Addition, subtraction |
| 15 | `*`, `/`, `//`, `%`, `@` | Left | Multiplication, division, modulo, matmul |
| 16 | `+x`, `-x`, `~` | - | Unary plus, minus, bitwise NOT |
| 17 | `**` | Right | Exponentiation |
| 18 | `await` | - | Await expression |
| 19 | `spawn` | Left | Walker spawn |
| 20 | `:>`, `<:` | Left | Atomic pipes |
| 21 | `++>`, `<++`, connection ops | Left | Graph connection |
| 22 (highest) | `x[i]`, `x.attr`, `x()`, `x?.attr` | Left | Subscript, attribute, call |

**Examples showing precedence:**

```jac
# Ternary binds loosely
x = a if cond else b + 1;   # x = a if cond else (b + 1)

# Logical operators
x = a or b and c;           # x = a or (b and c)
x = not a and b;            # x = (not a) and b

# Comparison chaining
valid = 0 < x < 10;         # (0 < x) and (x < 10)

# Arithmetic
x = a + b * c;              # x = a + (b * c)
x = a ** b ** c;            # x = a ** (b ** c)  (right associative)

# Bitwise
x = a | b & c;              # x = a | (b & c)
x = a << 2 + 1;             # x = a << (2 + 1)

# Pipe operators
result = a |> f |> g;       # result = g(f(a))

# Walrus in condition
if (n := len(x)) > 10 { }   # Assignment happens first
```

**Short-circuit evaluation:**

`and` and `or` use short-circuit evaluation:

```jac
# 'and' stops at first falsy value
result = a and b and c;  # Returns first falsy, or last value

# 'or' stops at first truthy value
result = a or b or c;    # Returns first truthy, or last value

# Common patterns
value = user_input or default;     # Use default if input is falsy
safe = obj and obj.method();       # Only call if obj exists
```

---

## 7. Control Flow

### 7.1 Conditional Statements

```jac
if condition {
    # block
} elif other_condition {
    # block
} else {
    # block
}

# Ternary expression
result = value_if_true if condition else value_if_false;
```

### 7.2 While Loops

```jac
while condition {
    # loop body
}

# With else clause (executes if loop completes normally)
while condition {
    # loop body
} else {
    # no break occurred
}
```

### 7.3 For Loops

```jac
# Iterate over collection
for item in items {
    print(item);
}

# With index
for (i, item) in enumerate(items) {
    print(f"{i}: {item}");
}

# C-style for loop
for i = 0 to i < 10 by i += 1 {
    print(i);
}

# With else clause
for item in items {
    if found(item) {
        break;
    }
} else {
    print("Not found");
}
```

### 7.4 Pattern Matching

```jac
match value {
    case 0 {
        print("zero");
    }
    case 1 | 2 | 3 {
        print("small");
    }
    case [x, y] {
        print(f"pair: {x}, {y}");
    }
    case {"key": v} {
        print(f"dict with key: {v}");
    }
    case Point(x=x, y=y) {
        print(f"point at {x}, {y}");
    }
    case _ {
        print("default");
    }
}
```

### 7.5 Switch Statement

```jac
switch value {
    case 1 {
        print("one");
    }
    case 2 {
        print("two");
    }
    default {
        print("other");
    }
}
```

Note: Unlike C, there is no fall-through between cases.

### 7.6 Loop Control

```jac
for item in items {
    if should_skip(item) {
        continue;    # Skip to next iteration
    }
    if should_stop(item) {
        break;       # Exit loop
    }
    if should_skip_outer(item) {
        skip;        # Skip in nested context
    }
}
```

### 7.7 Context Managers

```jac
with open("file.txt") as f {
    content = f.read();
}

# Multiple context managers
with open("in.txt") as fin, open("out.txt", "w") as fout {
    fout.write(fin.read());
}

# Async context manager
async with acquire_lock() as lock {
    # critical section
}
```

### 7.8 Exception Handling

**Basic try/except:**

```jac
try {
    result = risky_operation();
} except ValueError {
    print("Value error occurred");
}
```

**Capturing the exception:**

```jac
try {
    data = parse_json(input);
} except ValueError as e {
    print(f"Parse error: {e}");
} except KeyError as e {
    print(f"Missing key: {e}");
}
```

**Multiple exception types:**

```jac
try {
    process(data);
} except (TypeError, ValueError) as e {
    print(f"Type or value error: {e}");
}
```

**Full try/except/else/finally:**

```jac
try {
    file = open("data.txt");
    data = file.read();
} except FileNotFoundError {
    print("File not found");
    data = default_data;
} except PermissionError as e {
    print(f"Permission denied: {e}");
    raise;  # Re-raise the exception
} else {
    # Executes only if no exception occurred
    print(f"Read {len(data)} bytes");
} finally {
    # Always executes (cleanup)
    if file {
        file.close();
    }
}
```

**Raising exceptions:**

```jac
# Raise an exception
raise ValueError("Invalid input");

# Raise with a message
raise RuntimeError(f"Failed to process: {item}");

# Re-raise current exception
except SomeError {
    log_error();
    raise;
}

# Exception chaining (raise from)
try {
    low_level_operation();
} except LowLevelError as e {
    raise HighLevelError("Operation failed") from e;
}
```

**Custom exceptions:**

```jac
obj ValidationError(Exception) {
    has field: str;
    has message: str;
}

def validate(data: dict) -> None {
    if "name" not in data {
        raise ValidationError(field="name", message="Name is required");
    }
}
```

### 7.9 Assertions

Assertions verify conditions during development:

```jac
# Basic assertion
assert condition;

# Assertion with message
assert len(items) > 0, "Items list cannot be empty";

# Type checking
assert isinstance(value, int), f"Expected int, got {type(value)}";

# Invariant checking
def withdraw(amount: float) -> None {
    assert amount > 0, "Withdrawal amount must be positive";
    assert amount <= self.balance, "Insufficient funds";
    self.balance -= amount;
}
```

**Note:** Assertions can be disabled in production with optimization flags. Use exceptions for validation that must always run.

### 7.10 Generator Functions

Generators produce values lazily using `yield`:

**Basic generator:**

```jac
def count_up(n: int) -> int {
    for i in range(n) {
        yield i;
    }
}

# Usage
for num in count_up(5) {
    print(num);  # 0, 1, 2, 3, 4
}
```

**Generator with state:**

```jac
def fibonacci(limit: int) -> int {
    a = 0;
    b = 1;
    while a < limit {
        yield a;
        (a, b) = (b, a + b);
    }
}
```

**yield from (delegation):**

```jac
def flatten(nested: list) -> any {
    for item in nested {
        if isinstance(item, list) {
            yield from flatten(item);  # Delegate to sub-generator
        } else {
            yield item;
        }
    }
}

# Usage
nested = [[1, 2], [3, [4, 5]], 6];
flat = list(flatten(nested));  # [1, 2, 3, 4, 5, 6]
```

**Generator expressions:**

```jac
# Generator expression (lazy)
squares = (x ** 2 for x in range(1000000));

# List comprehension (eager)
squares_list = [x ** 2 for x in range(100)];
```

---

# Part II: Functions and Objects

## 8. Functions and Abilities

### 8.1 Function Declaration

```jac
def add(a: int, b: int) -> int {
    return a + b;
}

def greet(name: str) -> str {
    return f"Hello, {name}!";
}

# No return value
def log(message: str) -> None {
    print(f"[LOG] {message}");
}
```

### 8.2 Parameter Types and Ordering

**Parameter Categories:**

| Category | Syntax | Description |
|----------|--------|-------------|
| Positional-only | Before `/` | Must be passed by position |
| Positional-or-keyword | Normal params | Can be passed either way |
| Variadic positional | `*args` | Collects extra positional args |
| Keyword-only | After `*` or `*args` | Must be passed by keyword |
| Variadic keyword | `**kwargs` | Collects extra keyword args |

**Required Parameter Order:**

```jac
def complete_example(
    pos_only1: int,           # 1. Positional-only parameters
    pos_only2: str,
    /,                         # 2. Positional-only marker
    pos_or_kw: float,          # 3. Normal (positional-or-keyword)
    with_default: int = 10,    # 4. Parameters with defaults
    *args: int,                # 5. Variadic positional
    kw_only: str,              # 6. Keyword-only (after * or *args)
    kw_default: bool = True,   # 7. Keyword-only with default
    **kwargs: any              # 8. Variadic keyword (must be last)
) -> None {
    pass;
}
```

**Positional-only parameters (`/`):**

```jac
def greet(name: str, /) -> str {
    return f"Hello, {name}!";
}

greet("Alice");      # OK
greet(name="Alice"); # Error: positional-only
```

**Keyword-only parameters (after `*`):**

```jac
def configure(*, host: str, port: int = 8080) -> None {
    print(f"Connecting to {host}:{port}");
}

configure(host="localhost");           # OK
configure("localhost", 8080);          # Error: keyword-only
configure(host="localhost", port=443); # OK
```

**Variadic parameters:**

```jac
# *args collects extra positional arguments
def sum_all(*values: int) -> int {
    return sum(values);
}

sum_all(1, 2, 3, 4, 5);  # 15

# **kwargs collects extra keyword arguments
def build_config(**options: any) -> dict {
    return dict(options);
}

build_config(debug=True, verbose=False);  # {"debug": True, "verbose": False}

# Combined
def flexible(required: int, *args: int, **kwargs: any) -> None {
    print(f"Required: {required}");
    print(f"Extra positional: {args}");
    print(f"Extra keyword: {kwargs}");
}

flexible(1, 2, 3, name="test");
# Required: 1
# Extra positional: (2, 3)
# Extra keyword: {"name": "test"}
```

**Unpacking arguments:**

```jac
def add(a: int, b: int, c: int) -> int {
    return a + b + c;
}

# Unpack list/tuple into positional args
values = [1, 2, 3];
result = add(*values);  # add(1, 2, 3)

# Unpack dict into keyword args
params = {"a": 1, "b": 2, "c": 3};
result = add(**params);  # add(a=1, b=2, c=3)

# Combined unpacking
result = add(*[1, 2], **{"c": 3});  # add(1, 2, c=3)
```

### 8.3 Abilities (Methods)

The `can` keyword declares abilities (methods) on archetypes:

```jac
obj Calculator {
    has total: float = 0.0;

    can add(value: float) -> float {
        self.total += value;
        return self.total;
    }

    can reset -> None {
        self.total = 0.0;
    }

    # Abstract ability (no body)
    can compute -> float abs;
}
```

### 8.4 Static and Class Methods

```jac
obj Counter {
    static has count: int = 0;

    # Static method
    static can get_count -> int {
        return Counter.count;
    }

    # Instance method
    can increment -> None {
        Counter.count += 1;
    }
}
```

### 8.5 Lambda Expressions

```jac
# Simple lambda (note spacing around type annotations)
glob add = lambda a: int , b: int -> int : a + b;

# Lambda with block
glob process = lambda x: int -> int {
    result = x * 2;
    result += 1;
    return result;
};

# Lambda without parameters
glob get_value = lambda : 42;

# Lambda with return type only
glob get_default = lambda -> int : 100;

# Lambda with default parameters
glob power = lambda x: int = 2 , y: int = 3 : x ** y;

# Using lambdas
glob numbers = [1, 2, 3, 4, 5];
glob squared = list(map(lambda x: int : x ** 2, numbers));
glob evens = list(filter(lambda x: int : x % 2 == 0, numbers));

# Lambda returning lambda
glob make_adder = lambda x: int : (lambda y: int : x + y);
glob add_five = make_adder(5);  # add_five(10) returns 15
```

### 8.6 Immediately Invoked Function Expressions (IIFE)

```jac
result = (lambda x: int -> int: x * 2)(5);  # result = 10
```

### 8.7 Decorators

```jac
@decorator
def my_function -> None {
    pass;
}

@decorator_with_args(arg1, arg2)
def another_function -> None {
    pass;
}
```

### 8.8 Access Modifiers

```jac
# Public (default, accessible everywhere)
def:pub public_func -> None { }

# Private (accessible only within the module)
def:priv _private_func -> None { }

# Protected (accessible within module and subclasses)
def:protect _protected_func -> None { }
```

---

## 9. Object-Oriented Programming

### 9.1 Objects (Classes)

```jac
obj Person {
    has name: str;
    has age: int;

    def init(name: str, age: int) {
        self.name = name;
        self.age = age;
    }

    def postinit {
        # Called after init completes
        print(f"Created {self.name}");
    }

    can greet -> str {
        return f"Hi, I'm {self.name}";
    }
}

# Usage
person = Person(name="Alice", age=30);
print(person.greet());
```

### 9.2 Inheritance

```jac
obj Animal {
    has name: str;

    can speak -> str abs;  # Abstract
}

obj Dog(Animal) {
    has breed: str = "Unknown";

    override can speak -> str {
        return "Woof!";
    }
}

obj Cat(Animal) {
    override can speak -> str {
        return "Meow!";
    }
}

# Multiple inheritance
obj Pet(Animal, Trackable) {
    has owner: str;
}
```

### 9.3 Enumerations

```jac
enum Color {
    RED = "red",
    GREEN = "green",
    BLUE = "blue"
}

# With auto values
enum Status {
    PENDING,
    ACTIVE,
    COMPLETED
}

# With methods
enum HttpStatus {
    OK = 200,
    NOT_FOUND = 404,
    SERVER_ERROR = 500

    can is_success -> bool {
        return self.value < 400;
    }
}

# Usage
status = HttpStatus.OK;
if status.is_success() {
    print("Request succeeded");
}
```

### 9.4 Enums with Inline Python

```jac
enum HttpStatus {
    OK = 200,
    NOT_FOUND = 404

    ::py::
    def is_success(self):
        return 200 <= self.value < 300

    @property
    def message(self):
        return {200: "OK", 404: "Not Found"}.get(self.value, "Unknown")
    ::py::
}
```

### 9.5 Properties and Encapsulation

```jac
obj Account {
    has:priv _balance: float = 0.0;

    can get_balance -> float {
        return self._balance;
    }

    can deposit(amount: float) -> None {
        if amount > 0 {
            self._balance += amount;
        }
    }
}
```

---

## 10. Implementations and Forward Declarations

### 10.1 Forward Declarations

Declare types before defining them to handle circular references:

```jac
# Forward declarations
obj User;
obj Post;

# Now define with mutual references
obj User {
    has name: str;
    has posts: list[Post] = [];
}

obj Post {
    has content: str;
    has author: User;
}
```

### 10.2 Implementation Blocks

Separate interface from implementation:

```jac
# Interface (declaration)
obj Calculator {
    has value: float = 0.0;

    can add(x: float) -> float;
    can multiply(x: float) -> float;
}

# Implementation
impl Calculator.add(x: float) -> float {
    self.value += x;
    return self.value;
}

impl Calculator.multiply(x: float) -> float {
    self.value *= x;
    return self.value;
}
```

### 10.3 Separate Implementation Files

Convention: Use `.impl.jac` files for implementations.

**calculator.jac:**

```jac
obj Calculator {
    has value: float = 0.0;
    can add(x: float) -> float;
    can multiply(x: float) -> float;
}
```

**calculator.impl.jac:**

```jac
impl Calculator.add(x: float) -> float {
    self.value += x;
    return self.value;
}

impl Calculator.multiply(x: float) -> float {
    self.value *= x;
    return self.value;
}
```

### 10.4 When to Use Implementations

- **Circular dependencies**: Forward declare to break cycles
- **Code organization**: Keep interfaces clean
- **Plugin architectures**: Define interfaces that plugins implement
- **Large codebases**: Separate concerns across files

---

# Part III: Object-Spatial Programming (OSP)

> **Related Sections:**
>
> - [Graph Operators](#67-graph-operators-osp) - Connection and edge reference syntax
> - [Pipe Operators](#68-pipe-operators) - Spawn traversal modes
> - [Data Spatial Queries](#17-data-spatial-queries) - Filtering and querying
> - [Typed Context Blocks](#18-typed-context-blocks) - Type-based dispatch

## 11. Introduction to OSP

### 11.1 What is OSP?

Object-Spatial Programming models data as graphs and computation as mobile agents (walkers) that traverse the graph. Instead of calling functions on objects, walkers visit nodes and perform operations based on location.

### 11.2 Why OSP?

- **Natural graph modeling**: Social networks, knowledge graphs, state machines
- **AI agent architecture**: Walkers are natural representations of AI agents
- **Separation of concerns**: Data (nodes/edges) separate from behavior (walkers)
- **Spatial context**: `here`, `visitor` provide natural context

### 11.3 Core Concepts

| Concept | Description | Keyword |
|---------|-------------|---------|
| **Node** | Graph vertex holding data | `node` |
| **Edge** | Connection between nodes | `edge` |
| **Walker** | Mobile agent that traverses | `walker` |
| **Root** | Entry point to graph | `root` |
| **Here** | Walker's current location | `here` |
| **Visitor** | Reference to visiting walker | `visitor` |

### 11.4 Complete Example

```jac
node Person {
    has name: str;
    has age: int;
}

edge Knows {
    has since: int;
}

walker Greeter {
    can greet with `root entry {
        visit [-->];
    }

    can say_hello with Person entry {
        print(f"Hello, {here.name}!");
        visit [-->];
    }
}

with entry {
    # Build graph
    alice = Person(name="Alice", age=30);
    bob = Person(name="Bob", age=25);

    root ++> alice;
    alice +>: Knows(since=2020) :+> bob;

    # Spawn walker
    root spawn Greeter();
}
```

---

## 12. Nodes

### 12.1 Node Declaration

```jac
node Person {
    has name: str;
    has age: int = 0;

    can greet with Visitor entry {
        print(f"Hello from {self.name}");
    }
}

# Node with no data
node Waypoint { }
```

### 12.2 Node Entry/Exit Abilities

Abilities triggered when walkers enter or exit. The event clause syntax is:

```
can ability_name with [TypeExpression] (entry | exit) { ... }
```

Where `TypeExpression` is optional - if omitted, the ability triggers for ALL walkers.

```jac
node SecureRoom {
    has clearance_required: int;

    # Generic entry - triggers for ANY walker (no type filter)
    can on_enter with entry {
        print("Someone entered");
    }

    # Typed entry - triggers only for Inspector walkers
    can check_clearance with Inspector entry {
        if visitor.clearance < self.clearance_required {
            print("Access denied");
            disengage;
        }
    }

    # Type reference entry - using backtick for root
    can at_root with `root entry {
        print("At root node");
    }

    # Walker exiting
    can on_exit with Inspector exit {
        print("Inspector leaving");
    }

    # Multiple walker types (union)
    can process with Walker1 | Walker2 entry {
        print("Processing for Walker1 or Walker2");
    }
}
```

**Event Clause Forms:**

| Form | Triggers When |
|------|---------------|
| `with entry` | Any walker enters (no type filter) |
| `with TypeName entry` | Walker of TypeName enters |
| `` with `root entry `` | At root node entry |
| `with Type1 \| Type2 entry` | Walker of either type enters |
| `with exit` | Any walker exits |
| `with TypeName exit` | Walker of TypeName exits |

### 12.3 Node Inheritance

```jac
node Entity {
    has id: str;
    has created_at: str;
}

node User(Entity) {
    has username: str;
    has email: str;
}
```

---

## 13. Edges

### 13.1 Edge Declaration

```jac
edge Friend {
    has since: int;
    has strength: float = 1.0;
}

edge Follows { }  # Edge with no data

edge Weighted {
    has weight: float;

    can get_normalized(max_weight: float) -> float {
        return self.weight / max_weight;
    }
}
```

### 13.2 Edge Entry/Exit

Walkers can trigger abilities on edges during traversal:

```jac
edge Road {
    has distance: float;

    can on_traverse with Traveler entry {
        visitor.total_distance += self.distance;
    }
}
```

### 13.3 Directed vs Undirected

Edge direction is determined by connection operators:

```jac
a ++> b;          # Directed: a → b
a <++> b;         # Undirected: a ↔ b (creates edges both ways)
```

---

## 14. Walkers

### 14.1 Walker Declaration

```jac
walker Collector {
    has items: list = [];
    has max_items: int = 10;

    can start with `root entry {
        print("Starting collection");
        visit [-->];
    }

    can collect with DataNode entry {
        if len(self.items) < self.max_items {
            self.items.append(here.value);
        }
        visit [-->];
    }
}
```

### 14.2 Walker State

Walkers maintain state throughout their traversal:

```jac
walker Counter {
    has count: int = 0;

    can count_nodes with entry {
        self.count += 1;
        visit [-->];
    }
}

with entry {
    walker_instance = Counter();
    root spawn walker_instance;
    print(f"Counted {walker_instance.count} nodes");
}
```

### 14.3 The `visit` Statement

The `visit` statement queues nodes for the walker to visit next.

**Basic Syntax:**

```jac
visit [-->];                    # Visit all outgoing nodes
visit [<--];                    # Visit all incoming nodes
visit [<-->];                   # Visit both directions
```

**With Type Filters:**

```jac
visit [-->(`?Person)];          # Visit Person nodes only
visit [->:Friend:->];           # Visit via Friend edges only
visit [->:Friend:since>2020:->]; # Via Friend edges with condition
```

**With Else Clause:**

```jac
visit [-->] else {              # Fallback if no nodes to visit
    print("No outgoing edges");
}
```

**Direct Node Visit:**

```jac
visit target_node;              # Visit a specific node directly
visit self.target;              # Visit node stored in walker field
```

**Grammar:** `visit (COLON expression COLON)? expression (else_stmt | SEMI)`

The optional `COLON expression COLON` syntax (e.g., `visit :limit: [-->]`) may be used for limiting visits, but verify with current implementation.

### 14.4 The `report` Statement

Send data back without stopping:

```jac
walker DataCollector {
    can collect with DataNode entry {
        report here.value;  # Continues execution
        visit [-->];
    }
}

with entry {
    result = root spawn DataCollector();
    all_values = result.reports;  # List of reported values
}
```

### 14.5 The `disengage` Statement

Stop walker traversal immediately:

```jac
walker Searcher {
    has target: str;

    can search with Person entry {
        if here.name == self.target {
            report here;
            disengage;  # Stop traversal
        }
        visit [-->];
    }
}
```

### 14.6 Spawning Walkers

```jac
# Basic spawn
result = root spawn MyWalker();

# Spawn with parameters
result = root spawn MyWalker(param=value);

# Access results
print(result.returns);  # Return value
print(result.reports);  # All reported values

# Alternative syntax
result = MyWalker() spawn root;

# Multi-target spawn (concurrent)
results = MyWalker() spawn [node1, node2, node3];
```

### 14.7 Walker Inheritance

```jac
walker BaseVisitor {
    can log with entry {
        print(f"Visiting: {here}");
    }
}

walker DetailedVisitor(BaseVisitor) {
    override can log with entry {
        print(f"Detailed visit to: {type(here).__name__}");
    }
}
```

### 14.8 Special References

These keywords have special meaning in specific contexts:

| Reference | Valid Context | Description | See Also |
|-----------|---------------|-------------|----------|
| `self` | Any method/ability | Current instance (walker, node, object) | [Section 9](#9-object-oriented-programming) |
| `here` | Walker ability | Current node the walker is visiting | [Section 14.1](#141-walker-declaration) |
| `visitor` | Node ability | The walker that triggered this ability | [Section 12.2](#122-node-entryexit-abilities) |
| `root` | Anywhere | Root node of the current graph | [Section 15](#15-graph-construction) |
| `super` | Subclass method | Parent class reference | [Section 9.2](#92-inheritance) |
| `init` | Object body | Constructor method name | [Section 9.1](#91-objects-classes) |
| `postinit` | Object body | Post-constructor hook | [Section 5.2](#52-instance-variables-has) |
| `props` | JSX context | Component props reference | [Section 21](#21-client-side-development-jsx) |

**Usage examples:**

```jac
node SecureRoom {
    has required_level: int;

    # 'visitor' refers to the walker visiting this node
    # 'self' refers to this node instance
    can check with Inspector entry {
        if visitor.clearance >= self.required_level {
            print("Access granted to " + visitor.name);
        }
    }
}

walker Inspector {
    has clearance: int;
    has name: str;

    # 'here' refers to the current node being visited
    # 'self' refers to this walker instance
    can inspect with SecureRoom entry {
        print(f"{self.name} inspecting room at {here}");
        print(f"Room requires level {here.required_level}");
    }

    can start with `root entry {
        # 'root' is always the graph root
        print(f"Starting from root: {root}");
        visit [-->];
    }
}
```

**When each reference is valid:**

| Context | `self` | `here` | `visitor` | `root` |
|---------|--------|--------|-----------|--------|
| Walker ability | Walker instance | Current node | N/A | Graph root |
| Node ability | Node instance | N/A | Visiting walker | Graph root |
| Object method | Object instance | N/A | N/A | Graph root |
| Free code | N/A | N/A | N/A | Graph root |

---

## 15. Graph Construction

### 15.1 Creating Nodes

```jac
# Create and assign
alice = Person(name="Alice", age=30);
bob = Person(name="Bob", age=25);

# Inline creation in connection
root ++> Person(name="Charlie", age=35);
```

### 15.2 Creating Edges

```jac
# Untyped (generic edge)
alice ++> bob;

# Typed edge
alice +>: Friend(since=2020) :+> bob;

# Bidirectional typed
alice <+: Colleague(department="Engineering") :+> bob;
```

### 15.3 Chained Construction

```jac
# Build chains in one expression
root ++> a ++> b ++> c ++> d;

# With typed edges
root +>: Start :+> a +>: Next :+> b +>: Next :+> c +>: End :+> d;
```

### 15.4 Deleting Nodes and Edges

```jac
# Delete node
del node;

# Delete specific edge
alice del --> bob;

# Delete typed edge
alice del ->:Friend:-> bob;
```

### 15.5 Built-in Graph Functions

| Function | Description |
|----------|-------------|
| `jid(node)` | Get unique Jac ID of object |
| `jobj(node)` | Get Jac object wrapper |
| `grant(node, user)` | Grant access permission |
| `revoke(node, user)` | Revoke access permission |
| `allroots()` | Get all root references |
| `save(node)` | Persist node to storage |
| `commit()` | Commit pending changes |
| `printgraph(root)` | Print graph for debugging |

```jac
with entry {
    id = jid(alice);
    grant(secret_node, bob);
    save(alice);
    commit();
    printgraph(root);
}
```

---

## 16. Graph Traversal

### 16.1 Basic Traversal

Walker traversal is queue-based (BFS-like by default):

```jac
walker BFSWalker {
    can traverse with entry {
        print(f"Visiting: {here}");
        visit [-->];  # Queue all outgoing for later visits
    }
}
```

### 16.2 Filtered Traversal

```jac
walker FilteredWalker {
    can traverse with entry {
        # By node type
        visit [-->(`?Person)];

        # By attribute condition
        visit [--> (age > 25)];

        # By edge type
        visit [->:Friend:->];

        # Combined
        visit [->:Friend:since > 2020:->(`?Person)];
    }
}
```

### 16.3 Entry and Exit Events

```jac
node Room {
    can on_enter with Visitor entry {
        print("Entering room");
    }

    can on_exit with Visitor exit {
        print("Exiting room");
    }
}
```

---

## 17. Data Spatial Queries

### 17.1 Edge Reference Syntax

```jac
# Basic forms
[-->]                          # All outgoing nodes
[<--]                          # All incoming nodes
[<-->]                         # Both directions

# Typed forms
[->:EdgeType:->]              # Outgoing via EdgeType
[<-:EdgeType:<-]              # Incoming via EdgeType
[<-:EdgeType:->]              # Bidirectional via EdgeType

# With conditions
[->:Edge:attr > value:->]     # Filter by edge attribute
[->:Edge:a > 1, b < 5:->]     # Multiple conditions

# Node type filter
[-->(`?NodeType)]             # Filter result nodes by type

# Get edges vs nodes
[edge -->]                     # Get edge objects
[node -->]                     # Get node objects (explicit)
```

### 17.2 Attribute Filtering

```jac
# Filter by node attributes (after traversal)
adults = [-->](?age >= 18);
active_users = [-->](?status == "active", verified == True);

# Filter by edge attributes (during traversal)
recent_friends = [->:Friend:since > 2020:->];
strong_connections = [->:Link:weight > 0.8:->];
```

### 17.3 Complex Queries

```jac
# Chained traversal (multi-hop)
friends_of_friends = [here ->:Friend:-> ->:Friend:->];

# Mixed edge types
path = [here ->:Friend:-> ->:Colleague:->];

# Combined with filters
target = [->:Friend:since < 2020:->(`?Person)](?age > 30);
```

---

## 18. Typed Context Blocks

### 18.1 What are Typed Context Blocks?

Handle different types with specialized code paths. The syntax uses `->Type{code}` with no space between the arrow and type name:

```jac
walker AnimalVisitor {
    can visit with Animal entry {
        # Typed context block for Dog (subtype of Animal)
        ->Dog{print(f"{here.name} is a {here.breed} dog");}

        # Typed context block for Cat (subtype of Animal)
        ->Cat{print(f"{here.name} says meow");}

        # Default case (any other Animal type)
        ->_{print(f"{here.name} is some animal");}
    }
}
```

**Syntax Notes:**

- No space between `->` and the type name: `->Dog{` not `-> Dog {`
- Opening brace immediately follows the type
- Code typically on same line with closing brace
- Use `->_` for default/catch-all case

### 18.2 Tuple-Based Dispatch

```jac
walker Processor {
    can process with (Node1, Node2) entry {
        # Handle when visiting involves both types
    }
}
```

### 18.3 Context Blocks in Nodes

Nodes reacting to different walker types:

```jac
node DataNode {
    has value: int;

    can handle with Walker entry {
        ->Reader{print(f"Read value: {self.value}");}

        ->Writer{
            self.value = visitor.new_value;
            print(f"Updated to: {self.value}");
        }
    }
}
```

### 18.4 Complex Typed Context Example

From the reference examples, showing inheritance-based dispatch:

```jac
walker ShoppingCart {
    can process_item with Product entry {
        print(f"Processing {type(here).__name__}...");

        # Each subtype gets its own block
        ->Book{print(f"  -> Book: '{here.title}' by {here.author}");}
        ->Magazine{print(f"  -> Magazine: '{here.title}' Issue #{here.issue}");}
        ->Electronics{print(f"  -> Electronics: {here.name}, warranty {here.warranty_years}yr");}

        self.total += here.price;
        visit [-->];
    }
}
```

---

# Part IV: Full-Stack Development

## 19. Module System

### 19.1 Import Statements

```jac
# Simple import
import math;
import sys, json;

# Aliased import
import datetime as dt;

# From import
import from typing { List, Dict, Optional }
import from math { sqrt, pi, log as logarithm }

# Relative imports
import from . { sibling_module }
import from .. { parent_module }
import from .utils { helper_function }

# npm package imports (client-side)
import from react { useState, useEffect }
import from "@mui/material" { Button, TextField }
```

### 19.2 Include Statements

Include merges code directly (like C's `#include`):

```jac
include utils;  # Merges utils.jac into current scope
```

### 19.3 CSS and Asset Imports

```jac
import "./styles.css";
import "./global.css";
```

### 19.4 Export and Visibility

```jac
# Public by default
def helper -> int { return 42; }

# Explicitly public
def:pub api_function -> None { }

# Private to module
def:priv internal_helper -> None { }

# Public walker (becomes API endpoint with jac start)
walker:pub GetUsers { }

# Private walker
walker:priv InternalProcess { }
```

---

## 20. Server-Side Development

### 20.1 Server Code Blocks

```jac
sv {
    # Server-only code
    node User {
        has id: str;
        has email: str;
    }

    walker:pub CreateUser {
        has email: str;

        can create with `root entry {
            user = User(id=uuid4(), email=self.email);
            root ++> user;
            report user;
        }
    }
}
```

### 20.2 REST API with jac start

Public walkers automatically become REST endpoints:

```jac
walker:pub GetUsers {
    can get with `root entry {
        users = [-->(`?User)];
        report users;
    }
}

# Endpoint: POST /GetUsers
```

Start the server:

```bash
jac start main.jac --port 8000
```

### 20.3 Module Introspection

```jac
# List all walkers in module
walkers = get_module_walkers();

# List all functions
functions = get_module_functions();
```

### 20.4 Transport Layer

The transport layer handles HTTP request/response:

```jac
# Custom transport handling
import from jaclang.transport { BaseTransport, HTTPTransport }
```

---

## 21. Client-Side Development (JSX)

### 21.1 Client Code Blocks

```jac
cl {
    import from react { useState, useEffect }

    def:pub App -> any {
        has count: int = 0;

        return (
            <div>
                <h1>Counter: {count}</h1>
                <button onclick={lambda: self.count += 1}>
                    Increment
                </button>
            </div>
        );
    }
}
```

### 21.2 State Management with `has`

In client components, `has` creates reactive state:

```jac
def:pub TodoApp -> any {
    has todos: list = [];
    has input_text: str = "";

    def add_todo -> None {
        if self.input_text {
            self.todos.append({"text": self.input_text, "done": False});
            self.input_text = "";
        }
    }

    return (
        <div>
            <input
                value={self.input_text}
                oninput={lambda e: self.input_text = e.target.value}
            />
            <button onclick={self.add_todo}>Add</button>
            <ul>
                {[<li>{todo["text"]}</li> for todo in self.todos]}
            </ul>
        </div>
    );
}
```

### 21.3 Effects and Lifecycle

```jac
def:pub DataLoader -> any {
    has data: list = [];
    has loading: bool = True;

    useEffect(lambda: {
        fetch_data();
    }, []);

    async def fetch_data -> None {
        response = await fetch("/api/data");
        self.data = await response.json();
        self.loading = False;
    }

    if self.loading {
        return <div>Loading...</div>;
    }

    return <div>{[<p>{item}</p> for item in self.data]}</div>;
}
```

### 21.4 JSX Syntax

```jac
# Elements
<div>content</div>
<Component prop="value" />

# Attributes
<input type="text" value={variable} />
<button onclick={handler}>Click</button>

# Conditionals
{condition && <div>Shown if true</div>}
{condition ? <Yes /> : <No />}

# Lists
{[<Item key={i} data={item} /> for (i, item) in enumerate(items)]}

# Fragments
<>
    <Child1 />
    <Child2 />
</>
```

### 21.5 Styling Patterns

```jac
import from "@jac-client/utils" { cn }

# Inline styles
<div style={{"color": "red", "fontSize": "16px"}}>Styled</div>

# Tailwind classes
<div className="p-4 bg-blue-500 text-white">Tailwind</div>

# Conditional classes with cn()
className = cn(
    "base-class",
    condition && "active",
    {"error": hasError, "success": isSuccess}
);
<div className={className}>Dynamic</div>
```

### 21.6 Routing

```jac
import from react-router-dom { BrowserRouter, Routes, Route, Link }

def:pub App -> any {
    return (
        <BrowserRouter>
            <nav>
                <Link to="/">Home</Link>
                <Link to="/about">About</Link>
            </nav>
            <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/about" element={<About />} />
            </Routes>
        </BrowserRouter>
    );
}
```

### 21.7 Client Bundle System

The client is bundled using Vite:

```toml
# jac.toml
[plugins.client]
port = 5173
typescript = false
```

---

## 22. Server-Client Communication

### 22.1 Calling Server Walkers

From client code, call server walkers:

```jac
cl {
    async def add_todo(text: str) -> None {
        result = root spawn AddTodo(title=text);
        new_todo = result.reports[0];
        self.todos.append(new_todo);
    }
}
```

### 22.2 jacSpawn() Function

Client-side walker invocation:

```jac
cl {
    import from "@jac-client/utils" { jacSpawn }

    async def fetch_users -> None {
        result = await jacSpawn("GetUsers", {});
        self.users = result.reports;
    }
}
```

### 22.3 Starting Full-Stack Server

```bash
# Development with hot reload
jac start main.jac --port 8000 --watch

# Production
jac start main.jac --port 8000
```

---

## 23. Authentication & Users

### 23.1 Built-in Auth Functions

```jac
import from "@jac-client/utils" {
    jacLogin,
    jacSignup,
    jacLogout,
    jacIsLoggedIn
}

cl {
    async def handle_login -> None {
        success = await jacLogin(self.email, self.password);
        if success {
            self.logged_in = True;
        }
    }

    async def handle_signup -> None {
        success = await jacSignup(self.email, self.password);
        if success {
            await self.handle_login();
        }
    }

    def handle_logout -> None {
        jacLogout();
        self.logged_in = False;
    }
}
```

### 23.2 User Management

| Operation | Function/Endpoint | Description |
|-----------|-------------------|-------------|
| Register | `jacSignup()` | Create new user account |
| Login | `jacLogin()` | Authenticate and get JWT |
| Logout | `jacLogout()` | Clear client token |
| Update Username | API endpoint | Change username |
| Update Password | API endpoint | Change password |
| Guest Access | `__guest__` account | Anonymous user support |

### 23.3 Per-User Graph Isolation

Each authenticated user gets an isolated root node:

```jac
walker:pub GetMyData {
    can get with `root entry {
        # 'root' is user-specific
        my_data = [-->(`?MyData)];
        report my_data;
    }
}
```

### 23.4 Single Sign-On (SSO)

Configure in `jac.toml`:

```toml
[plugins.scale.sso.google]
client_id = "your-google-client-id"
client_secret = "your-google-client-secret"
```

**SSO Endpoints:**

| Endpoint | Description |
|----------|-------------|
| `/sso/{platform}/login` | Initiate SSO login |
| `/sso/{platform}/register` | Initiate SSO registration |
| `/sso/{platform}/login/callback` | OAuth callback |

---

## 24. Memory & Persistence

### 24.1 Memory Hierarchy

| Tier | Type | Implementation |
|------|------|----------------|
| L1 | Volatile | VolatileMemory (in-process) |
| L2 | Cache | LocalCacheMemory (TTL-based) |
| L3 | Persistent | SqliteMemory (default) |

### 24.2 TieredMemory

Automatic read-through caching and write-through persistence:

```jac
# Objects are automatically persisted
node User {
    has name: str;
}

# Manual save
save(user_node);
commit();
```

### 24.3 ExecutionContext

Manages runtime context:

- `system_root` -- System-level root node
- `user_root` -- User-specific root node
- `entry_node` -- Current entry point
- `Memory` -- Storage backend

### 24.4 Anchor Management

Anchors provide persistent object references across sessions.

---

## 25. Development Tools

### 25.1 Hot Module Replacement (HMR)

```bash
# Enable with --watch flag
jac start main.jac --watch
```

Changes to `.jac` files automatically reload without restart.

### 25.2 File System Watcher

The JacFileWatcher monitors for changes with debouncing to prevent rapid reloads.

### 25.3 Debug Mode

```bash
jac debug main.jac
```

Provides:

- Step-through execution
- Variable inspection
- Breakpoints
- Graph visualization

---

# Part V: AI Integration

> **Prerequisites:**
>
> - [The `by` Operator](#69-the-by-operator) - Basic syntax
> - [Function Declaration](#81-function-declaration) - Function signatures
>
> **Required Plugin:** `pip install byllm`

## 26. Meaning Typed Programming

### 26.1 The Concept

Meaning Typed Programming treats semantic intent as a first-class type. You declare *what* you want, and AI provides *how*:

```jac
# The function signature IS the specification
def classify_sentiment(text: str) -> str by llm;

# Usage - the LLM infers behavior from the name and types
result = classify_sentiment("I love this product!");
# result = "positive"
```

### 26.2 Implicit vs Explicit Semantics

**Implicit** -- derived from function/parameter names:

```jac
def translate_to_spanish(text: str) -> str by llm;
```

**Explicit** -- using `sem` for detailed descriptions:

```jac
sem classify = """
Analyze the emotional tone of the input text.
Return exactly one of: 'positive', 'negative', 'neutral'.
Consider context and sarcasm.
""";

def classify(text: str) -> str by llm;
```

---

## 27. Semantic Strings

### 27.1 The `sem` Keyword

```jac
sem classify_sentiment = """
Analyze the emotional tone of the text.
Return 'positive', 'negative', or 'neutral'.
Consider nuance, sarcasm, and context.
""";

def classify_sentiment(text: str) -> str by llm;
```

### 27.2 Parameter Semantics

```jac
sem analyze_code.code = "The source code to analyze";
sem analyze_code.language = "Programming language (python, javascript, etc.)";
sem analyze_code.return = "A structured analysis with issues and suggestions";

def analyze_code(code: str, language: str) -> dict by llm;
```

### 27.3 Complex Semantic Types

```jac
obj CodeAnalysis {
    has issues: list[str];
    has suggestions: list[str];
    has complexity_score: int;
    has summary: str;
}

sem analyze.return = """
Return a CodeAnalysis object with:
- issues: List of problems found
- suggestions: Improvement recommendations
- complexity_score: 1-10 complexity rating
- summary: One paragraph overview
""";

def analyze(code: str) -> CodeAnalysis by llm;
```

---

## 28. The `by` Operator and LLM Delegation

### 28.1 Basic Usage

```jac
# Inline expression
response = "Explain quantum computing in simple terms" by llm;

# Function delegation
def translate(text: str, target_lang: str) -> str by llm;

def summarize(article: str) -> str by llm;

def extract_entities(text: str) -> list[str] by llm;
```

### 28.2 Chained Transformations

```jac
result = text
    |> (lambda t: str -> str: t by llm("Correct grammar"))
    |> (lambda t: str -> str: t by llm("Simplify language"))
    |> (lambda t: str -> str: t by llm("Translate to Spanish"));
```

### 28.3 Model Configuration

```jac
def summarize(text: str) -> str by llm(
    model_name="gpt-4",
    temperature=0.7,
    max_tokens=2000
);

def creative_story(prompt: str) -> str by llm(
    model_name="claude-3-opus",
    temperature=1.0
);
```

**Configuration Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `model_name` | str | LLM provider/model identifier |
| `temperature` | float | Creativity (0.0-2.0) |
| `max_tokens` | int | Maximum response tokens |
| `stream` | bool | Enable streaming output |
| `tools` | list | Functions for tool calling |
| `method` | str | ReAct, Reason, Chain-of-Thoughts |
| `context` | list[str] | Additional system instructions |

### 28.4 Tool Calling (ReAct)

```jac
def get_weather(city: str) -> str {
    # Actual implementation
    return fetch_weather_api(city);
}

def search_web(query: str) -> list[str] {
    # Actual implementation
    return web_search_api(query);
}

def answer_question(question: str) -> str by llm(
    tools=[get_weather, search_web],
    method="ReAct"
);

# The LLM can now call these tools to answer questions
result = answer_question("What's the weather in Paris?");
```

### 28.5 Streaming Responses

```jac
def stream_story(prompt: str) -> str by llm(stream=True);

# Returns generator
for chunk in stream_story("Tell me a story") {
    print(chunk, end="");
}
```

### 28.6 Multimodal Input

```jac
import from byllm { Image, Video }

def describe_image(image: Image) -> str by llm;
def analyze_video(video: Video) -> str by llm;

# Usage
description = describe_image(Image("photo.jpg"));
description = describe_image(Image("https://example.com/image.png"));
```

### 28.7 Reasoning Methods

| Method | Description |
|--------|-------------|
| `Chain-of-Thoughts` | Step-by-step reasoning before answer |
| `Reason` | Explicit reasoning output |
| `ReAct` | Reasoning + Acting with tools |

```jac
def solve_math(problem: str) -> str by llm(method="Chain-of-Thoughts");
def complex_task(query: str) -> str by llm(method="ReAct", tools=[...]);
```

### 28.8 Testing with MockLLM

```jac
def classify(text: str) -> str by llm(
    model_name="mockllm",
    config={"outputs": ["positive", "negative", "neutral"]}
);

test classification_test {
    result = classify("Great product!");
    assert result in ["positive", "negative", "neutral"];
}
```

### 28.9 Configuration via jac.toml

```toml
[plugins.byllm.model]
default = "gpt-4"

[plugins.byllm.call_params]
temperature = 0.7
max_tokens = 1000

[plugins.byllm.litellm]
api_base = "http://localhost:4000"
```

### 28.10 Python Library Mode

Use `by` in pure Python with decorators:

```python
from byllm import by, Model

@by(Model("gpt-4"))
def summarize(text: str) -> str:
    """Summarize the given text."""
    pass

result = summarize("Long article text...")
```

---

## 29. Agentic AI Patterns

### 29.1 AI Agents as Walkers

```jac
walker AIAgent {
    has goal: str;
    has memory: list = [];

    can decide with Node entry {
        context = f"Goal: {self.goal}\nCurrent: {here}\nMemory: {self.memory}";
        decision = context by llm("Decide next action");
        self.memory.append({"location": here, "decision": decision});
        # Act on decision
        visit [-->];
    }
}
```

### 29.2 Tool-Using Agents

```jac
walker ResearchAgent {
    has query: str;

    def search(query: str) -> list[str] {
        return web_search(query);
    }

    def read_page(url: str) -> str {
        return fetch_content(url);
    }

    can research with `root entry by llm(
        tools=[self.search, self.read_page],
        method="ReAct"
    );
}
```

### 29.3 Multi-Agent Systems

```jac
walker Coordinator {
    can coordinate with `root entry {
        # Spawn specialized agents
        research = root spawn Researcher(topic="AI");
        writer = root spawn Writer(style="technical");
        reviewer = root spawn Reviewer();

        # Combine results
        report {
            "research": research.reports,
            "draft": writer.reports,
            "review": reviewer.reports
        };
    }
}
```

---

# Part VI: Concurrency

## 30. Async/Await

### 30.1 Async Functions

```jac
async def fetch_data(url: str) -> dict {
    response = await http_get(url);
    return await response.json();
}

async def process_multiple(urls: list[str]) -> list[dict] {
    results = [];
    for url in urls {
        data = await fetch_data(url);
        results.append(data);
    }
    return results;
}
```

### 30.2 Async Walkers

```jac
async walker DataFetcher {
    has url: str;

    async can fetch with `root entry {
        data = await http_get(self.url);
        report data;
    }
}
```

### 30.3 Async For Loops

```jac
async def process_stream(stream: AsyncIterator) -> None {
    async for item in stream {
        print(item);
    }
}
```

---

## 31. Concurrent Expressions

### 31.1 flow Keyword

Launch computation without waiting:

```jac
future = flow expensive_computation();

# Do other work while computation runs
other_result = do_something_else();

# Wait for result when needed
result = wait future;
```

### 31.2 Parallel Operations

```jac
# Launch multiple operations in parallel
future1 = flow fetch_users();
future2 = flow fetch_orders();
future3 = flow fetch_inventory();

# Continue with other work
process_local_data();

# Collect all results
users = wait future1;
orders = wait future2;
inventory = wait future3;
```

### 31.3 flow vs async

| Feature | async/await | flow/wait |
|---------|-------------|-----------|
| Model | Event loop (cooperative) | Thread pool (parallel) |
| Best for | I/O-bound, many concurrent | CPU-bound, few concurrent |
| Blocking | Non-blocking | Can block threads |

---

# Part VII: Advanced Features

## 32. Error Handling

### 32.1 Try/Except/Finally

```jac
try {
    result = risky_operation();
} except ValueError as e {
    print(f"Value error: {e}");
} except KeyError {
    print("Key not found");
} except Exception as e {
    print(f"Unexpected: {e}");
} finally {
    cleanup();
}
```

### 32.2 Raising Exceptions

```jac
def validate(value: int) -> None {
    if value < 0 {
        raise ValueError("Value must be non-negative");
    }
}

def process(data: dict) -> None {
    try {
        inner_process(data);
    } except KeyError as e {
        raise ValueError("Invalid data") from e;
    }
}
```

### 32.3 Assertions

```jac
assert condition;
assert value > 0, "Value must be positive";
assert data is not None, f"Data was None for id {id}";
```

---

## 33. Testing

### 33.1 Test Blocks

```jac
test addition_works {
    result = add(2, 3);
    assert result == 5;
}

test string_operations {
    s = "hello";
    assert len(s) == 5;
    assert "ell" in s;
    assert s.upper() == "HELLO";
}
```

### 33.2 Testing Walkers

```jac
test walker_collects_data {
    # Setup graph
    root ++> DataNode(value=1);
    root ++> DataNode(value=2);
    root ++> DataNode(value=3);

    # Run walker
    result = root spawn Collector();

    # Verify
    assert len(result.reports) == 3;
    assert sum(result.reports) == 6;
}
```

### 33.3 Float Comparison

```jac
test float_comparison {
    result = 0.1 + 0.2;
    assert almostEqual(result, 0.3, places=10);
}
```

### 33.4 JacTestClient

For API testing without starting a server:

```jac
import from jaclang.testing { JacTestClient }

test api_endpoints {
    client = JacTestClient.from_file("main.jac");

    # Register and login
    client.register_user("test@example.com", "password123");
    client.login("test@example.com", "password123");

    # Test endpoint
    response = client.post("/CreateItem", {"name": "Test"});
    assert response.status_code == 200;
    assert response.json()["name"] == "Test";
}
```

### 33.5 Running Tests

```bash
# Run all tests
jac test

# Run specific test
jac test --test-name test_addition

# Stop on first failure
jac test --xit

# Verbose output
jac test --verbose
```

---

## 34. Filter and Assign Comprehensions

### 34.1 Standard Comprehensions

```jac
# List comprehension
squares = [x ** 2 for x in range(10)];

# With condition
evens = [x for x in range(20) if x % 2 == 0];

# Dict comprehension
squared_dict = {x: x ** 2 for x in range(5)};

# Set comprehension
unique_lengths = {len(s) for s in strings};

# Generator expression
gen = (x ** 2 for x in range(1000000));
```

### 34.2 Filter Comprehension Syntax

Filter collections with `?condition`:

```jac
# Filter people by age
adults = people(?age >= 18);

# Multiple conditions
qualified = employees(?salary > 50000, experience >= 5);

# On graph traversal results
friends = [-->](?status == "active");
```

### 34.3 Assign Comprehension Syntax

Modify all items with `=attr=value`:

```jac
# Set attribute on all items
people(=verified=True);

# Chained: filter then assign
people(?age >= 18)(=can_vote=True);

# Multiple assignments
items(=status="processed", processed_at=now());
```

---

## 35. Pipe Operators

### 35.1 Forward Pipe

```jac
# Traditional
result = output(filter(transform(input)));

# With pipes
result = input |> transform |> filter |> output;

# More readable data pipeline
cleaned = raw_data
    |> remove_nulls
    |> normalize
    |> validate
    |> transform;
```

### 35.2 Backward Pipe

```jac
# Right to left
result = output <| filter <| transform <| input;
```

### 35.3 Atomic Pipes (Graph Operations)

```jac
# Depth-first traversal
node spawn :> DepthFirstWalker;

# Breadth-first traversal
node spawn |> BreadthFirstWalker;
```

---

# Part VIII: Ecosystem

## 36. CLI Reference

### 36.1 Execution Commands

| Command | Description |
|---------|-------------|
| `jac run <file>` | Execute Jac program |
| `jac enter <file> <entry>` | Run named entry point |
| `jac start [file]` | Start web server |
| `jac debug <file>` | Run in debug mode |

### 36.2 Analysis Commands

| Command | Description |
|---------|-------------|
| `jac check` | Type check code |
| `jac format` | Format source files |
| `jac test` | Run test suite |

### 36.3 Transform Commands

| Command | Description |
|---------|-------------|
| `jac py2jac <file>` | Convert Python to Jac |
| `jac jac2py <file>` | Convert Jac to Python |
| `jac js <file>` | Compile to JavaScript |

### 36.4 Project Commands

| Command | Description |
|---------|-------------|
| `jac create` | Create new project |
| `jac install` | Install dependencies |
| `jac add <pkg>` | Add dependency |
| `jac remove <pkg>` | Remove dependency |
| `jac clean` | Clean build artifacts |
| `jac script <name>` | Run project script |

### 36.5 Tool Commands

| Command | Description |
|---------|-------------|
| `jac dot <file>` | Generate graph visualization |
| `jac lsp` | Start language server |
| `jac config` | Manage configuration |
| `jac plugins` | Manage plugins |

---

## 37. Plugin System

### 37.1 Available Plugins

| Plugin | Package | Description |
|--------|---------|-------------|
| byllm | `pip install byllm` | LLM integration |
| jac-client | `pip install jac-client` | Full-stack web development |
| jac-scale | `pip install jac-scale` | Production deployment |
| jac-super | `pip install jac-super` | Enhanced console output |

### 37.2 Managing Plugins

```bash
# List plugins
jac plugins list

# Enable plugin
jac plugins enable byllm

# Disable plugin
jac plugins disable byllm

# Plugin info
jac plugins info byllm
```

### 37.3 Plugin Configuration

In `jac.toml`:

```toml
[plugins.byllm]
enabled = true
default_model = "gpt-4"

[plugins.client]
port = 5173
typescript = false

[plugins.scale]
replicas = 3
```

---

## 38. Project Configuration

### 38.1 jac.toml Structure

```toml
[project]
name = "my-app"
version = "1.0.0"
description = "My Jac application"
entry = "main.jac"

[dependencies]
numpy = "^1.24.0"
pandas = "^2.0.0"

[dependencies.dev]
pytest = "^7.0.0"

[dependencies.npm]
react = "^18.0.0"
"@mui/material" = "^5.0.0"

[plugins.byllm]
default_model = "gpt-4"

[plugins.client]
port = 5173

[scripts]
dev = "jac start main.jac --watch"
test = "jac test"
build = "jac build"

[environments.production]
OPENAI_API_KEY = "${OPENAI_API_KEY}"
```

### 38.2 Running Scripts

```bash
jac script dev
jac script test
jac script build
```

### 38.3 Environment Profiles

```bash
# Set environment
export JAC_ENV=production

# Run with specific environment
JAC_ENV=staging jac start main.jac
```

### 38.4 Environment Variables

**Server-side:**

| Variable | Description |
|----------|-------------|
| `OPENAI_API_KEY` | OpenAI API key |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `REDIS_HOST`, `REDIS_PORT` | Redis connection |
| `MONGO_URI`, `MONGO_DB` | MongoDB connection |
| `JWT_SECRET` | JWT signing secret |

**Client-side (Vite):**

Variables prefixed with `VITE_` are exposed to client:

```toml
# .env
VITE_API_URL=https://api.example.com
```

```jac
cl {
    api_url = import.meta.env.VITE_API_URL;
}
```

---

## 39. Python Interoperability

### 39.1 Using Python Libraries

```jac
import numpy as np;
import pandas as pd;
import from sklearn.linear_model { LinearRegression }

with entry {
    # NumPy
    arr = np.array([1, 2, 3, 4, 5]);
    print(f"Mean: {np.mean(arr)}");

    # Pandas
    df = pd.DataFrame({"a": [1, 2, 3], "b": [4, 5, 6]});
    print(df.describe());

    # Scikit-learn
    model = LinearRegression();
}
```

### 39.2 Inline Python Blocks

```jac
::py::
import numpy as np

def complex_calculation(data):
    """Pure Python for performance-critical code."""
    arr = np.array(data)
    return arr.mean(), arr.std()
::py::

with entry {
    mean, std = complex_calculation([1, 2, 3, 4, 5]);
    print(f"Mean: {mean}, Std: {std}");
}
```

**When to use inline Python:**

- Complex Python-only APIs
- Performance-critical numerical code
- Legacy code integration

**When NOT to use:**

- Simple imports (use `import` instead)
- New code that could use Jac features

### 39.3 Type Compatibility

| Jac Type | Python Type |
|----------|-------------|
| `int` | `int` |
| `float` | `float` |
| `str` | `str` |
| `bool` | `bool` |
| `list` | `list` |
| `dict` | `dict` |
| `tuple` | `tuple` |
| `set` | `set` |
| `None` | `None` |

### 39.4 Using Jac from Python

```python
from jaclang import jac_import

# Import Jac module
my_module = jac_import("my_module.jac")

# Use exported functions/classes
result = my_module.my_function(arg1, arg2)
instance = my_module.MyClass()
```

---

## 40. JavaScript/TypeScript Interoperability

### 40.1 npm Packages

```jac
cl {
    import from react { useState, useEffect, useCallback }
    import from "@tanstack/react-query" { useQuery, useMutation }
    import from lodash { debounce, throttle }
    import from axios { default as axios }
}
```

### 40.2 TypeScript Support

Enable in `jac.toml`:

```toml
[plugins.client]
typescript = true
```

### 40.3 Browser APIs

```jac
cl {
    # Window
    width = window.innerWidth;

    # LocalStorage
    window.localStorage.setItem("key", "value");
    value = window.localStorage.getItem("key");

    # Document
    element = document.getElementById("my-id");

    # Fetch
    async def load_data -> None {
        response = await fetch("/api/data");
        data = await response.json();
    }
}
```

---

# Part IX: Deployment and Scaling

## 41. jac-scale Plugin

### 41.1 Overview

jac-scale provides production-ready deployment with:

- FastAPI backend
- Redis caching
- MongoDB persistence
- Kubernetes orchestration

### 41.2 Installation

```bash
pip install jac-scale
jac plugins enable scale
```

### 41.3 Basic Deployment

```bash
# Development
jac start main.jac --port 8000

# Production with scaling
jac start --scale
```

### 41.4 Environment Configuration

| Variable | Description |
|----------|-------------|
| `REDIS_HOST` | Redis server host |
| `REDIS_PORT` | Redis server port |
| `MONGO_URI` | MongoDB connection URI |
| `MONGO_DB` | MongoDB database name |
| `K8S_NAMESPACE` | Kubernetes namespace |
| `K8S_REPLICAS` | Number of replicas |

### 41.5 CORS Configuration

```toml
[plugins.scale.cors]
allow_origins = ["https://example.com"]
allow_methods = ["GET", "POST", "PUT", "DELETE"]
allow_headers = ["*"]
```

---

## 42. Kubernetes Deployment

### 42.1 Auto-Scaling

```bash
jac start --scale
```

Automatically provisions:

- Deployment with specified replicas
- Service for load balancing
- ConfigMap for configuration
- StatefulSets for Redis/MongoDB

### 42.2 Generated Resources

```yaml
# Example generated deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jac-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: jac-app
```

### 42.3 Health Checks

Built-in endpoints:

- `/health` -- Liveness probe
- `/ready` -- Readiness probe

---

## 43. Production Architecture

### 43.1 Multi-Layer Memory

```
┌─────────────────┐
│   Application   │
├─────────────────┤
│  L1: Volatile   │  (in-memory)
├─────────────────┤
│  L2: Redis      │  (cache)
├─────────────────┤
│  L3: MongoDB    │  (persistent)
└─────────────────┘
```

### 43.2 FastAPI Integration

Public walkers become OpenAPI endpoints:

```bash
# Swagger docs available at
http://localhost:8000/docs
```

### 43.3 Service Discovery

Kubernetes service mesh integration for:

- Automatic load balancing
- Service-to-service communication
- Health monitoring

---

# Appendices

## Appendix A: Complete Keyword Reference

| Keyword | Category | Description |
|---------|----------|-------------|
| `abs` | Modifier | Abstract method/class (note: NOT `abstract`) |
| `and` | Operator | Logical AND (also `&&`) |
| `as` | Import | Alias |
| `assert` | Statement | Assertion |
| `async` | Modifier | Async function/walker |
| `await` | Expression | Await async |
| `break` | Control | Exit loop |
| `by` | Operator | Delegation operator (used by byllm for LLM) |
| `can` | Declaration | Ability (method on archetypes) |
| `case` | Control | Match/switch case |
| `cl` | Block | Client-side code block |
| `class` | Archetype | Python-style class definition |
| `continue` | Control | Next iteration |
| `def` | Declaration | Function |
| `default` | Control | Switch default case |
| `del` | Statement | Delete node/edge |
| `disengage` | OSP | Stop walker traversal |
| `edge` | Archetype | Edge type |
| `elif` | Control | Else if |
| `else` | Control | Else branch |
| `entry` | OSP | Entry event trigger |
| `enum` | Archetype | Enumeration |
| `except` | Control | Exception handler |
| `exit` | OSP | Exit event trigger |
| `finally` | Control | Finally block |
| `flow` | Concurrency | Start concurrent task |
| `for` | Control | For loop |
| `from` | Import | Import from |
| `glob` | Declaration | Global variable |
| `global` | Scope | Access global scope |
| `has` | Declaration | Instance field |
| `here` | OSP | Current node (in walker) |
| `if` | Control | Conditional |
| `impl` | Declaration | Implementation block |
| `import` | Module | Import |
| `in` | Operator | Membership |
| `include` | Module | Include/merge code |
| `init` | Method | Constructor |
| `is` | Operator | Identity |
| `lambda` | Expression | Anonymous function |
| `match` | Control | Pattern match |
| `node` | Archetype | Node type |
| `nonlocal` | Scope | Access nonlocal scope |
| `not` | Operator | Logical NOT |
| `obj` | Archetype | Object/class |
| `or` | Operator | Logical OR (also `\|\|`) |
| `override` | Modifier | Override method |
| `postinit` | Method | Post-constructor |
| `priv` | Access | Private |
| `props` | Reference | JSX props (client-side) |
| `protect` | Access | Protected |
| `pub` | Access | Public |
| `raise` | Statement | Raise exception |
| `report` | OSP | Report value from walker |
| `return` | Statement | Return value |
| `root` | OSP | Root node reference |
| `self` | Reference | Current instance |
| `sem` | Declaration | Semantic string |
| `skip` | Control | Skip (nested context) |
| `spawn` | OSP | Spawn walker |
| `static` | Modifier | Static member |
| `super` | Reference | Parent class |
| `sv` | Block | Server-side code block |
| `switch` | Control | Switch statement |
| `test` | Declaration | Test block |
| `to` | Control | For loop upper bound |
| `try` | Control | Try block |
| `visitor` | OSP | Visiting walker (in node) |
| `wait` | Concurrency | Wait for concurrent result |
| `walker` | Archetype | Walker type |
| `while` | Control | While loop |
| `with` | Statement | Context manager / entry block |
| `yield` | Statement | Generator yield |

**Notes:**

- The abstract keyword is `abs`, not `abstract`
- Logical operators have both word and symbol forms: `and`/`&&`, `or`/`||`
- `cl` and `sv` are block keywords for client/server code separation

---

## Appendix B: Operator Quick Reference

### Arithmetic

| Operator | Description |
|----------|-------------|
| `+` | Addition |
| `-` | Subtraction |
| `*` | Multiplication |
| `/` | Division |
| `//` | Floor division |
| `%` | Modulo |
| `**` | Power |

### Comparison

| Operator | Description |
|----------|-------------|
| `==` | Equal |
| `!=` | Not equal |
| `<` | Less than |
| `>` | Greater than |
| `<=` | Less or equal |
| `>=` | Greater or equal |

### Logical

| Operator | Description |
|----------|-------------|
| `and`, `&&` | Logical AND |
| `or`, `\|\|` | Logical OR |
| `not` | Logical NOT |

### Graph (OSP)

| Operator | Description |
|----------|-------------|
| `++>` | Forward connect |
| `<++` | Backward connect |
| `<++>` | Bidirectional connect |
| `+>:T:+>` | Typed forward |
| `<+:T:<+` | Typed backward |
| `<+:T:+>` | Typed bidirectional |
| `[-->]` | Outgoing edges |
| `[<--]` | Incoming edges |
| `[<-->]` | All edges |

### Pipe

| Operator | Description |
|----------|-------------|
| `\|>` | Forward pipe |
| `<\|` | Backward pipe |
| `:>` | Atomic forward |
| `<:` | Atomic backward |

---

## Appendix C: Grammar Summary

```
module        : element*
element       : import | archetype | ability | impl | test | entry

archetype     : (obj | node | edge | walker | enum) NAME inheritance? body
inheritance   : "(" NAME ("," NAME)* ")"
body          : "{" member* "}"

member        : has_stmt | ability | impl
has_stmt      : "has" (modifier)? NAME ":" type ("=" expr)? ";"
ability       : "can" NAME params? ("->" type)? (body | ";")

import        : "import" (module | "from" module "{" names "}")
entry         : "with" "entry" (":" NAME)? body
test          : "test" NAME body
impl          : "impl" NAME "." NAME params body

expr          : ... (standard expressions plus graph operators)
```

---

## Appendix D: Common Gotchas

### 1. Semicolons Required

```jac
# Wrong
x = 5
print(x)

# Correct
x = 5;
print(x);
```

### 2. Braces Required for Blocks

```jac
# Wrong (Python style)
if condition:
    do_something()

# Correct
if condition {
    do_something();
}
```

### 3. Type Annotations Required

```jac
# Wrong
def add(a, b) {
    return a + b;
}

# Correct
def add(a: int, b: int) -> int {
    return a + b;
}
```

### 4. `has` vs Local Variables

```jac
obj Example {
    has field: int = 0;  # Instance variable (with 'has')

    can method -> None {
        local = 5;  # Local variable (no 'has')
        self.field = local;
    }
}
```

### 5. Walker `visit` is Queued

```jac
walker Example {
    can traverse with Node entry {
        print("Visiting");
        visit [-->];  # Nodes queued, visited AFTER this method
        print("This prints before visiting children");
    }
}
```

### 6. `report` vs `return`

```jac
walker Example {
    can collect with Node entry {
        report here.value;  # Continues execution
        visit [-->];        # Still runs

        return here.value;  # Would stop here
    }
}
```

### 7. Global Modification Requires Declaration

```jac
glob counter: int = 0;

def increment -> None {
    global counter;  # Required!
    counter += 1;
}
```

---

## Appendix E: Migration from Python

### Class to Object

**Python:**

```python
class Person:
    def __init__(self, name: str, age: int):
        self.name = name
        self.age = age

    def greet(self) -> str:
        return f"Hi, I'm {self.name}"
```

**Jac:**

```jac
obj Person {
    has name: str;
    has age: int;

    can greet -> str {
        return f"Hi, I'm {self.name}";
    }
}
```

### Function

**Python:**

```python
def add(a: int, b: int) -> int:
    return a + b
```

**Jac:**

```jac
def add(a: int, b: int) -> int {
    return a + b;
}
```

### Control Flow

**Python:**

```python
if x > 0:
    print("positive")
elif x < 0:
    print("negative")
else:
    print("zero")
```

**Jac:**

```jac
if x > 0 {
    print("positive");
} elif x < 0 {
    print("negative");
} else {
    print("zero");
}
```

---

## Appendix F: LLM Provider Reference

| Provider | Model Names | Environment Variable |
|----------|-------------|---------------------|
| OpenAI | `gpt-4`, `gpt-4o`, `gpt-3.5-turbo` | `OPENAI_API_KEY` |
| Anthropic | `claude-3-opus`, `claude-3-sonnet` | `ANTHROPIC_API_KEY` |
| Google | `gemini-pro`, `gemini-ultra` | `GOOGLE_API_KEY` |
| Azure | `azure/gpt-4` | Azure config |
| Ollama | `ollama/llama2`, `ollama/mistral` | Local (no key) |

**Model Name Format:**

```
provider/model-name

Examples:
- gpt-4 (OpenAI, default provider)
- anthropic/claude-3-opus
- azure/gpt-4
- ollama/llama2
```

---

## Document Information

**Jac Language Reference**

Version: 3.1
Last Updated: January 2026

**Validation Status:** Validated against `jac/jaclang/pycore/jac.lark` and `jac/examples/reference/`

**Resources:**

- Website: [https://jaseci.org](https://jaseci.org)
- Documentation: [https://jac-lang.org](https://jac-lang.org)
- GitHub: [https://github.com/Jaseci-Labs/jaseci](https://github.com/Jaseci-Labs/jaseci)
- Discord: [https://discord.gg/6j3QNdtcN6](https://discord.gg/6j3QNdtcN6)
