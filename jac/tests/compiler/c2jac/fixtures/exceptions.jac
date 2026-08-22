"""Exception fixture for the jac2c backend.

`try`/`except`/`raise` lower to the jacrt setjmp/longjmp runtime with type-id
dispatch. Covers a caught exception, propagation of a raise across a call
boundary to an outer handler, and the non-throwing normal path.
"""

def classify(n: int) -> int {
    r = 0;
    try {
        if n < 0 {
            raise ValueError("neg");
        }
        r = 1;
    } except ValueError as e {
        r = 2;
    }
    return r;
}

def inner(n: int) -> int {
    if n < 0 {
        raise ValueError("x");
    }
    return n;
}

def outer(n: int) -> int {
    acc = 0;
    try {
        acc = inner(n);
    } except ValueError as e {
        acc = 99;
    }
    return acc;
}

def run_catch -> int {
    return ((classify(-5) * 10) + classify(5));
}

def run_propagate -> int {
    return outer(-1);
}

def run_nothrow -> int {
    return outer(7);
}
