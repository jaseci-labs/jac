"""Field-less archetypes keep the constructor of a special base (#8030 B1).

make_archetype applies dataclass() to every archetype; for a class that
declares no fields of its own that must not synthesize a zero-arg
__init__ that shadows an inherited constructor (builtin bases, classes
with explicit init). Mirrors the jac0 bootstrap's no-fields -> init=False
rule so all lowerings agree.
"""

class Box {
    def init(self: Box, v: int) {
        assert v == 7;
    }
}

obj BoxTag(Box) {}

obj Plain {}

obj WithField {
    has n: int = 0;
}


test "field-less obj subclass keeps inherited constructor" {
    b = BoxTag(7);
    assert b is not None;
}


test "field-less obj without bases still constructs zero-arg" {
    p = Plain();
    assert p is not None;
}


test "obj with fields keeps its dataclass constructor" {
    w = WithField(n=3);
    assert w.n == 3;
}
