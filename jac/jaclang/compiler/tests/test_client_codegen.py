from __future__ import annotations

from pathlib import Path

from jaclang.compiler.program import JacProgram


FIXTURE_DIR = Path(__file__).resolve().parent.parent / "passes" / "ecmascript" / "tests" / "fixtures"


def test_js_codegen_generates_js_and_manifest() -> None:
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


def test_compilation_skips_python_stubs() -> None:
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
    from tempfile import NamedTemporaryFile

    # Create a temporary test file
    test_code = '''"""Test type() to typeof conversion."""

cl def check_types() {
    let x = 42;
    let y = "hello";
    let z = True;

    let t1 = type(x);
    let t2 = type(y);
    let t3 = type(z);
    let t4 = type("world");

    return t1;
}
'''

    with NamedTemporaryFile(mode='w', suffix='.jac', delete=False) as f:
        f.write(test_code)
        f.flush()

        prog = JacProgram()
        module = prog.compile(f.name)

        assert module.gen.js.strip(), "Expected JavaScript output for client code"

        # Verify type() was converted to typeof
        assert "typeof" in module.gen.js, "type() should be converted to typeof"
        assert module.gen.js.count("typeof") == 4, "Should have 4 typeof expressions"

        # Verify no type() calls remain
        assert "type(" not in module.gen.js, "No type() calls should remain in JavaScript"

        # Verify the typeof expressions are correctly formed
        assert "typeof x" in module.gen.js
        assert "typeof y" in module.gen.js
        assert "typeof z" in module.gen.js
        assert 'typeof "world"' in module.gen.js

        # Clean up
        import os
        os.unlink(f.name)
