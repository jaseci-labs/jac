"""Archetypes an importer is the first to `isinstance`-test (issue #8201).

`Point` and `Other` are flat: no base, nothing here subclasses them, and
nothing here names them in an `isinstance`. Those are exactly the three facts a
module consults when it decides whether a class needs a vtable slot, so both
lay out without one -- and the consumer, which does test them, is the only
module that ever wanted the identity. `LibBase`/`LibKid` is the contrasting
shape whose hierarchy is visible here, so it carries a vtable the old
pointer-compare path could already use.

`make_point` builds an instance in the defining module, so the consumer also
sees an object whose header this module stamped.
"""

obj Point {
    has x: int = 0;
}

obj Other {
    has o: int = 0;
}

obj LibBase {
    has b: int = 0;
}

obj LibKid(LibBase) {
    has k: int = 0;
}

def make_point -> Point {
    return Point(x=9);
}
