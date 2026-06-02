"""Fixture: dict-like .get() on a user-defined obj with an unknown static type.

`opaque` returns `any`, so the backend cannot prove the receiver is the custom
`Cache` class. The poly helper must detect the `.get()` method and call it
instead of falling through to plain-object bracket notation (which would miss
keys stored in the internal `data` dict).
"""

obj Cache {
    has data: dict = {"x": 42};
    def get(key: str, default_: any = None) -> any {
        return self.data[key] if key in self.data else default_;
    }
}

cl def opaque(x: any) -> any {
    return x;
}

cl def test_poly_get_custom() -> dict {
    c = opaque(Cache());
    val_hit = c.get("x", -1);
    val_miss = c.get("z", -1);
    return {"hit": val_hit, "miss": val_miss};
}
