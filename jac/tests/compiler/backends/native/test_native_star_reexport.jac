"""End-to-end tests for native star re-export chains (`include`).

A consumer imports names that a middle module re-exports via `include`,
and an entry module includes a native library directly; both must lower
natively with interop bindings that resolve to the defining module.
"""

import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import ctypes;
import os;
import from tests.support { TESTS_DIR, compile_native, get_func, native_force_opts }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

test "star re-export chain compiles" {
    (eng, ir) = compile_native("na_star_reexport_main.jac");
    assert artifact_for(ir).llvm_ir is not None;
}

test "star re-export chain executes" {
    (eng, ir) = compile_native("na_star_reexport_main.jac");
    f = get_func(eng, "use_star", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 11 , "star_helper(5) must be 5 * 2 + 1";
}

test "star re-exported binding resolves to the defining module" {
    (eng, ir) = compile_native("na_star_reexport_main.jac");
    b = artifact_for(ir).interop_manifest.bindings["star_helper"];
    assert b.source_module == "na_star_reexport_lib.jac" , (
        f"binding must name the defining module, got {b.source_module}"
    );
}

test "entry-module include of native module executes" {
    (eng, ir) = compile_native("na_star_include_main.jac");
    f = get_func(eng, "inc_use", ctypes.c_int64, ctypes.c_int64);
    assert f(4) == 9 , "star_helper(4) must be 4 * 2 + 1";
}

test "struct re-export through include chain executes" {
    (eng, ir) = compile_native("na_star_reexport_main.jac");
    f = get_func(eng, "use_star_obj", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(7, 9) == 7 , "StarPoint.x must round-trip through star_make";
}
