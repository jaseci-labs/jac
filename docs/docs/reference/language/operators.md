# Operators

**On this page:**

- [Arithmetic](#1-arithmetic-operators), [Comparison](#2-comparison-operators), [Logical](#3-logical-operators), [Bitwise](#4-bitwise-operators) - The standard operator set
- [Assignment Operators](#5-assignment-operators) - Plain, augmented, and walrus forms
- [Null-Safe Operators](#6-null-safe-operators) - `?.`, `?[]`, and friends
- [Graph Operators (OSP)](#7-graph-operators-osp) - Edge creation and traversal
- [Pipe Operators](#8-pipe-operators) - `|>` and `:>` data flow
- [The `by` Operator](#9-the-by-operator) - LLM delegation
- [The `as` Cast Operator](#10-the-as-cast-operator) - Explicit re-typing
- [Operator Precedence](#11-operator-precedence) - Full precedence table

---

Jac includes all standard Python operators plus several unique operators for graph manipulation (`++>`, `-->`, etc.), null-safe access (`?.`, `?[]`), piping (`|>`, `:>`), and LLM delegation (`by`). These Jac-specific operators are covered in [sections 6-9](#6-null-safe-operators) below.

## 1 Arithmetic Operators

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

## 2 Comparison Operators

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

## 3 Logical Operators

```jac
def example() {
    a = True;
    b = False;

    result = a and b;
    result = a or b;
    result = not a;
}
```

Jac uses the word forms only -- there are no `&&`/`||` symbol operators.

## 4 Bitwise Operators

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

## 5 Assignment Operators

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

## 6 Null-Safe Operators

The `?` operator provides safe access to potentially null values, returning `None` instead of raising an error.

**Safe attribute access (`?.`):**

```jac
obj Profile {
    has settings: dict = {};
}

obj User {
    has profile: Profile | None = None;
}

def example(item: User | None, user: User | None) {
    # Without null-safe: raises AttributeError if item is None
    value = item.profile;

    # With null-safe: returns None if item is None
    value = item?.profile;

    # Chained - stops at first None
    result = user?.profile?.settings;
}
```

**Safe index access (`?[]`):**

The `?[]` operator safely handles both `None` containers and invalid subscripts. It returns `None` instead of raising `IndexError`, `KeyError`, or `TypeError`:

```jac
def example(my_list: list | None, config: dict | None) {
    # Without null-safe: raises TypeError if list is None
    item = my_list[0];

    # With null-safe: returns None if list is None
    item = my_list?[0];

    # Works with dictionaries too
    value = config?["key"];

    # Also handles out-of-bounds indices
    items = [1, 2, 3];
    result = items?[10];         # None (no IndexError)

    # And missing dictionary keys
    data = {"a": 1};
    result = data?["missing"];   # None (no KeyError)
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

def example(item: Data | None, data: Data | None) {
    # Returns None if item is None, doesn't call method
    result = item?.transform("x");

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
    valid_items = items[?value > 0];  # Filter where value > 0
}
```

**Behavior summary:**

| Expression | When `obj` is `None` | When `obj` is valid |
|------------|---------------------|---------------------|
| `obj?.attr` | `None` | `obj.attr` |
| `obj?[key]` | `None` | `obj[key]` |
| `obj?.method()` | `None` | `obj.method()` |
| `obj?.a?.b` | `None` | `obj.a.b` (or `None` if `a` is `None`) |

## 7 Graph Operators (OSP)

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

## 8 Pipe Operators

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

Atomic pipes feed a value into a callable, like `|>`/`<|`, but bind more tightly
(higher precedence). `:>` pipes left-to-right and `<:` right-to-left:

```jac
def double(x: int) -> int { return x * 2; }

with entry {
    r  = 5 :> double;    # 10
    r2 = double <: 5;    # 10
    print(r, r2);
}
```

!!! warning "`spawn` combined with a pipe operator does not currently work"
    Older material documents piping into a spawn to pick a traversal order --
    `start spawn :> Visitor()` or `start spawn |> Visitor()`. Both forms currently
    fail at runtime with `'Visitor' object is not callable`. Spawn a walker with
    the plain form instead (it works and runs the walker's entry abilities):

    ```jac
    node Item { has value: int = 0; }

    walker Visitor {
        can visit_item with Item entry { print(here.value); }
    }

    with entry {
        start = Item(value=1);
        start spawn Visitor();   # runs Visitor on `start`
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
    result = Builder() .> add(5) .> double();

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
        |> (lambda (x: list) { [i * 2 for i in x]; })
        |> (lambda (x: list) { [i for i in x if i > 10]; })
        |> sum;
}
```

**Comparison of pipe operators:**

| Operator | Name | Direction | Use Case |
|----------|------|-----------|----------|
| `\|>` | Forward pipe | Left to right | Function composition |
| `<\|` | Backward pipe | Right to left | Reverse composition |
| `:>` | Atomic forward | Left to right | Tight-binding forward pipe |
| `<:` | Atomic backward | Right to left | Tight-binding backward pipe |
| `.>` | Dot forward | Left to right | Method chaining |
| `<.` | Dot backward | Right to left | Reverse method chain |

## 9 The `by` Operator

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
def summarize(text: str) -> str by llm();
sem summarize = "Summarize the given text in 2-3 sentences";

def translate(text: str) -> str by llm(model_name="gpt-4");
sem translate = "Translate the given text to French";

with entry {
    result = summarize("Hello world");
}
```

Use the **`sem` keyword** to attach semantic descriptions to functions, parameters, and fields. These descriptions are included in the compiler-generated prompt, giving the LLM additional context beyond what it can infer from names and types:

```jac
obj Ingredient {
    has name: str;
    has cost: float;
}
sem Ingredient.cost = "Estimated cost in USD";

def plan_shopping(recipe: str) -> list[Ingredient] by llm();
sem plan_shopping = "Generate a shopping list for the given recipe";
sem plan_shopping.recipe = "A description of the meal to prepare";
```

!!! tip
    Always use `sem` to provide context for `by llm()` functions. Docstrings are for human documentation and are not included in compiler-generated prompts.

See [byLLM Reference](../plugins/byllm.md) for detailed LLM usage.

## 10 The `as` Cast Operator

The `as` operator performs a type cast: `value as Type` tells the type checker to treat `value` as `Type`. It is *unchecked* and *type-erased* -- at runtime it does nothing and evaluates to `value` unchanged; only its static type changes. The semantics match `typing.cast`, but the syntax reads left-to-right and needs no import.

```jac
def example(raw: any) {
    count = raw as int;          # statically an int; no runtime check
    items = raw as list[str];    # cast to a generic type
}
```

Its primary use is as the escape hatch for the strict gradual-typing rule (see [The `any` Type and Gradual Typing](types-and-values.md#the-any-type-and-gradual-typing)): an `any` value -- such as a walker report -- cannot flow silently into a declared concrete type, and the cast makes that re-typing explicit:

```jac
with entry {
    result = root spawn load_feed();
    tweets: list[TweetView] = result.reports[0] as list[TweetView];
}
```

**Precedence.** The cast binds just below the ternary and above every binary operator, so `a + b as T` parses as `(a + b) as T`. To cast a ternary, parenthesize it: `(x if c else y) as T`. Casts chain left-associatively, so `x as A as B` is `(x as A) as B`.

**Interaction with `with` / `except`.** Because `with <ctx> as <name>` and `except <type> as <name>` use `as` for their own alias, a top-level cast is not recognized in those positions -- parenthesize it instead: `with (x as T) as f`.

!!! warning
    The cast is unchecked. `"abc" as int` compiles without complaint; a wrong cast surfaces only as a later type error or a runtime failure. Use it when you genuinely know more than the checker, not to silence diagnostics blindly.

## 11 Operator Precedence

Complete precedence table from **lowest** (evaluated last) to **highest** (evaluated first):

| Precedence | Operators | Associativity | Description |
|------------|-----------|---------------|-------------|
| 1 (lowest) | `lambda` | - | Lambda expression |
| 2 | `if else` | Right | Ternary conditional |
| 3 | `as` | Left | Type cast |
| 4 | `by` | Right | By operator (LLM delegation) |
| 5 | `:=` | Right | Walrus operator |
| 6 | `or` | Left | Logical OR |
| 7 | `and` | Left | Logical AND |
| 8 | `not` | - | Logical NOT (unary) |
| 9 | `in`, `not in`, `is`, `is not`, `<`, `<=`, `>`, `>=`, `!=`, `==` | Left | Comparison/membership |
| 10 | `\|` | Left | Bitwise OR |
| 11 | `^` | Left | Bitwise XOR |
| 12 | `&` | Left | Bitwise AND |
| 13 | `<<`, `>>` | Left | Bit shifts |
| 14 | `\|>`, `<\|` | Left | Pipe operators |
| 15 | `+`, `-` | Left | Addition, subtraction |
| 16 | `*`, `/`, `//`, `%`, `@` | Left | Multiplication, division, modulo, matmul |
| 17 | `+x`, `-x`, `~` | - | Unary plus, minus, bitwise NOT |
| 18 | `**` | Right | Exponentiation |
| 19 | `await` | - | Await expression |
| 20 | `spawn` | Left | Walker spawn |
| 21 | `:>`, `<:` | Left | Atomic pipes |
| 22 | `++>`, `<++`, connection ops | Left | Graph connection |
| 23 (highest) | `x[i]`, `x.attr`, `x()`, `x?.attr` | Left | Subscript, attribute, call |

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

??? example "Try it: Operators"
    ```jac
    with entry {
        x = 10;
        y = 3;
        print(f"{x} + {y} = {x + y}");
        print(f"{x} ** {y} = {x ** y}");
        print(f"{x} > {y} = {x > y}");
        print(f"not False = {not False}");
        print(f"{x} in [1,5,10] = {x in [1, 5, 10]}");
    }
    ```
