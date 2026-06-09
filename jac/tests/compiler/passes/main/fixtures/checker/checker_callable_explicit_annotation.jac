"""Callable[[Args], ReturnType] with explicit parameter types.

Tests for Callable with concrete argument and return type annotations,
ensuring parameter matching and overload discrimination works correctly.
"""
import from typing { Callable, Optional }

# Basic callable signatures
def take_int_to_str(f: Callable[[int], str]) -> str {
    return f(42);
}

def take_any_callable(f: Callable) -> int {
    # Gradual form: any callable accepted
    return 0;
}

def take_multi_arg(f: Callable[[int, str], bool]) -> bool {
    return f(10, "hello");
}

# Overloaded functions keyed by signature
obj Handler {
    @overload
    def process(callback: Callable[[int], str]) -> str;

    @overload
    def process(callback: Callable[[str], int]) -> int;

    def process(callback: Callable) -> str | int {
        return callback(42) if isinstance(callback(42), str) else 0;
    }
}

# --- Valid: matching signatures ---
def ok_lambda_int_str() -> str {
    f: Callable[[int], str] = lambda x: str(x);
    return take_int_to_str(f);
}

def ok_lambda_multi() -> bool {
    f: Callable[[int, str], bool] = lambda x, y: x > 0;
    return take_multi_arg(f);
}

def ok_any_callable() -> int {
    f: Callable = lambda: 42;
    return take_any_callable(f);
}

def ok_named_func() -> str {
    def convert(n: int) -> str {
        return str(n);
    }
    return take_int_to_str(convert);
}

def ok_overload_str_int(h: Handler) -> int {
    f: Callable[[str], int] = lambda s: len(s);
    return h.process(f);
}

# --- Valid: assignability to broader type ---
def ok_assign_to_any() -> Callable {
    f: Callable[[int], str] = lambda x: str(x);
    g: Callable = f;  # narrower -> broader is ok
    return g;
}

# --- Invalid: wrong parameter types ---
def bad_wrong_params() -> str {
    # Callable[[str], str] cannot be assigned to Callable[[int], str]
    f: Callable[[str], str] = lambda x: x;
    return take_int_to_str(f);
}

# --- Invalid: wrong return type ---
def bad_wrong_return() -> str {
    # Callable[[int], int] cannot be assigned to Callable[[int], str]
    f: Callable[[int], int] = lambda x: x;
    return take_int_to_str(f);
}

# --- Invalid: arity mismatch ---
def bad_arity() -> str {
    # Callable[[int, str], str] has wrong arity for Callable[[int], str]
    f: Callable[[int, str], str] = lambda x, y: x + y;
    return take_int_to_str(f);
}

# --- Invalid: overload resolution failure ---
def bad_overload_ambiguous(h: Handler) -> str {
    # f cannot be assigned to either overload signature
    f: Callable[[float], str] = lambda x: str(x);
    return h.process(f);
}
