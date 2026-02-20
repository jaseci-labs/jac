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

"""Test that .impl.cl.jac files inherit CLIENT context from their .cl.jac parent.

When a .cl.jac file has an associated .impl.cl.jac file, the impl module should
be coerced to CLIENT context. This means regular imports in the impl file
should generate normal ES imports, not sv import stubs.
"""
test "impl.cl.jac inherits client context from parent cl.jac" {
    with TemporaryDirectory() as tmpdir {
        # main.cl.jac - client file with sv import
        main_cl = Path(tmpdir) / "main.cl.jac";
        main_cl.write_text(
            "sv import from server { serverFunc }\n\ndef:pub app() { return serverFunc(); }"
        );

        # main.impl.cl.jac - impl for client file, should inherit CLIENT context
        impl_file = Path(tmpdir) / "main.impl.cl.jac";
        impl_file.write_text("import from helper { getHelper }");

        prog = JacProgram();
        mod = prog.compile(str(main_cl));
        js = mod.gen.js;

        # sv import should generate __jacCallFunction stub
        assert "__jacCallFunction" in js , "sv import should generate __jacCallFunction";
        assert "serverFunc" in js , "serverFunc stub should be generated";

        # __jacCallFunction appears twice: 1 import + 1 call (for serverFunc)
        # If impl was not coerced to CLIENT, getHelper would also generate a stub
        assert js.count("__jacCallFunction") == 2 , f"Expected 2 occurrences (1 import + 1 call)";

        # helper should be a regular ES import (not an RPC stub)
        assert "getHelper" in js , "getHelper should be in the output";
        assert 'await __jacCallFunction("getHelper"' not in js , "getHelper should not be an RPC stub";
        assert 'import { getHelper }' in js , "getHelper should be a regular ES import";
    }
}

"""Test that imports in .impl.cl.jac of a .cl.jac are not treated as sv imports.

Previously, .impl.jac files had SERVER context by default, causing regular
imports to be treated as sv imports and generating duplicate __jacCallFunction
stubs. This test ensures that's fixed.
"""
test "impl.cl.jac imports not treated as sv imports" {
    with TemporaryDirectory() as tmpdir {
        # app.cl.jac - client file with sv import
        app_cl = Path(tmpdir) / "app.cl.jac";
        app_cl.write_text(
            "sv import from server { getData }\n\ndef:pub main() { return getData(); }"
        );

        # app.impl.cl.jac - impl file for client, should inherit CLIENT context
        impl_file = Path(tmpdir) / "app.impl.cl.jac";
        impl_file.write_text(
            "import from module_a { funcA }\nimport from module_b { funcB }"
        );

        prog = JacProgram();
        mod = prog.compile(str(app_cl));
        js = mod.gen.js;

        # funcA and funcB should NOT have __jacCallFunction stubs (regular imports)
        assert 'await __jacCallFunction("funcA"' not in js , "funcA should not be an RPC stub";
        assert 'await __jacCallFunction("funcB"' not in js , "funcB should not be an RPC stub";

        # They should be regular ES imports
        assert 'import { funcA }' in js , "funcA should be a regular ES import";
        assert 'import { funcB }' in js , "funcB should be a regular ES import";

        # Only getData should be an RPC stub (from sv import)
        assert 'await __jacCallFunction("getData"' in js , "getData should be an RPC stub";

        # __jacCallFunction should only appear twice (1 import + 1 call for getData)
        assert js.count("__jacCallFunction") == 2 , f"Expected 2 occurrences (1 import + 1 call)";
    }
}

"""Test that .impl.jac for regular .jac files keeps SERVER context (default)."""
test "impl.jac for regular jac keeps server context" {
    with TemporaryDirectory() as tmpdir {
        # main.jac - regular server file
        main_jac = Path(tmpdir) / "main.jac";
        main_jac.write_text("def:pub serverFunc() { return 1; }");

        # main.impl.jac - impl for regular jac (stays SERVER context)
        impl_file = Path(tmpdir) / "main.impl.jac";
        impl_file.write_text("import from helper { helperFunc }");

        prog = JacProgram();
        mod = prog.compile(str(main_jac));

        # For server-side .jac, impl should also be server context
        # Server imports don't generate JS (they're Python)
        assert mod.gen.py is not None , "Server module should have Python output";
    }
}
