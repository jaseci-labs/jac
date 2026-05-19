"""Fixture: `in` / `not in` where the container's static type is unknown.

`opaque` is declared to return `any`, so the type evaluator cannot prove the
static type of `s`, `nums`, or `mapping`. The ECMAScript backend must still
produce Python-equivalent membership semantics: substring search for strings,
element search for lists, key search for dicts.

A raw JavaScript `in` is wrong for the dynamic case: it throws a TypeError on
string operands and tests array *indices* rather than element values.
"""

cl def opaque(x: any) -> any {
    return x;
}

cl def membership() -> dict {
    s = opaque("hello world");
    nums = opaque([10, 20, 30]);
    mapping = opaque({"alpha": 1, "beta": 2});
    return {
        "str_hit": "world" in s,
        "str_miss": "zzz" in s,
        "str_not_in_hit": "zzz" not in s,
        "list_hit": 20 in nums,
        "list_miss": 99 in nums,
        "list_index_trap": 0 in nums,
        "dict_hit": "alpha" in mapping,
        "dict_miss": "gamma" in mapping
    };
}
