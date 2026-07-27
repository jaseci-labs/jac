"""End-to-end tests for native star re-export chains (`include`).

A consumer imports names that a middle module re-exports via `include`,
and an entry module includes a native library directly; both must lower
natively with interop bindings that resolve to the defining module.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

"""Compile a .na.jac fixture and return the JIT engine."""
def compile_native(fixture: str) -> tuple[ExecutionEngine, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: object, name: str, restype: type | None, *argtypes: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

test "star re-export chain compiles" {
    (eng, ir) = compile_native("na_star_reexport_main.na.jac");
    assert ir.gen.llvm_ir is not None;
}

test "star re-export chain executes" {
    (eng, ir) = compile_native("na_star_reexport_main.na.jac");
    f = get_func(eng, "use_star", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 11 , "star_helper(5) must be 5 * 2 + 1";
}

test "star re-exported binding resolves to the defining module" {
    (eng, ir) = compile_native("na_star_reexport_main.na.jac");
    b = ir.gen.interop_manifest.bindings["star_helper"];
    assert b.source_module == "na_star_reexport_lib.na" , (
        f"binding must name the defining module, got {b.source_module}"
    );
}

test "entry-module include of native module executes" {
    (eng, ir) = compile_native("na_star_include_main.na.jac");
    f = get_func(eng, "inc_use", ctypes.c_int64, ctypes.c_int64);
    assert f(4) == 9 , "star_helper(4) must be 4 * 2 + 1";
}

test "struct re-export through include chain executes" {
    (eng, ir) = compile_native("na_star_reexport_main.na.jac");
    f = get_func(eng, "use_star_obj", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(7, 9) == 7 , "StarPoint.x must round-trip through star_make";
}
