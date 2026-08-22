# Product-path facade for bisect (native list algorithms).
# Staged ``jac-py/Modules/_bisectmodule.jac`` remains the C-API hand oracle
# (PyObj stubs) for cc differential tests - not byte-identical to this facade.
# Semantics mirror CPython 3.14 ``Lib/bisect.py`` / ``Modules/_bisectmodule.c``.

def _p2_bisect_right(data: list, item: any, lo: int = 0, hi: int | None = None) -> int {
    if lo < 0 {
        raise ValueError("lo must be non-negative");
    }
    bound: int = 0;
    if hi is None {
        bound = len(data);
    } else {
        bound = hi;
    }
    while lo < bound {
        mid = (lo + bound) // 2;
        if item < data[mid] {
            bound = mid;
        } else {
            lo = mid + 1;
        }
    }
    return lo;
}

def _p2_bisect_left(data: list, item: any, lo: int = 0, hi: int | None = None) -> int {
    if lo < 0 {
        raise ValueError("lo must be non-negative");
    }
    bound: int = 0;
    if hi is None {
        bound = len(data);
    } else {
        bound = hi;
    }
    while lo < bound {
        mid = (lo + bound) // 2;
        if data[mid] < item {
            lo = mid + 1;
        } else {
            bound = mid;
        }
    }
    return lo;
}

def _p2_insort(data: list, item: any, lo: int = 0, hi: int | None = None) {
    data.insert(_p2_bisect_right(data, item, lo, hi), item);
}

def _p2_insort_left(data: list, item: any, lo: int = 0, hi: int | None = None) {
    data.insert(_p2_bisect_left(data, item, lo, hi), item);
}
