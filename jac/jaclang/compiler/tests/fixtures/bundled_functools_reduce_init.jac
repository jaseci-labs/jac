"""`functools.reduce` with an explicit initializer on the native backend.

CPython tells an omitted initializer from an explicit `None`: `reduce(f, xs,
None)` starts the fold at `None` and answers `None` for an empty list, where
`reduce(f, xs)` starts at the first item and raises on an empty list. The
bundled module keeps the two apart with a private sentinel default, so a
fold that seeds its accumulator with `None` runs the same steps natively.

Native-only: the sv checker resolves every call spelled against `reduce` to
its first overload, so the three-argument form cannot sit in a cross-backend
fixture. The expected values in the test are CPython's.
"""

import from functools { reduce }

def fold_step(acc: any, x: any) -> any {
    if isinstance(acc, type(None)) {
        return 100;
    }
    a: int = acc;
    b: int = x;
    return a + b;
}

def reduce_none_initial -> int {
    r: any = reduce(fold_step, [1, 2], None);
    v: int = r;
    return v;
}

def reduce_no_initial -> int {
    r: any = reduce(fold_step, [1, 2]);
    v: int = r;
    return v;
}

def reduce_int_initial -> int {
    r: any = reduce(fold_step, [1, 2], 10);
    v: int = r;
    return v;
}

def reduce_empty_none_initial -> int {
    r: any = reduce(fold_step, [], None);
    if isinstance(r, type(None)) {
        return 1;
    }
    return 0;
}
