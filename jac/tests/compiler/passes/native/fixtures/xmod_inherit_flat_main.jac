"""Inheriting a vtable-less imported archetype, adopted rather than refused.

`FlatKid` used to claim slot 0 for a vtable it carried only for having a
base, while `xmod_inherit_flat_lib` puts `depth` there -- no assignment
satisfied both units and the inherited read refused. Nothing dispatches
through `FlatKid`, so that header was a habit rather than a requirement: it
is dropped, the two units agree on `depth`, and the read lowers.

`stays_clean` shares the module to prove the base's own accessor is
unaffected either way.
"""

import from xmod_inherit_flat_lib { Anchor, make_anchor }

obj FlatKid(Anchor) {
    has extra: int = 0;
}

def read_inherited -> int {
    k = FlatKid(extra=2);
    return k.depth;
}

def stays_clean(n: int) -> int {
    a = make_anchor(n);
    return a.depth + 1;
}


with entry {
    print(read_inherited());
    print(stays_clean(5));
}
