"""TypeVar-function monomorphization.

A generic def (`def f[T](...)`) is a template, not a function: it declares
no symbol and emits no code on its own. Each callsite's checker-solved
argument types bind the type params; the pass stamps one specialized
private copy per distinct binding (keyed on the solved type mangles) and
the callsite links against that copy directly - whole-closure visibility,
no boxing. The same generic body specializes to different operations per
instantiation (`x + x` is integer addition at int and string concatenation
at str).
"""

def identity[T](val: T) -> T {
    return val;
}

def first[T](xs: list[T]) -> T {
    return xs[0];
}

def tail_of[T](xs: list[T]) -> T {
    return xs[len(xs) - 1];
}

def use_identity_int(v: int) -> int {
    return identity(v);
}

def use_identity_str_len(s: str) -> int {
    return len(identity(s));
}

def use_identity_float(v: float) -> float {
    return identity(v);
}

def use_identity_kw(v: int) -> int {
    return identity(val=v);
}

def use_tail_int(a: int, b: int) -> int {
    return tail_of([a, b]);
}

def use_tail_str_len(s: str, t2: str) -> int {
    return len(tail_of([s, t2]));
}

def use_first(a: int, b: int) -> int {
    return first([a, b]);
}

def use_first_str_len(s: str, t2: str) -> int {
    return len(first([s, t2]));
}

def never_called[T](x: T) -> T {
    return x;
}
