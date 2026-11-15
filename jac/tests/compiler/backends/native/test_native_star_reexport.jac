"""End-to-end tests for native star re-export chains (`include`).

A consumer imports names that a middle module re-exports via `include`,
and an entry module includes a native library directly; both must lower
natively with interop bindings that resolve to the defining module.
"""

import ctypes;
import os;
import from tests.support {
    TESTS_DIR,
    compile_native,
    compile_native_ir,
    get_func,
    native_force_opts
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

test "star re-export chain compiles" {
    (eng, ir) = compile_native("na_star_reexport_main.jac");
    assert ir.gen.llvm_ir is not None;
}

test "star re-export chain executes" {
    (eng, ir) = compile_native("na_star_reexport_main.jac");
    f = get_func(eng, "use_star", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 11 , "star_helper(5) must be 5 * 2 + 1";
}

test "star re-exported binding resolves to the defining module" {
    (eng, ir) = compile_native("na_star_reexport_main.jac");
    b = ir.gen.interop_manifest.bindings["star_helper"];
    assert b.source_module == "na_star_reexport_lib.jac" , (
        f"binding must name the defining module, got {b.source_module}"
    );
}

test "entry-module include of native module executes" {
    (eng, ir) = compile_native("na_star_include_main.jac");
    f = get_func(eng, "inc_use", ctypes.c_int64, ctypes.c_int64);
    assert f(4) == 9 , "star_helper(4) must be 4 * 2 + 1";
}

test "a typed import through a re-export module links to the defining unit" {
    import from unittest.mock { patch }
    with patch(
        "jaclang.compiler.placement.placement_facts.native_unit", return_value=True
    ) {
        ir = compile_native_ir("na_typed_reexport_main.jac");
    }
    deps = [os.path.basename(d) for d in ir.gen.native_deps];
    assert "na_star_reexport_mid.jac" not in deps , (
        f"a module with no code of its own is not a link unit, got {deps}"
    );
    assert "na_star_reexport_lib.jac" in deps , f"got {deps}";
}

test "struct re-export through include chain executes" {
    (eng, ir) = compile_native("na_star_reexport_main.jac");
    f = get_func(eng, "use_star_obj", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(7, 9) == 7 , "StarPoint.x must round-trip through star_make";
}
