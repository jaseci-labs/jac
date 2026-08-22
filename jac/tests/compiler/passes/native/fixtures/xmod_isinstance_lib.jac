"""Archetype hierarchy owned by another module (issue #8061).

Two unrelated hierarchies so the consumer's `isinstance` has both a positive
MRO walk (`Circle` -> `Shape`) and a negative one (`OtherKid` -> `Other`).
`make_shape` builds instances here, in the defining module, so the consumer
also sees objects whose vtable pointer was written by this module's code.
"""

obj Shape {
    has tag: int = 0;
}

obj Circle(Shape) {
    has r: int = 0;
}

obj Square(Shape) {
    has s: int = 0;
}

obj Other {
    has o: int = 0;
}

obj OtherKid(Other) {
    has k: int = 0;
}

def make_shape(k: int) -> Shape {
    if k == 0 {
        return Circle(tag=1, r=2);
    }
    return Square(tag=2, s=3);
}
