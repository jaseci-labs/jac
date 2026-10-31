"""Bug #34: Functions with non-None return type can implicitly return None.

The type checker validates explicit return statements but does not
check that all code paths return a value. A function declared as
`-> int` can fall through without returning, implicitly returning None.

Expected: Missing return on a code path should produce a type error.
"""

def maybe_return(x: int) -> int {
    if x > 0 {
        return x;
    }
    # <-- Missing return here: implicitly returns None, but declared -> int
}

def always_missing -> str {
    print("no return");
    # <-- No return at all, but declared -> str
}

def impl_missing(x: int) -> int;

impl impl_missing(x: int) -> int {
    if x > 0 {
        return x;
    }
    # <-- Missing return in an impl body
}

def impl_complete(x: int) -> int;

impl impl_complete(x: int) -> int {
    if x > 0 {
        return x;
    }
    return 0;
}

with entry {
    a = maybe_return(5);  # Ok at runtime
    b = maybe_return(-1);  # Returns None at runtime, but typed as int
    c = always_missing();  # Returns None at runtime, but typed as str
    d = impl_missing(1) + impl_complete(1);
}
