"""Dict emitter: all methods, operators, containers portion.

Cross-backend equivalence fixture.
"""

# --- Dict methods and operators ---
def dict_py() -> dict {
    d: dict = {"a": 1, "b": 2, "c": 3};

    get_hit: int = d.get("a", 0);
    get_miss: int = d.get("z", -1);

    keys: list = list(d.keys());
    values: list = list(d.values());
    items: list = list(d.items());

    d2: dict = {"x": 10};
    d2.update({"y": 20, "z": 30});

    d3: dict = d.copy();

    fk1: dict = dict.fromkeys(["x", "y", "z"], 0);
    fk2: dict = dict.fromkeys(["a", "b"]);

    d4: dict = {"a": 100, "b": 200, "c": 300};

    # dict_copy
    dc1: dict[str, int] = {"x": 10, "y": 20};
    dc1.clear();
    dc2: dict[str, int] = {"a": 1, "b": 2, "c": 3};
    dc3: dict[str, int] = dc2.copy();
    dc2["a"] = 999;

    # dict_extra
    de: dict[str, int] = {"a": 1, "b": 2, "c": 3};
    get_a: int = de.get("a", 0);
    get_missing: int = de.get("z", -1);
    get_exists: int = de.get("b", 99);
    popped: int = de.pop("b", 0);
    pop_len: int = len(de);
    pop_default: int = de.pop("z", -1);
    de2: dict[str, int] = {"c": 30, "d": 40};
    de.update(de2);
    upd_len: int = len(de);
    upd_c: int = de["c"];
    upd_d: int = de["d"];
    de3: dict[str, int] = {"x": 10, "y": 20};
    v: list = list(de3.values());

    # dict_setdefault
    ds1: dict[str, int] = {"a": 1, "b": 2};
    sd_missing: int = ds1.setdefault("c", 99);
    sd_missing_len: int = len(ds1);
    sd_missing_c: int = ds1["c"];
    ds2: dict[str, int] = {"x": 10, "y": 20};
    sd_existing: int = ds2.setdefault("x", 999);
    sd_existing_len: int = len(ds2);
    sd_existing_x: int = ds2["x"];
    ds3: dict[str, int] = {};
    ds3.setdefault("a", 1);
    ds3.setdefault("b", 2);
    ds3.setdefault("a", 100);
    sd_multi_len: int = len(ds3);
    sd_multi_a: int = ds3["a"];
    sd_multi_b: int = ds3["b"];

    # containers: | and |=
    d_in1: dict = {"x": 1};
    d_in2: dict = {"y": 2};
    dict_merge: dict = d_in1 | d_in2;
    dict_in: bool = "x" in d_in1;
    dict_nin: bool = "z" not in d_in1;
    d_ior: dict = {"a": 1, "b": 2};
    d_ior |= {"b": 99, "c": 3};

    # popitem (emit_popitem) — single-key dict for deterministic result
    dp: dict = {"pi_only": 77};
    pi: tuple = dp.popitem();
    pi_key: str = pi[0];
    pi_val: int = pi[1];
    pi_after_len: int = len(dp);

    return {
        "get_hit": get_hit,
        "get_miss": get_miss,
        "keys": keys,
        "values": values,
        "items": items,
        "after_update": d2,
        "copy": d3,
        "fromkeys_val": fk1,
        "fromkeys_none": fk2,
        "len": len(d4),
        "get_a_d4": d4["a"],
        "get_b_d4": d4["b"],
        "get_c_d4": d4["c"],
        "clear_len": len(dc1),
        "copy_len": len(dc3),
        "copy_a": dc3["a"],
        "copy_b": dc3["b"],
        "copy_c": dc3["c"],
        "orig_modified": dc2["a"],
        "get_a": get_a,
        "get_missing": get_missing,
        "get_exists": get_exists,
        "popped": popped,
        "pop_len": pop_len,
        "pop_default": pop_default,
        "upd_len": upd_len,
        "upd_c": upd_c,
        "upd_d": upd_d,
        "vals_len": len(v),
        "sd_missing": sd_missing,
        "sd_missing_len": sd_missing_len,
        "sd_missing_c": sd_missing_c,
        "sd_existing": sd_existing,
        "sd_existing_len": sd_existing_len,
        "sd_existing_x": sd_existing_x,
        "sd_multi_len": sd_multi_len,
        "sd_multi_a": sd_multi_a,
        "sd_multi_b": sd_multi_b,
        "dict_merge": dict_merge,
        "dict_in": dict_in,
        "dict_nin": dict_nin,
        "dict_ior": d_ior,
        "ior_len": len(d_ior),
        "ior_b": d_ior["b"],
        "ior_c": d_ior["c"],
        # popitem
        "items_len": len(items),
        "pi_key": pi_key,
        "pi_val": pi_val,
        "pi_after_len": pi_after_len
    };
}

