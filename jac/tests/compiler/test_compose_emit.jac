"""Tests for ComposeEmit.emit_jac_app — locks in HMR route persistence.

On a DexClassLoader hot-swap, JacApp is re-mounted and would reset to the
initial route. The dev emit restores the last route from SharedPreferences and
persists it on every navigation, so a code swap keeps the user on their current
screen. These tests call emit_jac_app directly on a minimal model (no Gradle,
no device) to pin the emitted Kotlin contract.
"""
import from jaclang.compiler.passes.compose.compose_model { ComposeModule }
import from jaclang.compiler.passes.ecmascript.intent.model {
    IntentRoute,
    IntentComponent
}
import from jaclang.compiler.passes.ecmascript.view_ir { ViewElement, HostTag }
import from jaclang.compiler.passes.compose.compose_emit {
    ComposeEmit,
    route_to_screen_name,
    normalize_route_segment
}
import from jaclang.compiler.passes.compose.compose_native_emit {
    _widget_param_kinds,
    _slot_wrap,
    _is_slot_param,
    _is_known_nonslot_param
}
import from jaclang.compiler.passes.compose { kotlin_ast as kt }
import from pathlib { Path }
import tempfile;

test "route_to_screen_name produces valid Kotlin identifiers" {
    assert route_to_screen_name("/") == "HomeScreen";
    assert route_to_screen_name("/foo-bar") == "FooBarScreen";
    assert route_to_screen_name("/user/:id") == "UserIdScreen";
    assert normalize_route_segment("foo-bar") == "FooBar";
}

test "emit_jac_app dispatches using IntentRoute.screen_name" {
    model = ComposeModule();
    model.intent.package_name = "dev.jac.t";
    model.intent.routes = [
        IntentRoute(path="/foo-bar", screen_name="CustomFooScreen", component="app")
    ];
    code = ComposeEmit(model=model, out_dir=Path("/tmp"), dev=False).emit_jac_app();
    assert "CustomFooScreen(" in code;
    assert "FooBarScreen(" not in code;
    assert '"/foo-bar"' in code;
}

test "dev emit_jac_app restores and persists the route" {
    model = ComposeModule();
    model.intent.package_name = "dev.jac.t";
    model.intent.routes = [
        IntentRoute(path="/", screen_name="HomeScreen", component="app")
    ];
    code = ComposeEmit(model=model, out_dir=Path("/tmp"), dev=True).emit_jac_app();

    # Restore: read the last path from the HMR prefs and validate it.
    assert 'getSharedPreferences("jac-hmr"' in code;
    assert "restoredPath" in code;
    assert 'hmr.getString("path", null)' in code;

    # Persist: a LaunchedEffect writes the current path whenever it changes.
    assert 'putString("path", currentEntry.path)' in code;
}

test "release emit_jac_app has no HMR persistence" {
    model = ComposeModule();
    model.intent.package_name = "dev.jac.t";
    model.intent.routes = [
        IntentRoute(path="/", screen_name="HomeScreen", component="app")
    ];
    code = ComposeEmit(model=model, out_dir=Path("/tmp"), dev=False).emit_jac_app();

    # Release must not read/write the HMR prefs — keeps the startPath path.
    assert "getSharedPreferences" not in code;
    assert "restoredPath" not in code;
    assert "val initialPath = if (JacRoutes.paths.contains(startPath))" in code;
}

# P0 #2 — DOM/Tailwind IR is rejected: the Compose framework has one code path
# (native compose_view). A component lowering only DOM IR must record a
# diagnostic, never silently emit a lossy Box stub.
test "DOM IR (comp.view) records a diagnostic, not a silent stub" {
    with tempfile.TemporaryDirectory() as tmp {
        model = ComposeModule();
        model.intent.package_name = "dev.jac.t";
        comp = IntentComponent(name="app", is_screen=True, route_path="/");
        comp.view = ViewElement(
            tag=HostTag(name="div", jac_node=None), attrs=[], children=[], jac_node=None
        );
        model.intent.components["app"] = comp;
        model.intent.routes = [
            IntentRoute(path="/", screen_name="HomeScreen", component="app")
        ];
        ComposeEmit(model=model, out_dir=Path(tmp)).emit_screens();
        joined = "\n".join(model.intent.diagnostics);
        assert "DOM IR" in joined;
        assert "app" in joined;
    }
}

