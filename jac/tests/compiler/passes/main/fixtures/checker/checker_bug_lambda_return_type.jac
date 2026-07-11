# Case 1: Lambda return checked against lambda's type, not enclosing fn's.
def outer_fn() -> str {
    get_style = lambda -> dict {
        return {"bg": "blue", "fg": "white"};  # OK
    };
    return "hello";
}

# Case 2: Nested lambdas — each return checks its own lambda's type.
def outer_fn2() -> str {
    outer_lambda = lambda -> list {
        inner_lambda = lambda -> int {
            return 42;  # OK
        };
        return [1, 2, 3];  # OK
    };
    return "world";
}

# Case 3: Lambda return type mismatch should still error.
def outer_fn3() -> str {
    bad_lambda = lambda -> int {
        return "not an int";  # Error: str != int
    };
    return "ok";
}

# Case 4: Function inside lambda — return checks against the inner function.
def outer_fn4() -> str {
    my_lambda = lambda -> dict {
        def inner_fn() -> int {
            return 99;  # OK
        }
        return {"key": "val"};  # OK
    };
    return "done";
}
