"""Client-side code generation tests -- migrated from test_client_codegen.py."""

import os;
import from pathlib { Path }
import from tempfile { NamedTemporaryFile, TemporaryDirectory }
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURE_DIR = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "ecmascript", "fixtures"
     );

# test_js_codegen_generates_js_and_manifest is skipped in Python (randomly fails on CI)
test "compilation skips python stubs" {
    fixture = os.path.join(FIXTURE_DIR, "client_jsx.jac");
    prog = JacProgram();
    mod = prog.compile(fixture);

    assert mod.gen.js.strip() , "Expected JavaScript output when emitting both";
    assert "function component" in mod.gen.js;
    assert "__jacJsx(" in mod.gen.js;

    # Client Python definitions are intentionally omitted
    assert "def component" not in mod.gen.py;
    assert "__jac_client__" not in mod.gen.py;
    assert "class ButtonProps" not in mod.gen.py;

    # Manifest data should be in mod.gen.client_manifest
    assert "__jac_client_manifest__" not in mod.gen.py;
    manifest = mod.gen.client_manifest;
    assert manifest , "Client manifest should be available in mod.gen";
    assert "component" in manifest.exports;
    assert "ButtonProps" in manifest.exports;
    assert "API_URL" in manifest.globals;

    assert "component" in mod.gen.client_manifest.exports;
    assert "ButtonProps" in mod.gen.client_manifest.exports;
    assert "API_URL" in mod.gen.client_manifest.globals;
    assert mod.gen.client_manifest.params.get("component", []) == [];
}

test "type to typeof conversion" {
    test_code = '"""Test type() to typeof conversion."""\n\ncl def check_types() {\n    x = 42;\n    y = "hello";\n    z = True;\n\n    t1 = type(x);\n    t2 = type(y);\n    t3 = type(z);\n    t4 = type("world");\n\n    return t1;\n}\n';

    with NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f {
        f.write(test_code);
        f.flush();
        prog = JacProgram();
        mod = prog.compile(f.name);
        assert mod.gen.js.strip() , "Expected JavaScript output for client code";
        assert "typeof" in mod.gen.js , "type() should be converted to typeof";
        assert mod.gen.js.count("typeof") == 4 , "Should have 4 typeof expressions";
        assert "type(" not in mod.gen.js , "No type() calls should remain in JavaScript";
        assert "typeof x" in mod.gen.js;
        assert "typeof y" in mod.gen.js;
        assert "typeof z" in mod.gen.js;
        assert 'typeof "world"' in mod.gen.js;
        os.unlink(f.name);
    }
}

test "spawn operator supports positional and spread" {
    test_code = "walker MixedWalker {\n    has label: str;\n    has count: int;\n    has meta: dict = {};\n    can execute with Root entry;\n}\n\ncl def spawn_client() {\n    node_id = \"abcd\";\n    extra = {\"meta\": {\"source\": \"client\"}};\n    positional = node_id spawn MixedWalker(\"First\", 3);\n    spread = MixedWalker(\"Second\", 1, **extra) spawn root;\n    return {\"positional\": positional, \"spread\": spread};\n}\n";

    with NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f {
        f.write(test_code);
        f.flush();
        prog = JacProgram();
        mod = prog.compile(f.name);
        js = mod.gen.js;
        assert '__jacSpawn("MixedWalker", node_id, {"label": "First", "count": 3})' in js;
        assert '__jacSpawn("MixedWalker", "", {"label": "Second", "count": 1, ...extra})' in js;
        os.unlink(f.name);
    }
}

test "client import local jac module gets relative path" {
    with TemporaryDirectory() as tmpdir {
        local_module = Path(tmpdir) / "mymodule.jac";
        local_module.write_text("cl def helper() { return 42; }");
        main_file = Path(tmpdir) / "main.jac";
        main_file.write_text(
            "\ncl {\n    import from mymodule { helper }\n\n    def:pub app() {\n        return helper();\n    }\n}\n"
        );
        prog = JacProgram();
        mod = prog.compile(str(main_file));
        js = mod.gen.js;
        assert "./mymodule.js" in js , f"Local Jac module import should use ./mymodule.js, got: {js}";
        assert 'from "mymodule"' not in js , "Should not have bare module name without ./ prefix";
    }
}

