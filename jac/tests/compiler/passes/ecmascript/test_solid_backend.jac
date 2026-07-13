"""Tests for the Solid FrameworkBackend (Phase 3 — signals lowering).

Solid inverts the re-render model: state is an accessor (`count()`), writes go
through a setter, dynamic JSX positions are thunks (`() => expr`), and effects use
`createEffect` / `onCleanup`. These tests pin the per-form lowering (contract §5)
and the acceptance fixtures (contract §7) by compiling fixtures with an explicit
SolidBackend and asserting on the emitted JS.
"""

import os;
import from pathlib { Path }
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import from jaclang.compiler.passes.ecmascript.backends.solid { SolidBackend }
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

glob FIXTURES = os.path.join(
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
    # Dynamic JSX child reads are bare accessor calls in `{…}` containers — under
    # the dom-expressions path `babel-plugin-jsx-dom-expressions` tracks the read,
    # so the `() =>` thunk (a `solid-js/h` artifact) is gone.
    assert "{count()}" in js , "dynamic child should be an un-thunked accessor read";
    assert "{name()}" in js;
    assert "() => count()" not in js , "JSX path must not thunk dynamic reads";
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

test "solid view seam emits un-thunked dynamic JSX, never wraps handlers (fixture #4/#6)" {
    js = compile_fixture_with_backend("reactive_view_audit.cl.jac", SolidBackend());
    # Dynamic attribute value and dynamic child are bare `{expr}` — un-thunked on
    # the JSX/dom-expressions path (the compiler owns reactive tracking).
    assert "value={count()}" in js , "dynamic attribute value should be un-thunked";
    assert "value={() => count()}" not in js , "JSX path must not thunk attr values";
    assert "{count()}" in js , "dynamic child should be an un-thunked accessor read";
    # Static literal attribute is a plain string attribute.
    assert 'type="text"' in js;
    # Event handler is emitted as-is — never wrapped in a view thunk.
    assert "onClick={" in js;
    assert "onClick={() => count()" not in js , "handler must not be view-wrapped";
}

test "solid lifts a keyed comprehension to native <For> (Branch 4)" {
    js = compile_fixture_with_backend("jsx_control_flow.cl.jac", SolidBackend());
    # A `[<li> for x in items]` comprehension lowers to native `<For each>`, NOT
    # `.map()`; the `(item) => element` render callback supplies the body.
    assert "<For each={items}>" in js , (
        "keyed comprehension should lower to <For each={items}>:\n" + js
    );
    # A comprehension `if` folds into the iterable, not a separate clause.
    assert "<For each={items.filter(" in js , (
        "a comprehension filter folds into <For each={coll.filter(...)}>:\n" + js
    );
    # The authored `key=` is dropped from the body — Solid's <For> keys by item
    # identity, so the host element must not carry a stray `key` attribute.
    assert "key=" not in js , (
        "Solid <For> body must not carry the lifted React-style `key`:\n" + js
    );
    # `For` is auto-injected from the solid-js core.
    for_import = `any(
        ("For" in line and "solid-js" in line)
        for line in js.split("\n")
        if line.lstrip().startswith("import")
    );
    assert for_import , "`For` must be imported from solid-js:\n" + js;
}

test "solid lifts a view-shaped ternary to native <Show> (Branch 4)" {
    js = compile_fixture_with_backend("jsx_control_flow.cl.jac", SolidBackend());
    # `<A/> if cond else <B/>` lowers to `<Show when={cond} fallback={<B/>}>`.
    assert "<Show when={flag}" in js , (
        "a view-shaped ternary should lower to <Show when={...}>:\n" + js
    );
    # The two-armed ternary carries a fallback (the `else <p>` arm).
    assert "fallback={" in js , "the `else <p>` arm becomes the Show fallback:\n" + js;
    # `Show` is auto-injected from the solid-js core.
    show_import = `any(
        ("Show" in line and "solid-js" in line)
        for line in js.split("\n")
        if line.lstrip().startswith("import")
    );
    assert show_import , "`Show` must be imported from solid-js:\n" + js;
}

test "JS family renders lifted control flow from the carried js_fallback (Branch 4)" {
    js = compile_fixture_with_backend("jsx_control_flow.cl.jac", ReactBackend());
    # React/Preact never emit Solid control-flow components — the lifted nodes
    # carry the producer's already-lowered `.map()`/`?:`, rendered via `__jacJsx`,
    # so output is byte-for-byte what it was before the producer learned to lift.
    assert "<For" not in js and "<Show" not in js , (
        "the JS family must not emit Solid control-flow components:\n" + js
    );
    assert ".map(" in js , "comprehension renders via .map() on the JS family";
    assert ".filter(" in js , "filtered comprehension renders via .filter()";
    assert " ? " in js , "the view ternary renders as a conditional expression";
}

test "solid awaiting lowers to a native solid-js Suspense import" {
    js = compile_fixture_with_backend("view_awaiting.cl.jac", SolidBackend());
    # Unlike the acceptance-matrix smoke check, assert the import *source*: the
    # awaiting clause must lower to Solid's own Suspense, not the React shim.
    assert 'import { Suspense } from "solid-js";' in js , f"expected a solid-js Suspense import, got: {js[:200]}";
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
    # The dom-expressions path emits JSX, not `solid-js/h` hyperscript.
    assert 'solid-js/h' not in script;
    assert "createRoot" not in script;
    assert 'JacClientErrorBoundary' in script;
    assert '<JacClientErrorBoundary FallbackComponent={ErrorFallback} onError={__jacReactErrorHandler}>' in script;
    assert '<App />' in script;
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
    # JSX (dom-expressions), not `solid-js/h` hyperscript.
    assert 'solid-js/h' not in script;
    assert 'react-dom/client' not in script;
    assert 'react-router-dom' not in script;
    assert 'React.createElement' not in script;
    assert 'BrowserRouter' not in script;
    # Native `@solidjs/router`: no <Routes>, routes are `<Route>` children of
    # `<Router>` directly, each with a `component` (not a prebuilt `element`). The
    # JSX children are lazy so the router establishes its context (eager `h(Route)`
    # children render router primitives "outside a Route" and throw).
    assert 'Router, Route, AuthGuard, __jacMakeLayoutRoot' in script;
    assert 'Routes,' not in script;
    assert 'from "./_routes.js"' in script;
    assert '<Route path={r.path} component={r.element} />' in script;
    # AuthGuard nests the protected routes and renders the matched child
    # (`props.children`) when authenticated.
    assert 'function _AuthGuardRoute(props) { return AuthGuard({ redirect: "/login", children: props.children }); }' in script;
    assert '<Route component={_AuthGuardRoute}>' in script;
    # Root layout (when present) rides the router's `root` prop.
    assert 'const routerProps = RootLayout ? { root: __jacMakeLayoutRoot(RootLayout) } : {};' in script;
    assert '<Router {...routerProps}>' in script;
    # The router tree is `<App />`, wrapped in the error boundary.
    assert '<App />' in script;
    assert 'JacClientErrorBoundary' in script;
    assert 'getElementById("__jac_root")' in script;
    # No top-level `app` wrapper import when has_app_wrapper is False.
    assert 'app as AppWrapper' not in script;
}

test "solid file-based-routing entry honors auth_redirect + app wrapper" {
    script = build_pages_solid_entry_script("main", "/signin", True);
    assert 'AuthGuard({ redirect: "/signin", children: props.children })' in script;
    # The entry module's `app` export wraps the router tree.
    assert 'import { app as AppWrapper } from "./main.js";' in script;
    assert '<AppWrapper><App /></AppWrapper>' in script;
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
    # own shim that re-exports the shared core with zero React imports (no __jacJsx —
    # the JSX path no longer needs a hyperscript factory). Overrides the basename
    # inherited from ReactBackend.
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

test "solid emits vite-plugin-solid lines for the bundler config" {
    # Branch 5: the Solid build uses `vite-plugin-solid` (wraps
    # `babel-plugin-jsx-dom-expressions`), not the old hyperscript h route.
    lines = SolidBackend().vite_plugin_lines();
    assert lines is not None , "SolidBackend.vite_plugin_lines() must return plugin lines";
    (import_line, call_line) = lines;
    assert "vite-plugin-solid" in import_line;
    assert "solidPlugin" in import_line;
    assert "solidPlugin()" in call_line;
}

test "solid prepends only __jacSpawn (no __jacJsx factory)" {
    assert SolidBackend().required_globals() == ["__jacSpawn"];
}

test "solid runtime shim compiles and links its impl bodies" {
    # Compile the real Solid runtime (shim + its `impl/` annex) the way the
    # bundler does and assert the bodies actually link — a parse error or an
    # unlinked impl would surface here as an empty `navigate` body, which the
    # text-only purity scan above cannot catch.
    rt = resolve_client_runtime_cl_path("solid");
    prog = JacProgram();
    ir = prog.compile(file_path=rt, no_cgen=True);
    assert not prog.errors_had , (
        f"Solid runtime failed to compile: {[str(e) for e in prog.errors_had]}"
    );
    has_impl_node = any(
        st.loc.mod_path and st.loc.mod_path.endswith(".impl.jac") for st in ir.body
    );
    assert has_impl_node , "Solid runtime impl annex was not linked";
    js = es_to_js(
        EsastGenPass(ir_in=ir, prog=prog, backend=SolidBackend()).ir_out.gen.es_ast
    );
    # The dom-expressions (JSX) path: no __jacJsx hyperscript factory.
    assert "function __jacJsx(" not in js , "Solid shim must not emit __jacJsx (dom-expressions path)";
    assert "createElement" not in js , "Solid shim must not use React.createElement";
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
        "function AuthGuard(",
        "function __jacMakeLayoutRoot("
    ] {
        assert fn in js , f"router binding did not link: {fn}";
    }
    # Link maps `to`->`href` via @solidjs/router's `A`; Navigate maps `to`->`href`.
    assert "SolidAnchor" in js , "Link adapter must delegate to @solidjs/router's A";
    assert "SolidNavigate" in js;
    # Forms: @tanstack/solid-form's createForm (Standard Schema, no resolver needed).
    assert "function JacForm(" in js;
    assert "function useJacForm(" in js;
    assert "createForm(" in js , "useJacForm must build a tanstack/solid-form controller";
    assert '"onTouched"' in js , "useJacForm must handle the default validateMode";
    use_jac_form = js.split("function useJacForm(", 1)[1].split("function JacForm(", 1)[
        0
    ];
    # Solid onTouched uses onChange only (stale onBlur errorMap across fields);
    # error display is gated on isTouched in JacForm. onBlur mode still exists.
    assert (
        'validators["onBlur"] = schema;\n        validators["onChange"] = schema' not in use_jac_form
    ) , "Solid onTouched must not wire both onBlur and onChange validators";
    assert (
        'form_mode === "onTouched")) {\n    validators["onChange"] = schema;' in use_jac_form
    ) , "Solid onTouched must validate on change only";
    # Error boundary + async boundary over solid-js primitives.
    assert "function JacClientErrorBoundary(" in js;
    # ErrorFallback is defined once in client_runtime_core and re-exported by
    # both shims, so the shim js carries the binding rather than the function.
    assert "ErrorFallback" in js;
    assert "function JacAwaiting(" in js;
    assert "SolidErrorBoundary" in js , "error boundary must use solid-js ErrorBoundary";
    assert "SolidSuspense" in js , "JacAwaiting must use solid-js Suspense";
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
        "__jacMakeLayoutRoot",
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
    # react / react-router-dom / react-hook-form / @tanstack/react-form.
    # Statically scan the shim source (and its impl) for any React-ecosystem import.
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
        "@tanstack/react-form",
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
