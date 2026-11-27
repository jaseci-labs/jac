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


test "every set-of-tuples spread agrees with the sv result" {
    eng = _compile();
    sv = _sv_module();
    for name in FNS {
        na = _get(eng, name)(0);
        want = getattr(sv, name)(0);
        assert na == want , f"{name}: native {na} != sv {want}";
    }
}
