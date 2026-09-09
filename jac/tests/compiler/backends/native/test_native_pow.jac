"""Native exponentiation (`**`) parity tests.

Regression coverage for the power-lowering seam in
`na_ir_gen_pass.impl/math.impl.jac` and the `int ** int` type contract in
`compiler/types/operations.jac`. Each case compiles a fixture that
previously lowered to invalid/unsound IR and asserts the JIT result against
CPython semantics: literal & dynamic exponents, builtin `pow`, `**=`, the
fixed-width i32 kernel, float power, and the zero-base ZeroDivisionError.
"""

import ctypes;
import os;
import from tests.support { JAC_ROOT, TESTS_DIR, native_force_opts }
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.backends.native.llvm.binding { ExecutionEngine }
import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
import from jaclang.compiler.driver.pass_driver { run_pass }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     CHECKER_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "fixtures", "checker"
     ),
     _POW_SEMANTICS_ENG: (ExecutionEngine | None) = None,
     _POW_SEMANTICS_IR: (uni.Module | None) = None;

"""Compile pow_semantics.jac once and cache the JIT engine."""
def pow_semantics_engine -> tuple[ExecutionEngine, uni.Module] {
    if _POW_SEMANTICS_ENG is None {
        prog = JacProgram();
        ir = prog.compile(
            file_path=str(os.path.join(FIXTURES, "pow_semantics.jac")),
            options=native_force_opts()
        );
        errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
        assert not prog.errors_had , f"Compilation errors in pow_semantics.jac: {errors}";
        eng = ir.gen.native_engine;
        assert eng is not None , "No native engine produced for pow_semantics.jac";
        _POW_SEMANTICS_ENG = eng;
        _POW_SEMANTICS_IR = ir;
    }
    eng_out = _POW_SEMANTICS_ENG;
    ir_out = _POW_SEMANTICS_IR;
    assert eng_out is not None and ir_out is not None;
    return (eng_out, ir_out);
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(
    eng: ExecutionEngine, name: str, restype: type | None, *argtypes: type
) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

"""Compile a checker fixture and run the type check pass."""
def compile_and_check(fixture_name: str) -> JacProgram {
    program = JacProgram();
    mod = program.compile(os.path.join(CHECKER_FIXTURES, fixture_name));
    run_pass(TypeCheckPass, mod, program);
    return program;
}

# int ** non-negative literal stays int and matches CPython.
test "pow: int ** non-negative literal is int" {
    (eng, _) = pow_semantics_engine();
    get_func(eng, "jac_entry", None)();
    pos = get_func(eng, "ipow_pos", ctypes.c_int64);
    assert pos() == 8;
    sq = get_func(eng, "ipow_sq", ctypes.c_int64);
    assert sq() == 49;
    one = get_func(eng, "ipow_one", ctypes.c_int64);
    assert one() == 1;
}

# int ** negative literal is float (Python: 4 ** -2 == 0.0625).
test "pow: int ** negative literal is float" {
    (eng, _) = pow_semantics_engine();
    get_func(eng, "jac_entry", None)();
    neg = get_func(eng, "ipow_neg", ctypes.c_double);
    assert neg() == 0.0625;
}

# int ** dynamic exponent is float and follows the runtime sign of exp.
test "pow: int ** dynamic exponent follows runtime sign" {
    (eng, _) = pow_semantics_engine();
    get_func(eng, "jac_entry", None)();
    dyn = get_func(eng, "ipow_dyn", ctypes.c_double, ctypes.c_int64, ctypes.c_int64);
    assert dyn(2, 3) == 8.0;
    assert dyn(2, -1) == 0.5;
    assert dyn(3, 0) == 1.0;
}

# i32 ** i32 exercises the fixed-width kernel without an i64 widen.
test "pow: fixed-width i32 kernel matches at true width" {
    (eng, _) = pow_semantics_engine();
    get_func(eng, "jac_entry", None)();
    d = get_func(eng, "ipow_i32_dyn", ctypes.c_double, ctypes.c_int32, ctypes.c_int32);
    assert d(2, 3) == 8.0;
    assert d(5, 2) == 25.0;
}

# float ** float and builtin pow(float, float) lower to libm pow.
test "pow: float operands use libm pow" {
    (eng, _) = pow_semantics_engine();
    get_func(eng, "jac_entry", None)();
    fp = get_func(eng, "fpow", ctypes.c_double, ctypes.c_double, ctypes.c_double);
    assert fp(2.0, 3.0) == 8.0;
    assert fp(9.0, 0.5) == 3.0;
    bp = get_func(eng, "bpow", ctypes.c_double, ctypes.c_double, ctypes.c_double);
    assert bp(2.0, 10.0) == 1024.0;
}

# builtin pow(int, int) matches operator `**` for constant exponents.
test "pow: builtin pow(int, int) matches operator" {
    (eng, _) = pow_semantics_engine();
    get_func(eng, "jac_entry", None)();
    bip = get_func(eng, "bpow_int", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert bip(2, 10) == 1024;
    assert bip(3, 3) == 27;
}

# `**=` lowers through the shared scalar-aug helper for both int and float.
test "pow: augmented assignment (**=) for int and float" {
    (eng, _) = pow_semantics_engine();
    get_func(eng, "jac_entry", None)();
    ia = get_func(eng, "ipow_aug", ctypes.c_int64, ctypes.c_int64);
    assert ia(2) == 8;
    assert ia(3) == 27;
    fa = get_func(eng, "fpow_aug", ctypes.c_double, ctypes.c_double);
    assert fa(3.0) == 9.0;
    assert fa(5.0) == 25.0;
}

# field, list, and dict `**=` route through the shared power seam.
test "pow: field list and dict augmented assignment" {
    (eng, _) = pow_semantics_engine();
    get_func(eng, "jac_entry", None)();
    field_fn = get_func(eng, "field_ipow_aug", ctypes.c_int64);
    assert field_fn() == 8;
    list_fn = get_func(eng, "list_ipow_aug", ctypes.c_int64);
    assert list_fn() == 8;
    dict_fn = get_func(eng, "dict_ipow_aug", ctypes.c_int64);
    assert dict_fn() == 8;
}

# 0 ** negative raises ZeroDivisionError (literal and dynamic exponent).
test "pow: zero base with negative exponent raises ZeroDivisionError" {
    (eng, _) = pow_semantics_engine();
    get_func(eng, "jac_entry", None)();
    lit = get_func(eng, "ipow_zero_base_neg", ctypes.c_int64);
    assert lit() == 1;
    dyn = get_func(eng, "ipow_zero_base_dyn", ctypes.c_int64);
    assert dyn() == 1;
    bpow_zero = get_func(eng, "bpow_zero_neg", ctypes.c_int64);
    assert bpow_zero() == 1;
    fpow_zero = get_func(eng, "fpow_zero_dyn", ctypes.c_int64);
    assert fpow_zero() == 1;
}

# Invalid `**=` that would truncate float results is rejected at compile time.
test "pow: negative **= on int rejects with E1001" {
    program = compile_and_check("checker_pow_aug_type_errors.jac");
    e1001 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1001"
    ];
    assert len(e1001) >= 2 , f"Expected >=2 E1001 for invalid **=, got {len(e1001)}";
}
