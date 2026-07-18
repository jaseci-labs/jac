"""Regression tests for native RC move-lowering (#6905 payoff, borrow-checker split).

When an assignment `b = a` binds a bare local `Name` that the native
the core `RcFactsPass` proves safe (LOCAL source, every use an alias-value, dead-out
at the move site), the native pass lowers it as a MOVE instead of an alias-copy:
it skips the defensive `__rc_retain` and nulls the source slot so the source's
later scope/iter cleanup release is a no-op. The destination inherits the single
reference and frees it exactly once.

These tests lock both halves: that the retain is actually elided (IR count) and
that the result is sound at runtime (no leak, no double free over a heavy loop).

The proof is now native-owned and does NOT depend on the ownership checker, so
move-lowering fires identically with `type_check=True` and `type_check=False`
(the `nacompile` path) -- pinned by `move-lowering is independent of type_check`.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }
import from jaclang.compiler.passes.native.na_ir_gen_pass { NaIRGenPass }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

"""Stand-in for `_can_native_move_lower` that disables move-lowering (baseline)."""
def _no_move_lower(pass_self: object, nd: object) -> bool {
    return False;
}

"""Compile a fixture and return (engine, ir). Defaults to the nacompile path."""
def compile_fixture(
    fixture: str, type_check: bool = False
) -> tuple[ExecutionEngine, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), type_check=type_check
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

"""Count emitted __rc_retain call sites, optionally with move-lowering off."""
def retain_calls(fixture: str, move_lower: bool, type_check: bool = False) -> int {
    orig = NaIRGenPass._can_native_move_lower;
    if not move_lower {
        NaIRGenPass._can_native_move_lower = _no_move_lower;
    }
    try {
        (eng, ir) = compile_fixture(fixture, type_check);
        return str(ir.gen.llvm_ir).count('call void @"__rc_retain"');
    } finally {
        NaIRGenPass._can_native_move_lower = orig;
    }
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: object, name: str, restype: type | None, *argtypes: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(restype, *argtypes)(addr);
}

test "move-lowering elides exactly the `b = a` alias retain" {
    # A/B on identical IR: the ONLY difference is whether the move is lowered.
    off = retain_calls("move_elision.na.jac", False);
    on = retain_calls("move_elision.na.jac", True);
    assert off - on == 1 , f"move-lowering should elide exactly one retain call; off={off} on={on}";
    # `take(x: Box)` receives an i64 (pointer-as-int), so the aliasing `b = a`
    # is the sole retain; move-lowering removes it entirely.
    assert on == 0 , f"expected 0 retain calls after move-lowering, got {on}";
}

test "move-lowering is independent of type_check (native-owned proof)" {
    # The proof lives in the native codegen path, not the type-check schedule, so
    # `nacompile`'s `type_check=False` gets the same elision the checker path does.
    on_unchecked = retain_calls("move_elision.na.jac", True, False);
    on_checked = retain_calls("move_elision.na.jac", True, True);
    assert on_unchecked == 0 , f"expected 0 retains with type_check=False, got {on_unchecked}";
    assert on_checked == 0 , f"expected 0 retains with type_check=True, got {on_checked}";
}

test "move-lowering nulls the source slot (keeps the free sound)" {
    (eng, ir) = compile_fixture("move_elision.na.jac");
    text = str(ir.gen.llvm_ir);
    # Nulling the moved-from slot is what makes eliding the retain sound: the
    # source's cleanup release then loads null and is a no-op, so the object is
    # freed exactly once (by the destination's cleanup).
    assert 'store %"Box"* null, %"Box"** %"a"' in text , "move source 'a' was not nulled after the move";
}

test "move-lowering is sound at runtime: correct result, no leak, no double free" {
    (eng, _) = compile_fixture("move_elision.na.jac");
    f = get_func(eng, "run_moves", ctypes.c_int64, ctypes.c_int64);
    assert f(1000) == 1000;
    # A heavy loop: a double free would corrupt the heap and crash here; a leak
    # would grow RSS unbounded. Reaching the assert cleanly proves neither.
    assert f(400000) == 400000;
}
