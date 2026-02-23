"""Dict get, pop, update, keys, values primitives.

Cross-backend equivalence fixture -- Python reference + native implementation.
"""

def dict_extra_py() -> dict {
    d: dict[str, int] = {"a": 1, "b": 2, "c": 3};
    # dict.get with and without default
    get_a: int = d.get("a", 0);
    get_missing: int = d.get("z", -1);
    get_exists: int = d.get("b", 99);
    # dict.pop
    popped: int = d.pop("b", 0);
    pop_len: int = len(d);
    pop_default: int = d.pop("z", -1);
    # dict.update
    d2: dict[str, int] = {"c": 30, "d": 40};
    d.update(d2);
    upd_len: int = len(d);
    upd_c: int = d["c"];
    upd_d: int = d["d"];
    # dict.values
    d3: dict[str, int] = {"x": 10, "y": 20};
    v: list = list(d3.values());
    return {
        "get_a": get_a,
        "get_missing": get_missing,
        "get_exists": get_exists,
        "popped": popped,
        "pop_len": pop_len,
        "pop_default": pop_default,
        "upd_len": upd_len,
        "upd_c": upd_c,
        "upd_d": upd_d,
        "vals_len": len(v)
    };
}

na {
    def dict_extra_na() -> dict[str, any] {
        d: dict[str, int] = {"a": 1, "b": 2, "c": 3};
        # dict.get with and without default
        get_a: int = d.get("a", 0);
        get_missing: int = d.get("z", -1);
        get_exists: int = d.get("b", 99);
        # dict.pop
        popped: int = d.pop("b", 0);
        pop_len: int = len(d);
        pop_default: int = d.pop("z", -1);
        # dict.update
        d2: dict[str, int] = {"c": 30, "d": 40};
        d.update(d2);
        upd_len: int = len(d);
        upd_c: int = d["c"];
        upd_d: int = d["d"];
        # dict.values
        d3: dict[str, int] = {"x": 10, "y": 20};
        v: list[int] = d3.values();
        return {
            "get_a": get_a,
            "get_missing": get_missing,
            "get_exists": get_exists,
            "popped": popped,
            "pop_len": pop_len,
            "pop_default": pop_default,
            "upd_len": upd_len,
            "upd_c": upd_c,
            "upd_d": upd_d,
            "vals_len": len(v)
        };
    }
}
