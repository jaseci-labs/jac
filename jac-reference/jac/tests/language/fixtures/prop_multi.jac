"""Regression: multiple impl-separated property accessors in one class.

Each property's `getter`/`setter` accessor is registered in the class scope
under the same bare name (`getter`, `setter`), so the decl/impl resolver must
scope `impl Cls.prop.getter` to the property — not collapse every getter onto a
single class-level symbol. Before the fix, only one property matched its impl
and the rest silently fell back to empty (`pass`) accessor bodies.
"""

obj Boxes {
    has _a: int = 1,
        _b: int = 2,
        _c: int = 3;

    has a: int { getter; setter(value: int); }

    has b: int { getter; }

    has c: int { getter; }
}

impl Boxes.a.getter -> int {
    return self._a;
}

impl Boxes.a.setter(value: int) {
    self._a = value;
}

impl Boxes.b.getter -> int {
    return self._b;
}

impl Boxes.c.getter -> int {
    return self._c;
}

with entry {
    boxes = Boxes();
    assert boxes.a == 1;
    assert boxes.b == 2;
    assert boxes.c == 3;
    boxes.a = 10;
    assert boxes.a == 10;
    # b and c stay independent of a's setter
    assert boxes.b == 2;
    assert boxes.c == 3;
    print("ok");
}