cl def dict_cl() -> dict {
    d: dict = {"a": 1, "b": 2, "c": 3};

    get_hit: int = d.get("a", 0);
    get_miss: int = d.get("z", -1);

    keys: list = list(d.keys());
    values: list = list(d.values());
    items: list = list(d.items());

    d2: dict = {"x": 10};
    d2.update({"y": 20, "z": 30});

    d3: dict = d.copy();

    fk1: dict = dict.fromkeys(["x", "y", "z"], 0);
    fk2: dict = dict.fromkeys(["a", "b"]);

    dc1: dict[str, int] = {"x": 10, "y": 20};
    dc1.clear();
    dc2: dict[str, int] = {"a": 1, "b": 2, "c": 3};
    dc3: dict[str, int] = dc2.copy();
    dc2["a"] = 999;

    de: dict[str, int] = {"a": 1, "b": 2, "c": 3};
    get_a: int = de.get("a", 0);
    get_missing: int = de.get("z", -1);
    get_exists: int = de.get("b", 99);
    popped: int = de.pop("b", 0);
    pop_len: int = len(de);
    pop_default: int = de.pop("z", -1);
    de2: dict[str, int] = {"c": 30, "d": 40};
    de.update(de2);
    upd_len: int = len(de);
    upd_c: int = de["c"];
    upd_d: int = de["d"];
    de3: dict[str, int] = {"x": 10, "y": 20};
    v: list = list(de3.values());

    ds1: dict[str, int] = {"a": 1, "b": 2};
    sd_missing: int = ds1.setdefault("c", 99);
    sd_missing_len: int = len(ds1);
    sd_missing_c: int = ds1["c"];
    ds2: dict[str, int] = {"x": 10, "y": 20};
    sd_existing: int = ds2.setdefault("x", 999);
    sd_existing_len: int = len(ds2);
    sd_existing_x: int = ds2["x"];
    ds3: dict[str, int] = {};
    ds3.setdefault("a", 1);
    ds3.setdefault("b", 2);
    ds3.setdefault("a", 100);
    sd_multi_len: int = len(ds3);
    sd_multi_a: int = ds3["a"];
    sd_multi_b: int = ds3["b"];

    d_in1: dict = {"x": 1};
    d_in2: dict = {"y": 2};
    dict_merge: dict = d_in1 | d_in2;
    dict_in: bool = "x" in d_in1;
    dict_nin: bool = "z" not in d_in1;
    d_ior: dict = {"a": 1, "b": 2};
    d_ior |= {"b": 99, "c": 3};

    return {
        "get_hit": get_hit,
        "get_miss": get_miss,
        "keys": keys,
        "values": values,
        "items": items,
        "after_update": d2,
        "copy": d3,
        "fromkeys_val": fk1,
        "fromkeys_none": fk2,
        "clear_len": len(dc1),
        "copy_len": len(dc3),
        "copy_a": dc3["a"],
        "copy_b": dc3["b"],
        "copy_c": dc3["c"],
        "orig_modified": dc2["a"],
        "get_a": get_a,
        "get_missing": get_missing,
        "get_exists": get_exists,
        "popped": popped,
        "pop_len": pop_len,
        "pop_default": pop_default,
        "upd_len": upd_len,
        "upd_c": upd_c,
        "upd_d": upd_d,
        "vals_len": len(v),
        "sd_missing": sd_missing,
        "sd_missing_len": sd_missing_len,
        "sd_missing_c": sd_missing_c,
        "sd_existing": sd_existing,
        "sd_existing_len": sd_existing_len,
        "sd_existing_x": sd_existing_x,
        "sd_multi_len": sd_multi_len,
        "sd_multi_a": sd_multi_a,
        "sd_multi_b": sd_multi_b,
        "dict_merge": dict_merge,
        "dict_in": dict_in,
        "dict_nin": dict_nin,
        "dict_ior": d_ior
    };
}

