"""Test fixture for Callable type checking."""
import from typing { Callable }

# Basic Callable type annotation
def takes_callback(cb: Callable[[int], str]) -> str {
    return cb(42);
}

def int_to_str(x: int) -> str {
    return str(x);
}

def str_to_str(x: str) -> str {
    return x;
}

# Gradual callable form - accepts any function
def takes_any_callable(cb: Callable[..., str]) -> str {
    return cb();
}

def no_args_str() -> str {
    return "hello";
}

def two_args_str(a: int, b: int) -> str {
    return str(a + b);
}

# --- Multi-parameter functions ---

def add_two(a: int, b: int) -> int {
    return a + b;
}

def concat_three(a: str, b: str, c: str) -> str {
    return a + b + c;
}

def mixed_params(x: int, y: str, z: float) -> str {
    return f"{x}-{y}-{z}";
}

def wrong_order(a: str, b: int) -> int {
    return b;
}

# Function that takes a multi-param Callable
def apply_binary_op(op: Callable[[int, int], int], x: int, y: int) -> int {
    return op(x, y);
}

def apply_ternary_str(op: Callable[[str, str, str], str], a: str, b: str, c: str) -> str {
    return op(a, b, c);
}

def apply_mixed(op: Callable[[int, str, float], str], x: int, y: str, z: float) -> str {
    return op(x, y, z);
}

# --- Extra params with defaults tests ---
# If src has more params than dest, extra params must have defaults

# Function with extra param that HAS default - OK
def with_default(a: int, b: int, c: int = 10) -> int {
    return a + b + c;
}

# Function with extra param that has NO default - ERROR
def without_default(a: int, b: int, c: int) -> int {
    return a + b + c;
}

# --- Contravariance tests (Animal/Dog hierarchy) ---
# Parameters are contravariant: function must accept AT LEAST as general types

class Animal {}
class Dog(Animal) {}
class Cat(Animal) {}

# Function that accepts any Animal (wider type)
def handle_animal(a: Animal) -> str {
    return "handled animal";
}

# Function that only accepts Dog (narrower type)
def handle_dog(d: Dog) -> str {
    return "handled dog";
}

# Function expecting Callable that takes Dog
def apply_to_dog(handler: Callable[[Dog], str], d: Dog) -> str {
    return handler(d);
}

# Function expecting Callable that takes Animal
def apply_to_animal(handler: Callable[[Animal], str], a: Animal) -> str {
    return handler(a);
}

# --- Method and classmethod tests ---
# In Jac, methods have implicit self (no need to declare)
# self/cls should be filtered when checking Callable compatibility

class Calculator {
    # Method with implicit self - takes int, returns int
    def double(x: int) -> int {
        return x * 2;
    }

    @classmethod
    def class_double(cls: type, x: int) -> int {
        return x * 2;
    }

    @classmethod
    def class_describe(cls: type, x: int) -> str {
        return f"Class value: {x}";
    }
}

# Function that takes method as Callable
def apply_int_op(op: Callable[[int], int], x: int) -> int {
    return op(x);
}

def apply_int_to_str(op: Callable[[int], str], x: int) -> str {
    return op(x);
}

with entry {
    # --- Valid assignments ---

    # Function with matching signature assigned to Callable
    f1: Callable[[int], str] = int_to_str;  # <-- Ok

    # Gradual callable accepts any function that returns str
    f2: Callable[..., str] = no_args_str;    # <-- Ok
    f3: Callable[..., str] = two_args_str;   # <-- Ok
    f4: Callable[..., str] = int_to_str;     # <-- Ok

    # Passing function to parameter expecting Callable
    r1: str = takes_callback(int_to_str);    # <-- Ok

    # Gradual callable in parameter
    r2: str = takes_any_callable(no_args_str);  # <-- Ok

    # --- Multi-parameter Callable tests (valid) ---

    # Two-parameter Callable[[int, int], int]
    m1: Callable[[int, int], int] = add_two;  # <-- Ok

    # Three-parameter Callable[[str, str, str], str]
    m2: Callable[[str, str, str], str] = concat_three;  # <-- Ok

    # Mixed types Callable[[int, str, float], str]
    m3: Callable[[int, str, float], str] = mixed_params;  # <-- Ok

    # Passing multi-param function to function expecting Callable
    m4: int = apply_binary_op(add_two, 10, 20);  # <-- Ok

    m5: str = apply_ternary_str(concat_three, "a", "b", "c");  # <-- Ok

    m6: str = apply_mixed(mixed_params, 1, "hello", 3.14);  # <-- Ok

    # Gradual callable with multi-param functions
    m7: Callable[..., int] = add_two;  # <-- Ok
    m8: Callable[..., str] = concat_three;  # <-- Ok

    # NOTE: Bare `Callable` (without type args) is not yet supported.
    # Use `Callable[..., Any]` instead for a fully gradual callable.

    # --- Method/classmethod as Callable (self/cls filtered) ---

    calc = Calculator();

    # Method with implicit self -> Callable[[int], int]
    # self is filtered, only x:int remains
    c1: Callable[[int], int] = calc.double;  # <-- Ok
    # Classmethod -> Callable[[int], int]
    # cls is filtered, only x:int remains
    c4: Callable[[int], int] = Calculator.class_double;  # <-- Ok

    # Classmethod returning str
    c5: Callable[[int], str] = Calculator.class_describe;  # <-- Ok

    # Using method in higher-order function
    c6: int = apply_int_op(calc.double, 5);  # <-- Ok

    # --- Extra params with defaults tests ---
    # Function with 3 params (c has default) assigned to Callable expecting 2 params
    d1: Callable[[int, int], int] = with_default;  # <-- Ok (c has default)

    # --- Contravariance tests ---
    # Contravariance: function accepting wider type can be assigned to Callable expecting narrower type

    # handle_animal accepts Animal, Callable expects Dog
    # OK because: if caller passes Dog, function accepts Animal, Dog IS an Animal
    v1: Callable[[Dog], str] = handle_animal;  # <-- Ok (contravariant)

    # Using in higher-order function
    v2: str = apply_to_dog(handle_animal, Dog());  # <-- Ok

    # --- Type errors ---

    # Wrong parameter type (expects int -> str, got str -> str)
    f5: Callable[[int], str] = str_to_str;  # <-- Error

    # Wrong return type assignment
    r3: int = takes_callback(int_to_str);   # <-- Error

    # --- Multi-parameter type errors ---

    # Wrong parameter order (expects [int, int], got [str, int])
    e1: Callable[[int, int], int] = wrong_order;  # <-- Error

    # Wrong number of parameters (expects 2, got 3)
    e2: Callable[[int, int], int] = concat_three;  # <-- Error

    # Wrong return type for multi-param
    e3: Callable[[int, int], str] = add_two;  # <-- Error

    # --- Method/classmethod type errors ---

    # Wrong return type for method
    e4: Callable[[int], str] = calc.double;  # <-- Error (returns int, not str)

    # Wrong param type for classmethod
    e5: Callable[[str], int] = Calculator.class_double;  # <-- Error (expects int, not str)

    # --- Contravariance errors ---
    # handle_dog only accepts Dog, but Callable expects Animal
    # FAIL because: caller might pass Cat (an Animal), but function only accepts Dog
    e6: Callable[[Animal], str] = handle_dog;  # <-- Error (contravariance violation)

    # --- Extra params without defaults errors ---
    # Function with 3 params (NO defaults) assigned to Callable expecting 2 params
    e7: Callable[[int, int], int] = without_default;  # <-- Error (c has no default)
}
