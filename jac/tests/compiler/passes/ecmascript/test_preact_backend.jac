"""Tests for the Preact FrameworkBackend (Phase 1)."""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import from jaclang.compiler.passes.ecmascript.backends.preact { PreactBackend }
import from jaclang.compiler.passes.ecmascript.backends.registry {
    resolve_active_backend,
    resolve_framework_backend
}
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.project.config { JacConfig, ClientConfig, set_config }
import from jaclang.runtimelib.preact_entry { build_simple_preact_entry_script }
import from jaclang.runtimelib.runtime_source {
    client_runtime_cl_basename,
    resolve_client_runtime_cl_path
}

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "ecmascript", "fixtures"
     );

"""Compile a fixture with the given backend and return emitted JS."""
def compile_fixture_with_backend(fixture_name: str, backend: object) -> str {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, fixture_name), no_cgen=True);
    assert not prog.errors_had , (
        f"Compilation errors in {fixture_name}: {[str(e) for e in prog.errors_had]}"
    );
    es_pass = EsastGenPass(ir_in=ir, prog=prog, backend=backend);
    es_ir = es_pass.ir_out;
    return es_to_js(es_ir.gen.es_ast);
}

test "registry resolves preact backend" {
    backend = resolve_framework_backend("preact");
    assert backend.name() == "preact";
    assert backend.runtime_module() == "@jac/runtime";
    assert backend.import_source("useState") == "preact/hooks";
    assert backend.import_source("useEffect") == "preact/hooks";
    assert backend.import_source("useRef") == "preact/hooks";
    assert backend.import_source("__jacSpawn") == "@jac/runtime";
}

test "preact entry script uses render and h" {
    script = build_simple_preact_entry_script("main");
    assert 'import { render, h } from "preact";' in script;
    assert "createRoot" not in script;
    assert 'render(' in script;
    assert 'h(App, null)' in script;
}

test "runtime source selects preact runtime for preact framework" {
    assert client_runtime_cl_basename("preact") == "preact_runtime.cl.jac";
    assert client_runtime_cl_basename("react") == "client_runtime.cl.jac";
    path = resolve_client_runtime_cl_path("preact");
    assert path.endswith("preact_runtime.cl.jac");
    assert os.path.isfile(path);
}

test "reactive counter fixture imports hooks from preact" {
    backend = PreactBackend();
    js = compile_fixture_with_backend("reactive_state.cl.jac", backend);
    assert 'from "preact/hooks"' in js;
    assert "useState" in js;
    assert 'from "react"' not in js;
    assert "setCount" in js;
}

test "reactive effect fixture imports useEffect from preact hooks" {
    backend = PreactBackend();
    js = compile_fixture_with_backend("reactive_effects_sync.jac", backend);
    assert 'from "preact/hooks"' in js;
    assert "useEffect" in js;
    assert 'from "react"' not in js;
}

test "conditional jsx fixture compiles under preact backend" {
    backend = PreactBackend();
    js = compile_fixture_with_backend("jsx_child_control_flow.cl.jac", backend);
    assert "__jacJsx" in js;
    assert 'from "react"' not in js;
}

test "resolve_active_backend reads preact from project config" {
    cfg = JacConfig();
    cfg.client = ClientConfig(framework="preact");
    set_config(cfg);
    backend = resolve_active_backend();
    assert backend.name() == "preact";
}
