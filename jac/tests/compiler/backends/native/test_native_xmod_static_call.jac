"""A cross-module static call into a Python-side class refuses out loud.

A module whose class inherits a Python-side base is classified Python-side by
the native import walk for every importing unit, so the walk registers no
struct type for that class. The cross-module *free-function* crossing has
always ended at a terminal diagnostic when nothing native answers the name,
but the class-qualified form had no such arm: `Merger.merge(...)` found no
`Merger` in `struct_types`, skipped the static arm entirely, and fell through
`_codegen_method_call` to a bare `return None`. Codegen dropped the call and
said nothing -- the silent-wrong-answer class (#7685 family, found by wave 1's
parity canary weaving two statements where bytecode wove four).

The two forms now land the same way: the decision step refuses the call by
name. Where native is required that refusal is an E5092 error; otherwise a
body-scoped call demotes its own function and leaves its siblings native.

The control is the same three files with the Python base removed. It must
still lower and still agree with the Python lane, so the refusal reads as a
diagnosis of the Python-side crossing rather than of class-qualified calls.
"""

import ctypes;
import importlib;
import os;
import sys;
import from tests.support {
    TESTS_DIR,
    compile_mir,
    compile_native,
    compile_native_refused,
    diagnostics_text,
    error_codes,
    native_address
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     MERGED = 7;


"""Run the fixture's function in the plain Python lane."""
def _run_py_lane(stem: str, func_name: str) -> object {
    added = False;
    if FIXTURES not in sys.path {
        sys.path.insert(0, FIXTURES);
        added = True;
    }
    stems = [stem, "xmod_static_native_merge", "xmod_static_types"];
    try {
        for _s in stems {
            sys.modules.pop(_s, None);
        }
        mod = importlib.import_module(stem);
        return getattr(mod, func_name)();
    } finally {
        if added {
            sys.path.remove(FIXTURES);
        }
        for _s in stems {
            sys.modules.pop(_s, None);
        }
    }
}


test "a module-scope static call into a Python-side class refuses" {
    result = compile_native_refused("xmod_static_pybase_main.jac");
    text = diagnostics_text(result);
    assert "E5092" in error_codes(result) , (
        "the call resolved to no native `Merger`, so codegen dropped it and "
        f"the entry block wove nothing: {text}"
    );
    assert "Merger.merge" in text , (
        f"the diagnostic must name the callee it refuses, the way the "
        f"free-function crossing names its function: {text}"
    );
}


test "a body-scoped static call demotes only its owning function" {
    fx = compile_mir("xmod_static_pybase_seam.jac");
    assert not fx.is_demoted("clean") , f"the clean sibling was lost: {fx.demoted()}";
    assert fx.is_demoted("probe") , (
        "the calling function must be demoted, not lowered with the call "
        f"quietly removed: {fx.demoted()}"
    );
    assert "Merger.merge" in fx.reason("probe") , (
        f"the demotion reason must name the callee: {fx.reason('probe')}"
    );
}


test "the same call with no Python base still lowers" {
    fx = compile_mir("xmod_static_native_main.jac");
    assert not fx.is_demoted("run_merge") , f"the caller was demoted: {fx.demoted()}";
    merge_unit = fx.result.unit(
        os.path.realpath(os.path.join(FIXTURES, "xmod_static_native_merge.jac"))
    );
    assert not merge_unit.demoted , (
        "the imported static method lost its native lowering: "
        f"{[(d.symbol, d.reason) for d in merge_unit.demoted]}"
    );
}


test "the control's two lanes agree on the merged value" {
    (eng, _) = compile_native("xmod_static_native_main.jac");
    addr = native_address(eng, "run_merge");
    assert addr != 0 , "run_merge is absent from the JIT engine";
    native_val = ctypes.CFUNCTYPE(ctypes.c_int64)(addr)();
    py_val = _run_py_lane("xmod_static_native_main", "run_merge");
    assert native_val == MERGED , (
        f"the native lane merged to {native_val}, expected {MERGED}"
    );
    assert native_val == py_val , (
        f"lane divergence: native {native_val} vs python {py_val}"
    );
}
