"""JavaScript fixture compilation without registering tests as an import side effect."""

import os;
import from pathlib { Path }
import from jaclang.compiler.backends.es { EsastGenPass }
import from jaclang.compiler.backends.es.es_unparse { es_to_js }
import from jaclang.compiler.backends.es.estree { Node as EsNode }
import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
import from jaclang.compiler.passes.context { Alert }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.pass_driver { deliver_alerts, run_pass }
import from jaclang.compiler.passes.execution { new_context, walk_pass }
import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.backends.es.framework_backend { FrameworkBackend }

glob _js_compile_cache: dict[str, str] = {},
     _js_production_compile_cache: dict[str, str] = {},
     _node_stage: list[str] = [];

"""Run EsastGenPass over a module with an explicit framework backend."""
def run_es_pass(
    ir: Module, prog: JacProgram, backend: FrameworkBackend
) -> EsastGenPass {
    ctx = new_context(EsastGenPass, ir, prog=prog);
    es_pass = EsastGenPass(module=ir, ctx=ctx, backend=backend);
    walk_pass(es_pass);
    deliver_alerts(ctx.errors_had, ctx.warnings_had, prog);
    return es_pass;
}

"""JavaScript EsastGenPass emits for a module with an explicit framework backend."""
def es_js_with_backend(ir: Module, prog: JacProgram, backend: FrameworkBackend) -> str {
    es_ast = run_es_pass(ir, prog, backend).module.gen.es_ast;
    assert isinstance(es_ast, EsNode) , "es_ast should be an EsNode";
    return es_to_js(es_ast);
}

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
    es_ir = es_pass.module;

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

"""Stage a directory where node can resolve the `@jac/prelude` module."""
def stage_prelude_dir(dir_path: str = "") -> str {
    import from jaclang.compiler.backends.es.jac_runtime_js {
        stage_jac_prelude_package
    }
    if dir_path {
        stage = dir_path;
    } elif _node_stage {
        return _node_stage[0];
    } else {
        import tempfile;
        stage = tempfile.mkdtemp(prefix="jac_node_stage_");
    }
    stage_jac_prelude_package(stage);
    if not dir_path {
        _node_stage.append(stage);
    }
    return stage;
}

"""Run one emitted client module under node and return the completed process."""
def run_js_module(source: str, timeout: float = 30.0) -> any {
    import subprocess;
    import tempfile;
    stage = stage_prelude_dir();
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".mjs", delete=False, dir=stage
    ) as mod {
        mod.write(source);
        mod_path = mod.name;
    }
    return subprocess.run(
        ["node", mod_path], capture_output=True, text=True, timeout=timeout
    );
}
