"""An ancestor chain that leaves this unit before it ends (issue #8201).

`DeepKid` derives from `LibKid`, which derives from `LibBase` in the module
that defines both. This module linearizes `DeepKid` before any imported
registry is merged, so the chain it records reaches `LibKid` and stops:
nothing here can see that `LibKid` has a base at all. `LibBase` used to drop
out of the hierarchy, and a check against it first answered `False` for
classes that genuinely derive from it, then -- once that silence became a
refusal -- demoted the whole site.

`extended_mro` (#8320) closes the gap at the root: after the imported
registry merges, `DeepKid`'s recorded chain is continued through `LibKid`'s
own recorded chain, so `LibBase` is linearized, the `(class, ancestor)`
table holds the pair, and every check below lowers and answers the truth.
`chk_flat` names a class whose chain was always whole and is the control.
"""

import from xmod_isinstance_flat_lib { Point, Other, LibBase, LibKid }

obj DeepKid(LibKid) {
    has d: int = 0;
}

def chk_deep(k: int) -> int {
    o: any = 0;
    if k == 0 {
        o = DeepKid(b=1, k=2, d=3);
    } elif k == 1 {
        o = LibKid(b=1, k=2);
    } else {
        o = Other(o=4);
    }
    if isinstance(o, LibBase) {
        return 1;
    }
    return 0;
}

def chk_flat(k: int) -> int {
    o: any = 0;
    if k == 0 {
        o = Point(x=1);
    } else {
        o = Other(o=2);
    }
    if isinstance(o, Point) {
        return 1;
    }
    return 0;
}

def chk_unrelated_operand -> int {
    p = Point(x=1);
    if isinstance(p, LibBase) {
        return 1;
    }
    return 0;
}

def chk_base_typed_operand(k: int) -> int {
    b: LibBase = DeepKid(b=1, k=2, d=3) if k == 0 else LibKid(b=1, k=2);
    if isinstance(b, LibBase) {
        return 1;
    }
    return 0;
}
