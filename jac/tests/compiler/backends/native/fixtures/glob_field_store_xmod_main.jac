"""Fixture: storing into a field of an object glob another module declares.

The consumer assigns each imported glob's `handle` from a field of one of its
own globals, the shape the JacPython zlib and bz2 bindings use for their
defining-class tokens (#9596). Lowering `execute` used to raise
`'IntType' object has no attribute 'is_opaque'`.
"""

import from glob_field_store_xmod_holder { First, Second }
import from glob_field_store_xmod_definition { Definition }

glob first_def = Definition(),
     second_def = Definition();

def execute -> int {
    First.handle = first_def.handle;
    Second.handle = second_def.handle;
    return 0;
}

with entry {
    print(execute());
    print(First.handle == first_def.handle);
    print(Second.handle == second_def.handle);
}