# P0 #1 — fail-fast: any codegen diagnostic aborts the emit before Gradle ever
# sees a broken/empty-screen project. write() raises and writes no Kotlin.
test "write() raises on diagnostics and writes no Kotlin sources" {
    with tempfile.TemporaryDirectory() as tmp {
        model = ComposeModule();
        model.intent.package_name = "dev.jac.t";
        comp = IntentComponent(name="app", is_screen=True, route_path="/");
        comp.view = ViewElement(
            tag=HostTag(name="div", jac_node=None), attrs=[], children=[], jac_node=None
        );
        model.intent.components["app"] = comp;
        model.intent.routes = [
            IntentRoute(path="/", screen_name="HomeScreen", component="app")
        ];
        out = Path(tmp) / "android";
        raised = False;
        try {
            ComposeEmit(model=model, out_dir=out).write();
        } except RuntimeError {
            raised = True;
        }
        assert raised;
        # The fail-fast gate runs before the Kotlin write loop, so no .kt is
        # emitted for the rejected screen.
        kt_files = [p for p in out.rglob("*.kt")] if out.is_dir() else [];
        assert all("Screens.kt" != p.name for p in kt_files);
    }
}

test "write() succeeds with no diagnostics on a clean native model" {
    # Sanity check that the fail-fast gate does not fire for valid native IR.
    src = '''
def:pub app -> Composable {
    return <Column>
        <Text>"ok"</Text>
    </Column>;
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "app.jac";
        path.write_text(src, encoding="utf-8");
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.compiler.passes.compose.compose_gen_pass {
            run_compose_gen_pass
        }
        program = Jac.program;
        mod = program.compile(str(path));
        model = run_compose_gen_pass(mod, program);
        model.intent.package_name = "dev.jac.t";
        out = Path(tmp) / "android";
        raised = False;
        try {
            ComposeEmit(model=model, out_dir=out).write();
        } except Exception {
            raised = True;
        }
        assert not raised;
        assert not model.intent.diagnostics;
        assert (out / "app" / "src" / "main" / "java").is_dir();
    }
}

# P0 #4 — slot-wrapping is driven by the shared signature classifier, not a
# type-free heuristic: the emitter reads the SAME compose_widgets.txt the checker
# ingests, so the two cannot disagree about which argument is a @Composable slot.

test "the shared classifier loads and marks Scaffold's slots" {
    kinds = _widget_param_kinds();
    assert kinds , "compose_widgets.txt must load into the emitter's slot model";
    assert _is_slot_param("Scaffold", "topBar") , "topBar is a Scaffold slot";
    assert _is_slot_param("Scaffold", "content") , "content is a Scaffold slot";
    # a value/event param is NOT a slot
    assert not _is_slot_param("OutlinedTextField", "enabled");
    assert _is_known_nonslot_param("OutlinedTextField", "enabled");
}

test "_slot_wrap wraps declared slots and open-vocab widgets, not known values" {
    call = kt.KtComposableCall(name="Text", args=[]);
    # a declared slot on a known widget -> lambda-wrapped @Composable () -> Unit
    wrapped = _slot_wrap(call, "Scaffold", "topBar");
    assert isinstance(wrapped, kt.KtLambda) , "a Scaffold slot must wrap in a lambda";
    # a composable passed to a KNOWN non-slot value param -> left as a plain value
    passthru = _slot_wrap(call, "OutlinedTextField", "enabled");
    assert passthru is call , "a known value param must not be slot-wrapped";
    # an unknown (user/library) widget -> open-vocab fallback still wraps
    open_vocab = _slot_wrap(call, "MyCustomCard", "header");
    assert isinstance(open_vocab, kt.KtLambda) , "unknown widgets fall back to wrapping";
    # a non-composable attribute value is never touched
    lit = kt.KtLiteral(value="hi");
    assert _slot_wrap(lit, "Text", "text") is lit;
}

# #5 — emit_jac_app's dispatcher and emit_screens' screen functions share ONE
# route->screen resolution, so a `when` arm can never point at a screen that was
# never emitted (or vice versa).
test "emit_jac_app when-arms reference only screens emit_screens defines" {
    model = ComposeModule();
    model.intent.package_name = "dev.jac.t";
    model.intent.routes = [
        IntentRoute(path="/", screen_name="HomeScreen", component="app"),
        IntentRoute(path="/profile", screen_name="ProfileScreen", component="profile")
    ];
    for n in ["app", "profile"] {
        model.intent.components[n] = IntentComponent(name=n, is_screen=True);
    }
    em = ComposeEmit(model=model, out_dir=Path("/tmp"));
    app = em.emit_jac_app();
    screens = em.emit_screens();
    for sname in ["HomeScreen", "ProfileScreen"] {
        assert f"fun {sname}(" in screens , f"{sname} must be defined";
        assert f"{sname}(" in app , f"{sname} must be dispatched";
    }
    assert model.intent.diagnostics == [] , "clean model must have no diagnostics";
}

# #6 — lossy normalization: `/foo-bar` and `/foo_bar` both lower to FooBarScreen.
# In production, screen_name is computed from the path (screen_name_for), so two
# distinct pages whose paths normalize identically collide. Rather than
# silently dropping one screen (old `seen`-set behaviour) and emitting a `when`
# arm into nothing, the resolver records a diagnostic so write() refuses to
# ship broken/duplicate Kotlin.
test "route plan flags screen-name collisions instead of silent dupes" {
    model = ComposeModule();
    model.intent.package_name = "dev.jac.t";
    # Both paths normalize to FooBarScreen (locked by the identifier test above);
    # production would assign each route that same computed screen_name.
    model.intent.routes = [
        IntentRoute(path="/foo-bar", screen_name="FooBarScreen"),
        IntentRoute(path="/foo_bar", screen_name="FooBarScreen")
    ];
    ComposeEmit(model=model, out_dir=Path("/tmp")).emit_screens();
    joined = "\n".join(model.intent.diagnostics);
    assert "FooBarScreen" in joined;
    assert "both lower to screen" in joined;
}

# #7 — navigation operation/mode are typed Kotlin enums, not string literals
# compared at runtime (no `operation == "replace"` / `mode == "webview"`).
test "navigation uses typed enums, not stringly-typed operation/mode" {
    model = ComposeModule();
    model.intent.package_name = "dev.jac.t";
    model.intent.routes = [
        IntentRoute(path="/", screen_name="HomeScreen", component="app")
    ];
    model.intent.components["app"] = IntentComponent(name="app", is_screen=True);
    code = ComposeEmit(model=model, out_dir=Path("/tmp")).emit_screens();
    assert "enum class JacNavOperation" in code;
    assert "enum class JacExternalMode" in code;
    assert "fun navigate(operation: JacNavOperation," in code;
    assert "fun openExternal(mode: JacExternalMode," in code;
    assert 'operation == "replace"' not in code;
    assert 'mode == "webview"' not in code;
}

# #8 — Jac arithmetic semantics runtime. `/`, `//`, `%` lower to JacMath so
# the emitted Kotlin can't adopt Kotlin's truncating integer semantics. The
# helpers preserve the Jac result type via Kotlin overload resolution
# (Int operands -> Int, a float operand -> Double) and floor/mod toward the
# correct (Jac/Python) direction.
test "JacMath runtime encodes Jac division/floor/mod semantics" {
    import from jaclang.compiler.passes.compose.compose_emit { _emit_jac_math }
    kt = _emit_jac_math("dev.jac.t");
    assert "package dev.jac.t" in kt;
    assert "object JacMath" in kt;
    # true division always yields Double
    assert "fun truediv(a: Number, b: Number): Double" in kt;
    # floor division: Int overload floors toward -inf (Math.floorDiv), Double
    # overload via kotlin.math.floor
    assert "fun floorDiv(a: Int, b: Int): Int = Math.floorDiv(a, b)" in kt;
    assert "kotlin.math.floor(a / b)" in kt;
    # modulo: Int overload takes divisor's sign (Math.floorMod)
    assert "fun mod(a: Int, b: Int): Int = Math.floorMod(a, b)" in kt;
    assert "fun mod(a: Double, b: Double): Double = ((a % b) + b) % b" in kt;
}

# #9 — pages that export the same name must not clobber each other on merge.
# The router lets distinct files share an export name (e.g. every page exports
# `View`); the path-derived component_import is the unique identity, so each
# page's component is re-keyed to it before merging into the aggregate model.
test "repeated export names merge to distinct components by component_import" {
    import from jaclang.compiler.passes.ecmascript.intent.model { IntentComponent }
    import from jaclang.compiler.passes.compose.view_ir { ComposeElement }

    def _page(export_name: str) -> ComposeModule {
        pm = ComposeModule();
        pm.intent.components[export_name] = IntentComponent(name=export_name);
        pm.compose_views[export_name] = ComposeElement(name=export_name);
        return pm;
    }

    # two pages both exporting `View` — the bug: merge keys by source export
    page_index = _page("View");
    page_about = _page("View");
    page_index.rename_component("View", "PagesIndex");
    page_about.rename_component("View", "PagesAbout");

    model = ComposeModule();
    model.merge_from(page_index);
    model.merge_from(page_about);

    assert "PagesIndex" in model.intent.components;
    assert "PagesAbout" in model.intent.components;
    assert "View" not in model.intent.components;
    assert model.compose_view_for("PagesIndex") is not None;
    assert model.compose_view_for("PagesAbout") is not None;
    assert model.compose_view_for("PagesIndex")
        is not model.compose_view_for("PagesAbout");
}
