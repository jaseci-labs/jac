"""A leading `*` spread of a list of tuples into a set, checked by value.

Native lists register one instantiation per storage flavour and every
pointer-element list shares `List.ptr`, whose element slot is erased to a
byte pointer on purpose. Sets do not share that erasure: they carry a
`tupleN` flavour that hashes and compares the N bytes behind the pointer.

A leading spread seeded the set's flavour from the source list's *lowered*
element type, so the erased byte pointer came back, no tuple layout was
recovered from it, and the set was built on the plain pointer flavour --
whose keys are hashed and compared as NUL-terminated C strings over the
boxed tuple's own bytes. Two int pairs sharing a first component read as
the same one-byte key, so they collapsed into one member and a pair that
was never inserted answered True to `in`. Nothing reached stderr.

Every assertion reads the set back as a number carrying both its length
and a membership answer, and every function is additionally checked
against the sv/bytecode result of the same fixture, the parity idiom
`test_native_union_slot_ops` uses. A set that is silently short fails the
value check rather than passing on the strength of having been built.

Refs #8160
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
     FIXTURE = "set_spread_tuple.jac",
     FNS = [
         "head_dup",
         "head_member",
         "head_absent",
         "head_zero_lead",
         "head_triple",
         "head_glob",
         "compr_set",
         "head_set_spread",
         "tail_list_spread",
         "two_list_spreads",
         "str_head_spread",
         "int_head_spread",
         "param_spread",
         "param_str_spread",
         "field_spread",
         "call_spread",
         "slice_spread",
         "source_survives"
     ];


"""Compile the fixture natively and return the JIT engine."""
def _compile -> object {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, FIXTURE)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {FIXTURE}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {FIXTURE}";
    gi_addr = native_address(eng, "__jac_glob_init");
    if gi_addr {
        ctypes.CFUNCTYPE(None)(gi_addr)();
    }
    return eng;
}


"""ctypes handle for an (int) -> int function in the JIT engine."""
def _get(eng: any, name: str) -> object {
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
}


"""Import the same fixture through the sv/bytecode pathway."""
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


test "a leading spread of a list of tuples keeps its members distinct" {
    eng = _compile();
    expect = {
        "head_dup": 2,
        "head_zero_lead": 31,
        "head_triple": 21,
        "head_glob": 21,
        "two_list_spreads": 31
    };
    for (name, want) in expect.items() {
        got = _get(eng, name)(0);
        assert got == want , (
            f"{name}: got {got}, want {want} -- a short set means the members "
            "were compared as C strings over the boxed tuple's bytes rather "
            "than by the tuple layout"
        );
    }
}


test "membership answers by tuple value, not by a leading byte" {
    eng = _compile();
    assert _get(eng, "head_member")(0) == 11 , ("both inserted pairs must answer True");
    assert _get(eng, "head_absent")(0) == 0 , (
        "a pair that was never inserted must answer False even when it shares "
        "a component with one that was"
    );
}


test "the shapes that already recovered the layout are unchanged" {
    eng = _compile();
    assert _get(eng, "compr_set")(0) == 21 , "a set comprehension of tuples";
    assert _get(eng, "head_set_spread")(0) == 21 , (
        "a set source carries its own element size through the spread"
    );
    assert _get(eng, "tail_list_spread")(0) == 21 , (
        "a list of tuples spread into a set whose flavour a set source " "already fixed"
    );
}


test "the layout is recovered whatever the source expression is" {
    eng = _compile();
    expect = {
        "param_spread": 21,
        "field_spread": 21,
        "call_spread": 21,
        "slice_spread": 21
    };
    for (name, want) in expect.items() {
        got = _get(eng, name)(0);
        assert got == want , (
            f"{name}: got {got}, want {want} -- a parameter, a field, a call "
            "result and a slice each reach their element type by a different "
            "route, and none of them may fall back to pointer bytes"
        );
    }
}


test "a spread whose element slot was never erased is untouched" {
    eng = _compile();
    assert _get(eng, "str_head_spread")(0) == 21 , (
        "string elements are genuinely C-string keys and must stay so"
    );
    assert _get(eng, "int_head_spread")(0) == 21 , "scalar elements";
}


test "the spread copies its source rather than aliasing it" {
    eng = _compile();
    assert _get(eng, "source_survives")(0) == 230 , (
        "appending to the source after the display must not reach the set"
    );
}


test "every set-of-tuples spread agrees with the sv result" {
    eng = _compile();
    sv = _sv_module();
    for name in FNS {
        na = _get(eng, name)(0);
        want = getattr(sv, name)(0);
        assert na == want , f"{name}: native {na} != sv {want}";
    }
}
