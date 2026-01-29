"""Tests for client-side code generation."""

from __future__ import annotations

import os
from pathlib import Path
from tempfile import NamedTemporaryFile

import pytest

from jaclang.pycore.program import JacProgram

FIXTURE_DIR = Path(__file__).resolve().parent / "passes" / "ecmascript" / "fixtures"


@pytest.mark.skip(reason="Failing randomly on CI")
def test_js_codegen_generates_js_and_manifest() -> None:
    """Test JavaScript code generation produces valid output and manifest."""
    fixture = FIXTURE_DIR / "client_jsx.jac"
    prog = JacProgram()
    module = prog.compile(str(fixture))

    assert module.gen.js.strip(), "Expected JavaScript output for client declarations"
    assert "function component" in module.gen.js
    assert "__jacJsx(" in module.gen.js

    # Client Python code should be omitted in js_only mode
    assert "def component" not in module.gen.py

    # Metadata should be stored in module.gen.client_manifest
    assert "__jac_client_manifest__" not in module.gen.py
    manifest = module.gen.client_manifest
    assert manifest, "Client manifest should be available in module.gen"
    assert "component" in manifest.exports
    assert "ButtonProps" in manifest.exports
    assert "API_URL" in manifest.globals

    # Module.gen.client_manifest should have the metadata
    assert "component" in module.gen.client_manifest.exports
    assert "ButtonProps" in module.gen.client_manifest.exports
    assert "API_URL" in module.gen.client_manifest.globals
    assert module.gen.client_manifest.params.get("component", []) == []
    assert "ButtonProps" not in module.gen.client_manifest.params

    # Bug fixes
    assert 'let component = new MyComponent({title: "Custom Title"});' in module.gen.js


def test_compilation_skips_python_stubs() -> None:
    """Test that client Python definitions are intentionally omitted."""
    fixture = FIXTURE_DIR / "client_jsx.jac"
    prog = JacProgram()
    module = prog.compile(str(fixture))

    assert module.gen.js.strip(), "Expected JavaScript output when emitting both"
    assert "function component" in module.gen.js
    assert "__jacJsx(" in module.gen.js

    # Client Python definitions are intentionally omitted
    assert "def component" not in module.gen.py
    assert "__jac_client__" not in module.gen.py
    assert "class ButtonProps" not in module.gen.py

    # Manifest data should be in module.gen.client_manifest
    assert "__jac_client_manifest__" not in module.gen.py
    manifest = module.gen.client_manifest
    assert manifest, "Client manifest should be available in module.gen"
    assert "component" in manifest.exports
    assert "ButtonProps" in manifest.exports
    assert "API_URL" in manifest.globals

    # Module.gen.client_manifest should have the metadata
    assert "component" in module.gen.client_manifest.exports
    assert "ButtonProps" in module.gen.client_manifest.exports
    assert "API_URL" in module.gen.client_manifest.globals
    assert module.gen.client_manifest.params.get("component", []) == []


def test_type_to_typeof_conversion() -> None:
    """Test that type() calls are converted to typeof in JavaScript."""
    # Create a temporary test file
    test_code = '''"""Test type() to typeof conversion."""

cl def check_types() {
    x = 42;
    y = "hello";
    z = True;

    t1 = type(x);
    t2 = type(y);
    t3 = type(z);
    t4 = type("world");

    return t1;
}
'''

    with NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f:
        f.write(test_code)
        f.flush()

        prog = JacProgram()
        module = prog.compile(f.name)

        assert module.gen.js.strip(), "Expected JavaScript output for client code"

        # Verify type() was converted to typeof
        assert "typeof" in module.gen.js, "type() should be converted to typeof"
        assert module.gen.js.count("typeof") == 4, "Should have 4 typeof expressions"

        # Verify no type() calls remain
        assert "type(" not in module.gen.js, (
            "No type() calls should remain in JavaScript"
        )

        # Verify the typeof expressions are correctly formed
        assert "typeof x" in module.gen.js
        assert "typeof y" in module.gen.js
        assert "typeof z" in module.gen.js
        assert 'typeof "world"' in module.gen.js

        # Clean up
        os.unlink(f.name)


def test_spawn_operator_supports_positional_and_spread() -> None:
    """Ensure spawn lowering handles positional args and **kwargs."""
    test_code = """walker MixedWalker {
    has label: str;
    has count: int;
    has meta: dict = {};
    can execute with `root entry;
}

cl def spawn_client() {
    node_id = "abcd";
    extra = {"meta": {"source": "client"}};
    positional = node_id spawn MixedWalker("First", 3);
    spread = MixedWalker("Second", 1, **extra) spawn root;
    return {"positional": positional, "spread": spread};
}
"""

    with NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f:
        f.write(test_code)
        f.flush()

        prog = JacProgram()
        module = prog.compile(f.name)
        js = module.gen.js

        assert (
            '__jacSpawn("MixedWalker", node_id, {"label": "First", "count": 3})' in js
        )
        assert (
            '__jacSpawn("MixedWalker", "", {"label": "Second", "count": 1, ...extra})'
            in js
        )

        os.unlink(f.name)


