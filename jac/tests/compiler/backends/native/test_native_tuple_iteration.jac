"""Iterating a tuple lowers natively and agrees with the sv result by value.

A tuple literal lowers to an unboxed LLVM literal struct, so the for-loop's
iterable dispatch -- which matches the collection value against the list, dict,
set, str and bytes runtime shapes -- had nothing to match and the loop demoted
with E5092. The list-literal spelling of the same loop lowered fine, so the one
real call site (`ModulePath.resolve_relative_path_list`) had to be rewritten
into a list to shed the seam.

Every case here is checked by value against the sv/bytecode result of the same
fixture rather than by "did it compile", because a materialized sequence has
two silent failure modes that a successful compile does not see: the wrong
element flavor reads each slot at the wrong width, and a dropped element just
makes the loop shorter.

The shapes covered are the ones that pick different backing stores or exercise
a different arrival path: homogeneous str/int/float tuples, the empty and
single-element literals, a tuple bound to a local, a tuple returned from a
call, and a nested loop with `break`/`continue` over the tuple.

A tuple of mixed element storage is the one shape that must not iterate, and
it gets its own fixture: the loop variable is one slot typed from the tuple's
first element, so boxing the elements would answer the body's `isinstance`
against the wrong member. It has to refuse loudly instead.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_address, native_force_opts }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.compiler.frontend.codeinfo {
    get_effective_default_codespace_override,
    set_effective_default_codespace
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "tuple_iteration.jac",
     MIXED_FIXTURE = "tuple_iteration_mixed.jac",
     ALL_FNS = [
         "str_tuple",
         "str_list",
         "int_tuple",
         "int_list",
         "float_tuple",
         "empty_tuple",
         "single_tuple",
         "local_tuple",
         "call_tuple",
         "hetero_list",
         "nested_tuple"
     ],
     SEEDS = [0, 1, 7],
     _MEMO: list = [];


"""Compile the fixture natively once and return the JIT engine."""
def _engine -> any {
    if _MEMO {
        return _MEMO[0];
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, FIXTURE)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {FIXTURE}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {FIXTURE}";
    _MEMO.append(eng);
    return eng;
}


"""ctypes handle for an (int) -> int function in the JIT engine."""
def _get(name: str) -> any {
    addr = native_address(_engine(), name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
}


"""Import the same fixture through the sv/bytecode pathway."""
def _sv_module -> any {
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


test "a homogeneous str tuple iterates every element in order" {
    f = _get("str_tuple");
    assert f(0) == 11885 , (
        "31-weighted fold over lengths 12, 11 and 12: a dropped element or a "
        "reordered one lands somewhere else"
    );
    assert _get("str_list")(0) == f(0) , "the list spelling must agree";
}


test "a homogeneous int tuple iterates as a raw-integer sequence" {
    f = _get("int_tuple");
    assert f(0) == 357 , "3, 5 then 7";
    assert _get("int_list")(0) == f(0) , "the list spelling must agree";
}


test "a homogeneous float tuple keeps its element width" {
    assert _get("float_tuple")(0) == 706 , (
        "1.5, 2.25 and 4.0 scaled by 4: a raw-integer store would read the "
        "bit pattern instead"
    );
}


test "the degenerate literals lower: an empty tuple and a single element" {
    assert _get("empty_tuple")(5) == 5 , "an empty tuple runs the body zero times";
    assert _get("single_tuple")(0) == 9 , (
        "a one-element tuple runs the body exactly once"
    );
}


test "a tuple bound to a local iterates the same as one in the header" {
    assert _get("local_tuple")(0) == 120 , "7-weighted fold over lengths 2, 3 and 1";
}


test "a tuple returned from a call iterates off the call" {
    assert _get("call_tuple")(0) == 246 , "2, 4 then 6";
}


test "the mixed list twin still iterates boxed and reads the right member" {
    assert _get("hetero_list")(0) == 38 , ("1, then len('ab'), then 3, folded by 5");
}


test "a tuple of mixed element storage refuses instead of answering wrong" {
    import contextlib;
    import io;
    buf = io.StringIO();
    prog = JacProgram();
    with contextlib.redirect_stderr(buf) {
        prog.compile(
            file_path=str(os.path.join(FIXTURES, MIXED_FIXTURE)),
            options=native_force_opts()
        );
    }
    # The refusal demotes mixed_tuple to a seam whose reason names the
    # construct, and the module entry that natively calls the demoted
    # function stays a loud E5092 -- a mixed tuple must never lower
    # silently: the loop variable is typed from the tuple's first element,
    # so a boxed iteration answers the body's isinstance against the wrong
    # member.
    seam = buf.getvalue();
    assert "demoting mixed_tuple" in seam , (
        f"expected the mixed-tuple refusal to demote mixed_tuple, got:\n{seam}"
    );
    assert "for-loop iterable" in seam and "mixed element storage" in seam , (
        f"the demotion reason must name the mixed-tuple refusal, got:\n{seam}"
    );
    errs = [str(e) for e in (prog.errors_had or [])];
    joined = " ".join(errs);
    assert "mixed_tuple" in joined , (
        f"the native entry caller of the demoted function must stay loud, "
        f"got: {errs}"
    );
}


test "the refused tuple still gives the right answer through sv" {
    prev = get_effective_default_codespace_override();
    set_effective_default_codespace("server");
    try {
        mods = JacRuntime.jac_import(
            target=MIXED_FIXTURE[:-4], base_path=FIXTURES, reload_module=True
        );
    } finally {
        set_effective_default_codespace(prev);
    }
    assert mods , "sv import of the mixed fixture produced no module";
    assert mods[0].mixed_tuple(0) == 38 , (
        "the demoted spelling must still compute 1, len('ab'), 3 folded by 5"
    );
    assert mods[0].mixed_list(0) == 38 , "the list spelling agrees";
}


test "break and continue work over a tuple loop nested in another loop" {
    assert _get("nested_tuple")(0) == 954 , (
        "'bbb' is skipped, 'cccc' breaks the inner loop, three outer passes"
    );
}


test "every tuple loop agrees with the sv result" {
    sv = _sv_module();
    for name in ALL_FNS {
        na_fn = _get(name);
        sv_fn = getattr(sv, name);
        for seed in SEEDS {
            assert na_fn(seed) == sv_fn(seed) , (
                f"{name}({seed}): native {na_fn(seed)} != sv {sv_fn(seed)}"
            );
        }
    }
}
