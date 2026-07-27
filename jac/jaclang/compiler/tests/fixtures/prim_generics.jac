"""Generic-function cross-backend equivalence fixture.

Pins py (sv) TypeVar-function semantics against native monomorphization:
per-callsite solving, multiple instantiations of one template, and
container type-param flow. ES/JS opts out.
"""

def gid[T](val: T) -> T {
    return val;
}

def gfirst[T](xs: list[T]) -> T {
    return xs[0];
}

def generics_py -> dict {
    a = gid(41) + 1;
    s = gid("abc");
    f = gid(1.5) + gid(2.5);
    n = gfirst([7, 8, 9]);
    w = gfirst(["xy", "z"]);
    return {
        "int_id": a,
        "str_len": len(s),
        "float_sum": f,
        "first_int": n,
        "first_len": len(w),

    };
}

cl def generics_cl -> dict {
    return {};
}

na {
    def na_gid[T](val: T) -> T {
        return val;
    }

    def na_gfirst[T](xs: list[T]) -> T {
        return xs[0];
    }

    def generics_na -> dict[str, any] {
        a = na_gid(41) + 1;
        s = na_gid("abc");
        f = na_gid(1.5) + na_gid(2.5);
        n = na_gfirst([7, 8, 9]);
        w = na_gfirst(["xy", "z"]);
        return {
            "int_id": a,
            "str_len": len(s),
            "float_sum": f,
            "first_int": n,
            "first_len": len(w),

        };
    }
}
