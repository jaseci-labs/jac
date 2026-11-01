"""`list.extend` reads its source through the same coercion every other method uses.

A dict's value slot is erased, so iterating `d.values()` yields a raw box even
where the declared value type is a list. `extend` read the length header off
that box directly instead of unboxing it the way `append`, `insert` and the
spread helpers do, so the shape read as "extend is not lowered" when in fact
only the erased-source case was missing.

That is the exact shape the capability check uses to flatten its per-owner
violation map:

    _demotable: dict[int, list[...]];
    for _unit_viols in _demotable.values() {
        _report.extend(_unit_viols);
    }

The source is coerced to the target's list type when it does not already hold
a list. `extend_plain_list` pins the already-typed path, which never went
through the box and must not start now.
"""

import ctypes;
import from tests.support { compile_native, native_address }

glob _ENGINE: list[any] = [];


"""JIT the fixture once; return its execution engine."""
def engine -> any {
    if _ENGINE {
        return _ENGINE[0];
    }
    (eng, _) = compile_native("list_extend_boxed.jac");
    _ENGINE.append(eng);
    return eng;
}


"""A fixture function taking one bool and returning an i64."""
def flag_fn(name: str) -> any {
    addr = native_address(engine(), name);
    assert addr != 0 , f"'{name}' is absent from the JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_bool)(addr);
}


test "extending from a dict's list values lands every element" {
    fn = flag_fn("count_str_lists");
    assert fn(True) == 3 , f"expected 3 elements, got {fn(True)}";
    assert fn(False) == 0 , f"the un-extended arm gave {fn(False)}, expected 0";
}


test "the elements pulled through the box are usable" {
    fn = flag_fn("extend_str_lists");
    assert fn(True) == 6 , (
        f"summing len() over the extended list gave {fn(True)}, expected 6 -- "
        "the slots do not hold usable strings"
    );
    assert fn(False) == 0 , f"the un-extended arm gave {fn(False)}, expected 0";
}


test "a list of tuples extends through the same erased slot" {
    fn = flag_fn("count_tuple_lists");
    assert fn(True) == 3 , f"expected 3 tuples, got {fn(True)}";
    assert fn(False) == 0 , f"the un-extended arm gave {fn(False)}, expected 0";
}


test "an already-typed source still extends without the coercion" {
    fn = flag_fn("extend_plain_list");
    assert fn(True) == 16 , f"expected 1+4+5+6, got {fn(True)}";
    assert fn(False) == 1 , f"the un-extended arm gave {fn(False)}, expected 1";
}
