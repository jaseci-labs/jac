# Part II: Functions and Objects

**In this part:**

- [Functions and Abilities](#functions-and-abilities) - Function declaration, parameters, abilities
- [Object-Oriented Programming](#object-oriented-programming) - Objects, inheritance, enums
- [Implementations and Forward Declarations](#implementations-and-forward-declarations) - Impl blocks, separation of interface

---

This part covers Jac's approach to functions and object-oriented programming. Jac uses `def` for standalone functions and `can` for methods (called "abilities") on objects. The key difference from Python: `has` declarations make your data model explicit, and `impl` blocks let you separate interface from implementation.

## Functions and Abilities

Functions in Jac use familiar `def` syntax with mandatory type annotations. Jac also introduces "abilities" (`can`) for methods attached to nodes, edges, and walkers. Abilities can be triggered automatically based on context (like when a walker visits a node) rather than being called explicitly.

### 1 Function Declaration

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

### 2 Docstrings

Docstrings appear *before* declarations (not inside like Python):

```jac
"""Module-level docstring."""

"Function docstring."
def add(a: int, b: int) -> int {
    return a + b;
}

"Object docstring."
obj Person {
    has name: str;
}
```

### 3 Parameter Types and Ordering

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
    print("called");
}
```

**Positional-only parameters (`/`):**

```jac
def greet(name: str, /) -> str {
    return f"Hello, {name}!";
}

with entry {
    greet("Alice");      # OK
    # greet(name="Alice"); # Error: positional-only
}
```

**Keyword-only parameters (after `*`):**

```jac
def configure(*, host: str, port: int = 8080) -> None {
    print(f"Connecting to {host}:{port}");
}

with entry {
    configure(host="localhost");           # OK
    # configure("localhost", 8080);        # Error: keyword-only
    configure(host="localhost", port=443); # OK
}
```

**Variadic parameters:**

```jac
# *args collects extra positional arguments
def sum_all(*values: int) -> int {
    return sum(values);
}

# **kwargs collects extra keyword arguments
def build_config(**options: object) -> dict {
    return dict(options);
}

# Combined
def flexible(required: int, *args: int, **kwargs: object) -> None {
    print(f"Required: {required}");
    print(f"Extra positional: {args}");
    print(f"Extra keyword: {kwargs}");
}

with entry {
    sum_all(1, 2, 3, 4, 5);  # 15
    build_config(debug=True, verbose=False);  # {"debug": True, "verbose": False}
    flexible(1, 2, 3, name="test");
    # Required: 1
    # Extra positional: (2, 3)
    # Extra keyword: {"name": "test"}
}
```

**Unpacking arguments:**

```jac
def add(a: int, b: int, c: int) -> int {
    return a + b + c;
}

with entry {
    # Unpack list/tuple into positional args
    values = [1, 2, 3];
    result = add(*values);  # add(1, 2, 3)

    # Unpack dict into keyword args
    params = {"a": 1, "b": 2, "c": 3};
    result = add(**params);  # add(a=1, b=2, c=3)

    # Combined unpacking
    result = add(*[1, 2], **{"c": 3});  # add(1, 2, c=3)
}
```

### 4 `can` vs `def`

Jac has two keywords for defining callable behavior: `def` for standard functions/methods and `can` for event-driven abilities on archetypes. Use `def` when you want explicit calling; use `can` when behavior should trigger automatically based on walker/node context.

| Feature | `def` | `can` |
|---------|-------|-------|
| **Call style** | Called explicitly: `obj.method()` | Triggered automatically on walker entry/exit |
| **Used in** | Any archetype, standalone functions | Walkers, nodes, edges |
| **Syntax** | `def name(args) -> Type { }` | `can name with NodeType entry { }` |
| **Best for** | Regular methods, utility functions, API endpoints | Graph traversal logic, event handlers |

```jac
walker ListItems {
    has items: list = [];

    # 'can' ability -- fires automatically when walker enters a Root node
    can collect with Root entry {
        visit [-->];
    }

    # 'can' ability -- fires on each Item node visited
    can gather with Item entry {
        self.items.append(here.value);
    }

    # 'can' ability -- fires when walker exits Root
    can report_all with Root exit {
        report self.items;
    }
}
```

> See [Part III: OSP](osp.md) for complete walker and ability documentation.

### 5 Methods

The `def` keyword declares methods on archetypes:

```jac
obj Calculator {
    has total: float = 0.0;

    def add(value: float) -> float {
        self.total += value;
        return self.total;
    }

    def reset() -> None {
        self.total = 0.0;
    }
}
```

### 6 Static Methods and Class Methods

Jac provides three method modifiers: `def` (instance method, receives `self`), `static def` (no receiver), and `class def` (class method, receives the class itself).

```jac
obj Counter {
    static has count: int = 0;

    # Static method -- no self or cls, pure utility
    static def get_count() -> int {
        return Counter.count;
    }

    # Static factory -- explicit class name keeps the return type clean
    static def make() -> Counter {
        return Counter();
    }

    # Instance method -- self is the instance
    def increment() -> None {
        Counter.count += 1;
    }
}
```

| Modifier | Receiver | Use case |
|----------|----------|----------|
| `def` | `self` (implicit) | Instance behavior |
| `static def` | none | Utility functions, named constructors |
| `class def` | the class (implicit) | Class-bound methods that need access to the class object |

#### Factory Methods

The simplest way to expose a named constructor is a `static def` that returns the enclosing type:

```jac
obj Animal {
    has name: str,
        sound: str = "...";

    static def named(name: str) -> Animal {
        return Animal(name=name);
    }

    def speak() -> str {
        return f"{self.name} says {self.sound}";
    }
}

obj Dog(Animal) {
    has sound: str = "woof";
}

with entry {
    a = Animal.named("Rex");
    print(a.speak());         # Rex says ...
    d = Dog(name="Rex");
    print(d.speak());         # Rex says woof
}
```

#### `Self` as a Type Annotation

`Self` works as a type annotation in instance methods, enabling fluent/builder patterns where each method returns the receiver:

```jac
obj QueryBuilder {
    has table: str = "",
        limit_val: int = -1;

    def from_table(table: str) -> Self {
        self.table = table;
        return self;
    }

    def limit(n: int) -> Self {
        self.limit_val = n;
        return self;
    }
}

with entry {
    q = QueryBuilder().from_table("users").limit(10);
}
```

| Context | `Self` resolves to |
|---------|-------------------|
| Instance `def` return annotation | `type(self)` -- the runtime class, used for fluent return-self |

!!! note "Polymorphic `class def` factories"
    A `class def` that returns `Self` and constructs `Self(...)` runs correctly today -- subclass calls return subclass instances -- but the static checker does not yet bind `Self` in `class def` return positions or as a callable target. For clean `jac check` output, prefer the `static def` factory above and name the concrete class explicitly. Tracking issue: polymorphic `Self` in `class def` is a planned type-checker enhancement.

### 7 Lambda Expressions

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

# Lambda returning lambda (closure -- see callout below)
glob make_adder = lambda x: int : (lambda y: int : x + y);
glob add_five = make_adder(5);  # add_five(10) returns 15
```

!!! info "Closures"
    A lambda (or nested `def`) captures variables from its enclosing scope, producing a *closure*. Each call to the outer function creates a fresh binding, so independently configured callables don't share state:

    ```jac
    glob make_adder = lambda x: int : (lambda y: int : x + y);

    with entry {
        add_five = make_adder(5);
        add_ten  = make_adder(10);
        print(add_five(10));   # 15
        print(add_ten(10));    # 20  (each closure keeps its own captured x)
    }
    ```

    Captured values are read freely. To mutate state across calls, prefer returning a configured object (see [IIFE & Anonymous Factories](#8-iife-anonymous-factories) below) over rebinding a captured local.

### 8 IIFE & Anonymous Factories

An *Immediately Invoked Function Expression* defines a function and calls it in the same expression -- useful for inlining a one-shot computation, or for producing a configured value from a private scope.

**Lambda IIFE** (single expression):

```jac
with entry {
    result = (lambda x: int -> int : x * 2)(5);   # result = 10
}
```

**`def` IIFE** (multi-statement, anonymous):

```jac
with entry {
    config = (def () -> dict {
        host = "localhost";
        port = 8080;
        return {"host": host, "port": port, "url": f"http://{host}:{port}"};
    })();
    print(config);
}
```

**Anonymous factory** -- IIFE + closure to produce a configured callable. This is Jac's equivalent of the JS `x => y => x + y` factory idiom:

```jac
with entry {
    adder = (def make_adder(x: int) {
        return lambda y: int : x + y;
    })(10);

    print(adder(5));   # 15
}
```

**Typed-product factory** -- when the product needs methods or a fixed shape, return an `obj` instance instead of a dict. The factory itself is an anonymous lambda that closes over its arguments:

```jac
obj Counter {
    has count: int;
    def inc -> None { self.count += 1; }
    def get -> int  { return self.count; }
}

glob make_counter = lambda start: int -> Counter : Counter(count=start);

with entry {
    c = make_counter(10);
    c.inc(); c.inc(); c.inc();
    print(c.get());   # 13
}
```

!!! note "Why no anonymous archetypes?"
    Jac's `obj`, `node`, `edge`, and `walker` archetypes must be declared with a name at module scope -- there is no inline `obj { has x: int; }` expression. For one-off structural products use a `dict`; when you need methods or a stable type, declare a named `obj` once and have the factory return instances of it.

!!! tip "Coming from JavaScript?"
    | JS idiom | Jac equivalent |
    |---|---|
    | `x => x + 1` | `lambda x: int : x + 1` |
    | `() => ({a: 1})` | `lambda : {"a": 1}` |
    | `(() => 42)()` | `(def () -> int { return 42; })()` |
    | `x => y => x + y` | `lambda x: int : (lambda y: int : x + y)` |
    | anonymous `class { ... }` | not supported -- declare a named `obj` and return instances |

    Jac lambdas require type annotations on parameters and a space before the body colon (`lambda x: int : x + 1`).

### 9 Decorators

```jac
def decorator(func: object) -> object {
    return func;
}

def decorator_with_args(arg1: object, arg2: object) -> object {
    return lambda func: object: func;
}

@decorator
def my_function -> None {
    print("decorated");
}

@decorator_with_args("a", "b")
def another_function -> None {
    print("decorated with args");
}
```

### 10 Access Modifiers

```jac
# Public (default, accessible everywhere)
def:pub public_func -> None { }

# Private (accessible only within the module)
def:priv _private_func -> None { }

# Protected (accessible within module and subclasses)
def:protect _protected_func -> None { }
```

??? example "Try it: Functions complete example"
    ```jac
    def greet(name: str) -> str {
        return f"Hello, {name}!";
    }

    def add(a: int, b: int) -> int {
        return a + b;
    }

    def apply(func: Callable[[int, int], int], x: int, y: int) -> int {
        return func(x, y);
    }

    with entry {
        print(greet("World"));
        print(add(3, 4));
        print(apply(lambda x: int, y: int -> int { return x * y; }, 5, 6));
    }
    ```

---

## Object-Oriented Programming

Jac uses `obj` instead of `class` to define types (though `class` is also supported for Python compatibility). The key differences from Python: fields are declared with `has` at the top of the definition, methods use `can` instead of `def`, and there's no explicit `__init__` -- the constructor is generated automatically from `has` declarations.

### 1 Objects (Classes)

Objects are Jac's basic unit of data and behavior. Use `obj` for general-purpose types. For graph-based programming, use `node`, `edge`, or `walker` instead (see Part III: OSP).

!!! note "When to use `obj` vs `class`"
    Jac's `obj` enforces stricter semantics than Python's `class` -- fields are declared upfront with `has`, constructors are auto-generated, and the structure is designed to be portable across codespaces (server, client, native). This strictness is intentional: it enables the compiler to target multiple execution environments from the same source code.

    If you need Python-specific class machinery like metaclasses or `@property` decorators, use a Python `class` instead. Jac provides `static def` for static methods, `class def` for class methods (with `Self`), and `static has` for class-level fields.

```jac
obj Person {
    has name: str;
    has age: int;

    def postinit() -> None {
        # Called after the auto-generated init completes
        print(f"Created {self.name}");
    }

    def greet() -> str {
        return f"Hi, I'm {self.name}";
    }
}

with entry {
    # Usage
    person = Person(name="Alice", age=30);
    print(person.greet());
}
```

### 2 Explicit vs. Dynamic Attributes

Jac enforces a **declarative data model**. All instance attributes must be declared upfront using `has`. While the current runtime might permit dynamic attribute assignment (adding a field that wasn't in `has`), this is considered an **anti-pattern** and will be strictly forbidden in future compiler versions.

> [!WARNING]
> **Dynamic Attribute Assignment is an Anti-Pattern**
> Explicitly declare all fields using `has`. Avoid adding new attributes to an instance after creation, as this violates the declarative nature of Jac objects and breaks portability across codespaces (server, client, native).

**Anti-Pattern (Dynamic Assignment):**

```jac
obj Person {
    has name: str;
}

with entry {
    p = Person(name="Alice");
    p.height = 175; # INVALID: 'height' is not in 'has'
    print(p.height);
}
```

**Correct Approach (Declarative):**

```jac
obj Person {
    has name: str,
        height: int = 0; # Declare all expected fields
}

with entry {
    p = Person(name="Alice", height=175);
    print(p.height);
}
```

#### Initialization with `by postinit`

If an attribute's value depends on other fields or requires complex calculation during setup, use the `by postinit` modifier and define a `postinit` method.

```jac
obj Rectangle {
    has width: float,
        height: float;
    has area: float by postinit;

    def postinit() {
        self.area = self.width * self.height;
    }
}
```

#### More Examples (Using `class`)

Even when using `class` for Python compatibility, you should avoid dynamic assignment within methods:

**Avoid this pattern:**

```jac
class Dog {
    def rename() -> None {
        self.secret = "oops"; # Dynamic assignment - Avoid!
    }

    def train() -> None {
        self.trick = "sit"; # Dynamic assignment - Avoid!
    }
}
```

**Prefer this pattern:**

```jac
obj Dog {
    has secret: str = "",
        trick: str = "";

    def rename() -> None {
        self.secret = "oops";
    }

    def train() -> None {
        self.trick = "sit";
    }
}
```

### 3 Inheritance

```jac
obj Animal {
    has name: str;

    def speak() -> str {
        return "";  # Base implementation
    }
}

obj Dog(Animal) {
    has breed: str = "Unknown";

    override def speak() -> str {
        return "Woof!";
    }
}

obj Cat(Animal) {
    override def speak() -> str {
        return "Meow!";
    }
}

# Trackable mixin
obj Trackable {
    has tracked: bool = False;
}

# Multiple inheritance
# Note: When a parent has fields with defaults, all child fields
# must also have defaults (Python dataclass constraint)
obj Pet(Animal, Trackable) {
    has owner: str = "";
    has name: str = "";
}
```

### 3 Enumerations

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

with entry {
    # Usage
    color = Color.RED;
    status = Status.ACTIVE;
    print(f"Color: {color}, Status: {status}");
}
```

### 4 Typed-Base Enums

`enum X: T { ... }` declares an enum whose members are instances of `T`. The base type follows the enum name after a colon. `int` and `str` desugar to Python's `IntEnum` and `StrEnum`; any other base `T` desugars to the mixin form `class X(T, Enum)`.

```jac
enum HttpStatus: int {
    OK = 200,
    NOT_FOUND = 404,
    SERVER_ERROR = 500
}

enum Tag: str {
    OPEN = "open",
    CLOSE = "close"
}

with entry {
    # Members compare and behave as the underlying type
    print(HttpStatus.OK == 200);             # True
    print(isinstance(Tag.OPEN, str));        # True
    print(HttpStatus.OK + 1);                # 201 -- arithmetic works
}
```

| Declaration | Desugars to |
|-------------|-------------|
| `enum X { A = 0 }` | `class X(Enum)` |
| `enum X: int { A = 0 }` | `class X(IntEnum)` |
| `enum X: str { A = "a" }` | `class X(StrEnum)` |
| `enum X: T { A = T(...) }` | `class X(T, Enum)` (mixin) |

The mixin form is useful when members must carry behavior or state from a custom type:

```jac
obj Box {
    has size: int = 0;
}

enum Crate: Box {
    SMALL = Box(),
    LARGE = Box()
}
```

### 5 Enums with Inline Python

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

### 6 Properties and Encapsulation

```jac
obj Account {
    has:priv _balance: float = 0.0;

    def get_balance() -> float {
        return self._balance;
    }

    def deposit(amount: float) -> None {
        if amount > 0 {
            self._balance += amount;
        }
    }
}
```

??? example "Try it: Objects and Enums complete example"
    ```jac
    enum Color {
        RED = "red",
        GREEN = "green",
        BLUE = "blue"
    }

    obj Animal {
        has name: str,
            sound: str;

        def speak() -> str {
            return f"{self.name} says {self.sound}!";
        }
    }

    obj Dog(Animal) {
        has breed: str;

        def speak() -> str {
            return f"{self.name} the {self.breed} says {self.sound}!";
        }
    }

    with entry {
        dog = Dog(name="Rex", sound="woof", breed="Labrador");
        print(dog.speak());
        print(f"Favorite color: {Color.BLUE.value}");
    }
    ```

---

## Implementations and Forward Declarations

Jac separates *interface* (what an object has and can do) from *implementation* (how it does it). This separation enables cleaner architecture, easier testing, and better organization of large codebases. You declare the interface in one place and implement abilities in `impl` blocks -- even in separate files.

### 1 Forward Declarations

Forward declarations let you reference a type before it's fully defined. This is essential for circular references (like User referencing Post and Post referencing User) and for organizing code across multiple files.

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

### 2 Implementation Blocks

The `impl` keyword attaches method bodies to declared abilities. This pattern keeps your interface clean and readable while moving implementation details elsewhere. It's particularly useful for large classes, for providing multiple implementations (like mock versions for testing), or for organizing abilities that span many lines.

```jac
# Interface (declaration)
obj Calculator {
    has value: float = 0.0;

    def add(x: float) -> float;
    def multiply(x: float) -> float;
}

# Implementation
impl Calculator.add {
    self.value += x;
    return self.value;
}

impl Calculator.multiply {
    self.value *= x;
    return self.value;
}
```

### 3 Separate Implementation Files

Convention: Use `.impl.jac` files for implementations.

**calculator.jac:**

```jac
obj Calculator {
    has value: float = 0.0;
    def add(x: float) -> float;
    def multiply(x: float) -> float;
}
```

**calculator.impl.jac:**

```jac
impl Calculator.add {
    self.value += x;
    return self.value;
}

impl Calculator.multiply {
    self.value *= x;
    return self.value;
}
```

### 4 Variant Modules

A single logical module can be split across *variant files* that target different execution contexts. Variant suffixes are `.sv.jac` (server), `.cl.jac` (client), and `.na.jac` (native). All files sharing the same base name are automatically discovered and compiled together.

**Head module precedence:** `.jac` > `.sv.jac` > `.cl.jac` > `.na.jac`. The highest-precedence file that exists on disk becomes the *head module*; all lower-precedence variants are attached as variant annexes. If no plain `.jac` file exists, the next available variant acts as head.

```
mymod/
├── mymod.jac            # Head module (declarations + entry)
├── mymod.sv.jac         # Server variant (extra server-only declarations)
├── mymod.cl.jac         # Client variant (extra client-only declarations)
├── mymod.impl.jac       # Head implementations (can also impl variant decls)
├── impl/
│   └── mymod.sv.impl.jac   # Server variant impl (from shared folder)
└── mymod.test.jac       # Tests
```

Each variant gets its own symbol table during parsing. The compiler then connects declarations and implementations across all variants:

- Impl files match their variant automatically (e.g., `mymod.sv.impl.jac` provides bodies for declarations in `mymod.sv.jac`).
- A head impl file (`mymod.impl.jac`) can provide implementations for declarations in *any* variant (cross-variant matching).
- Impl files can live in the same directory or in an `impl/` subdirectory.

**mymod.jac:**

```jac
obj Circle {
    has radius: float;
    def area -> float;
}
```

**mymod.sv.jac:**

```jac
obj CircleService {
    has name: str;
    def describe -> str;
}
```

**mymod.cl.jac:**

```jac
obj Display {
    has label: str;
    def render -> str;
}
```

**mymod.impl.jac** (cross-variant -- provides impls for both head and client variant):

```jac
impl Circle.area -> float {
    return 3.14159 * self.radius * self.radius;
}

impl Display.render -> str {
    return "Displaying: " + self.label;
}
```

**impl/mymod.sv.impl.jac** (server variant impl from shared folder):

```jac
impl CircleService.describe -> str {
    return "Service: " + self.name;
}
```

#### Native Variant Files (`.na.jac`)

Native variant files compile to LLVM IR and execute via JIT (MCJIT). Code in `.na.jac` files runs as native machine code, bypassing the Python runtime entirely. This is useful for performance-critical code and for calling C libraries directly. The same functionality is available in `to na:` sections (or `na` statement prefixes) within regular `.jac` files.

**C Library Imports:**

Native code can import C shared libraries using the `import from` syntax with a library path and extern function declarations, either at the top level of a `.na.jac` file or under a `to na:` section in a regular `.jac` file:

<!-- jac-skip -->
```jac
# math_native.na.jac
import from "/usr/lib/libm.so.6" {
    def sqrt(x: f64) -> f64;
    def pow(base: f64, exp: f64) -> f64;
}

def hypotenuse(a: f64, b: f64) -> f64 {
    return sqrt(a * a + b * b);
}
```

Declarations inside the braces are body-less function signatures that become LLVM `declare` (extern) statements. The shared library is loaded automatically at JIT time, and symbols are resolved by name.

**Type mapping:** Jac's `int` maps to `i64` and `float` maps to `f64` in native code. Use fixed-width types (`i8`, `i16`, `i32`, `u8`, `u16`, `u32`, `f32`, etc.) when C functions expect specific sizes. The compiler automatically coerces between standard and fixed-width types at call boundaries.

**Example -- calling raylib from Jac:**

<!-- jac-skip -->
```jac
# game.na.jac
import from "libraylib.so" {
    def InitWindow(width: i32, height: i32, title: str) -> None;
    def CloseWindow() -> None;
    def WindowShouldClose() -> i8;
    def BeginDrawing() -> None;
    def EndDrawing() -> None;
    def ClearBackground(color: i32) -> None;
    def DrawText(text: str, x: i32, y: i32, size: i32, color: i32) -> None;
}

with entry {
    InitWindow(800, 600, "Hello from Jac");
    while WindowShouldClose() == 0 {
        BeginDrawing();
        ClearBackground(0);
        DrawText("Jac + Raylib", 300, 280, 30, -1);
        EndDrawing();
    }
    CloseWindow();
}
```

### 5 When to Use Implementations

- **Circular dependencies**: Forward declare to break cycles
- **Code organization**: Keep interfaces clean
- **UI components**: Separate render tree from method logic (`.cl.jac` + `.impl.jac`)
- **Plugin architectures**: Define interfaces that plugins implement
- **Large codebases**: Separate concerns across files
- **Variant modules**: Split server, client, and native code into separate files while keeping them as one logical module
- **C interop**: Use `.na.jac` files to call C libraries directly from JIT-compiled native code

---

## Learn More

**Tutorials:**

- [Jac Basics](../../tutorials/language/basics.md) - Objects, functions, and syntax
- [Testing](../testing.md) - Write tests for your code

**Related Reference:**

- [Part I: Foundation](foundation.md) - Variables, types, control flow
- [Part III: OSP](osp.md) - Nodes, edges, walkers