na {
    def dict_na() -> dict[str, any] {
        d: dict[str, int] = {"a": 100, "b": 200, "c": 300};

        # dict_copy
        dc1: dict[str, int] = {"x": 10, "y": 20};
        dc1.clear();
        dc2: dict[str, int] = {"a": 1, "b": 2, "c": 3};
        dc3: dict[str, int] = dc2.copy();
        dc2["a"] = 999;

        # dict_extra
        de: dict[str, int] = {"a": 1, "b": 2, "c": 3};
        get_a: int = de.get("a", 0);
        get_missing: int = de.get("z", -1);
        get_exists: int = de.get("b", 99);
        popped: int = de.pop("b", 0);
        pop_len: int = len(de);
        pop_default: int = de.pop("z", -1);
        de2: dict[str, int] = {"c": 30, "d": 40};
        de.update(de2);
        upd_len: int = len(de);
        upd_c: int = de["c"];
        upd_d: int = de["d"];
        de3: dict[str, int] = {"x": 10, "y": 20};
        v: list[int] = de3.values();

        # dict_setdefault
        ds1: dict[str, int] = {"a": 1, "b": 2};
        sd_missing: int = ds1.setdefault("c", 99);
        sd_missing_len: int = len(ds1);
        sd_missing_c: int = ds1["c"];
        ds2: dict[str, int] = {"x": 10, "y": 20};
        sd_existing: int = ds2.setdefault("x", 999);
        sd_existing_len: int = len(ds2);
        sd_existing_x: int = ds2["x"];
        ds3: dict[str, int] = {};
        ds3.setdefault("a", 1);
        ds3.setdefault("b", 2);
        ds3.setdefault("a", 100);
        sd_multi_len: int = len(ds3);
        sd_multi_a: int = ds3["a"];
        sd_multi_b: int = ds3["b"];

        # containers in/not-in
        d_in1: dict[str, int] = {"x": 1};
        dict_in: int = 1 if "x" in d_in1 else 0;
        dict_nin: int = 1 if "z" not in d_in1 else 0;

        # dict |= (ior)
        d_ior: dict[str, int] = {"a": 1, "b": 2};
        d_ior |= {"b": 99, "c": 3};
        ior_len: int = len(d_ior);
        ior_b: int = d_ior["b"];
        ior_c: int = d_ior["c"];

        # items
        di_items: dict[str, int] = {"a": 1, "b": 2, "c": 3};
        items_len: int = len(di_items.items());

        # popitem (single-key dict for deterministic result)
        dp: dict[str, int] = {"pi_only": 77};
        pi = dp.popitem();
        pi_val: int = pi[1];
        pi_after_len: int = len(dp);


        return {
            "len": len(d),
            "get_a_d4": d["a"],
            "get_b_d4": d["b"],
            "get_c_d4": d["c"],
            "clear_len": len(dc1),
            "copy_len": len(dc3),
            "copy_a": dc3["a"],
            "copy_b": dc3["b"],
            "copy_c": dc3["c"],
            "orig_modified": dc2["a"],
            "get_a": get_a,
            "get_missing": get_missing,
            "get_exists": get_exists,
            "popped": popped,
            "pop_len": pop_len,
            "pop_default": pop_default,
            "upd_len": upd_len,
            "upd_c": upd_c,
            "upd_d": upd_d,
            "vals_len": len(v),
            "sd_missing": sd_missing,
            "sd_missing_len": sd_missing_len,
            "sd_missing_c": sd_missing_c,
            "sd_existing": sd_existing,
            "sd_existing_len": sd_existing_len,
            "sd_existing_x": sd_existing_x,
            "sd_multi_len": sd_multi_len,
            "sd_multi_a": sd_multi_a,
            "sd_multi_b": sd_multi_b,
            "dict_in": dict_in,
            "dict_nin": dict_nin,
            "ior_len": ior_len,
            "ior_b": ior_b,
            "ior_c": ior_c,
            "items_len": items_len,
            "pi_val": pi_val,
            "pi_after_len": pi_after_len
        };
    }
}
