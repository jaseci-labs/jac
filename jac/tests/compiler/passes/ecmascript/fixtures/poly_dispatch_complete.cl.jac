"""Fixture: broad polymorphic method dispatch on receivers whose static type
is `any`.

`opaque` returns `any`, so the ECMAScript backend cannot prove the receiver's
type for any of the calls below and must route them all through the runtime
`_jac.poly.call` dispatcher. This exercises dict, list, and set operations,
user-defined-object method forwarding, the Python `dict.get` null-vs-default
semantics, and the AttributeError fallback for an unsupported operation.
"""

obj Box {
    has data: list = [10, 20, 30];

    # A method whose name collides with a primitive method (`count`). On an
    # any-typed receiver this routes through `_jac.poly.call`, which must
    # forward to this user method rather than treating the instance as a list.
    def count() -> int {
        return len(self.data);
    }
}

cl def opaque(x: any) -> any {
    return x;
}

cl def test_poly_complete() -> dict {
    # --- dict methods (receiver statically `any`) ---
    d = opaque({"a": 1, "b": 2});
    keys = d.keys();
    vals = d.values();
    d.update({"c": 3});
    has_c = d.get("c", -1);

    # Python `dict.get`: a present key whose value is None returns None, not
    # the default. A missing key returns the default.
    d2 = opaque({"x": None});
    null_hit = d2.get("x", -1);
    missing = d2.get("y", -1);

    # --- list methods (receiver statically `any`) ---
    lst = opaque([3, 1, 2]);
    lst.append(4);
    lst.sort();
    cnt = lst.count(1);

    # --- set methods (receiver statically `any`) ---
    s = opaque({1, 2});
    s.add(3);
    s.discard(1);
    has_three = 3 in s;
    has_one = 1 in s;

    # --- user-object method forwarding through the dispatcher ---
    b = opaque(Box());
    box_count = b.count();

    # --- JS-global method on a function-typed receiver ---
    # `Object` is an untyped reference, so `Object.keys(...)` routes through
    # the dispatcher. At runtime `Object` is a function; the dispatcher must
    # forward to its own `.keys` method rather than treat it as a dict.
    obj_keys = Object.keys({"p": 1, "q": 2});

    return {
        "keys": keys,
        "vals": vals,
        "has_c": has_c,
        "null_hit": null_hit,
        "missing": missing,
        "lst": lst,
        "cnt": cnt,
        "has_three": has_three,
        "has_one": has_one,
        "box_count": box_count,
        "obj_keys": obj_keys
    };
}

cl def test_poly_attribute_error() -> bool {
    # An eligible (primitive) method name on an incompatible runtime type must
    # raise a catchable AttributeError, not silently return a wrong value.
    raised = False;
    try {
        x = opaque(42);
        x.keys();
    } except Exception as e {
        raised = True;
    }
    return raised;
}
