"""Tests for the Preact FrameworkBackend (Phase 1)."""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import from jaclang.compiler.passes.ecmascript.backends.preact { PreactBackend }
import from jaclang.compiler.passes.ecmascript.backends.react { ReactBackend }
import from jaclang.compiler.passes.ecmascript.backends.registry {
    resolve_active_backend,
    resolve_framework_backend
}
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.compiler.passes.ecmascript.reactive_intent {
    AsyncBoundary,
    Effect,
    RefField,
    StateField
}
import jaclang.compiler.passes.ecmascript.estree as es;
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

test "react backend reports runtime symbols for reactive lowering" {
    backend = ReactBackend();
    init = es.Literal(value=0, raw="0");
    assert backend.state_field_symbols(StateField(name="count", init_expr=init)) == [
        "useState"
    ];
    assert backend.ref_field_symbols(RefField(name="node", init_expr=init)) == [
        "useRef"
    ];
    assert backend.effect_symbols(
        Effect(body=[], deps=[], is_entry=True, is_async=False)
    ) == ["useEffect"];
    try_expr = es.Identifier(name="tryFn");
    awaiting_only = AsyncBoundary(
        try_expr=try_expr, awaiting_expr=None, except_exprs=[]
    );
    assert backend.async_boundary_symbols(awaiting_only) == ["JacAwaiting"];
    with_except = AsyncBoundary(
        try_expr=try_expr,
        awaiting_expr=None,
        except_exprs=[es.Identifier(name="onErr")]
    );
    assert backend.async_boundary_symbols(with_except) == [
        "JacAwaiting",
        "JacClientErrorBoundary"
    ];
}

test "preact backend inherits hook symbol names from react" {
    backend = PreactBackend();
    init = es.Literal(value=0, raw="0");
    assert backend.state_field_symbols(StateField(name="count", init_expr=init)) == [
        "useState"
    ];
    assert backend.effect_symbols(
        Effect(body=[], deps=[], is_entry=True, is_async=False)
    ) == ["useEffect"];
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
    assert 'getElementById("root")' in script;
    assert 'getElementById("__jac_root")' in script;
}

test "preact shares the canonical client runtime source" {
    # Preact rides on the React-flavored runtime; `react` imports are remapped
    # to `preact/compat` at bundle time via vite_aliases (see test below).
    assert client_runtime_cl_basename("preact") == "client_runtime.cl.jac";
    assert client_runtime_cl_basename("react") == "client_runtime.cl.jac";
    path = resolve_client_runtime_cl_path("preact");
    assert path.endswith("client_runtime.cl.jac");
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

test "runtime_source_basename delegates to backend via registry" {
    assert ReactBackend().runtime_source_basename() == "client_runtime.cl.jac";
    assert PreactBackend().runtime_source_basename() == "client_runtime.cl.jac";
    # Verify the runtime_source module delegates to the backend
    assert client_runtime_cl_basename("react") == "client_runtime.cl.jac";
    assert client_runtime_cl_basename("preact") == "client_runtime.cl.jac";
}

test "vite_aliases returns empty for react and compat mapping for preact" {
    assert ReactBackend().vite_aliases() == {};
    preact_aliases = PreactBackend().vite_aliases();
    assert preact_aliases == {"react": "preact/compat", "react-dom": "preact/compat"};
}

test "preact async_boundary_symbols with except arms returns both symbols" {
    backend = PreactBackend();
    try_expr = es.Identifier(name="tryFn");
    awaiting_only = AsyncBoundary(
        try_expr=try_expr, awaiting_expr=None, except_exprs=[]
    );
    assert backend.async_boundary_symbols(awaiting_only) == ["JacAwaiting"];
    with_except = AsyncBoundary(
        try_expr=try_expr,
        awaiting_expr=None,
        except_exprs=[es.Identifier(name="onErr")]
    );
    assert backend.async_boundary_symbols(with_except) == [
        "JacAwaiting",
        "JacClientErrorBoundary"
    ];
}

test "preact ref_field_symbols inherits useRef from react" {
    backend = PreactBackend();
    init = es.Literal(value=0, raw="0");
    assert backend.ref_field_symbols(RefField(name="node", init_expr=init)) == [
        "useRef"
    ];
}

test "react client runtime shim imports no solid ecosystem package" {
    # Symmetric guard to the Solid negative-import test: a React/Preact build must
    # never resolve @tanstack/solid-form or solid-js. Statically scan the shim
    # source (and its impl) for any Solid-ecosystem import.
    runtime_dir = Path(resolve_client_runtime_cl_path("react")).parent;
    sources = [
        runtime_dir / "client_runtime.cl.jac",
        runtime_dir / "impl" / "client_runtime.impl.jac"
    ];
    forbidden = ["@tanstack/solid-form", "solid-js"];
    for src in sources {
        assert src.is_file() , f"missing React runtime source: {src}";
        for ln in src.read_text(encoding="utf-8").splitlines() {
            stripped = ln.strip();
            if not stripped.startswith("import") {
                continue;
            }
            for pkg in forbidden {
                assert f"'{pkg}'" not in stripped and f'"{pkg}"' not in stripped , (
                    f"React runtime must not import '{pkg}': {stripped}"
                );
            }
        }
    }
}
