"""`isinstance` against a vtable-less imported archetype (issue #8201).

`Point` and `Other` are laid out by their own module without a vtable slot, so
the pointer compare the earlier cross-module fix installed has nothing to
compare and every site naming them used to demote -- including `chk_typed`,
where the operand's class is statically known.

`MainKid` is the sharper case: subclassing an imported flat archetype puts a
vtable-carrying class in the candidate set, so the site lowered, and then read
a plain `Point`'s first field as if it were a vtable pointer and answered
`False` for `isinstance(point, Point)`.

`chk_hier` covers the contrasting shape whose vtables were always there, so the
answers below also prove the fast path still decides it.
"""

import from xmod_isinstance_flat_lib { Point, Other, LibBase, LibKid, make_point }

obj MainKid(Point) {
    has m: int = 0;
}

obj Local {
    has z: int = 0;
}

def chk_flat(k: int) -> int {
    o: any = 0;
    if k == 0 {
        o = Point(x=1);
    } elif k == 1 {
        o = Other(o=2);
    } elif k == 2 {
        o = Local(z=3);
    } else {
        o = 7;
    }
    if isinstance(o, Point) {
        return 1;
    }
    return 0;
}

def chk_local(k: int) -> int {
    o: any = 0;
    if k == 0 {
        o = Local(z=3);
    } else {
        o = Point(x=1);
    }
    if isinstance(o, Local) {
        return 1;
    }
    return 0;
}

def chk_typed -> int {
    p = Point(x=1);
    if isinstance(p, Point) {
        return 1;
    }
    return 0;
}

def chk_lib_built -> int {
    p = make_point();
    if isinstance(p, Point) {
        return 1;
    }
    return 0;
}

def chk_kid(k: int) -> int {
    o: any = 0;
    if k == 0 {
        o = MainKid(x=1, m=2);
    } elif k == 1 {
        o = Point(x=3);
    } elif k == 2 {
        o = make_point();
    } else {
        o = Other(o=4);
    }
    if isinstance(o, Point) {
        return 1;
    }
    return 0;
}

def chk_kid_leaf(k: int) -> int {
    o: any = 0;
    if k == 0 {
        o = MainKid(x=1, m=2);
    } else {
        o = Point(x=3);
    }
    if isinstance(o, MainKid) {
        return 1;
    }
    return 0;
}

def chk_hier(k: int) -> int {
    o: any = 0;
    if k == 0 {
        o = LibKid(b=1, k=2);
    } elif k == 1 {
        o = LibBase(b=1);
    } else {
        o = Other(o=4);
    }
    if isinstance(o, LibBase) {
        return 1;
    }
    return 0;
}

def chk_tuple_arm(k: int) -> int {
    o: any = 0;
    if k == 0 {
        o = Point(x=1);
    } elif k == 1 {
        o = LibKid(b=1, k=2);
    } else {
        o = Other(o=4);
    }
    if isinstance(o, (Point, LibBase)) {
        return 1;
    }
    return 0;
}
