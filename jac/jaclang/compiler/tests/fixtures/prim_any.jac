"""`isinstance`-on-`any` + scalar box/unbox round-trip (#6421).

Mechanism-B prerequisite for the native stdlib roadmap (#6404): generic-over-`any`
code (`json.dumps`/`loads`, `collections`, ...) recurses over heterogeneous values
and dispatches on their runtime type. Native lowers `any` to a tagged `JacVal`
union, so `isinstance(x, T)` becomes a tag comparison and `T = any -> concrete`
becomes a tag-dispatched unbox.

The Python reference pins the semantics; `require=["na"]` makes the native backend
a hard regression guard. `bool` is exercised first (it must be distinguishable from
`int`, mirroring CPython's `isinstance(True, bool)` / `isinstance(5, bool)`).
"""

# A generic serializer-style dispatcher: classify an `any` by runtime type.
def tag_py(x: any) -> str {
    if isinstance(x, bool) { return "bool"; }
    if isinstance(x, int) { return "int"; }
    if isinstance(x, float) { return "float"; }
    if isinstance(x, str) { return "str"; }
    if isinstance(x, list) { return "list"; }
    if isinstance(x, dict) { return "dict"; }
    return "other";
}

def any_dispatch_py() -> dict {
    yb: any = True;
    yi: any = 42;
    yf: any = 3.5;
    ys: any = "hi";
    yl: any = [1, 2, 3];
    yd: any = {"k": 1};
    return {
        "t_bool": tag_py(yb),
        "t_int": tag_py(yi),
        "t_float": tag_py(yf),
        "t_str": tag_py(ys),
        "t_list": tag_py(yl),
        "t_dict": tag_py(yd),
        # boxed at the call site from concrete literals
        "t_lit_int": tag_py(7),
        "t_lit_str": tag_py("x"),
        # bool <-> int subtype congruence (CPython: bool ⊂ int)
        "is_int_bool": 1 if isinstance(yi, bool) else 0,
        "is_bool_int": 1 if isinstance(yb, int) else 0,
        # any -> concrete unbox (read the int back out)
        "unbox": yi
    };
}

na {
    def tag_na(x: any) -> str {
        if isinstance(x, bool) { return "bool"; }
        if isinstance(x, int) { return "int"; }
        if isinstance(x, float) { return "float"; }
        if isinstance(x, str) { return "str"; }
        if isinstance(x, list) { return "list"; }
        if isinstance(x, dict) { return "dict"; }
        return "other";
    }

    def any_dispatch_na() -> dict[str, any] {
        yb: any = True;
        yi: any = 42;
        yf: any = 3.5;
        ys: any = "hi";
        yl: any = [1, 2, 3];
        yd: any = {"k": 1};
        # explicit `any -> concrete` unbox (tag-dispatched at the coercion seam)
        zi: int = yi;
        return {
            "t_bool": tag_na(yb),
            "t_int": tag_na(yi),
            "t_float": tag_na(yf),
            "t_str": tag_na(ys),
            "t_list": tag_na(yl),
            "t_dict": tag_na(yd),
            "t_lit_int": tag_na(7),
            "t_lit_str": tag_na("x"),
            "is_int_bool": 1 if isinstance(yi, bool) else 0,
            "is_bool_int": 1 if isinstance(yb, int) else 0,
            "unbox": zi
        };
    }
}