test "def pub called from client imports jac call function" {
    test_code = '"""\nTest def:pub called from client context.\n"""\n\ndef:pub get_server_data(name: str) -> dict {\n    return {"message": "Hello " + name};\n}\n\ncl {\n    def:pub app() -> any {\n        data = await get_server_data("World");\n        return <div>{data}</div>;\n    }\n}\n';

    with NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f {
        f.write(test_code);
        f.flush();
        prog = JacProgram();
        mod = prog.compile(f.name);
        js = mod.gen.js;
        assert js.strip() , "Expected JavaScript output for client code";
        assert "__jacCallFunction" in js , "__jacCallFunction should be present in generated JS";
        assert "@jac/runtime" in js , "__jacCallFunction should be imported from @jac/runtime";
        assert '__jacCallFunction("get_server_data"' in js , "Should generate __jacCallFunction call with function name";
        os.unlink(f.name);
    }
}

test "endpoint effects classifies walkers and functions" {
    test_code = '"""Test auto endpoint effects."""\n\nnode Todo {\n    has title: str,\n        done: bool = False;\n}\n\nwalker get_todos {\n    can visit_root with Root entry {\n        report [-->];\n    }\n}\n\nwalker create_todo {\n    has title: str;\n    can do_create with Root entry {\n        here ++> Todo(title=self.title);\n    }\n}\n\ndef:pub get_stats() -> dict {\n    return {"count": 10};\n}\n\ndef:pub reset_data() -> dict {\n    items = [];\n    del items;\n    return {};\n}\n\ncl {\n    def:pub app() {\n        todos = root spawn get_todos();\n        root spawn create_todo(title="test");\n        stats = await get_stats();\n        result = await reset_data();\n    }\n}\n';

    with NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f {
        f.write(test_code);
        f.flush();
        prog = JacProgram();
        mod = prog.compile(f.name);
        effects = mod.gen.client_manifest.endpoint_effects;
        # Walker reader: no write operations in body
        assert "walker:get_todos" in effects , "get_todos should be in endpoint_effects";
        assert not effects["walker:get_todos"]["is_writer"] , "get_todos should be classified as reader";
        # Walker writer: has connect op (++>) and node constructor
        assert "walker:create_todo" in effects , "create_todo should be in endpoint_effects";
        assert effects["walker:create_todo"]["is_writer"] , "create_todo should be classified as writer";
        # Function reader: just returns data, no mutations
        assert "func:get_stats" in effects , "get_stats should be in endpoint_effects";
        assert not effects["func:get_stats"]["is_writer"] , "get_stats should be classified as reader";
        # Function writer: has del statement
        assert "func:reset_data" in effects , "reset_data should be in endpoint_effects";
        assert effects["func:reset_data"]["is_writer"] , "reset_data should be classified as writer";
        # Verify touches metadata is present
        for key in effects {
            assert "touches" in effects[key] , f"{key} should have touches list";
            assert len(effects[key]["touches"]) > 0 , f"{key} should have non-empty touches";
        }
        os.unlink(f.name);
    }
}

test "jac call function sends params directly" {
    jac_root = Path(jaclang.__file__).resolve().parent.parent.parent;
    runtime_path = (
        jac_root / "jac-client" / "jac_client" / "plugin" / "impl" / "client_runtime.impl.jac"
    );

    if not runtime_path.exists() {
        return;  # skip if jac-client not found

    }

    content = runtime_path.read_text();

    assert "impl __jacCallFunction" in content , "Should have __jacCallFunction implementation";
    assert '"args": args' not in content , 'client_runtime should NOT wrap params in "args" object';
    assert "'args': args" not in content , "client_runtime should NOT wrap params in 'args' object";
    assert "JSON.stringify(args)" in content , "client_runtime should send params directly with JSON.stringify(args)";
}
