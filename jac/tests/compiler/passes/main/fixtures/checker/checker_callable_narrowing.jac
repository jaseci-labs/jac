"""Tests for callable() type narrowing in the type checker.

callable(x) should narrow a union type to only its callable members
in the true branch, and to only its non-callable members in the false branch.
This mirrors how isinstance() narrowing works but uses callability as the predicate.
"""
import from typing { Callable }

obj Foo {
    has name: str;
}

# 1. Basic callable narrowing: callable(x) in true branch narrows to Callable member
#    Without narrowing: Callable[[int], str] | str cannot assign to Callable  -> Error
#    With narrowing:    Callable[[int], str] can assign to Callable           -> Ok
def test_callable_basic(
    handler: Callable[[int], str] | str
) -> str {
    if callable(handler) {
        cb: Callable[[int], str] = handler;  # <-- Ok after narrowing
        return cb(42);
    }
    return handler;  # <-- Ok: str after excluding callable
}

# 2. callable() narrowing in else branch: non-callable members remain
#    True branch:  handler narrowed to Callable[[int], str]
#    Else branch:  handler narrowed to str (non-callable)
def test_callable_else(
    handler: Callable[[int], str] | str
) -> str {
    if callable(handler) {
        cb: Callable[[int], str] = handler;  # <-- Ok after narrowing
        return cb(42);
    } else {
        s: str = handler;  # <-- Ok after negative narrowing (str)
        return s;
    }
}

# 3. callable() with early return promotes narrowing
#    After early return from callable branch, handler must be str.
def test_callable_early_return(
    handler: Callable[[int], str] | str
) -> str {
    if callable(handler) {
        return handler(42);
    }
    s: str = handler;  # <-- Ok: str after callable excluded
    return s;
}

# 4. not callable() inverts narrowing
#    `not callable(x)` true means x is NOT callable → narrow to non-callable
def test_not_callable(
    handler: Callable[[int], str] | str
) -> str {
    if not callable(handler) {
        s: str = handler;  # <-- Ok: str (non-callable)
        return s;
    }
    cb: Callable[[int], str] = handler;  # <-- Ok: callable after early return
    return cb(42);
}

# 5. callable() with None in union
#    Callable[[int], str] | None → callable branch gets Callable, else gets None
def test_callable_with_none(
    handler: Callable[[int], str] | None
) -> str {
    if callable(handler) {
        cb: Callable[[int], str] = handler;  # <-- Ok after narrowing
        return cb(42);
    }
    return "default";
}

# 6. callable() with multiple non-callable types in union
def test_callable_multi_non_callable(
    val: Callable[[str], int] | str | int
) -> int {
    if callable(val) {
        cb: Callable[[str], int] = val;  # <-- Ok after narrowing
        return cb("test");
    }
    return 0;
}

# 7. callable() else branch with multiple non-callable types
def test_callable_else_multi(
    val: Callable[[str], int] | str | int
) -> str {
    if callable(val) {
        return str(val("test"));
    } else {
        result: str | int = val;  # <-- Ok: str | int (non-callables)
        return str(result);
    }
}

# === Error cases: these SHOULD produce type errors ===

# E1. Without callable guard, full union cannot assign to Callable
def test_error_no_callable_guard(
    handler: Callable[[int], str] | str
) -> str {
    fail: Callable[[int], str] = handler;  # <-- Error (union cannot assign to Callable)
    return fail(42);
}

# E2. Without callable guard, full union cannot assign to str
def test_error_no_str_guard(
    handler: Callable[[int], str] | str
) -> str {
    fail: str = handler;  # <-- Error (union cannot assign to str)
    return fail;
}

# E3. Wrong assignment inside callable branch: str in callable branch
def test_error_callable_branch_wrong_type(
    handler: Callable[[int], str] | str
) -> str {
    if callable(handler) {
        s: str = handler;  # <-- Error: handler is Callable here, not str
        return s;
    }
    return "default";
}

# E4. Wrong assignment inside else branch: Callable in non-callable branch
def test_error_else_branch_wrong_type(
    handler: Callable[[int], str] | str
) -> str {
    if callable(handler) {
        return handler(42);
    } else {
        cb: Callable[[int], str] = handler;  # <-- Error: handler is str here
        return cb(42);
    }
}
