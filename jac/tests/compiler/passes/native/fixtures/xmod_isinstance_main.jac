"""`isinstance` against imported archetypes (issue #8061).

Every target named here is defined in `xmod_isinstance_lib`, so the candidate
set has to come from the program-wide class hierarchy rather than the classes
this module happens to define, and each candidate's vtable has to be reachable
as an external symbol. `chk_base` walks the imported MRO (a `Circle` matches
`Shape`), `chk_leaf` must not treat a sibling as a match, `chk_typed` runs the
statically typed pointer form, and `chk_lib_built` checks objects the library
itself allocated.
"""

import from xmod_isinstance_lib { Shape, Circle, Square, OtherKid, make_shape }

def chk_base(k: int) -> int {
    x: any = 0;
    if k == 0 {
        x = Circle(tag=1, r=2);
    } elif k == 1 {
        x = Square(tag=2, s=3);
    } elif k == 2 {
        x = OtherKid(o=4, k=5);
    } else {
        x = 7;
    }
    if isinstance(x, Shape) {
        return 1;
    }
    return 0;
}

def chk_leaf(k: int) -> int {
    x: any = 0;
    if k == 0 {
        x = Circle(tag=1, r=2);
    } else {
        x = Square(tag=2, s=3);
    }
    if isinstance(x, Circle) {
        return 1;
    }
    return 0;
}

def chk_typed -> int {
    c = Circle(tag=1, r=2);
    if isinstance(c, Shape) {
        return 1;
    }
    return 0;
}

def chk_lib_built(k: int) -> int {
    s = make_shape(k);
    if isinstance(s, Circle) {
        return 1;
    }
    return 0;
}
