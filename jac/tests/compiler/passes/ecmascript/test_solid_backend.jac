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
import from jaclang.runtimelib.solid_entry { build_simple_solid_entry_script }

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
    assert "render(() => h(App, {}), __jacMountEl)" in script;
    assert 'getElementById("__jac_root")' in script;
}
