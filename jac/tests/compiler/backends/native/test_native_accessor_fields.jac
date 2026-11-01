"""Behavioral tests for accessor (`{ getter; setter; }`) fields (#8074).

A property has no instance storage on the Python side, so the native lowering
must run the accessor body on every read and every write. The failure this
pins is a *well-typed wrong value*: before the fix a property occupied a data
slot and `b.doubled` compiled to a raw load of that never-written slot, which
reads garbage rather than failing to compile. So every assertion here checks a
value through the JIT, and the expected numbers are the ones the bytecode
backend produces for the same fixture (`accessor_fields.jac` asserts them in
its own `with entry`).

`neighbour_fields_intact` is the layout half: `tail` is declared after two
accessors, so it only reads back as `11` if properties took no slots.
"""

import ctypes;
import from tests.support { compile_native, native_address }

glob _ENGINE_MEMO: list[any] = [];

"""Compile the accessor fixture once and hand back its JIT engine."""
def accessor_engine -> tuple[any, any] {
    if _ENGINE_MEMO {
        return _ENGINE_MEMO[0];
    }
    (eng, fx) = compile_native("accessor_fields.jac");
    _ENGINE_MEMO.append((eng, fx, ));
    return (eng, fx);
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: any, name: str, restype: type | None, *argtypes: type) -> any {
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(restype, *argtypes)(addr);
}


test "accessor with no backing field computes from other fields" {
    (eng, _) = accessor_engine();
    f = get_func(eng, "read_computed", ctypes.c_int64, ctypes.c_int64);
    assert f(9) == 18 , "b.doubled runs the getter over the live head";
    assert f(0) == 0 , "a zero head is a zero result, not a stale slot";
}


test "accessor over a backing slot reads the backing slot" {
    (eng, _) = accessor_engine();
    f = get_func(eng, "read_backed", ctypes.c_int64);
    assert f() == 3 , "b.width returns _width's default, not an unwritten slot";
}


test "assigning an accessor field runs the setter body" {
    (eng, _) = accessor_engine();
    f = get_func(eng, "write_through_setter", ctypes.c_int64, ctypes.c_int64);
    assert f(4) == 40 , "the setter multiplies by ten before storing";
    r = get_func(eng, "roundtrip_setter", ctypes.c_int64, ctypes.c_int64);
    assert r(4) == 40 , "reading back after the setter goes through the getter";
}


test "a property takes no data slot, so later fields do not shift" {
    (eng, _) = accessor_engine();
    f = get_func(eng, "neighbour_fields_intact", ctypes.c_int64);
    assert f() == 7011 , "head is 7 and tail is 11 across two intervening properties";
}


test "accessors resolve the same way inside a method body" {
    (eng, _) = accessor_engine();
    f = get_func(eng, "accessors_from_method", ctypes.c_int64);
    assert f() == 82 , "doubled 14 + width 50 + head 7 + tail 11";
}


test "an overridden accessor dispatches on the runtime class" {
    (eng, _) = accessor_engine();
    f = get_func(eng, "inherited_accessor", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 101 , "Tagged.label.getter";
    assert f(1) == 102 , "Renamed.label.getter overrides it";
}
