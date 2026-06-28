"""Bundled native `json` cross-backend equivalence fixture (issues #6404 / #6940).

The SAME `import from json { loads, dumps }` binds CPython's `json` on the sv
(Python) backend and the bundled `na_stdlib/json.na.jac` Mechanism-B module on
the na (native LLVM) backend. This fixture pins the two congruent on:

  * loads -- values are extracted to SCALARS (int/float/str/bool/None) because the
    cross-backend harness marshals a returned dict[str, any] (and nested dicts)
    but reads a returned list as raw i64; so arrays are probed via len + indexed
    element reads rather than returned whole.
  * dumps -- compared as exact strings (CPython default `(', ', ': ')` separators,
    insertion-ordered keys). Floats are intentionally NOT dumps-tested: native
    `str(float)` is `%g`, not CPython's shortest-round-trip repr (gated on #6940
    Phase 0.3 Ryu). Float PARSING is exact and is compared with a tolerance.

ES/JS opts out.
"""

import from json { loads, dumps }


def json_py() -> dict {
    scalars: any = loads(
        "{\"a\": 1, \"b\": \"hi\", \"c\": true, \"d\": false, \"e\": null, \"f\": 3.5, \"g\": -7}"
    );
    arr: any = loads("[10, 20, 30]");
    nested: any = loads("{\"x\": {\"y\": 5}}");
    esc: any = loads("\"a\\nb\"");
    uni: any = loads("\"\\u0041\"");
    obj_simple: dict[str, any] = {"a": 1, "b": "x"};
    obj_mixed: dict[str, any] = {"i": 1, "s": "x", "b": True, "z": None};
    return {
        "l_a": scalars["a"],
        "l_b": scalars["b"],
        "l_c": scalars["c"],
        "l_d": scalars["d"],
        "rt_null": dumps(loads("null")),
        "l_f": scalars["f"],
        "l_g": scalars["g"],
        "arr_len": len(arr),
        "arr0": arr[0],
        "arr2": arr[2],
        "nested": nested["x"]["y"],
        "esc": esc,
        "uni": uni,
        "d_int": dumps(42),
        "d_negint": dumps(-7),
        "d_str": dumps("hi"),
        "d_str_esc": dumps("a\"b\nc"),
        "d_true": dumps(True),
        "d_false": dumps(False),
        "d_none": dumps(None),
        "d_list": dumps(loads("[1, 2, 3]")),
        "d_list_nested": dumps(loads("[1, [2, 3]]")),
        "d_obj": dumps(obj_simple),
        "d_obj_mixed": dumps(obj_mixed),

    };
}


cl def json_cl() -> dict {
    return {};
}


na {
    def json_na() -> dict[str, any] {
        scalars: any = loads(
            "{\"a\": 1, \"b\": \"hi\", \"c\": true, \"d\": false, \"e\": null, \"f\": 3.5, \"g\": -7}"
        );
        arr: any = loads("[10, 20, 30]");
        nested: any = loads("{\"x\": {\"y\": 5}}");
        esc: any = loads("\"a\\nb\"");
        uni: any = loads("\"\\u0041\"");
        obj_simple: dict[str, any] = {"a": 1, "b": "x"};
        obj_mixed: dict[str, any] = {"i": 1, "s": "x", "b": True, "z": None};
        return {
            "l_a": scalars["a"],
            "l_b": scalars["b"],
            "l_c": scalars["c"],
            "l_d": scalars["d"],
            "rt_null": dumps(loads("null")),
            "l_f": scalars["f"],
            "l_g": scalars["g"],
            "arr_len": len(arr),
            "arr0": arr[0],
            "arr2": arr[2],
            "nested": nested["x"]["y"],
            "esc": esc,
            "uni": uni,
            "d_int": dumps(42),
            "d_negint": dumps(-7),
            "d_str": dumps("hi"),
            "d_str_esc": dumps("a\"b\nc"),
            "d_true": dumps(True),
            "d_false": dumps(False),
            "d_none": dumps(None),
            "d_list": dumps(loads("[1, 2, 3]")),
            "d_list_nested": dumps(loads("[1, [2, 3]]")),
            "d_obj": dumps(obj_simple),
            "d_obj_mixed": dumps(obj_mixed),

        };
    }
}
