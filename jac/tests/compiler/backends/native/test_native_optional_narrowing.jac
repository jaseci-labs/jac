"""Congruence tests for flow-sensitive optional narrowing in jac native.

The sv/bytecode backend already narrows: after a test that proves an optional
is non-None, uses of that value on the proven path see the narrowed type. The
native backend saw the JacOpt/JacVal box instead, so idiomatic guarded code
either failed to lower or forced the author to launder the value through a
typed rebind.

Every behavioral test here compares the native result against the sv result
for the same fixture, so the assertions are a real congruence gate rather than
hardcoded constants. `narrowing removes the tag check` pins the payoff: with
narrowing disabled the same fixture emits checked unwraps, and with it on the
proven uses emit none.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, compile_native, names_function, native_address, native_force_opts }
import jaclang;

import from jaclang.runtime.runtime { JacRuntime }

import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "optional_narrowing.jac";

"""Import the same fixture on the sv/bytecode path for congruence."""
def sv_module -> any {
    return JacRuntime.jac_import(target=FIXTURE[:-4], base_path=FIXTURES)[0];
}

"""Get a ctypes-callable int -> int function from the JIT engine."""
def get_func(eng: any, name: str) -> any {
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
}

"""Assert native and sv agree on `name` over `inputs`, and return the values."""
def congruent(eng: any, sv: object, name: str, inputs: list[int]) -> list[int] {
    native_fn = get_func(eng, name);
    sv_fn = getattr(sv, name);
    out: list[int] = [];
    for n in inputs {
        got = native_fn(n);
        want = sv_fn(n);
        assert got == want , (
            f"{name}({n}): native returned {got}, sv returned {want}"
        );
        out.append(got);
    }
    return out;
}

"""Slice one function's body out of a printed LLVM module."""
def func_ir(llvm_ir: str, name: str) -> str {
    out: list[str] = [];
    inside = False;
    for line in str(llvm_ir).split("\n") {
        if not inside and line.startswith("define ") and names_function(line, name) {
            inside = True;
        }
        if inside {
            out.append(line);
            if line.startswith("}") {
                break;
            }
        }
    }
    assert out , f"function '{name}' not found in the emitted module";
    return "\n".join(out);
}

"""Stand-in for `_narrowed_flow_type` that disables narrowing (baseline)."""
def _no_narrowing(pass_self: any, nd: any) -> any {
    return None;
}

test "pointer optional: `is None` early-return guard narrows the fall-through" {
    (eng, _) = compile_native(FIXTURE);
    sv = sv_module();
    vals = congruent(eng, sv, "ptr_guard_is_none", [0, 1, 3]);
    assert vals == [-1, 1, 3] , f"unexpected ptr_guard_is_none results: {vals}";
}

test "pointer optional: `is not None` positive branch narrows the body" {
    (eng, _) = compile_native(FIXTURE);
    sv = sv_module();
    vals = congruent(eng, sv, "ptr_is_not_none", [0, 1, 3]);
    assert vals == [-1, 1, 3] , f"unexpected ptr_is_not_none results: {vals}";
}

test "pointer optional: if/else narrows both branches" {
    (eng, _) = compile_native(FIXTURE);
    sv = sv_module();
    vals = congruent(eng, sv, "ptr_if_else", [0, 2, 5]);
    assert vals == [-1, 20, 50] , f"unexpected ptr_if_else results: {vals}";
}

test "pointer optional: plain truthiness narrows the true branch" {
    (eng, _) = compile_native(FIXTURE);
    sv = sv_module();
    vals = congruent(eng, sv, "ptr_truthy", [0, 2, 4]);
    assert vals == [-1, 102, 104] , f"unexpected ptr_truthy results: {vals}";
}

test "pointer optional: `!= None` narrows like `is not None`" {
    (eng, _) = compile_native(FIXTURE);
    sv = sv_module();
    vals = congruent(eng, sv, "ptr_ne_none", [0, 2, 4]);
    assert vals == [-1, 202, 204] , f"unexpected ptr_ne_none results: {vals}";
}

test "scalar optional: `is None` early-return guard narrows the fall-through" {
    (eng, _) = compile_native(FIXTURE);
    sv = sv_module();
    vals = congruent(eng, sv, "scalar_guard", [0, 1, 4]);
    assert vals == [-1, 4, 13] , f"unexpected scalar_guard results: {vals}";
}

test "scalar optional: early `continue` narrows the rest of the loop body" {
    (eng, _) = compile_native(FIXTURE);
    sv = sv_module();
    vals = congruent(eng, sv, "scalar_continue_guard", [0, 3, 5]);
    assert vals == [0, 3, 18] , f"unexpected scalar_continue_guard results: {vals}";
}

test "scalar optional: early `raise` narrows the fall-through" {
    (eng, _) = compile_native(FIXTURE);
    sv = sv_module();
    vals = congruent(eng, sv, "scalar_raise_guard", [1, 3]);
    assert vals == [5, 11] , f"unexpected scalar_raise_guard results: {vals}";
}

test "isinstance narrows a boxed union to the tested member" {
    (eng, _) = compile_native(FIXTURE);
    sv = sv_module();
    vals = congruent(eng, sv, "iso_any", [0, 2, 5]);
    assert vals == [-1, 9, 21] , f"unexpected iso_any results: {vals}";
}

test "a redundant `is None` on a proven value still reads the tag" {
    (eng, _) = compile_native(FIXTURE);
    sv = sv_module();
    vals = congruent(eng, sv, "redundant_guard", [0, 1, 2]);
    assert vals == [-1, 6, 9] , f"unexpected redundant_guard results: {vals}";
}

