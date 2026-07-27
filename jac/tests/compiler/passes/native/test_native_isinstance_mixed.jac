"""Behavioral tests for isinstance over mixed builtin + archetype tuples.

Graduated from the E5092 guardrail (`isinstance mixed tuple unsupported type
errors` in test_native_gen_pass.jac): the mixed form now lowers as a guarded
disjunction — JacVal tag compares for the builtin arms, and a vtable identity
compare (behind an object-tag branch, so it never dereferences a non-pointer
payload) for the archetype arms.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

"""Compile a .na.jac fixture and return the JIT engine."""
def compile_native(fixture: str) -> tuple[ExecutionEngine, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: object, name: str, restype: type | None, *argtypes: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

test "isinstance mixed: builtin arm matches int and bool, rejects str/None" {
    (eng, _) = compile_native("isinstance_mixed.na.jac");
    f = get_func(eng, "chk_int_foo", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1 , "int must match the int arm";
    assert f(1) == 0 , "str must not match (int, Foo)";
    assert f(5) == 1 , "bool must match the int arm (Python semantics)";
    assert f(6) == 0 , "None must not match (int, Foo)";
}

test "isinstance mixed: archetype arm matches exact type and subtype" {
    (eng, _) = compile_native("isinstance_mixed.na.jac");
    f = get_func(eng, "chk_int_foo", ctypes.c_int64, ctypes.c_int64);
    assert f(2) == 1 , "Foo instance must match the Foo arm";
    assert f(3) == 1 , "Sub(Foo) instance must match the Foo arm via MRO";
    assert f(4) == 0 , "unrelated archetype must not match (int, Foo)";
}

test "isinstance mixed: str + archetype tuple" {
    (eng, _) = compile_native("isinstance_mixed.na.jac");
    f = get_func(eng, "chk_str_other", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1 , "str must match the str arm";
    assert f(1) == 1 , "Other instance must match the Other arm";
    assert f(2) == 0 , "Foo must not match (str, Other)";
}

test "isinstance mixed: hierarchy-less target forces vtable materialization" {
    (eng, _) = compile_native("isinstance_mixed.na.jac");
    f = get_func(eng, "chk_lone", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1 , "Lone instance must match its own arm";
    assert f(1) == 1 , "float must match the float arm";
}

test "isinstance mixed: statically typed struct operand" {
    (eng, _) = compile_native("isinstance_mixed.na.jac");
    f = get_func(eng, "chk_typed_operand", ctypes.c_int64);
    assert f() == 1 , "Sub-typed operand must match the Foo arm";
}
