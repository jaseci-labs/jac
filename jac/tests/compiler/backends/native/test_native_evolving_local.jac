"""An unannotated local whose bindings disagree on their native type is boxed.

The slot took the native type of the first assignment. `v = None; v = "7";
v = int(...)` got a text slot, the int was stored with `inttoptr`, and the next
overwrite released the int as if it were a string, crashing the process. The
slot now joins every binding of the local: when the values disagree on their
lowered type the local is an `any` box, as if it were annotated with the union.
A local bound to one type, or to one type and None, keeps its direct slot.
Only a local first bound to None can be rebound to another type, so the join
only ever widens those.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "an unannotated local bound to disagreeing types is boxed" {
    (eng, _ir) = compile_native("evolving_local.jac");
    assert get_func(eng, "mixed_member_values", ctypes.c_int64)() == 223;
    assert get_func(eng, "optional_str_stays_text", ctypes.c_int64)() == 5;
    assert get_func(eng, "one_type_stays_scalar", ctypes.c_int64)() == 42;
}
