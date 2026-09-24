"""Set displays whose elements are tuples, checked by value and by lifetime.

A tuple expression lowers to a by-value struct, while a native set stores a
tuple through a boxed pointer and hashes/compares the bytes behind it (the
`tupleN` flavour). `.add()` and set comprehensions boxed each element before
inserting it; the set display did not. It keyed the set by the first
element's unboxed struct type, which `_hash_key_spec` maps to the scalar
`i64` flavour, and emitting that flavour's hash helpers crashed native
lowering with "Operands must be the same type, got ({i64, i64}, i64)".
`{(1, 2)}` alone was enough.

Every function folds its set into one number carrying the length and the
membership answers, and is also checked against the sv/bytecode result of
the same fixture. `lit_owned_members` reads the fixture's `drop` ledger: the
box the display builds for its first element has to be released like every
later one, or the object inside it is never destroyed.
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
     FIXTURE = "set_literal_tuple.jac",
     FNS = [
         "lit_pairs",
         "lit_dup",
         "lit_single",
         "lit_runtime",
         "lit_triple",
         "lit_str_pairs",
         "lit_float_pairs",
         "lit_declared_add",
         "lit_returned",
         "lit_glob",
         "lit_iter_sum",
         "compr_pairs",
         "ctor_pairs",
         "lit_owned_members"
     ],
     _MEMO: list[any] = [];


"""Compile the fixture once natively and return the JIT engine."""
def _compile -> any {
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
    gi_addr = native_address(eng, "__jac_glob_init");
    if gi_addr {
        ctypes.CFUNCTYPE(None)(gi_addr)();
    }
    _MEMO.append(eng);
    return eng;
}


"""ctypes handle for an (int) -> int function in the JIT engine."""
def _get(name: str) -> any {
    addr = native_address(_compile(), name);
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


test "a set display of tuples lowers and keeps its members by value" {
    expect = {
        "lit_pairs": 210,
        "lit_dup": 21,
        "lit_single": 11,
        "lit_triple": 21,
        "lit_str_pairs": 210,
        "lit_float_pairs": 21
    };
    for (name, want) in expect.items() {
        got = _get(name)(0);
        assert got == want , f"{name}: got {got}, want {want}";
    }
    assert _get("lit_runtime")(4) == 21 , "components computed at run time";
}


test "a display shares its flavour with the declared set type" {
    assert _get("lit_declared_add")(0) == 31 , (
        "`.add()` on a display-built set must hash like the display did"
    );
    assert _get("lit_returned")(0) == 210 , "returned through set[tuple[int, int]]";
    assert _get("lit_glob")(0) == 21 , "a module-level display built in glob init";
    assert _get("lit_iter_sum")(0) == 14 , "iteration unpacks every component";
}


test "comprehensions and set() of tuples are unchanged" {
    assert _get("compr_pairs")(0) == 31;
    assert _get("ctor_pairs")(0) == 21;
}


test "every box a display builds is released with the set" {
    got = _get("lit_owned_members")(0);
    assert got == 22 , (
        f"got {got}, want 22: both members of the first display must be "
        "destroyed when it is replaced (12 means the first element's box leaked)"
    );
}


test "every set-of-tuples display agrees with the sv result" {
    sv = _sv_module();
    for name in FNS {
        arg = 4 if name == "lit_runtime" else 0;
        na = _get(name)(arg);
        want = getattr(sv, name)(arg);
        assert na == want , f"{name}: native {na} != sv {want}";
    }
}