def test_client_import_local_jac_module_gets_relative_path() -> None:
    """Test that absolute imports of local Jac modules get ./ prefix in JS."""
    from tempfile import TemporaryDirectory

    with TemporaryDirectory() as tmpdir:
        # Create a local module file
        local_module = Path(tmpdir) / "mymodule.jac"
        local_module.write_text("cl def helper() { return 42; }")

        # Create main file that imports it without dot prefix
        main_file = Path(tmpdir) / "main.jac"
        main_file.write_text("""
cl {
    import from mymodule { helper }

    def:pub app() {
        return helper();
    }
}
""")

        prog = JacProgram()
        module = prog.compile(str(main_file))

        js = module.gen.js
        # Should have ./ prefix for local module, not bare "mymodule"
        assert "./mymodule.js" in js, (
            f"Local Jac module import should use ./mymodule.js, got: {js}"
        )
        assert 'from "mymodule"' not in js, (
            "Should not have bare module name without ./ prefix"
        )


def test_def_pub_called_from_client_imports_jac_call_function() -> None:
    """Test that calling def:pub from cl{} generates __jacCallFunction import.

    When a server function (def:pub) is called from client code (cl {}),
    the generated JavaScript must import __jacCallFunction from @jac/runtime.
    This is a regression test for the bug where the import was missing.
    """
    test_code = '''
"""Test def:pub called from client context."""

def:pub get_server_data(name: str) -> dict {
    return {"message": "Hello " + name};
}

cl {
    def:pub app() -> any {
        data = await get_server_data("World");
        return <div>{data}</div>;
    }
}
'''

    with NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f:
        f.write(test_code)
        f.flush()

        prog = JacProgram()
        module = prog.compile(f.name)

        js = module.gen.js
        assert js.strip(), "Expected JavaScript output for client code"

        # Verify __jacCallFunction is imported from @jac/runtime
        assert "__jacCallFunction" in js, (
            "__jacCallFunction should be present in generated JS"
        )
        # Check for the import statement (may have varying whitespace)
        assert "@jac/runtime" in js, (
            "__jacCallFunction should be imported from @jac/runtime"
        )

        # Verify the function call is generated correctly
        assert '__jacCallFunction("get_server_data"' in js, (
            "Should generate __jacCallFunction call with function name"
        )

        # Clean up
        os.unlink(f.name)


def test_jac_call_function_sends_params_directly() -> None:
    """Test that __jacCallFunction sends params directly, not wrapped in 'args'.

    The client runtime's __jacCallFunction should send parameters as:
        JSON.stringify(args)  // correct: {"name": "value"}
    NOT:
        JSON.stringify({"args": args})  // wrong: {"args": {"name": "value"}}

    This is a regression test for the bug where the server returned 422
    because params were wrapped in an extra 'args' object.
    """
    # Find the jac-client runtime source file
    jac_root = Path(__file__).resolve().parent.parent.parent.parent
    runtime_path = (
        jac_root
        / "jac-client"
        / "jac_client"
        / "plugin"
        / "impl"
        / "client_runtime.impl.jac"
    )

    if not runtime_path.exists():
        pytest.skip("jac-client not found in expected location")

    content = runtime_path.read_text()

    # Find the __jacCallFunction implementation
    assert "impl __jacCallFunction" in content, (
        "Should have __jacCallFunction implementation"
    )

    # Should NOT have the {"args": args} wrapper pattern
    assert '"args": args' not in content, (
        "client_runtime should NOT wrap params in 'args' object. "
        'Use JSON.stringify(args) not JSON.stringify({"args": args})'
    )
    assert "'args': args" not in content, (
        "client_runtime should NOT wrap params in 'args' object"
    )

    # Should have direct JSON.stringify(args)
    assert "JSON.stringify(args)" in content, (
        "client_runtime should send params directly with JSON.stringify(args)"
    )


def test_compiler_generates_export_statements() -> None:
    """Test that compiler generates comprehensive export statement with all :pub items."""
    fixture = FIXTURE_DIR / "client_jsx.jac"
    prog = JacProgram()
    module = prog.compile(str(fixture))

    js = module.gen.js
    manifest = module.gen.client_manifest

    # Verify single comprehensive export statement exists
    assert js.count("export {") == 1, "Should have exactly one export statement"

    export_start = js.index("export {")
    export_end = js.index("};", export_start) + 2
    export_statement = js[export_start:export_end]

    # All manifest exports and globals should be in export statement
    all_exported_names = set(manifest.exports + manifest.globals)
    for name in all_exported_names:
        assert name in export_statement, f"'{name}' missing from export statement"


