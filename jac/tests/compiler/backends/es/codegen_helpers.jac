"""JavaScript fixture compilation without registering tests as an import side effect."""

import from jaclang.compiler.pipeline.contracts { PassIdentity }
import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import os;
import from pathlib { Path }
import from jaclang.compiler.backends.es.es_unparse { es_to_js }
import from jaclang.compiler.backends.es.estree { Node as EsNode }
import from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.pipeline.executor { run_pass }

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

"""Compile a Jac fixture to JavaScript and return the emitted source."""
def compile_fixture_to_js(fixture_name: str, fixture_dir: str = "") -> str {
    fixture_path = _resolve_fixture_path(fixture_name, fixture_dir);
    cache_key = os.path.abspath(fixture_path);
    if cache_key in _js_compile_cache {
        return _js_compile_cache[cache_key];
    }
    prog = JacProgram();
    ir = prog.compile(file_path=fixture_path, no_cgen=True);
    assert not prog.errors_had , (
        f"Compilation errors in {fixture_name}: {[str(e) for e in prog.errors_had]}"
    );

    es_pass = run_pass(PassIdentity.EsastGenPass, ir, prog);
    es_ir = es_pass.ir_out;

    assert hasattr(artifact_for(es_ir), "es_ast") , "es_ast attribute missing";
    es_ast = artifact_for(es_ir).es_ast;
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
    assert not prog.errors_had , (
        f"Compilation errors in {fixture_name}: {[str(e) for e in prog.errors_had]}"
    );
    assert artifact_for(ir).js and artifact_for(ir).js.strip() , (
        f"Production JS codegen produced no output for {fixture_name}"
    );
    _js_production_compile_cache[cache_key] = artifact_for(ir).js;
    return artifact_for(ir).js;
}
