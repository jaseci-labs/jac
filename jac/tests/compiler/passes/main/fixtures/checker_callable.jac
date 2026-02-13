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

    # --- Type errors ---

    # Wrong parameter type (expects int -> str, got str -> str)
    f5: Callable[[int], str] = str_to_str;  # <-- Error

    # Wrong return type assignment
    r3: int = takes_callback(int_to_str);   # <-- Error
}
