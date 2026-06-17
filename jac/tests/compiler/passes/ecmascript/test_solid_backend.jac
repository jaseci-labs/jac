"""Tests for the Solid FrameworkBackend (Phase 3 — signals lowering).

Solid inverts the re-render model: state is an accessor (`count()`), writes go
through a setter, dynamic JSX positions are thunks (`() => expr`), and effects use
`createEffect` / `onCleanup`. These tests pin the per-form lowering (contract §5)
and the acceptance fixtures (contract §7) by compiling fixtures with an explicit
SolidBackend and asserting on the emitted JS.
"""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import from jaclang.compiler.passes.ecmascript.backends.solid { SolidBackend }
import from jaclang.compiler.passes.ecmascript.backends.registry {
    resolve_active_backend,
    resolve_framework_backend
}
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.compiler.passes.ecmascript.reactive_intent {
    AsyncBoundary,
    Effect,
    RefField,
    StateField,
    StateUpdate
}
import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.project.config { JacConfig, ClientConfig, set_config }
import from jaclang.runtimelib.solid_entry {
    build_simple_solid_entry_script,
    build_pages_solid_entry_script
}
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

test "registry resolves the solid backend" {
    backend = resolve_framework_backend("solid");
    assert backend.name() == "solid";
    assert backend.import_source("createSignal") == "solid-js";
    assert backend.import_source("createEffect") == "solid-js";
    assert backend.import_source("Suspense") == "solid-js";
    assert backend.import_source("__jacJsx") == "@jac/runtime";
}

test "resolve_active_backend reads solid from project config" {
    cfg = JacConfig();
    cfg.client = ClientConfig(framework="solid");
    set_config(cfg);
    backend = resolve_active_backend();
    assert backend.name() == "solid";
}

test "solid reports signals runtime symbols for reactive lowering" {
    backend = SolidBackend();
    init = es.Literal(value=0, raw="0");
    assert backend.state_field_symbols(StateField(name="count", init_expr=init)) == [
        "createSignal"
    ];
    # Refs are deferred on Solid — a `let` binding needs no import.
    assert backend.ref_field_symbols(RefField(name="node", init_expr=init)) == [];
    assert backend.effect_symbols(
        Effect(body=[], deps=[], is_entry=True, is_async=False)
    ) == ["createEffect"];
    assert backend.effect_symbols(
        Effect(body=[], deps=[], is_entry=False, is_async=False)
    ) == ["onCleanup"];
    try_expr = es.Identifier(name="tryFn");
    awaiting_only = AsyncBoundary(
        try_expr=try_expr, awaiting_expr=None, except_exprs=[]
    );
    assert backend.async_boundary_symbols(awaiting_only) == ["Suspense"];
    with_except = AsyncBoundary(
        try_expr=try_expr,
        awaiting_expr=None,
        except_exprs=[es.Identifier(name="onErr")]
    );
    assert backend.async_boundary_symbols(with_except) == ["Suspense", "ErrorBoundary"];
}

test "solid read seam lowers a reactive read to an accessor call" {
    read_node = SolidBackend().lower_state_read("count");
    assert isinstance(read_node, es.CallExpression);
    assert read_node.callee.name == "count";
    assert read_node.arguments == [];
}

test "solid view seam thunks a dynamic position" {
    expr = es.Identifier(name="count");
    out = SolidBackend().lower_view_expr(expr);
    assert isinstance(out, es.ArrowFunctionExpression);
    assert out.params == [];
    assert out.body is expr;
}

test "solid aug-assign uses a functional updater (contract §5.3)" {
    backend = SolidBackend();
    upd = StateUpdate(name="count", value=es.Literal(value=1, raw="1"), aug_op="+");
    out = backend.lower_state_update(upd);
    js = es_to_js(out);
    assert js == "setCount(prev => (prev + 1))" , f"unexpected: {js}";
}

test "solid counter fixture: createSignal, accessor reads, setter writes (fixture #1)" {
    js = compile_fixture_with_backend("reactive_state.cl.jac", SolidBackend());
    # State declaration uses createSignal, not useState.
    assert "const [count, setCount] = createSignal(0)" in js;
    assert "useState" not in js;
    assert 'from "solid-js"' in js;
    # Writes route through the setter.
    assert "setCount(42)" in js;
    assert 'setName("hello")' in js;
    # Plain self-referential assign — documented stale-read asymmetry (§5.3).
    assert "setCount((count() + 1))" in js;
    # Dynamic JSX child reads are accessor calls wrapped in a thunk.
    assert "() => count()" in js , "dynamic child should thunk an accessor call";
    assert "() => name()" in js;
}