test "a redundant `is None` on a proven zero payload is still False" {
    (eng, _) = compile_native(FIXTURE);
    sv = sv_module();
    vals = congruent(eng, sv, "zero_payload_redundant_guard", [0, 1, 5]);
    assert vals == [-1, 7, 7] , (
        f"unexpected zero_payload_redundant_guard results: {vals}"
    );
}

test "`is None` as a value never compares against a narrowed payload" {
    (eng, _) = compile_native(FIXTURE);
    sv = sv_module();
    vals = congruent(eng, sv, "zero_payload_none_test_value", [0, 1, 5]);
    assert vals == [-1, 9, 9] , (
        f"unexpected zero_payload_none_test_value results: {vals}"
    );
    # a float payload is the case that actually miscompiles if the operand of
    # a None test is narrowed: `x is None` becomes `fcmp une x, 0.0`
    fvals = congruent(eng, sv, "float_none_test_value", [0, 2, 4]);
    assert fvals == [-1, 11, 13] , (
        f"unexpected float_none_test_value results: {fvals}"
    );
}

test "truthiness of a proven container stays len > 0" {
    (eng, _) = compile_native(FIXTURE);
    sv = sv_module();
    vals = congruent(eng, sv, "truthy_after_guard", [0, 1, 3]);
    assert vals == [-1, 1, 3] , f"unexpected truthy_after_guard results: {vals}";
}

test "a rebind re-widens: the tag is still read after reassignment" {
    (eng, _) = compile_native(FIXTURE);
    sv = sv_module();
    vals = congruent(eng, sv, "rebind_widens", [0, 2, 6]);
    assert vals == [-1, 6, 21] , f"unexpected rebind_widens results: {vals}";
}

test "a loop that rebinds before the use still narrows" {
    (eng, _) = compile_native(FIXTURE);
    sv = sv_module();
    vals = congruent(eng, sv, "loop_fresh_each_iter", [0, 2, 6]);
    assert vals == [-4, 7, 54] , f"unexpected loop_fresh_each_iter results: {vals}";
}

test "a callee that rebinds the attribute keeps the checked unwrap" {
    # k=0 leaves the attribute set, so both backends agree on a value. k=1
    # routes through `drop_slot`, which the checker's intra-procedural walk
    # cannot see: sv raises TypeError there, so native must not read a payload.
    (eng, ir) = compile_native(FIXTURE);
    sv = sv_module();
    vals = congruent(eng, sv, "callee_rebinds_attr", [0]);
    assert vals == [1] , f"unexpected callee_rebinds_attr results: {vals}";
    body = func_ir(str(ir.gen.llvm_ir), "callee_rebinds_attr");
    assert "opt.isnone" in body , (
        "an attribute a callee can rebind must keep its checked unwrap"
    );
}

test "a value live across a loop back edge keeps the checked unwrap" {
    # n=6 keeps the rebound value non-None on every iteration, so both
    # backends agree. n=2 puts None on the back edge and sv raises TypeError,
    # so the in-loop use must not have been narrowed away.
    (eng, ir) = compile_native(FIXTURE);
    sv = sv_module();
    vals = congruent(eng, sv, "back_edge_rewiden", [0, 6]);
    assert vals == [-1, 21] , f"unexpected back_edge_rewiden results: {vals}";
    body = func_ir(str(ir.gen.llvm_ir), "back_edge_rewiden");
    assert "opt.isnone" in body , (
        "a use the loop body rebinds after must keep its checked unwrap"
    );
}

test "`case None` over a narrowed subject folds instead of comparing to null" {
    (eng, _) = compile_native(FIXTURE);
    sv = sv_module();
    vals = congruent(eng, sv, "match_narrowed_subject", [0, 2, 4]);
    assert vals == [-1, 5, 5] , f"unexpected match_narrowed_subject results: {vals}";
}

test "the narrowed in-loop use keeps its tag check elided" {
    # `scalar_continue_guard` assigns at the top of the body, so the guard's
    # proof is fresh every iteration and the loop rule must still allow it.
    (_, ir) = compile_native(FIXTURE);
    body = func_ir(str(ir.gen.llvm_ir), "scalar_continue_guard");
    assert "opt.isnone" not in body , (
        "assign-then-guard inside a loop must still narrow"
    );
}

test "narrowing removes the tag check from the proven use" {
    # optional_scalar.jac lowers with and without narrowing, so the checked
    # unwrap the guard makes unnecessary is directly measurable as an A/B.
    orig = NaIRGenPass._narrowed_flow_type;
    _napatch: any = NaIRGenPass;
    _napatch._narrowed_flow_type = _no_narrowing;
    try {
        (_, base_ir) = compile_native("optional_scalar.jac");
        base = str(base_ir.gen.llvm_ir);
    } finally {
        NaIRGenPass._narrowed_flow_type = orig;
    }
    (_, narrowed_ir) = compile_native("optional_scalar.jac");
    narrowed = str(narrowed_ir.gen.llvm_ir);

    for name in ["use_pick", "opt_local", "opt_param"] {
        assert "opt.isnone" in func_ir(base, name) , (
            f"baseline {name} should pay a checked unwrap without narrowing"
        );
        assert "opt.isnone" not in func_ir(narrowed, name) , (
            f"narrowed {name} must read the payload with no tag check"
        );
    }
}

test "a proven pointer-optional use emits no unwrap branch" {
    (_, narrowed_ir) = compile_native(FIXTURE);
    body = func_ir(str(narrowed_ir.gen.llvm_ir), "ptr_guard_is_none");
    assert "opt.isnone" not in body , (
        "the guarded len(ids) must read the payload with no tag check"
    );
    assert "raise.TypeError" not in body , (
        "the guarded len(ids) must not branch to a runtime raise"
    );
}
