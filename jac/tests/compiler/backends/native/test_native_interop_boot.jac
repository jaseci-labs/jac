"""A natively-executed entry must fill its native->server callback table.

`register_py_callbacks` binds every `native_imports` symbol to a ctypes
trampoline that resolves its Python callable lazily out of
`gen.interop_py_funcs`. Only the module's Python image fills that table --
through the meta importer's interop setup -- and a natively-executed entry
never runs that image, so each callback logged a warning and answered 0: the
native caller read a wrong value instead of the server function's result.
`ensure_py_funcs_loaded` resolves the bound functions at native boot instead.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_address, unit_symbol }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.runtime.interop_bridge { ensure_py_funcs_loaded }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     SEAM = "na_py_interop.jac";

def _compiled -> tuple[JacProgram, uni.Module] {
    # Server default + the jac.toml pin on native_add_one_to_doubled leaves
    # py_double on the server lane, which is what makes the seam exist;
    # force_codespace='native' would force it native too and there would be
    # nothing for the boot loader to resolve.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, SEAM)),
        options=CompileOptions(default_codespace='server')
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
    return (prog, ir, );
}


test "the seam records a native->server binding to resolve" {
    (prog, ir) = _compiled();
    manifest = ir.gen.interop_manifest;
    assert manifest is not None;
    names = [b.name for b in manifest.native_imports];
    assert "py_double" in names , (
        f"the na->sv seam left nothing for the boot loader: {names}"
    );
}


test "the boot loader resolves the server function into the table" {
    (prog, ir) = _compiled();
    table = ir.gen.interop_py_funcs;
    table.pop("py_double", None);
    loaded = ensure_py_funcs_loaded(
        ir.gen.interop_manifest,
        table,
        base_path=str(FIXTURES),
        default_module="na_py_interop"
    );
    assert loaded >= 1 , (
        f"boot loader resolved nothing; table={sorted(table.keys())}"
    );
    assert "py_double" in table , sorted(table.keys());
}


test "the native call reaches the server function after boot loading" {
    (prog, ir) = _compiled();
    eng = ir.gen.native_engine;
    assert eng is not None , "no JIT engine for the seam fixture";
    table = ir.gen.interop_py_funcs;
    table.pop("py_double", None);
    ensure_py_funcs_loaded(
        ir.gen.interop_manifest,
        table,
        base_path=str(FIXTURES),
        default_module="na_py_interop"
    );
    addr = native_address(eng, unit_symbol(ir, "native_add_one_to_doubled"));
    assert addr != 0 , "native_add_one_to_doubled not found in the JIT engine";
    fn = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
    assert fn(5) == 11 , (
        "the native call did not reach the server function; 0 means the "
        "callback table never filled"
    );
}
