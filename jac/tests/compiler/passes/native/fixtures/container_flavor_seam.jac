"""Homogeneous containers crossing an `any`-flavored seam.

`dict[str, int]` stores values in an `i64` slot array; `dict[str, any]` stores
them as `{ i8 tag, i64 payload }` jacvals. The two layouts are different
widths, so a pointer cast between them reinterprets every value. The coercion
authority already refused (or reflavored) that mismatch for `list`; `dict` fell
through to a raw `bitcast` and silently produced garbage -- which is what
corrupted `json.dumps`, whose `_dump_value(value: any)` takes exactly this
seam.

`set` is not pinned here: `set[any]` is not a lowerable signature type at all,
so the seam it would exercise cannot be reached from Jac source.
"""

def _sum_dict_any(d: dict[str, any]) -> int {
    total: int = 0;
    for k in d {
        v: any = d[k];
        if isinstance(v, int) {
            iv: int = v;
            total += iv;
        }
    }
    return total;
}


def _sum_list_any(l: list[any]) -> int {
    total: int = 0;
    for v in l {
        if isinstance(v, int) {
            iv: int = v;
            total += iv;
        }
    }
    return total;
}


"""A `dict[str, int]` handed to a `dict[str, any]` parameter: 7 + 42."""
def dict_seam_na -> int {
    d: dict[str, int] = {"k": 7, "j": 42};
    return _sum_dict_any(d);
}


"""The list seam the coercion authority already covered: 7 + 42."""
def list_seam_na -> int {
    l: list[int] = [7, 42];
    return _sum_list_any(l);
}
