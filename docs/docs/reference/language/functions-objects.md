# Part II: Functions and Objects

**In this part:**

- [Functions and Abilities](#functions-and-abilities) - Function declaration, parameters, abilities
- [Object-Oriented Programming](#object-oriented-programming) - Objects, inheritance, enums
- [Implementations and Forward Declarations](#implementations-and-forward-declarations) - Impl blocks, separation of interface

---

This part covers Jac's approach to functions and object-oriented programming. Jac uses `def` for standalone functions and `can` for methods (called "abilities") on objects. The key difference from Python: `has` declarations make your data model explicit, and `impl` blocks let you separate interface from implementation.

## Functions and Abilities

Functions in Jac use familiar `def` syntax with mandatory type annotations. Jac also introduces "abilities" (`can`) for methods attached to objects, nodes, edges, and walkers. Abilities can be triggered automatically based on context (like when a walker visits a node) rather than being called explicitly.

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
def build_config(**options: any) -> dict {
    return dict(options);
}

# Combined
def flexible(required: int, *args: int, **kwargs: any) -> None {
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

### 4 Methods

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

### 5 Static Methods

```jac
obj Counter {
    static has count: int = 0;

    # Static method
    static def get_count() -> int {
        return Counter.count;
    }

    # Instance method
    def increment() -> None {
        Counter.count += 1;
    }
}
```

### 6 Lambda Expressions

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

### 7 Immediately Invoked Function Expressions (IIFE)

```jac
with entry {
    result = (lambda x: int -> int: x * 2)(5);  # result = 10
}
```

### 8 Decorators

```jac
def decorator(func: any) -> any {
    return func;
}

def decorator_with_args(arg1: any, arg2: any) -> any {
    return lambda func: any: func;
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

### 9 Access Modifiers

```jac
# Public (default, accessible everywhere)
def:pub public_func -> None { }

# Private (accessible only within the module)
def:priv _private_func -> None { }

# Protected (accessible within module and subclasses)
def:protect _protected_func -> None { }
```

---

## Object-Oriented Programming

Jac uses `obj` instead of `class` to define types (though `class` is also supported for Python compatibility). The key differences from Python: fields are declared with `has` at the top of the definition, methods use `can` instead of `def`, and there's no explicit `__init__` -- the constructor is generated automatically from `has` declarations.

### 1 Objects (Classes)

Objects are Jac's basic unit of data and behavior. Use `obj` for general-purpose types. For graph-based programming, use `node`, `edge`, or `walker` instead (see Part III: OSP).

```jac
obj Person {
    has name: str;
    has age: int;

    def init(name: str, age: int) {
        self.name = name;
        self.age = age;
    }

    def postinit() -> None {
        # Called after init completes
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

### 2 Inheritance

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

# Multiple inheritance
obj Pet(Animal, Trackable) {
    has owner: str;
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

### 4 Enums with Inline Python

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

### 5 Properties and Encapsulation

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

### 4 When to Use Implementations

- **Circular dependencies**: Forward declare to break cycles
- **Code organization**: Keep interfaces clean
- **Plugin architectures**: Define interfaces that plugins implement
- **Large codebases**: Separate concerns across files

---

## Learn More

**Tutorials:**

- [Jac Basics](../../tutorials/language/basics.md) - Objects, functions, and syntax
- [Testing](../../tutorials/language/testing.md) - Write tests for your code

**Related Reference:**

- [Part I: Foundation](foundation.md) - Variables, types, control flow
- [Part III: OSP](osp.md) - Nodes, edges, walkers
