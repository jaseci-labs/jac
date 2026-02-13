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
}
