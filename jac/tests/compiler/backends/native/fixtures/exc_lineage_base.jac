"""A base exception class and a handler that never imports its subclasses.

`guard` catches `LibError` around a callback; the subclass the callback
raises is defined in `exc_lineage_main.jac`, which this module cannot see.
"""

obj:pub LibError(Exception) {}

obj:pub LibDetail(LibError) {}

def:pub raise_detail(n: int) -> int {
    if n > 0 {
        raise LibDetail("detail " + str(n));
    }
    return n;
}

def:pub guard(cb: (Callable[[int], int]), n: int) -> int {
    try {
        return cb(n);
    } except LibError {
        return -1;
    }
}
