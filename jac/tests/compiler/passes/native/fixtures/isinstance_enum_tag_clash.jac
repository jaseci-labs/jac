"""An enum union where the enum does NOT own the int tag alone.

`int` claims jacval tags 0 and 7, and an enum member boxes as tag 0, so a bare
tag compare cannot tell `Access.PUBLIC` from `3`. The backend has to refuse
this rather than answer `True` for a plain int, which is what a classification
that skipped the sole-ownership test would do.
"""

enum Access { PRIVATE = 'private', PUBLIC = 'public' }

def chk_enum_over_int(pick: int) -> bool {
    spec: (Access | int) = 0;
    if pick == 1 {
        spec = Access.PUBLIC;
    }
    return isinstance(spec, Access);
}
