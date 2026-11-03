"""A cross-module static call into a Python-side class refuses out loud.

The old backend's import walk registered no struct type for a class over a
Python-side base, and the class-qualified form `Merger.merge(...)` fell
through to a bare `return None`: codegen dropped the call and said nothing --
the silent-wrong-answer class (#7685 family).

Under MIR a module whose only Python-side trait is an `async` method lowers
natively, so the merge module here is made genuinely Python-side by pinning
it to the server. The call into it is refused, naming the callee, and under
forced (not required) native placement it demotes to Python -- the entry
block for a module-scope call, the owning function for a body-scoped one --
while its siblings stay native (#8206's partition).

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
    by_source_name,
    native_address,
    native_force_opts,
    source_spelled
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     MERGED = 7;


"""Forced-native options: a refusal demotes the code that holds it."""
def _opts -> CompileOptions {
    return CompileOptions(force_codespace='native');
}


"""Compile a fixture on the native pathway; return (program, module)."""
def _compile_native(fixture: str) -> tuple[any, ...] {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, fixture), options=_opts());
    return (prog, ir);
}


"""Copy `fixture` and the modules it imports into a project that pins the
merge module to the server, so `Merger` is Python-side for every importer."""
def _pinned_copy(fixture: str, scratch: str) -> str {
    import shutil;
    with open(os.path.join(scratch, "jac.toml"), "w") as f {
        f.write(
            '[project]\nname = "xmod_static"\n\n[placement.pins]\n'
                + '"xmod_static_pybase_merge" = "server"\n'
        );
    }
    for name in [fixture, "xmod_static_pybase_merge.jac", "xmod_static_types.jac"] {
        shutil.copyfile(os.path.join(FIXTURES, name), os.path.join(scratch, name));
    }
    return os.path.join(scratch, fixture);
}

"""Compile a pinned copy of a fixture on the native pathway; return
(program, module, stderr)."""
def _compile_logged(fixture: str) -> tuple[any, ...] {
    import contextlib;
    import io;
    import tempfile;
    buf = io.StringIO();
    with tempfile.TemporaryDirectory() as scratch {
        path = _pinned_copy(fixture, scratch);
        with contextlib.redirect_stderr(buf) {
            prog = JacProgram();
            ir = prog.compile(file_path=path, options=_opts());
        }
    }
    return (prog, ir, source_spelled(buf.getvalue()));
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


test "a module-scope static call into a Python-side class demotes the entry" {
    (prog, ir, log) = _compile_logged("xmod_static_pybase_main.jac");
    assert not prog.errors_had , (
        f"forced native placement demotes, it does not fail: {[
            str(e) for e in prog.errors_had
        ]}"
    );
    iface: any = ir.gen.native_iface;
    assert iface is not None and iface.entry_symbol == "" , (
        "the call resolved to no native `Merger`, so the entry block must not "
        "lower with the call quietly removed"
    );
    assert "Merger.merge" in log , (
        f"the demotion must name the callee it refuses, the way the "
        f"free-function crossing names its function: {log}"
    );
}


test "a body-scoped static call demotes only its owning function" {
    (prog, ir, log) = _compile_logged("xmod_static_pybase_seam.jac");
    assert not prog.errors_had , (
        f"a function owns this violation, so it demotes rather than failing "
        f"the module: {[str(e) for e in prog.errors_had]}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "clean" in layout.functions , (
        f"the clean sibling was lost: {sorted(layout.functions)}"
    );
    iface: any = ir.gen.native_iface;
    assert "probe" in iface.demoted and "probe" not in layout.functions , (
        "the calling function must be demoted out of the native layout, not "
        "lowered with the call quietly removed"
    );
    assert "demoting probe" in log and "Merger" in log , (
        f"the demotion reason must name the callee: {log}"
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
    (merge_prog, merge_ir) = _compile_native("xmod_static_native_merge.jac");
    assert not merge_prog.errors_had , [str(e) for e in merge_prog.errors_had];
    merge_layout: any = merge_ir.gen.native_layout;
    assert "Merger.merge" in by_source_name(merge_layout.methods) , (
        f"the static method lost its native lowering: {sorted(merge_layout.methods)}"
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
