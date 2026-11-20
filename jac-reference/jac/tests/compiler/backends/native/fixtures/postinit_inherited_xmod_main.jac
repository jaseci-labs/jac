"""Native cross-module inherited-postinit consumer (#8090): `Leaf` inherits
its postinit from `Mid` in the imported module, so constructing it here must
resolve the postinit along the MRO the same way an `init` resolves. Before
the fix the constructor's exact-name lookup missed, the chain never ran, and
`make_leaf` read back the un-postinit'd 0 instead of 42."""

import from postinit_inherited_xmod_lib { Leaf, Mid }

def make_leaf() -> int {
    l = Leaf();
    return l.m;
}

def make_mid() -> int {
    m = Mid();
    return m.m;
}
