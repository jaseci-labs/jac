"""An enum union where the enum does NOT own the int tag alone.

`int` claims jacval tags 0 and 7, and under the old backend an enum member
boxed as tag 0, so a bare tag compare could not tell `Access.PUBLIC` from `3`
and the check was refused. MIR boxes an enum member under a tag of its own and
tests the member's enum by name, so `chk_enum_over_int` lowers and must answer
`False` for a plain int.

`chk_protocol` asks about a protocol (`Iterable`), which no tag or class name
answers natively, so it is refused and demotes to its Python implementation.
"""

enum Access { PRIVATE = 'private', PUBLIC = 'public' }

def chk_enum_over_int(pick: int) -> bool {
    spec: (Access | int) = 0;
    if pick == 1 {
        spec = Access.PUBLIC;
    }
    return isinstance(spec, Access);
}

def chk_protocol(pick: int) -> bool {
    spec: (Access | int) = 0;
    if pick == 1 {
        spec = Access.PUBLIC;
    }
    return isinstance(spec, Iterable);
}
