"""Congruence tests for the native union representation rule.

Two call sites pick a representation for a set of Jac types sharing one
slot, and they used to disagree. `a if cond else b` lowers to a phi over
the two branch values; when the branches lowered differently the phi was
invalid IR and the module never compiled, which is why POLY handoffs in the
parser had to be spelled as an `any`-typed local plus an if/else assignment
instead of the ternary. A declared multi-member union lowered to its first
member's representation, silently reinterpreting the others.

Both now run through one shared rule. These tests assert the native result
equals the sv/bytecode result of the same fixture for every shape:
conditional expressions (shared lowering, all-pointer, genuinely mixed,
call argument, nested, closure-typed) and declared unions in parameter,
return and global position. A structural test additionally pins that the
two ternary shapes which already lowered did not start paying for a box.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_force_opts }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.jac0core.codeinfo {
    get_effective_default_codespace_override,
    set_effective_default_codespace
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     FIXTURE = "ternary_union.jac",
     FLAGS = [0, 1, 2, 3],
     TERNARY_FNS = [
         "same_rep",
         "all_ptr",
         "mixed_rep",
         "call_arg",
         "nested",
         "closure_arm"
     ],
     DECLARED_UNION_FNS = ["use_u_param", "use_u_return", "use_u_glob"];


"""Compile the fixture natively, run its glob init, return (engine, module).

`__jac_glob_init` is what a real binary runs before anything else; the
declared-union globals need it because a boxed initializer is a runtime
store, not a constant.
"""
def _compile(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine for {fixture}";
    gi = eng.get_function_address("__jac_glob_init");
    assert gi != 0 , "fixture emitted no __jac_glob_init";
    ctypes.CFUNCTYPE(None)(gi)();
    return (eng, ir);
}


"""ctypes handle for an (int) -> int function in the JIT engine."""
def _get(eng: object, name: str) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
}


"""Import the same fixture through the sv/bytecode pathway.

The default codespace is pinned to `server` for the import so the reference
values come from the bytecode backend no matter what the markerless
placement inference would otherwise decide.
"""
def _sv_module -> object {
    prev = get_effective_default_codespace_override();
    set_effective_default_codespace("server");
    try {
        mods = JacRuntime.jac_import(
            target=FIXTURE[:-4], base_path=FIXTURES, reload_module=True
        );
    } finally {
        set_effective_default_codespace(prev);
    }
    assert mods , "sv import of the fixture produced no module";
    return mods[0];
}


"""LLVM IR text of a single `define ... @name(` function body."""
def _fn_body(txt: str, name: str) -> str {
    marker = "@\"" + name + "\"(";
    start = txt.find("define ");
    while start != -1 {
        end = txt.find("\n}", start);
        if end == -1 {
            break;
        }
        block = txt[start:end + 2];
        header_end = block.find("\n");
        header = block[:header_end] if header_end != -1 else block;
        if marker in header {
            return block;
        }
        start = txt.find("define ", end);
    }
    return "";
}


"""Assert native and sv agree on every flag for each named function."""
def _assert_congruent(eng: object, sv: object, names: list[str]) {
    for name in names {
        na_fn = _get(eng, name);
        sv_fn = getattr(sv, name);
        for flag in FLAGS {
            assert na_fn(flag) == sv_fn(flag) , (
                f"{name}({flag}): native {na_fn(flag)} != sv {sv_fn(flag)}"
            );
        }
    }
}


test "ternary congruence: every conditional shape matches the sv result" {
    (eng, _) = _compile(FIXTURE);
    _assert_congruent(eng, _sv_module(), TERNARY_FNS);
}


test "declared union congruence: param, return and global match the sv result" {
    (eng, _) = _compile(FIXTURE);
    _assert_congruent(eng, _sv_module(), DECLARED_UNION_FNS);
}


test "ternary: a genuinely mixed pointer/i64 pair round-trips its payload" {
    (eng, _) = _compile(FIXTURE);
    mixed_rep = _get(eng, "mixed_rep");
    call_arg = _get(eng, "call_arg");
    nested = _get(eng, "nested");

    # The int arm arrives as itself; the list arm as the negated length, so
    # a boxed value that lost its payload or its tag cannot pass.
    assert mixed_rep(1) == -3 , "list arm of a pointer/i64 ternary";
    assert mixed_rep(0) == 7 , "int arm of a pointer/i64 ternary";
    assert call_arg(1) == -4 , "list arm of a ternary passed as a call argument";
    assert call_arg(0) == 9 , "int arm of a ternary passed as a call argument";
    assert nested(2) == -3 , "outer arm of a nested ternary";
    assert nested(1) == -2 , "inner pointer arm of a nested ternary";
    assert nested(0) == 5 , "inner int arm of a nested ternary";
}


test "ternary: an all-pointer pair with a closure arm still wraps the closure" {
    # A stored closure ({fn, env}) and a bare named function are both
    # pointers, so the rule keeps the closure layout and the bare function
    # has to be wrapped into it. Short-circuiting that to a raw bitcast
    # segfaults the moment the result is called.
    (eng, _) = _compile(FIXTURE);
    closure_arm = _get(eng, "closure_arm");
    assert closure_arm(1) == 15 , "capturing-closure arm (5 + 10)";
    assert closure_arm(0) == 20 , "bare-function arm (5 * 4)";
}


test "declared union: mixed members round-trip in param, return and global" {
    (eng, _) = _compile(FIXTURE);
    use_u_param = _get(eng, "use_u_param");
    use_u_return = _get(eng, "use_u_return");
    use_u_glob = _get(eng, "use_u_glob");

    assert use_u_param(1) == 7 , "int member through an `int | str` parameter";
    assert use_u_param(0) == -4 , "str member through an `int | str` parameter";
    assert use_u_return(1) == 5 , "int member out of an `int | str` return";
    assert use_u_return(0) == -3 , "str member out of an `int | str` return";
    assert use_u_glob(0) == 11 , "int member in an `int | str` global";
    assert use_u_glob(1) == -5 , "str member in an `int | str` global";
}


test "ternary: a shared lowering and an all-pointer pair never box" {
    (_, ir) = _compile(FIXTURE);
    txt = str(ir.gen.llvm_ir);

    same_rep = _fn_body(txt, "same_rep");
    all_ptr = _fn_body(txt, "all_ptr");
    assert same_rep , "same_rep was not emitted";
    assert all_ptr , "all_ptr was not emitted";

    # Two int branches keep the i64 phi they have always had.
    assert "phi  i64 " in same_rep , (
        "an int/int ternary must still phi on i64, not on a boxed value"
    );
    assert "jacval" not in same_rep , (
        "an int/int ternary started boxing to jacval -- the unification rule "
        "must be free on branches that already share a lowering"
    );

    # Two list branches keep the first member's pointer layout.
    assert "jacval" not in all_ptr , (
        "an all-pointer ternary started boxing to jacval -- an all-pointer "
        "union keeps the first member's layout"
    );
}