test "solid aug-assign fixture emits functional updaters (fixture #3)" {
    js = compile_fixture_with_backend("reactive_aug_assign.cl.jac", SolidBackend());
    assert "setCount(prev => (prev + 5))" in js;
    assert "setCount(prev => (prev - 2))" in js;
    assert "setCount(prev => (prev * 3))" in js;
    # Never the stale double-read form.
    assert "setCount((count() +" not in js;
}

test "solid sync effect lowers to createEffect (fixture #2)" {
    js = compile_fixture_with_backend("reactive_effects_sync.jac", SolidBackend());
    assert "createEffect(" in js;
    assert "useEffect" not in js;
    assert 'from "solid-js"' in js;
    # Reactive read inside the effect body is an accessor call.
    assert "document.title = title()" in js;
}

test "solid cleanup effect lowers to onCleanup" {
    js = compile_fixture_with_backend("reactive_effects_cleanup.jac", SolidBackend());
    assert "onCleanup(" in js;
    assert "useEffect" not in js;
}

test "solid async effect keeps the IIFE and ignores the dep array" {
    js = compile_fixture_with_backend("reactive_effects_deps.jac", SolidBackend());
    assert "createEffect(" in js;
    assert "useEffect" not in js;
    # Writes inside the async effect route through setters.
    assert "setLoading(" in js;
    assert "setUserData(" in js;
}

test "solid view seam thunks dynamic JSX, never event handlers (fixture #4/#6)" {
    js = compile_fixture_with_backend("reactive_view_audit.cl.jac", SolidBackend());
    # Dynamic attribute value and dynamic child route through the thunk seam.
    assert '"value": () => count()' in js , "dynamic attribute value should thunk";
    assert "() => count()" in js , "dynamic child should thunk";
    # Static literal attribute bypasses the seam.
    assert '"type": "text"' in js;
    # Event handler is emitted as-is — never double-wrapped in a view thunk.
    assert '"onClick":' in js;
    assert '"onClick": () => count()' not in js , "handler must not be view-wrapped";
}

test "solid async boundary lowers to Suspense and ErrorBoundary" {
    js = compile_fixture_with_backend("view_awaiting.cl.jac", SolidBackend());
    assert "Suspense" in js;
    assert "JacAwaiting" not in js , "Solid must not emit the React Suspense shim";
}

test "solid ref field defers to a let binding (fixture #7)" {
    backend = SolidBackend();
    stmts = backend.lower_ref_field(
        RefField(name="el", init_expr=es.Literal(value=None, raw="null"))
    );
    js = es_to_js(stmts[0]);
    assert js.startswith("let el") , f"ref should be a let binding, got: {js}";
    assert "useRef" not in js;
}

test "solid entry script renders via solid-js/web" {
    script = build_simple_solid_entry_script("main");
    assert 'import { render } from "solid-js/web";' in script;
    assert 'import h from "solid-js/h";' in script;
    assert "createRoot" not in script;
    assert 'JacClientErrorBoundary' in script;
    assert 'h(JacClientErrorBoundary, { FallbackComponent: ErrorFallback, onError: __jacReactErrorHandler }, h(App, {}))' in script;
    assert 'getElementById("__jac_root")' in script;
}

test "solid file-based-routing entry mounts via solid-js/web + router shim" {
    # The Solid analogue of the React file-based entry: same `_routes.js`
    # manifest, but assembled through the runtime shim's `@solidjs/router`
    # adapters and Solid's `render` — and crucially with NO React-ecosystem
    # import. `has_app_wrapper=False`, so the router is the root.
    script = build_pages_solid_entry_script("main", "/login", False);
    # Solid mount surface, never React's.
    assert 'import { render } from "solid-js/web";' in script;
    assert 'import h from "solid-js/h";' in script;
    assert 'react-dom/client' not in script;
    assert 'react-router-dom' not in script;
    assert 'React.createElement' not in script;
    assert 'BrowserRouter' not in script;
    # Router tree + auth wiring come from the shim's `@jac/runtime` exports.
    assert 'Router, Routes, Route, AuthGuard' in script;
    assert 'from "./_routes.js"' in script;
    assert 'h(Route, { path: r.path, element: h(r.element, {}) })' in script;
    assert 'AuthGuard("/login")' in script;
    assert 'h(Router, {}' in script;
    # Element creation is hyperscript, and the tree is wrapped in the boundary.
    assert 'const appElement = h(App, {});' in script;
    assert 'JacClientErrorBoundary' in script;
    assert 'getElementById("__jac_root")' in script;
    # No top-level `app` wrapper import when has_app_wrapper is False.
    assert 'app as AppWrapper' not in script;
}

