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

The two forms now land the same way, and where they land is #8206's
partition: a module-scope call has no owning callable and stays module-fatal,
a body-scoped one demotes its own function and leaves its siblings native.

The control is the same three files with the Python base removed. It must
still lower and still agree with the Python lane, so the refusal reads as a
diagnosis of the Python-side crossing rather than of class-qualified calls.
"""

import ctypes;
import importlib;
import os;
import sys;
import from tests.support { TESTS_DIR, native_address, native_force_opts }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.na_coverage { na_coverage_begin, na_coverage_end }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     MERGED = 7;


"""Forced-native options that skip the IR cache so the coverage always runs."""
def _opts -> CompileOptions {
    return CompileOptions(force_codespace='native');
}


"""Compile a fixture on the native pathway; return (program, module)."""
def _compile_native(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, fixture), options=_opts());
    return (prog, ir);
}


"""Compile a fixture under the demotion coverage; return (program, module, coverage)."""
def _compile_with_coverage(fixture: str) -> tuple {
    prog = JacProgram();
    na_coverage_begin();
    try {
        ir = prog.compile(file_path=os.path.join(FIXTURES, fixture), options=_opts());
    } finally {
        coverage = na_coverage_end();
    }
    return (prog, ir, coverage);
}


"""The coverage seam list recorded for a fixture path."""
def _seams_of(coverage: dict, fixture: str) -> list[str] {
    rec = coverage.get(os.path.realpath(os.path.join(FIXTURES, fixture)));
    if rec is None {
        return [];
    }
    return [str(s) for s in (rec.get("seams") or [])];
}


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
    (prog, ir) = _compile_native("xmod_static_pybase_main.jac");
    texts = [str(e) for e in prog.errors_had];
    codes = [
        str(alrt.code.code)
        for alrt in prog.errors_had
        if alrt.code is not None
    ];
    assert "E5092" in codes , (
        "the call resolved to no native `Merger`, so codegen dropped it and "
        f"the entry block wove nothing: {texts}"
    );
    assert any("Merger.merge" in t for t in texts) , (
        f"the diagnostic must name the callee it refuses, the way the "
        f"free-function crossing names its function: {texts}"
    );
    assert ir.gen.llvm_ir is None , (
        "a module whose entry silently loses a statement is worse than a "
        "refusal, so nothing may lower here"
    );
}


test "a body-scoped static call demotes only its owning function" {
    (prog, ir, coverage) = _compile_with_coverage("xmod_static_pybase_seam.jac");
    assert not prog.errors_had , (
        f"a function owns this violation, so it demotes rather than failing "
        f"the module: {[str(e) for e in prog.errors_had]}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "clean" in layout.functions , (
        f"the clean sibling was lost: {sorted(layout.functions)}"
    );
    assert "probe" not in layout.functions , (
        "the calling function must be demoted out of the native layout, not "
        "lowered with the call quietly removed"
    );
    seams = [
        s
        for s in _seams_of(coverage, "xmod_static_pybase_seam.jac")
        if s.startswith("probe: ")
    ];
    assert len(seams) == 1 , (
        f"expected exactly one coverage seam for probe, got: {_seams_of(
            coverage, 'xmod_static_pybase_seam.jac'
        )}"
    );
    assert "Merger.merge" in seams[0] , (
        f"the seam reason must name the callee: {seams[0]}"
    );
}


test "the same call with no Python base still lowers" {
    (prog, ir) = _compile_native("xmod_static_native_main.jac");
    assert not prog.errors_had , (
        f"only the Python-side crossing may refuse; a class-qualified call "
        f"into a native module must be untouched: {[str(e) for e in prog.errors_had]}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "run_merge" in layout.functions , (
        f"the caller was demoted: {sorted(layout.functions)}"
    );
    assert "Merger.merge" in layout.methods , (
        f"the imported static method lost its native lowering: {sorted(layout.methods)}"
    );
}


test "the control's two lanes agree on the merged value" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "xmod_static_native_main.jac"),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    eng = ir.gen.native_engine;
    assert eng is not None , "no native engine for the control";
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
