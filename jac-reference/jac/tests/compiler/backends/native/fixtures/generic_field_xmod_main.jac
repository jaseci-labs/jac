"""Reads a generic archetype's erased slot across a module boundary.

`Cell` and `Leaf` are both imported, so the type argument that names what
comes out of the erased slot is resolved against an imported class here --
the shape the sealed parser hits, where `SubTag[Token]` is read from files
that neither declares.
"""

import from generic_field_xmod_lib { Cell, Leaf, build }

"""A cell built here, off an imported generic."""
def local_built(k: int) -> int {
    c = Cell[Leaf](slot=Leaf(num=90 + k, name="main"), kind=k);
    return c.slot.num;
}

"""A cell the library allocated, read through the imported type argument."""
def lib_built(k: int) -> int {
    c = build(5 + k);
    return c.slot.num + c.kind;
}

"""The imported str field through the erased slot."""
def lib_name_len(k: int) -> int {
    c = build(k);
    return len(c.slot.name);
}

with entry {
    assert local_built(1) == 91;
    assert lib_built(0) == 15;
    assert lib_name_len(0) == 3;
    print("ok");
}
