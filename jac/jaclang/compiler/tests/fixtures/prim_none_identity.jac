"""None identity on unboxed scalars: cross-backend equivalence (#7922).

An unboxed int is never None on any backend. The native backend used a
leftover -1 marshalling sentinel for int-vs-None `is` comparisons, which
made `-1 is None` evaluate true.
"""

def nid_py -> dict {
    y: int = 0 - 1;
    z: int = 0;
    neg1_is_none: int = 1 if (y is None) else 0;
    neg1_is_not_none: int = 1 if (y is not None) else 0;
    zero_is_none: int = 1 if (z is None) else 0;
    return {
        "neg1_is_none": neg1_is_none,
        "neg1_is_not_none": neg1_is_not_none,
        "zero_is_none": zero_is_none
    };
}

def nid_cl -> dict {
    y: int = 0 - 1;
    z: int = 0;
    neg1_is_none: int = 1 if (y is None) else 0;
    neg1_is_not_none: int = 1 if (y is not None) else 0;
    zero_is_none: int = 1 if (z is None) else 0;
    return {
        "neg1_is_none": neg1_is_none,
        "neg1_is_not_none": neg1_is_not_none,
        "zero_is_none": zero_is_none
    };
}

def nid_na -> dict[str, any] {
    y: int = 0 - 1;
    z: int = 0;
    neg1_is_none: int = 1 if (y is None) else 0;
    neg1_is_not_none: int = 1 if (y is not None) else 0;
    zero_is_none: int = 1 if (z is None) else 0;
    return {
        "neg1_is_none": neg1_is_none,
        "neg1_is_not_none": neg1_is_not_none,
        "zero_is_none": zero_is_none
    };
}
