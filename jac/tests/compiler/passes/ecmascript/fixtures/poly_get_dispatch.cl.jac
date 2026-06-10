"""Fixture: dict .get() on a receiver whose static type is not provably dict.

`opaque` returns `any`, so the type checker cannot prove the receiver is a
dict. The ECMAScript backend must fall back to the runtime-polymorphic
`_jac.poly.get` helper instead of emitting the Python method name verbatim.
"""

cl def opaque(x: any) -> any {
    return x;
}

cl def test_poly_get() -> dict {
    mapping = opaque({"a": 1, "b": 2});
    val_hit = mapping.get("a");
    val_miss = mapping.get("z", -1);
    return {"hit": val_hit, "miss": val_miss};
}
