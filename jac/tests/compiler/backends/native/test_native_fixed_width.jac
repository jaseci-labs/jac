"""Native lowering of the fixed-width numeric contract (#8532).

Unsigned types lower with unsigned instructions, every sized operation traps
on overflow, T(x) is a range-checked cast, T.wrap and wrapping_* are modular,
and f32 rounds to binary32 after every operation. Each probe lives in
fixtures/fixed_width_unsigned.jac and is JIT-compiled once.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_address, native_force_opts }
import from jaclang.compiler.driver.program { JacProgram }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.backends.native.llvm.binding { ExecutionEngine }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     _ENG: (ExecutionEngine | None) = None;

def engine -> ExecutionEngine {
    if _ENG is None {
        prog = JacProgram();
        ir = prog.compile(
            file_path=str(os.path.join(FIXTURES, "fixed_width_unsigned.jac")),
            options=native_force_opts()
        );
        errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
        assert not prog.errors_had , f"Compilation errors: {errors}";
        eng = ir.gen.native_engine;
        assert eng is not None , "No native engine produced";
        _ENG = eng;
    }
    out = _ENG;
    assert out is not None;
    return out;
}

def probe(name: str) -> int {
    eng = engine();
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64)(addr)();
}

def probe_f(name: str) -> float {
    eng = engine();
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_double)(addr)();
}

test "unsigned arithmetic traps on overflow instead of wrapping" {
    assert probe("u8_add_traps") == 1;
    assert probe("u8_sub_traps") == 1;
    assert probe("i32_max_plus_one_traps") == 1;
    assert probe("i32_aug_traps") == 1;
}

test "unsigned values compare and shift as unsigned" {
    assert probe("u64_compares_unsigned") == 1;
    assert probe("u64_max_above_zero") == 1;
    assert probe("u8_logical_shift") == 100;
    assert probe("i8_arith_shift") == -1;
}

test "division and modulo use the operand's signedness" {
    assert probe_f("u32_truediv_is_float") == 3.5;
    assert probe("u8_floordiv_mod") == 66002;
    assert probe("i8_floor_semantics") == -3999;
    assert probe("i8_min_div_m1_traps") == 1;
    assert probe("i8_min_mod_m1") == 7;
}

test "negation and abs trap at the signed minimum" {
    assert probe("i8_neg_min_traps") == 1;
    assert probe("i8_abs_min_traps") == 1;
}

test "shifts and powers range-check" {
    assert probe("u8_shl_overflow_traps") == 1;
    assert probe("u8_shift_count_traps") == 1;
    assert probe("u8_pow_traps") == 1;
    assert probe("u8_pow_fits") == 128;
}

test "T(x) is a checked cast and T.wrap is modular" {
    assert probe("cast_u8_300_traps") == 1;
    assert probe("cast_u8_negative_traps") == 1;
    assert probe("cast_i8_from_u8_traps") == 1;
    assert probe("cast_float_truncates") == -3;
    assert probe("cast_float_out_of_range_traps") == 1;
    assert probe("u8_wrap_300") == 44;
    assert probe("i8_wrap_200") == -56;
    assert probe("u8_invert_zero") == 255;
}

test "widening follows the source signedness" {
    assert probe("widen_keeps_sign") == -5;
    assert probe("widen_unsigned_zero_extends") == 200200;
    assert probe("literal_adopts_i32") == 2;
}

test "the wrapping family never traps and MIN/MAX fold to constants" {
    assert probe("wrapping_family") == -56 + 255000 + 0 + 1000000 + 1280;
    assert probe("bounds") == -128 + 65535 + 2147;
}

test "f32 rounds to binary32 after every operation" {
    assert probe_f("f32_literal_rounds") == 0.10000000149011612;
    assert probe_f("f32_rounds_per_op") == 0.30000001192092896;
}

test "plain int keeps its pre-existing lowering: shifts, negation, abs and pow do not trap" {
    assert probe("plain_int_is_not_sized") == 4;
}