test "solid file-based-routing entry honors auth_redirect + app wrapper" {
    script = build_pages_solid_entry_script("main", "/signin", True);
    assert 'AuthGuard("/signin")' in script;
    # The entry module's `app` export wraps the router tree.
    assert 'import { app as AppWrapper } from "./main.js";' in script;
    assert 'const appElement = h(AppWrapper, {}, h(App, {}));' in script;
}

test "backend.build_pages_entry_script dispatches per framework" {
    # The ViteCompiler delegates file-based-routing entry generation to the
    # active backend; Solid must produce a React-free entry while React keeps
    # the `react-dom/client` route tree.
    import from jaclang.compiler.passes.ecmascript.backends.react { ReactBackend }
    solid_js = SolidBackend().build_pages_entry_script("main", "/login", False);
    react_js = ReactBackend().build_pages_entry_script("main", "/login", False);
    assert 'solid-js/web' in solid_js;
    assert 'react-dom/client' not in solid_js;
    assert 'react-dom/client' in react_js;
    assert 'solid-js/web' not in react_js;
}

test "solid selects its own framework-free runtime shim" {
    # Solid must NOT ride the React-flavored `client_runtime.cl.jac`; it has its
    # own shim that re-exports the shared core with a `solid-js/h`-backed
    # __jacJsx and zero React imports. This overrides the basename inherited
    # from ReactBackend.
    assert SolidBackend().runtime_source_basename() == "solid_runtime.cl.jac";
    assert client_runtime_cl_basename("solid") == "solid_runtime.cl.jac";
    path = resolve_client_runtime_cl_path("solid");
    assert path.endswith("solid_runtime.cl.jac");
    assert os.path.isfile(path);
}

test "solid needs no vite aliases (no react remapping)" {
    # Unlike Preact (react -> preact/compat), Solid imports no React package, so
    # the bundler needs no module remapping.
    assert SolidBackend().vite_aliases() == {};
}

test "solid runtime shim compiles and links its impl bodies" {
    # Compile the real Solid runtime (shim + its `impl/` annex) the way the
    # bundler does and assert the bodies actually link — a parse error or an
    # unlinked impl would surface here as an empty `__jacJsx`/`navigate` body,
    # which the text-only purity scan above cannot catch.
    rt = resolve_client_runtime_cl_path("solid");
    prog = JacProgram();
    ir = prog.compile(file_path=rt, no_cgen=True);
    assert not prog.errors_had , (
        f"Solid runtime failed to compile: {[str(e) for e in prog.errors_had]}"
    );
    assert len(ir.impl_mod) >= 1 , "Solid runtime impl annex was not linked";
    js = es_to_js(
        EsastGenPass(ir_in=ir, prog=prog, backend=SolidBackend()).ir_out.gen.es_ast
    );
    # __jacJsx has a real body that targets Solid's hyperscript runtime.
    assert "function __jacJsx(" in js;
    assert "childrenArray" in js , "__jacJsx body did not link";
    assert "createElement" not in js , "Solid __jacJsx must not use React.createElement";
    # Public surface forwards to the framework-agnostic core.
    assert "_navigate(path)" in js , "navigate forwarder did not link";
    assert "jacIsLoggedIn" in js;
}

