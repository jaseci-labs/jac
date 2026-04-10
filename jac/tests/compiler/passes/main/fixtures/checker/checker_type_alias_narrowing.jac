"""Tests for type narrowing through TypeAlias definitions.

When a type alias is defined with `TypeAlias` annotation, the type checker
should resolve the alias to the underlying type so that narrowing (isinstance,
callable, None checks) works correctly through the alias.
"""
import from typing { Callable, TypeAlias }

obj Foo {
    has value: int;
}

# TypeAlias with expression RHS (non-string)
glob MaybeFoo: TypeAlias = Foo | None;
glob HandlerOrStr: TypeAlias = Callable[[int], str] | str;
glob MultiNonCallable: TypeAlias = Callable[[str], int] | str | int;

# 1. isinstance narrows TypeAlias'd union
def test_isinstance_through_alias(val: MaybeFoo) -> int {
    if isinstance(val, Foo) {
        return val.value;  # Ok: val narrowed to Foo
    }
    return 0;
}

# 2. None check narrows TypeAlias'd union
def test_none_narrow_through_alias(val: MaybeFoo) -> int {
    if val is not None {
        f: Foo = val;  # Ok: val narrowed to Foo
        return f.value;
    }
    return 0;
}

# 3. callable() narrows TypeAlias'd union in true branch
def test_callable_through_alias(handler: HandlerOrStr) -> str {
    if callable(handler) {
        cb: Callable[[int], str] = handler;  # Ok after narrowing
        return cb(42);
    }
    return handler;  # Ok: str after excluding callable
}

# 4. callable() narrows TypeAlias'd union in else branch
def test_callable_else_through_alias(handler: HandlerOrStr) -> str {
    if callable(handler) {
        return handler(42);
    } else {
        s: str = handler;  # Ok after negative narrowing
        return s;
    }
}

# 5. not callable() inverts narrowing through alias
def test_not_callable_through_alias(handler: HandlerOrStr) -> str {
    if not callable(handler) {
        s: str = handler;  # Ok: non-callable
        return s;
    }
    cb: Callable[[int], str] = handler;  # Ok: callable after early return
    return cb(42);
}

# TypeAlias with string RHS (forward reference / complex type expression)
glob StringAlias: TypeAlias = 'Callable[[int], str] | str';

# 6. callable() narrows string-based TypeAlias'd union
def test_callable_string_alias(handler: StringAlias) -> str {
    if callable(handler) {
        cb: Callable[[int], str] = handler;  # Ok after narrowing
        return cb(42);
    }
    return handler;  # Ok: str after excluding callable
}

# === Error cases: these SHOULD produce type errors ===

# E1. Without isinstance guard, TypeAlias'd union cannot assign to component
def test_error_no_isinstance_guard(val: MaybeFoo) -> int {
    f: Foo = val;  # Error: Foo | None cannot assign to Foo
    return f.value;
}

# E2. Without callable guard, TypeAlias'd union cannot assign to Callable
def test_error_no_callable_guard(handler: HandlerOrStr) -> str {
    fail: Callable[[int], str] = handler;  # Error: union cannot assign to Callable
    return fail(42);
}
