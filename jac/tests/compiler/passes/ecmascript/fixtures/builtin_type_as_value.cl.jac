"""Regression fixture for jaseci-labs/jaseci#7454.

A builtin type used as a *value* -- a `map`/`filter` callback, a `key=`
function, an alias, an element of a collection -- lowered to a bare JS string
tag (`"int"`), so calling it threw `TypeError: "int" is not a function` in the
browser.  Only the direct-call form (`int(x)`) reached the builtin emitters.

Every form below must resolve to the same callable the direct call emits, and
the type must keep working as isinstance/issubclass classinfo.
"""

cl def parse_all(parts: list) -> list {
    # `int` as a map callback.  JS `.map` hands its callback
    # (value, index, array), so a two-arity coercion like `int(x, base)` would
    # read the index as a radix and yield NaN unless map keeps Python's
    # one-argument call contract.
    return list(map(int, parts));
}

cl def keep_truthy(items: list) -> list {
    return list(filter(bool, items));
}

cl def sort_numerically(items: list) -> list {
    # A builtin type as a `key=` function.
    return sorted(items, key=int);
}

cl def alias_call(x: str) -> int {
    # Aliasing a builtin type, then calling through the alias.
    f = int;
    return f(x);
}

cl def coerce_all(x: any) -> list {
    # Builtin types stored in a collection, then called out of it.
    coercions = [str, int, bool];
    return [c(x) for c in coercions];
}

cl def direct_call(x: str) -> int {
    # Direct calls were never broken -- guard that they stay coerced.
    return int(x);
}

cl def classify(value: any) -> str {
    # A builtin type in classinfo position must still be a working type.  The
    # returned names are prefixed so the test can assert that no *bare* type
    # tag (`"int"`) survives in callable position.
    if isinstance(value, bool) {
        return "kind:bool";
    }
    if isinstance(value, int) {
        return "kind:int";
    }
    if isinstance(value, (str, list)) {
        return "kind:seq";
    }
    return "kind:other";
}

cl def subclass_probe -> list[bool] {
    return [issubclass(bool, int), issubclass(str, int)];
}
