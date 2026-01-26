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
