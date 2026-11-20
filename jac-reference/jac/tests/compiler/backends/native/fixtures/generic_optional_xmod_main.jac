"""Reading an imported generic archetype's optional erased slot.

The importer never sees the library's layout registry, so the slot it writes
through its own constructor call and the slot the library wrote are two
separate stores that have to agree. `lib_name_len` additionally reads a `str`
payload back out of a slot this module never touched.
"""

import from generic_optional_xmod_lib { Ctx, Leaf, build }

"""A cell the importer constructed, read through its own type argument."""
def local_built(k: int) -> int {
    c = Ctx[Leaf](value=Leaf(num=10 + k, name="local"), tag=3);
    if c.value is not None {
        return c.value.num + c.tag;
    }
    return -1;
}

"""A cell the library constructed, read on this side of the import."""
def lib_built(k: int) -> int {
    c = build(20 + k);
    if c.value is not None {
        return c.value.num + c.tag;
    }
    return -1;
}

"""A str payload out of a slot only the library ever wrote."""
def lib_name_len(k: int) -> int {
    c = build(k);
    if c.value is not None {
        return len(c.value.name);
    }
    return -1;
}

with entry {
    assert local_built(0) == 13;
    assert lib_built(0) == 60;
    assert lib_name_len(0) == 3;
    print("ok");
}
