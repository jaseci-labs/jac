"""Behavioral tests for operator-overload dispatch on archetypes (#7626 B3).

Binary operators on archetype operands lower as static dunder calls:
the left operand's magic method resolves through the MRO (the same walk
class patterns use); when the left type has no matching dunder, the
right operand's reflected form dispatches with swapped operands.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, compile_native, get_func, native_force_opts }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

test "operator dunder: a + b dispatches __add__" {
    (eng, _) = compile_native("operator_dunders.jac");
    f = get_func(eng, "add_vecs", ctypes.c_int64);
    assert f() == 3142 , "Vec(1,2) + Vec(30,40) == Vec(31,42)";
}

test "operator dunder: a * k dispatches __mul__" {
    (eng, _) = compile_native("operator_dunders.jac");
    f = get_func(eng, "mul_vec", ctypes.c_int64);
    assert f() == 1520 , "Vec(3,4) * 5 == Vec(15,20)";
}

test "operator dunder: reflected __radd__ dispatches with swapped operands" {
    (eng, _) = compile_native("operator_dunders.jac");
    f = get_func(eng, "radd_vec", ctypes.c_int64);
    assert f() == 1314 , "Tag(10) + Vec(3,4) == Vec(13,14) via Vec.__radd__";
}

test "operator dunder: inherited __add__ resolves through the MRO" {
    (eng, _) = compile_native("operator_dunders.jac");
    f = get_func(eng, "inherited_add", ctypes.c_int64);
    assert f() == 809 , "Vec3(7,8) + Vec(1,1) == Vec(8,9)";
}
