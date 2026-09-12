"""Behavioral tests for isinstance over mixed builtin + archetype tuples.

Graduated from the E5092 guardrail (`isinstance mixed tuple unsupported type
errors` in test_native_gen_pass.jac): the mixed form now lowers as a guarded
disjunction — JacVal tag compares for the builtin arms, and a vtable identity
compare (behind an object-tag branch, so it never dereferences a non-pointer
payload) for the archetype arms.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, compile_native, get_func, native_force_opts }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

test "isinstance recognizes native string fields locals parameters and optionals" {
    (eng, _) = compile_native("isinstance_mixed.jac");
    assert get_func(eng, "chk_string_representations", ctypes.c_int64)() == 127;
}

test "isinstance mixed: builtin arm matches int and bool, rejects str/None" {
    (eng, _) = compile_native("isinstance_mixed.jac");
    f = get_func(eng, "chk_int_foo", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1 , "int must match the int arm";
    assert f(1) == 0 , "str must not match (int, Foo)";
    assert f(5) == 1 , "bool must match the int arm (Python semantics)";
    assert f(6) == 0 , "None must not match (int, Foo)";
}

test "isinstance mixed: archetype arm matches exact type and subtype" {
    (eng, _) = compile_native("isinstance_mixed.jac");
    f = get_func(eng, "chk_int_foo", ctypes.c_int64, ctypes.c_int64);
    assert f(2) == 1 , "Foo instance must match the Foo arm";
    assert f(3) == 1 , "Sub(Foo) instance must match the Foo arm via MRO";
    assert f(4) == 0 , "unrelated archetype must not match (int, Foo)";
}

test "isinstance mixed: str + archetype tuple" {
    (eng, _) = compile_native("isinstance_mixed.jac");
    f = get_func(eng, "chk_str_other", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1 , "str must match the str arm";
    assert f(1) == 1 , "Other instance must match the Other arm";
    assert f(2) == 0 , "Foo must not match (str, Other)";
}

test "isinstance mixed: hierarchy-less target forces vtable materialization" {
    (eng, _) = compile_native("isinstance_mixed.jac");
    f = get_func(eng, "chk_lone", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1 , "Lone instance must match its own arm";
    assert f(1) == 1 , "float must match the float arm";
}

test "isinstance mixed: statically typed struct operand" {
    (eng, _) = compile_native("isinstance_mixed.jac");
    f = get_func(eng, "chk_typed_operand", ctypes.c_int64);
    assert f() == 1 , "Sub-typed operand must match the Foo arm";
}