def test_pub_keyword_required_for_exports() -> None:
    """Test that only :pub declarations are exported, not all client declarations."""
    test_code = """
    cl {
        glob PRIVATE_VAR: str = "private";
        glob:pub PUBLIC_VAR: str = "public";

        def private_helper() -> str {
            return "private";
        }
        obj PrivateClass {
            has value: int = 0;
        }
        def:pub public_app() -> any {
            return <div>{private_helper()}</div>;
        }
        obj:pub PublicClass {
            has value: int = 0;
        }
    }"""

    with NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f:
        f.write(test_code)
        f.flush()

        prog = JacProgram()
        module = prog.compile(f.name)
        manifest = module.gen.client_manifest
        js = module.gen.js

        # Only :pub items should be in manifest
        assert "public_app" in manifest.exports and "PublicClass" in manifest.exports
        assert "PUBLIC_VAR" in manifest.globals
        assert (
            "private_helper" not in manifest.exports
            and "PrivateClass" not in manifest.exports
        )
        assert "PRIVATE_VAR" not in manifest.globals

        # Only :pub items should be in export statement
        export_start = js.index("export {")
        export_statement = js[export_start : js.index("};", export_start) + 2]
        assert all(
            name in export_statement
            for name in ["PUBLIC_VAR", "public_app", "PublicClass"]
        )
        assert all(
            name not in export_statement
            for name in ["PRIVATE_VAR", "private_helper", "PrivateClass"]
        )

        os.unlink(f.name)


def test_no_exports_without_pub_keyword() -> None:
    """Test that modules without :pub declarations have no export statement."""
    test_code = """
    cl {
        glob INTERNAL_VAR: str = "internal";
        def helper() -> str { return "helper"; }
        def app() -> any { return <div>{helper()}</div>; }
    }"""

    with NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f:
        f.write(test_code)
        f.flush()

        prog = JacProgram()
        module = prog.compile(f.name)

        assert len(module.gen.client_manifest.exports) == 0
        assert len(module.gen.client_manifest.globals) == 0
        assert "export {" not in module.gen.js

        os.unlink(f.name)


def test_single_component_export_generation() -> None:
    """Test export generation for a simple single-component module."""
    test_code = """
    cl {
        def:pub Button(label: str) -> any {
            return <button>{label}</button>;
        }
    }"""

    with NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f:
        f.write(test_code)
        f.flush()

        prog = JacProgram()
        module = prog.compile(f.name)

        assert "Button" in module.gen.client_manifest.exports
        assert "export {" in module.gen.js and "Button" in module.gen.js
        assert module.gen.js.count("export {") == 1

        os.unlink(f.name)


def test_mixed_exports_and_globals() -> None:
    """Test export generation with both function exports and global variables."""
    test_code = """
    cl {
        glob API_URL: str = "https://example.com";
        glob MAX_ITEMS: int = 100;
        def:pub fetchData() -> any { return API_URL; }
        def:pub getLimit() -> int { return MAX_ITEMS; }
    }"""

    with NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f:
        f.write(test_code)
        f.flush()

        prog = JacProgram()
        module = prog.compile(f.name)

        assert module.gen.js.count("export {") == 1
        export_start = module.gen.js.index("export {")
        export_statement = module.gen.js[
            export_start : module.gen.js.index("};", export_start) + 2
        ]

        expected = set(
            module.gen.client_manifest.exports + module.gen.client_manifest.globals
        )
        assert all(name in export_statement for name in expected)

        os.unlink(f.name)


def test_private_items_not_importable() -> None:
    """Test that only :pub items are exported and importable."""
    from tempfile import TemporaryDirectory

    with TemporaryDirectory() as tmpdir:
        provider = Path(tmpdir) / "provider.jac"
        provider.write_text("""
        cl {
            glob:pub PUBLIC_CONST: str = "public";
            glob PRIVATE_CONST: str = "private";
            def:pub publicFunc() -> str { return "public"; }
            def privateFunc() -> str { return "private"; }
        }""")

        consumer = Path(tmpdir) / "consumer.jac"
        consumer.write_text("""
        cl {
            import from provider { publicFunc, PUBLIC_CONST }
            def:pub app() -> any {
                return <div>{publicFunc()} {PUBLIC_CONST}</div>;
            }
        }""")

        prog = JacProgram()
        provider_mod = prog.compile(str(provider))

        # Only :pub items in manifest and export statement
        assert "PUBLIC_CONST" in provider_mod.gen.client_manifest.globals
        assert "PRIVATE_CONST" not in provider_mod.gen.client_manifest.globals
        assert "publicFunc" in provider_mod.gen.client_manifest.exports
        assert "privateFunc" not in provider_mod.gen.client_manifest.exports

        export_idx = provider_mod.gen.js.index("export {")
        assert "PUBLIC_CONST" in provider_mod.gen.js[export_idx:]
        assert "publicFunc" in provider_mod.gen.js[export_idx:]

        # Consumer can import :pub items
        consumer_mod = prog.compile(str(consumer))
        assert (
            "publicFunc" in consumer_mod.gen.js
            and "PUBLIC_CONST" in consumer_mod.gen.js
        )
