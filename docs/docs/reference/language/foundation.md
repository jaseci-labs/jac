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

Jac is an AI-native full-stack programming language that extends Python with Object-Spatial Programming (OSP). It provides a unified language for backend, frontend, and AI development.

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
jac run hello.jac
```

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
x = 5;
print(x);
result = compute(x) + 10;
```

### 4 Code Blocks

Code blocks use braces:

```jac
if condition {
    statement1;
    statement2;
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

To use a reserved keyword as an identifier, escape it with angle brackets:

```jac
has <class>: str;  # Uses 'class' as field name
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
has name: str;
has count: int = 0;
has items: list[str] = [];
has mapping: dict[str, int] = {};
```

### 3 Generic Types

```jac
def first[T](items: list[T]) -> T {
    return items[0];
}

obj Container[T] {
    has value: T;
}
```

### 4 Union Types

```jac
has value: int | str | None;

def process(data: list[int] | dict[str, int]) -> None {
    # Handle either type
}
```

### 5 Type References (Backtick)

The backtick operator creates a reference to a type itself, rather than an instance of that type. This is essential for OSP operations like filtering graph traversals by node type, or for metaprogramming. Think of it as "the type called X" rather than "a value of type X".

```jac
`TypeName       # Reference to TypeName type
`root           # Reference to root node

# In edge references
[-->(`?Person)]  # Filter nodes by Person type
```

### 6 Literals

**Numbers:**

```jac
decimal = 42;
hex = 0x2A;
octal = 0o52;
binary = 0b101010;
floating = 3.14159;
scientific = 1.5e-10;

# Underscore separators (for readability)
million = 1_000_000;
hex_word = 0xFF_FF;
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

### 7 F-String Format Specifications

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

## Variables and Scope

Jac distinguishes between local variables (within functions), instance variables (`has` declarations in objects), and global variables (`glob`). Unlike Python where you assign `self.x = value` in `__init__`, Jac uses declarative `has` statements that make your data model explicit and visible at a glance.

### 1 Local Variables

```jac
# Type inferred
x = 42;
name = "Alice";

# Explicit type
count: int = 0;
items: list[str] = [];
```

### 2 Instance Variables (has)

The `has` keyword declares instance variables in a clean, declarative style. Unlike Python's `self.x = value` pattern scattered throughout `__init__`, `has` statements appear at the top of your class definition, making the data model immediately visible. This design improves readability for both humans and AI code generators.

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
if True {
    block_var = 42;    # Created in block
}
# block_var is still accessible here in Jac (unlike some languages)

for i in range(3) {
    loop_var = i;
}
# loop_var and i are accessible here
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
# Word form (preferred)
result = a and b;
result = a or b;
result = not a;

# Symbol form (also valid)
result = a && b;
result = a || b;
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

### 5 Assignment Operators

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

### 6 Null-Safe Operators

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

### 7 Graph Operators (OSP)

Graph operators are fundamental to Object-Spatial Programming. They let you create connections between nodes (`++>`) and traverse the graph (`-->`). Unlike traditional object references, graph connections are first-class entities that can have their own types and attributes. Use these operators whenever you're building or navigating graph structures.

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

### 8 Pipe Operators

Pipe operators enable functional-style data transformation by passing results from one operation to the next. Instead of deeply nested function calls like `format(filter(transform(data)))`, you write `data |> transform |> filter |> format` -- reading naturally from left to right. Jac offers three pipe variants: standard pipes for functions, atomic pipes for controlling walker traversal order, and dot pipes for method chaining.

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

### 9 The `by` Operator

The `by` operator is Jac's mechanism for delegation -- handing off work to an external system. Its most powerful use is with the `byllm` plugin, where `by llm` delegates function implementation to a language model. This enables "Meaning Typed Programming" where you declare *what* a function should do, and the LLM provides *how*. The operator is intentionally generic, allowing plugins to define custom delegation targets.

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

## Control Flow

Jac's control flow is familiar to Python developers with a few enhancements: braces instead of indentation, semicolons to end statements, and additional constructs like C-style for loops (`for i = 0 to i < 10 by i += 1`) and `switch` statements. Jac also supports Python's pattern matching (`match/case`) for destructuring complex data.

### 1 Conditional Statements

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

### 2 While Loops

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

### 3 For Loops

Jac supports Python-style iteration and also adds C-style for loops with explicit initialization, condition, and update expressions. The C-style syntax uses `to` for the condition and `by` for the update step -- useful when you need precise control over loop variables.

```jac
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
    if found(item) {
        break;
    }
} else {
    print("Not found");
}
```

### 4 Pattern Matching

Pattern matching lets you destructure and test complex data in a single construct. Unlike a chain of `if/elif` statements, `match` can extract values from lists, dicts, and objects while testing their structure. Use it when handling multiple data shapes or implementing state machines.

**Basic Patterns:**

```jac
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
```

**Advanced Patterns:**

```jac
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

### 6 Loop Control

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

### 7 Context Managers

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

### 8 Exception Handling

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

### 9 Assertions

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

### 10 Generator Functions

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
