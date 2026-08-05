"""Tests for M5 — Material surface breadth, Raw escape hatch, theme/typography."""
import from jaclang.compiler.passes.compose.compose_gen_pass { run_compose_gen_pass }
import from jaclang.compiler.passes.compose.compose_emit { ComposeEmit }
import from jaclang.compiler.passes.compose.compose_native_emit { ComposeNativeEmitter }
import from jaclang.compiler.passes.compose.gradle_scaffold { build_gradle_scaffold }
import from jaclang.compiler.passes.compose.jac_to_kotlin { jac_expr_to_kt }
import from jaclang.compiler.passes.ecmascript.intent.detection { unwrap_ability_body }
import from jaclang.compiler.passes.compose.kotlin_unparse { kt_to_source }
import from pathlib { Path }
import jaclang.jac0core.unitree as uni;
import tempfile;

test "Typography.titleLarge lowers to MaterialTheme.typography" {
    src = '''
def test_typo -> any {
    return Typography.titleLarge;
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "typo.jac";
        path.write_text(src, encoding="utf-8");
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        mod = Jac.program.compile(str(path));
        found = False;
        for ability in mod.get_all_sub_nodes(uni.Ability) {
            if ability.name_ref and ability.name_ref.sym_name == "test_typo" {
                stmts = unwrap_ability_body(ability);
                if stmts {
                    for stmt in stmts {
                        if isinstance(stmt, uni.ReturnStmt) and stmt.expr {
                            found = True;
                            kt_node = jac_expr_to_kt(stmt.expr);
                            src_kt = kt_to_source(kt_node);
                            assert "MaterialTheme.typography.titleLarge" in src_kt;
                            assert "Typography" not in src_kt;
                        }
                    }
                }
            }
        }
        assert found;
    }
}

test "integer.dp lowers to Kotlin dp extension" {
    src = '''
def test_dp -> any {
    return 16.dp;
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "dp.jac";
        path.write_text(src, encoding="utf-8");
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        mod = Jac.program.compile(str(path));
        found = False;
        for ability in mod.get_all_sub_nodes(uni.Ability) {
            if ability.name_ref and ability.name_ref.sym_name == "test_dp" {
                stmts = unwrap_ability_body(ability);
                if stmts {
                    for stmt in stmts {
                        if isinstance(stmt, uni.ReturnStmt) and stmt.expr {
                            found = True;
                            kt_node = jac_expr_to_kt(stmt.expr);
                            src_kt = kt_to_source(kt_node).replace(" ", "");
                            assert "16.dp" in src_kt;
                        }
                    }
                }
            }
        }
        assert found;
    }
}

test "Raw element emits verbatim Kotlin" {
    src = '''
def:pub app -> Composable {
    return <Column>
        <Raw kotlin={"Icon(Icons.Default.Star, contentDescription = null)"} />
    </Column>;
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "raw.jac";
        path.write_text(src, encoding="utf-8");
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        program = Jac.program;
        mod = program.compile(str(path));
        model = run_compose_gen_pass(mod, program);
        comp = model.intent.components["app"];
        emitter = ComposeNativeEmitter();
        kt = emitter.emit_component_view(model, comp);
        assert "Icon(Icons.Default.Star" in kt;
        assert "<Raw" not in kt;
    }
}

test "ComposeEmit includes MaterialTheme and typography imports" {
    src = '''
def:pub app -> Composable {
    return <Column>
        <Text style={Typography.titleLarge}>"Title"</Text>
    </Column>;
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "title.jac";
        path.write_text(src, encoding="utf-8");
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        program = Jac.program;
        mod = program.compile(str(path));
        model = run_compose_gen_pass(mod, program);
        model.intent.package_name = "dev.jac.test";
        screens = ComposeEmit(model=model, out_dir=Path(tmp)).emit_screens();
        assert "import androidx.compose.material3.*" in screens;
        assert "MaterialTheme.typography.titleLarge" in screens;
    }
}

test "scaffold wraps JacApp in MaterialTheme" {
    files = build_gradle_scaffold(
        "dev.jac.myapp", "My App", "http://10.0.2.2:8000", ["/"], dev=True
    );
    main = files["hot/src/main/java/dev/jac/myapp/MainActivity.kt"];
    dev_entry = files["hot/src/main/java/dev/jac/myapp/JacDevEntry.kt"];
    assert "MaterialTheme {" in main;
    assert "MaterialTheme {" in dev_entry;
}

test "expanded primitives emit Scaffold and Icon" {
    src = '''
def:pub app -> Composable {
    return <Scaffold topBar={<TopAppBar title={<Text>"App"</Text>} />}>
        <Icon imageVector={Icons.Default.Home} contentDescription={"Home"} />
    </Scaffold>;
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "scaffold.jac";
        path.write_text(src, encoding="utf-8");
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        program = Jac.program;
        mod = program.compile(str(path));
        model = run_compose_gen_pass(mod, program);
        model.intent.package_name = "dev.jac.test";
        screens = ComposeEmit(model=model, out_dir=Path(tmp)).emit_screens();
        assert "Scaffold(" in screens;
        assert "TopAppBar(" in screens;
        assert "Icon(" in screens;
        assert "import androidx.compose.material3.*" in screens;
    }
}

test "off-whitelist widgets emit near-identity and resolve via wildcard imports" {
    # Slider / LinearProgressIndicator / AssistChip are not hand-curated
    # primitives. The emitter lowers them as ordinary composable calls and the wildcard
    # material3 import makes them resolve with zero per-widget scaffolding —
    # this is the open-vocabulary contract.
    src = '''
def:pub app -> Composable {
    return <Column>
        <Slider value={0.5} onValueChange={(v) => {}} />
        <LinearProgressIndicator />
        <AssistChip onClick={(e) => {}} label={<Text>"Chip"</Text>} />
    </Column>;
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "widgets.jac";
        path.write_text(src, encoding="utf-8");
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        program = Jac.program;
        mod = program.compile(str(path));
        model = run_compose_gen_pass(mod, program);
        model.intent.package_name = "dev.jac.test";
        screens = ComposeEmit(model=model, out_dir=Path(tmp)).emit_screens();
        assert "Slider(" in screens;
        assert "LinearProgressIndicator(" in screens;
        assert "AssistChip(" in screens;
        assert "import androidx.compose.material3.*" in screens;
    }
}

test "composable-valued attributes emit as @Composable slot lambdas" {
    # A composable passed as an attribute value is a Compose content slot and
    # must be wrapped in a lambda: `topBar = { TopAppBar(...) }`, not the invalid
    # `topBar = TopAppBar(...)`. Covers the whole open vocabulary generically.
    src = '''
def:pub app -> Composable {
    return <Scaffold topBar={<TopAppBar title={<Text>"App"</Text>} />}>
        <Text>"Body"</Text>
    </Scaffold>;
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "slots.jac";
        path.write_text(src, encoding="utf-8");
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        program = Jac.program;
        mod = program.compile(str(path));
        model = run_compose_gen_pass(mod, program);
        model.intent.package_name = "dev.jac.test";
        screens = ComposeEmit(model=model, out_dir=Path(tmp)).emit_screens();
        # slot is lambda-wrapped, not passed as a bare value
        assert "topBar = {" in screens;
        assert "topBar = TopAppBar" not in screens;
    }
}
