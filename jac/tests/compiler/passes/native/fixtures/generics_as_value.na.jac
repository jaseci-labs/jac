"""Generic fns as values, v1 (#7626 A5).

A template bound to a name annotated with a CONCRETE Callable type
stamps its specialization eagerly (the annotation supplies the TypeVar
solution) and wraps into a closure value; the call then flows through
the normal closure-call path. Unannotated escapes stay a loud error
(see the guardrail in test_native_generics.jac).
"""

def pick2[T](x: T, y: T) -> T {
    return x;
}

def use_pick_int(v: int) -> int {
    f: Callable[[int, int], int] = pick2;
    return f(v, 3);
}

def use_pick_str_len -> int {
    a: str = "abc";
    b: str = "de";
    g: Callable[[str, str], str] = pick2;
    return len(g(a, b));
}
