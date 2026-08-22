"""Heterogeneous containers: tagged-element list and dict round trips.

Cross-backend equivalence fixture.
"""

def hetero_py -> dict {
    l: list = [1, "two", 3.5, True];
    first: int = l[0];
    second: str = l[1];
    third: float = l[2];
    l[1] = "TWO";
    total: int = 0;
    for v in l {
        if isinstance(v, int) {
            iv: int = v;
            total = total + iv;
        }
    }
    d: dict = {"a": 1, "b": "bee", "c": 2.5};
    return {
        "first": first,
        "second": second,
        "third": third,
        "after_set": l[1],
        "iter_int_total": total,
        "d_a": d["a"],
        "d_b": d["b"],
        "d_c": d["c"],
        "lst": l,
        "d": d
    };
}


def hetero_na -> dict[str, any] {
    l: list = [1, "two", 3.5, True];
    first: int = l[0];
    second: str = l[1];
    third: float = l[2];
    l[1] = "TWO";
    total: int = 0;
    for v in l {
        if isinstance(v, int) {
            iv: int = v;
            total = total + iv;
        }
    }
    d: dict = {"a": 1, "b": "bee", "c": 2.5};
    return {
        "first": first,
        "second": second,
        "third": third,
        "after_set": l[1],
        "iter_int_total": total,
        "d_a": d["a"],
        "d_b": d["b"],
        "d_c": d["c"],
        "lst": l,
        "d": d
    };
}
