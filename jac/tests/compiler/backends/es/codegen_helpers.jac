"""JavaScript fixture compilation without registering tests as an import side effect."""

import os;
import from pathlib { Path }
import from jaclang.compiler.backends.es { EsastGenPass }
import from jaclang.compiler.backends.es.es_unparse { es_to_js }
import from jaclang.compiler.backends.es.estree { Node as EsNode }
import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
import from jaclang.compiler.passes.transform { Alert }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.pass_driver { run_pass }

glob _js_compile_cache: dict[str, str] = {},
     _js_production_compile_cache: dict[str, str] = {};

"""Resolve a fixture name to an on-disk path."""
def _resolve_fixture_path(fixture_name: str, fixture_dir: str = "") -> str {
    fixture_path = fixture_name;
    if not Path(fixture_path).exists() and fixture_dir {
        fixture_path = os.path.join(fixture_dir, fixture_name);
    }
    return fixture_path;
}

"""Return compile errors that are not non-fatal TypeCheckPass diagnostics."""
def _fatal_compile_errors(prog: JacProgram) -> list[Alert] {
    # Filter out type-checker diagnostics (non-fatal warnings about
    # Unknown types in client code).  Only fail on parse/compile errors.
    # issubclass: diagnostics may come from TypeCheckPass itself or its
    # TypeCheckPass schedule entry.
    return [
        e
        for e in prog.errors_had
        if not issubclass(e.from_pass, TypeCheckPass)
    ];
}

"""Compile a Jac fixture to JavaScript and return the emitted source."""
def compile_fixture_to_js(fixture_name: str, fixture_dir: str = "") -> str {
    fixture_path = _resolve_fixture_path(fixture_name, fixture_dir);
    cache_key = os.path.abspath(fixture_path);
    if cache_key in _js_compile_cache {
        return _js_compile_cache[cache_key];
    }
    prog = JacProgram();
    ir = prog.compile(file_path=fixture_path, no_cgen=True);
    _fatal = _fatal_compile_errors(prog);
    assert not _fatal , (
        f"Compilation errors in {fixture_name}: {[str(e) for e in _fatal]}"
    );

    es_pass = run_pass(EsastGenPass, ir, prog);
    es_ir = es_pass.ir_out;

    assert hasattr(es_ir.gen, "es_ast") , "es_ast attribute missing";
    es_ast = es_ir.gen.es_ast;
    assert isinstance(es_ast, EsNode) , "es_ast should be an EsNode";

    result = es_to_js(es_ast);
    _js_compile_cache[cache_key] = result;
    return result;
}

"""Compile a fixture through the normal production codegen path."""
def compile_fixture_to_js_production(fixture_name: str, fixture_dir: str = "") -> str {
    fixture_path = _resolve_fixture_path(fixture_name, fixture_dir);
    cache_key = os.path.abspath(fixture_path);
    if cache_key in _js_production_compile_cache {
        return _js_production_compile_cache[cache_key];
    }
    prog = JacProgram();
    ir = prog.compile(file_path=fixture_path);
    _fatal = _fatal_compile_errors(prog);
    assert not _fatal , (
        f"Compilation errors in {fixture_name}: {[str(e) for e in _fatal]}"
    );
    assert ir.gen.js and ir.gen.js.strip() , (
        f"Production JS codegen produced no output for {fixture_name}"
    );
    _js_production_compile_cache[cache_key] = ir.gen.js;
    return ir.gen.js;
}