test "solid runtime shim reaches router/form parity with the React shim" {
    # The Solid shim must expose the same router + form + error/async surface as
    # the React shim, sourced from Solid-native libraries (no React ecosystem),
    # so `@jac/runtime` stays framework-identical for app code. Compile the real
    # shim and assert each ported body links.
    rt = resolve_client_runtime_cl_path("solid");
    prog = JacProgram();
    ir = prog.compile(file_path=rt, no_cgen=True);
    assert not prog.errors_had , (
        f"Solid runtime failed to compile: {[str(e) for e in prog.errors_had]}"
    );
    js = es_to_js(
        EsastGenPass(ir_in=ir, prog=prog, backend=SolidBackend()).ir_out.gen.es_ast
    );
    # Router adapters bridging react-router-dom's shape onto @solidjs/router.
    for fn in [
        "function Routes(",
        "function Route(",
        "function Link(",
        "function Navigate(",
        "function Outlet(",
        "function useRouter(",
        "function AuthGuard("
    ] {
        assert fn in js , f"router binding did not link: {fn}";
    }
    # Link maps `to`->`href` via @solidjs/router's `A`; Navigate maps `to`->`href`.
    assert "SolidAnchor" in js , "Link adapter must delegate to @solidjs/router's A";
    assert "SolidNavigate" in js;
    # Forms: solid-hook-form's createForm + the hand-rolled zod resolver (no @hookform).
    assert "function JacForm(" in js;
    assert "function useJacForm(" in js;
    assert "createForm(" in js , "useJacForm must build a solid-hook-form controller";
    assert "function __zodResolver(" in js , "hand-rolled zod resolver did not link";
    assert "safeParse" in js , "zod resolver must validate via schema.safeParse";
    # Error boundary + async boundary over solid-js primitives.
    assert "function JacClientErrorBoundary(" in js;
    assert "function ErrorFallback(" in js;
    assert "function JacAwaiting(" in js;
    assert "SolidErrorBoundary" in js , "error boundary must use solid-js ErrorBoundary";
    assert "SolidSuspense" in js , "JacAwaiting must use solid-js Suspense";
    # The submit wrapper must be async so handleSubmit can await it.
    assert "async function submitHandler(" in js;
    # Absolutely no React element factory leaks through the form/router JSX.
    assert "createElement" not in js , "Solid parity surface must not use React.createElement";
}

test "solid runtime shim exports the full router/form surface" {
    # The compiled shim's ES module must re-export every router/form/error name so
    # `@jac/runtime` resolves them for app code (mirrors ROUTER_EXPORTS + the
    # React shim's public surface).
    rt = resolve_client_runtime_cl_path("solid");
    prog = JacProgram();
    ir = prog.compile(file_path=rt, no_cgen=True);
    js = es_to_js(
        EsastGenPass(ir_in=ir, prog=prog, backend=SolidBackend()).ir_out.gen.es_ast
    );
    export_line = "";
    for ln in js.splitlines() {
        if ln.strip().startswith("export {") {
            export_line = ln;
        }
    }
    assert export_line , "Solid shim emitted no export statement";
    for name in [
        "Router",
        "Routes",
        "Route",
        "Link",
        "Navigate",
        "Outlet",
        "useNavigate",
        "useLocation",
        "useParams",
        "useRouter",
        "AuthGuard",
        "JacForm",
        "useJacForm",
        "JacSchema",
        "JacClientErrorBoundary",
        "ErrorFallback",
        "errorOverlay",
        "JacAwaiting",
        "__jacReactErrorHandler"
    ] {
        assert name in export_line , f"@jac/runtime (solid) must export {name}";
    }
    # Solid must NOT export React-only re-render hooks (it gets these from solid-js).
    assert "useState" not in export_line , "Solid shim must not export useState";
    assert "useEffect" not in export_line , "Solid shim must not export useEffect";
}

test "solid runtime shim imports no react ecosystem package" {
    # The whole point of the runtime split: a Solid build must never resolve
    # react / react-router-dom / react-hook-form. Statically scan the shim
    # source (and its impl) for any React-ecosystem import.
    runtime_dir = Path(resolve_client_runtime_cl_path("solid")).parent;
    sources = [
        runtime_dir / "solid_runtime.cl.jac",
        runtime_dir / "impl" / "solid_runtime.impl.jac"
    ];
    forbidden = [
        "react",
        "react-dom",
        "react-router-dom",
        "react-hook-form",
        "react-error-boundary",
        "@hookform"
    ];
    for src in sources {
        assert src.is_file() , f"missing Solid runtime source: {src}";
        for ln in src.read_text(encoding="utf-8").splitlines() {
            stripped = ln.strip();
            if not stripped.startswith("import") {
                continue;
            }
            for pkg in forbidden {
                assert f"'{pkg}'" not in stripped and f'"{pkg}"' not in stripped , (
                    f"Solid runtime must not import '{pkg}': {stripped}"
                );
            }
        }
    }
}
