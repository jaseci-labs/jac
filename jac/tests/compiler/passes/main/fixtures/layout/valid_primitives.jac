"""Fixture: obj with primitive fields (all layout-compatible)."""

obj IntFields {
    has x: int,
        y: int,
        z: int;
}

obj AllPrimitives {
    has a: int,
        b: float,
        c: bool,
        d: str,
        e: bytes;
}
