# Part I: Foundation

**In this part:**

- [Introduction](#introduction) - What is Jac, principles, comparison to Python
- [Getting Started](#getting-started) - Installation, first program, CLI basics
- [Language Basics](#language-basics) - Syntax, comments, code structure
- [Types and Values](#types-and-values) - Type system, generics, literals
- [Variables and Scope](#variables-and-scope) - Local, instance, global variables
- [Operators](#operators) - Arithmetic, comparison, logical, graph operators
- [Control Flow](#control-flow) - Conditionals, loops, pattern matching

---

## Introduction

### 1 What is Jac?

Jac is an AI-native full-stack programming language that supersets Python and JavaScript with native compilation support. It introduces Object-Spatial Programming (OSP) and novel constructs for AI-integrated programming (such as `by llm()`), providing a unified language for backend, frontend, and AI development with full access to the PyPI and npm ecosystems.

```jac
with entry {
    print("Hello, Jac!");
}
```

### 2 The Six Principles

| Principle | Description |
|-----------|-------------|
| **AI-Native** | LLMs as first-class citizens through Meaning Typed Programming |
| **Full-Stack** | Backend and frontend in one unified language |
| **Superset** | Full access to PyPI and npm ecosystems |
| **Object-Spatial** | Graph-based domain modeling with mobile walkers |
| **Cloud-Native** | One-command deployment with automatic scaling |
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
# Full installation with all plugins
pip install jaseci

# Minimal installation
pip install jaclang

# Individual plugins
pip install byllm        # LLM integration
pip install jac-client   # Full-stack web
pip install jac-scale    # Production deployment
```

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
| `.jac` | Universal Jac code |
| `.sv.jac` | Server-side only |
| `.cl.jac` | Client-side only |
| `.impl.jac` | Implementation file |

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

### 6 Identifiers

Valid identifiers start with a letter or underscore, followed by letters, digits, or underscores.

To use a reserved keyword as an identifier, escape it with a backtick prefix:

```jac
obj Example {
    has `class: str;  # Backtick-escaped keyword used as identifier
}
```

### 7 Entry Point Variants

Entry points define where code execution begins. Unlike Python's `if __name__ == "__main__"` pattern, Jac provides explicit entry block syntax. Use `entry` for code that always runs, `entry:__main__` for main-module-only code (like tests or CLI scripts), and named entries for exposing multiple entry points from a single file.

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

## Types and Values

Jac is statically typed -- all variables, fields, and function signatures require type annotations. This enables better tooling, clearer APIs, and catches errors at compile time rather than runtime. The type system is compatible with Python's typing module.

### 1 Builtin Types

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

### 2 Type Annotations

Type annotations are required for fields and function signatures:

```jac
obj Example {
    has name: str;
    has count: int = 0;
    has items: list[str] = [];
    has mapping: dict[str, int] = {};
}
```

### 3 Generic Types

Jac will support generic type parameters using Python-style syntax (coming soon):

```jac
# Generic function (coming soon):
# def first[T](items: list[T]) -> T {
#     return items[0];
# }

# Generic object (coming soon):
# obj Container[T] {
#     has value: T;
# }

# For now, use `any` as a placeholder:
def first(items: list) -> any {
    return items[0];
}

obj Container {
    has value: any;
}
```

### 4 Union Types

```jac
obj Example {
    has value: int | str | None;
}

def process(data: list[int] | dict[str, int]) -> None {
    # Handle either type
}
```

### 5 Type References

Type references are used in OSP operations like filtering graph traversals by node type. The `Root` keyword refers to the root node type in entry/exit clauses, and the `(?:TypeName)` syntax filters collections or traversals by type.

```jac
def example() {
    # In edge references
    [-->](?:Person);  # Filter nodes by Person type
}
```

### 6 Literals

**Numbers:**

```jac
def example() {
    decimal = 42;
    hex = 0x2A;
    octal = 0o52;
    binary = 0b101010;
    floating = 3.14159;
    scientific = 1.5e-10;

    # Underscore separators (for readability)
    million = 1_000_000;
    hex_word = 0xFF_FF;
}
```

**Strings:**

```jac
def example() {
    regular = "hello\nworld";
    raw = r"no\escape";
    bytes_lit = b"binary data";
    x = 42;
    f_string = f"Value: {x}";
    multiline = """
        Multiple
        lines
    """;
}
```

### 7 F-String Format Specifications

F-strings support powerful formatting with the syntax `{expression:format_spec}`.

**Basic formatting:**

```jac
def example() {
    name = "Alice";
    age = 30;

    # Simple interpolation
    greeting = f"Hello, {name}!";

    # With expressions
    message = f"In 5 years: {age + 5}";
}
```

**Width and alignment:**

```jac
def example() {
    name = "Alice";
    # Width specification
    f"{name:10}";           # "Alice     " (10 chars, left-aligned)
    f"{name:>10}";          # "     Alice" (right-aligned)
    f"{name:^10}";          # "  Alice   " (centered)
    f"{name:<10}";          # "Alice     " (left-aligned, explicit)

    # Fill character
    f"{name:*>10}";         # "*****Alice" (fill with *)
    f"{name:-^10}";         # "--Alice---" (centered with -)
}
```

**Number formatting:**

```jac
def example() {
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
}
```

**Sign and padding:**

```jac
def example() {
    x = 42;
    y = -42;

    f"{x:+}";               # "+42" (always show sign)
    f"{y:+}";               # "-42"
    f"{x:05}";              # "00042" (zero-padded)
}
```

**Conversions (`!r`, `!s`, `!a`):**

```jac
def example() {
    text = "hello\nworld";

    f"{text}";              # "hello\nworld" (default str())
    f"{text!s}";            # "hello\nworld" (explicit str())
    f"{text!r}";            # "'hello\\nworld'" (repr())
    f"{text!a}";            # "'hello\\nworld'" (ascii())
}
```

**Nested expressions:**

```jac
def example() {
    width = 10;
    pi = 3.14159;

    # Dynamic width
    f"{pi:{width}}";   # "   3.14159"

    # Expression in format
    value = "test";
    f"{value:>10}";    # "      test"
}
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
def example() {
    list_lit = [1, 2, 3];
    tuple_lit = (1, 2, 3);
    set_lit = {1, 2, 3};
    dict_lit = {"key": "value", "num": 42};
    empty_dict: dict = {};
    empty_list: list = [];
}
```

---

## Variables and Scope

Jac distinguishes between local variables (within functions), instance variables (`has` declarations in objects), and global variables (`glob`). Unlike Python where you assign `self.x = value` in `__init__`, Jac uses declarative `has` statements that make your data model explicit and visible at a glance.

### 1 Local Variables

```jac
def example() {
    # Type inferred
    x = 42;
    name = "Alice";

    # Explicit type
    count: int = 0;
    items: list[str] = [];
}
```

### 2 Instance Variables (has)

The `has` keyword declares instance variables in a clean, declarative style. Unlike Python's `self.x = value` pattern scattered throughout `__init__`, `has` statements appear at the top of your class definition, making the data model immediately visible. This design improves readability for both humans and AI code generators.

```jac
obj Person {
    has name: str;                    # Required
    has age: int = 0;                 # With default
    static has count: int = 0;        # Static (class-level)
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

### 3 Global Variables (glob)

```jac
glob PI: float = 3.14159;
glob config: dict = {};

with entry {
    global PI;
    print(PI);
}
```

### 4 Scope Rules

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
def example() {
    if True {
        block_var = 42;    # Created in block
    }
    # block_var is still accessible here in Jac (unlike some languages)

    for i in range(3) {
        loop_var = i;
    }
    # loop_var and i are accessible here
}
```

### 5 Truthiness

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
def example() {
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
    items = [1, 2, 3];
    if items {
        print(items);
    } else {
        print("No items to process");
    }

    # Default value pattern
    user_input = "";
    name = user_input or "Anonymous";
}
```

---

## Operators

Jac includes all standard Python operators plus several unique operators for graph manipulation (`++>`, `-->`, etc.), null-safe access (`?.`, `?[]`), piping (`|>`, `:>`), and LLM delegation (`by`). These Jac-specific operators are covered in sections 6.6-6.9.

### 1 Arithmetic Operators

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

### 2 Comparison Operators

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

### 3 Logical Operators

```jac
def example() {
    a = True;
    b = False;

    # Word form (preferred)
    result = a and b;
    result = a or b;
    result = not a;

    # Symbol form (also valid)
    result = a && b;
    result = a || b;
}
```

### 4 Bitwise Operators

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
def example() {
    flags = 0b1010;
    FLAG_MASK = 0b0010;
    NEW_FLAG = 0b0100;
    value = 16;

    # Bitwise AND - check if bit is set
    has_flag = (flags & FLAG_MASK) != 0;

    # Bitwise OR - set a bit
    flags = flags | NEW_FLAG;

    # Bitwise XOR - toggle a bit
    flags = flags ^ FLAG_MASK;

    # Bitwise NOT - invert all bits
    inverted = ~value;

    # Left shift - multiply by 2^n
    doubled = value << 1;      # value * 2
    quadrupled = value << 2;   # value * 4

    # Right shift - divide by 2^n
    halved = value >> 1;       # value // 2
    quartered = value >> 2;    # value // 4
}
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

### 5 Assignment Operators

**Simple Assignment:**

```jac
def example() {
    x = 5;
    name = "Alice";
    a = b = c = 0;  # Chained assignment
}
```

**Walrus Operator (`:=`):**

The walrus operator assigns a value and returns it in a single expression:

```jac
def example() {
    items = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

    # In conditionals - assign and test
    if (n := len(items)) > 10 {
        print(f"List has {n} items, too many!");
    }

    # In comprehensions
    data = [1, 2, 3];
    results = [y for x in data if (y := x * 2) > 2];

    # In function calls
    text = "hello";
    print(f"Length: {(n := len(text))}, doubled: {n * 2}");
}
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
def example() {
    count = 0;
    total = 100.0;
    tax_rate = 1.08;
    value = 2;
    flags = 0b0000;
    NEW_FLAG = 0b0100;
    OLD_FLAG = 0b0010;
    bits = 0b1010;
    mask = 0b0011;
    register = 1;

    # Numeric augmented assignment
    count += 1;
    total *= tax_rate;
    value **= 2;

    # Bitwise augmented assignment
    flags |= NEW_FLAG;      # Set a flag
    flags &= ~OLD_FLAG;     # Clear a flag
    bits ^= mask;           # Toggle bits
    register <<= 4;         # Shift left
}
```

### 6 Null-Safe Operators

The `?` operator provides safe access to potentially null values, returning `None` instead of raising an error.

**Safe attribute access (`?.`):**

```jac
obj Profile {
    has settings: dict = {};
}

obj User {
    has profile: Profile | None = None;
}

def example(obj: User | None, user: User | None) {
    # Without null-safe: raises AttributeError if obj is None
    value = obj.profile;

    # With null-safe: returns None if obj is None
    value = obj?.profile;

    # Chained - stops at first None
    result = user?.profile?.settings;
}
```

**Safe index access (`?[]`):**

```jac
def example(my_list: list | None, config: dict | None) {
    # Without null-safe: raises TypeError if list is None
    item = my_list[0];

    # With null-safe: returns None if list is None
    item = my_list?[0];

    # Works with dictionaries too
    value = config?["key"];
}
```

**Safe method calls:**

```jac
obj Data {
    def transform(param: str) -> Data {
        return self;
    }
    def format() -> str {
        return "formatted";
    }
}

def example(obj: Data | None, data: Data | None) {
    # Returns None if obj is None, doesn't call method
    result = obj?.transform("x");

    # Chained with arguments
    output = data?.transform("param")?.format();
}
```

**Combining with default values:**

```jac
obj User {
    has name: str = "";
    has is_active: bool = True;
}

def example(user: User | None) {
    # Null-safe with fallback using or
    name = user?.name or "Anonymous";

    # In conditionals
    if user?.is_active {
        print(user);
    }
}
```

**In filter comprehensions:**

```jac
obj Item {
    has value: int = 0;
}

def example() {
    items = [Item(value=1), Item(value=-1), Item(value=2)];
    # The ? in filter comprehensions
    valid_items = items(?value > 0);  # Filter where value > 0
}
```

**Behavior summary:**

| Expression | When `obj` is `None` | When `obj` is valid |
|------------|---------------------|---------------------|
| `obj?.attr` | `None` | `obj.attr` |
| `obj?[key]` | `None` | `obj[key]` |
| `obj?.method()` | `None` | `obj.method()` |
| `obj?.a?.b` | `None` | `obj.a.b` (or `None` if `a` is `None`) |

### 7 Graph Operators (OSP)

Graph operators are fundamental to Object-Spatial Programming. They let you create connections between nodes (`++>`) and traverse the graph (`-->`). Unlike traditional object references, graph connections are first-class entities that can have their own types and attributes. Use these operators whenever you're building or navigating graph structures.

**Connection Operators:**

```jac
node Person {
    has name: str;
}

edge Friend {
    has since: int = 2020;
}

with entry {
    node1 = Person(name="Alice");
    node2 = Person(name="Bob");

    # Untyped connections
    node1 ++> node2;         # Forward
    node1 <++ node2;         # Backward
    node1 <++> node2;        # Bidirectional

    # Typed connections
    alice = Person(name="Alice");
    bob = Person(name="Bob");
    alice +>: Friend(since=2020) :+> bob;
}
```

**Edge Reference Operators:**

```jac
node Item {
    has value: int = 0;
}

edge Link {
    has weight: int = 1;
}

walker Visitor {
    can visit with Item entry {
        # All outgoing edges
        neighbors = [-->];

        # All incoming edges
        sources = [<--];

        # Typed outgoing
        linked = [->:Link:->];

        # Filtered by edge attribute
        heavy = [->:Link:weight > 5:->];
    }
}
```

### 8 Pipe Operators

Pipe operators enable functional-style data transformation by passing results from one operation to the next. Instead of deeply nested function calls like `format(filter(transform(data)))`, you write `data |> transform |> filter |> format` -- reading naturally from left to right. Jac offers three pipe variants: standard pipes for functions, atomic pipes for controlling walker traversal order, and dot pipes for method chaining.

**Standard Pipes (`|>`, `<|`):**

```jac
def double(x: int) -> int { return x * 2; }
def add_one(x: int) -> int { return x + 1; }

def example() {
    data = 5;

    # Forward pipe - data flows left to right
    result = data |> double |> add_one;

    # Equivalent to:
    result = add_one(double(data));
}
```

**Atomic Pipes (`:>`, `<:`):**

Atomic pipes are used with spawn operations and affect traversal order:

```jac
node Item {
    has value: int = 0;
}

walker Visitor {
    can visit with Item entry {
        print(here.value);
    }
}

with entry {
    start = Item(value=1);

    # Atomic pipe forward - depth-first traversal
    start spawn :> Visitor();

    # Standard pipe with spawn - breadth-first traversal
    start spawn |> Visitor();
}
```

**Dot Pipes (`.>`, `<.`):**

Dot pipes chain method calls:

```jac
obj Builder {
    has value: int = 0;

    def add(n: int) -> Builder {
        self.value += n;
        return self;
    }
    def double() -> Builder {
        self.value *= 2;
        return self;
    }
}

def example() {
    # Dot forward pipe
    result = Builder() .> add(5) .> double;

    # Equivalent to:
    result = Builder().add(5).double();
}
```

**Pipe with lambdas:**

```jac
def example() {
    numbers = [1, 2, 3, 4, 5, 6, 7, 8];

    # Using lambdas in pipe chains
    result = numbers
        |> (lambda x: list : [i * 2 for i in x])
        |> (lambda x: list : [i for i in x if i > 10])
        |> sum;
}
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

### 9 The `by` Operator

The `by` operator is Jac's mechanism for delegation -- handing off work to an external system. Its most powerful use is with the `byllm` plugin, where `by llm` delegates function implementation to a language model. This enables "Meaning Typed Programming" where you declare *what* a function should do, and the LLM provides *how*. The operator is intentionally generic, allowing plugins to define custom delegation targets.

**General Syntax:**

```jac
def example() {
    # Basic by expression
    result = "hello" by "world";

    # Chained by expressions (right-associative)
    result = "a" by "b" by "c";  # Parsed as: "a" by ("b" by "c")

    # With expressions
    result = (1 + 2) by (3 * 4);
}
```

**With byllm Plugin (LLM Delegation):**

When the `byllm` plugin is installed, `by` enables LLM delegation:

```jac
# Function implementation delegated to LLM
"""Summarize the given text."""
def summarize(text: str) -> str by llm();

"""Translate text to French."""
def translate(text: str) -> str by llm(model_name="gpt-4");

with entry {
    # Expression processed by LLM
    result = summarize("Hello world");
}
```

See [Part V: AI Integration](ai-integration.md) for detailed LLM usage.

### 10 Operator Precedence

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
def f(x: int) -> int { return x + 1; }
def g(x: int) -> int { return x * 2; }

def example() {
    a = 1; b = 2; c = 3; cond = True;

    # Ternary binds loosely
    x = a if cond else b + 1;   # x = a if cond else (b + 1)

    # Logical operators
    x = a or b and c;           # x = a or (b and c)
    x = not a and b;            # x = (not a) and b

    # Comparison chaining
    x = 5;
    valid = 0 < x < 10;         # (0 < x) and (x < 10)

    # Arithmetic
    x = a + b * c;              # x = a + (b * c)
    x = a ** b ** c;            # x = a ** (b ** c)

    # Bitwise
    x = a | b & c;              # x = a | (b & c)
    x = a << 2 + 1;             # x = a << (2 + 1)

    # Pipe operators
    result = a |> f |> g;       # result = g(f(a))

    # Walrus in condition
    items = [1, 2, 3];
    if (n := len(items)) > 2 { print(n); }
}
```

**Short-circuit evaluation:**

`and` and `or` use short-circuit evaluation:

```jac
def example() {
    a = 1; b = 2; c = 3;

    # 'and' stops at first falsy value
    result = a and b and c;  # Returns first falsy, or last value

    # 'or' stops at first truthy value
    result = a or b or c;    # Returns first truthy, or last value

    # Common patterns
    user_input = "";
    fallback = "fallback";
    value = user_input or fallback;     # Use fallback if input is falsy
}
```

---

## Control Flow

Jac's control flow is familiar to Python developers with a few enhancements: braces instead of indentation, semicolons to end statements, and additional constructs like C-style for loops (`for i = 0 to i < 10 by i += 1`) and `switch` statements. Jac also supports Python's pattern matching (`match/case`) for destructuring complex data.

### 1 Conditional Statements

```jac
def example() {
    condition = True;
    other_condition = False;

    if condition {
        print("condition true");
    } elif other_condition {
        print("other condition");
    } else {
        print("else");
    }

    # Ternary expression
    result = "yes" if condition else "no";
}
```

### 2 While Loops

```jac
def example() {
    count = 0;

    while count < 3 {
        print(count);
        count += 1;
    }

    # With else clause (executes if loop completes normally)
    count = 0;
    while count < 3 {
        count += 1;
    } else {
        print("completed");
    }
}
```

### 3 For Loops

Jac supports Python-style iteration and also adds C-style for loops with explicit initialization, condition, and update expressions. The C-style syntax uses `to` for the condition and `by` for the update step -- useful when you need precise control over loop variables.

```jac
def example() {
    items = [1, 2, 3];

    # Iterate over collection (Python-style)
    for item in items {
        print(item);
    }

    # With index
    for (i, item) in enumerate(items) {
        print(f"{i}: {item}");
    }

    # C-style for loop: for INIT to CONDITION by UPDATE
    for i = 0 to i < 10 by i += 1 {
        print(i);
    }

    # With else clause
    for item in items {
        if item == 5 {
            break;
        }
    } else {
        print("Not found");
    }
}
```

### 4 Pattern Matching

Pattern matching lets you destructure and test complex data in a single construct. Unlike a chain of `if/elif` statements, `match` can extract values from lists, dicts, and objects while testing their structure. Use it when handling multiple data shapes or implementing state machines.

**Basic Patterns:**

```jac
obj Point {
    has x: int = 0;
    has y: int = 0;
}

def example(value: any) {
    match value {
        case 0:
            print("zero");

        case 1 | 2 | 3:
            print("small");

        case [x, y]:
            print(f"pair: {x}, {y}");

        case {"key": v}:
            print(f"dict with key: {v}");

        case Point(x=x, y=y):
            print(f"point at {x}, {y}");

        case _:
            print("default");
    }
}
```

**Advanced Patterns:**

```jac
def example(data: any) {
    match data {
        case [1, *middle, 5]:              # Spread: capture remainder
            print(f"Middle: {middle}");

        case {"key1": 1, **rest}:          # Dict spread
            print(f"Rest: {rest}");

        case [1, 2, last as captured]:     # As: bind to name
            print(f"Captured: {captured}");

        case [1, 2] | [3, 4]:              # Or: match either
            print("Matched");
    }
}
```

**Pattern Types:**

| Pattern | Example | Description |
|---------|---------|-------------|
| Literal | `case 42:` | Match exact value |
| Capture | `case x:` | Capture into variable |
| Wildcard | `case _:` | Match anything, don't capture |
| Sequence | `case [a, b]:` | Match list/tuple structure |
| Mapping | `case {"k": v}:` | Match dict structure |
| Class | `case Point(x, y):` | Match class instance |
| Or | `case 1 \| 2:` | Match any option |
| As | `case x as name:` | Capture with alias |
| Star | `case [first, *rest]:` | Capture sequence remainder |
| Double-star | `case {**rest}:` | Capture dict remainder |

### 5 Switch Statement

```jac
def example(value: int) {
    switch value {
        case 1:
            print("one");

        case 2:
            print("two");

        default:
            print("other");
    }
}
```

Note: Unlike C, there is no fall-through between cases.

### 6 Loop Control

```jac
def example() {
    items = [1, 2, 3, 4, 5];

    for item in items {
        if item == 2 {
            continue;    # Skip to next iteration
        }
        if item == 4 {
            break;       # Exit loop
        }
        print(item);
    }
}
```

### 7 Context Managers

```jac
def example() {
    with open("file.txt") as f {
        content = f.read();
    }

    # Multiple context managers
    with open("in.txt") as fin, open("out.txt", "w") as fout {
        fout.write(fin.read());
    }
}
```

### 8 Exception Handling

**Basic try/except:**

```jac
def risky_operation() -> int {
    raise ValueError("error");
}

def example() {
    try {
        result = risky_operation();
    } except ValueError {
        print("Value error occurred");
    }
}
```

**Capturing the exception:**

```jac
import json;

def example(input: str) {
    try {
        data = json.loads(input);
    } except ValueError as e {
        print(f"Parse error: {e}");
    } except KeyError as e {
        print(f"Missing key: {e}");
    }
}
```

**Multiple exception types:**

```jac
def process(data: any) -> None {
    print(data);
}

def example(data: any) {
    try {
        process(data);
    } except (TypeError, ValueError) as e {
        print(f"Type or value error: {e}");
    }
}
```

**Full try/except/else/finally:**

```jac
def example() {
    default_data = "default";
    file = None;
    data = "";

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
}
```

**Raising exceptions:**

```jac
def validate(input: str) -> None {
    if not input {
        # Raise an exception
        raise ValueError("Invalid input");
    }
}

def process(item: str) -> None {
    try {
        validate(item);
    } except ValueError as e {
        # Re-raise with more context
        raise RuntimeError(f"Failed to process: {item}") from e;
    }
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

### 9 Assertions

Assertions verify conditions during development:

```jac
def example() {
    condition = True;
    items = [1, 2, 3];
    value = 42;

    # Basic assertion
    assert condition;

    # Assertion with message
    assert len(items) > 0, "Items list cannot be empty";

    # Type checking
    assert isinstance(value, int), f"Expected int, got {type(value)}";
}

# Invariant checking in class methods
obj Account {
    has balance: float = 0.0;

    def withdraw(amount: float) -> None {
        assert amount > 0, "Withdrawal amount must be positive";
        assert amount <= self.balance, "Insufficient funds";
        self.balance -= amount;
    }
}
```

**Note:** Assertions can be disabled in production with optimization flags. Use exceptions for validation that must always run.

### 10 Generator Functions

Generators produce values lazily using `yield`:

**Basic generator:**

```jac
def count_up(n: int) -> int {
    for i in range(n) {
        yield i;
    }
}

with entry {
    # Usage
    for num in count_up(5) {
        print(num);  # 0, 1, 2, 3, 4
    }
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

with entry {
    # Usage
    nested = [[1, 2], [3, [4, 5]], 6];
    flat = list(flatten(nested));  # [1, 2, 3, 4, 5, 6]
}
```

**Generator expressions:**

```jac
def example() {
    # Generator expression (lazy)
    squares = (x ** 2 for x in range(1000000));

    # List comprehension (eager)
    squares_list = [x ** 2 for x in range(100)];
}
```

---

## Learn More

**Tutorials:**

- [Jac Basics](../../tutorials/language/basics.md) - Step-by-step introduction to Jac syntax
- [Hello World](../../quick-guide/hello-world.md) - Your first Jac program

**Related Reference:**

- [Part II: Functions & Objects](functions-objects.md) - Classes, methods, inheritance
