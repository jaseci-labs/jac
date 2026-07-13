"""RC + exception unwind fixture for jac2c landing pads.

Proves that owned locals introduced in a try body (and in a callee that
raises into an outer handler) are released on the exceptional path. Without
frame-tracked landing pads, longjmp skips scope_release and leaks.
"""

obj Counter {
    has n: int;

    def init(start: int) {
        self.n = start;
    }
}

def run_try_local -> int {
    try {
        c = Counter(1);
        raise ValueError("boom");
    } except ValueError {
        return 1;
    }
    return 0;
}

def _raise_with_local -> int {
    c = Counter(7);
    if c.n < 0 {
        return -1;
    }
    raise ValueError("from-callee");
}

def run_callee_raise -> int {
    try {
        _raise_with_local();
    } except ValueError {
        return 2;
    }
    return 0;
}

def run_nothrow -> int {
    r = 0;
    try {
        c = Counter(3);
        r = c.n;
    } except ValueError {
        return -1;
    }
    return r;
}
