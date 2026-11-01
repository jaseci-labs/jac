"""`isinstance` lowers when the operand is optional.

An optional is None or a present payload, so the check has to test presence
first: `None` is an instance of nothing, and the payload is only inspected
when one is present (the user-archetype path reads a vtable pointer off the
object, so an unguarded unwrap would dereference an undefined payload). Most
tree navigation returns optionals, so an `isinstance` on a `T | None` value
must lower rather than demote its function.

Refs #8039
"""

import ctypes;
import from tests.support { compile_mir, compile_native, get_func }

test "isinstance on an optional: None is an instance of nothing" {
    (eng, _) = compile_native("isinstance_optional.jac");
    f = get_func(eng, "opt_single", ctypes.c_bool, ctypes.c_int64);
    assert f(1) is True , "Leaf should match";
    assert f(2) is False , "Twig should not match Leaf";
    assert f(0) is False , "None must be False, not a crash";
}

test "isinstance on an optional against a class tuple" {
    (eng, _) = compile_native("isinstance_optional.jac");
    f = get_func(eng, "opt_tuple", ctypes.c_bool, ctypes.c_int64);
    assert f(1) is True;
    assert f(2) is True;
    assert f(0) is False;
}

test "the none-branch never inspects the payload" {
    (eng, _) = compile_native("isinstance_optional.jac");
    f = get_func(eng, "opt_negative", ctypes.c_bool, ctypes.c_int64);
    # pick=0 leaves the option empty; an unguarded unwrap would read a vtable
    # off an undefined payload here.
    assert f(0) is False;
    assert f(1) is False;
}

test "an optional crosses into a static method and still narrows" {
    (eng, _) = compile_native("isinstance_optional.jac");
    f = get_func(eng, "opt_through_static", ctypes.c_bool, ctypes.c_int64);
    assert f(1) is True;
    assert f(0) is False;
}

test "the optional-isinstance fixture lowers with nothing demoted" {
    demoted = compile_mir("isinstance_optional.jac").demoted();
    assert not demoted , str(demoted);
}
