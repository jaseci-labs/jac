"""Tests for client-side code generation."""

from __future__ import annotations

import os
from pathlib import Path
from tempfile import NamedTemporaryFile

from jaclang.compiler.program import JacProgram
from jaclang.utils.test import TestCase


FIXTURE_DIR = (
    Path(__file__).resolve().parent.parent
    / "passes"
    / "ecmascript"
    / "tests"
    / "fixtures"
)


class TestClientCodegen(TestCase):
    """Test client-side code generation and JavaScript transpilation."""

    def test_js_codegen_generates_js_and_manifest(self) -> None:
        """Test JavaScript code generation produces valid output and manifest."""
        fixture = FIXTURE_DIR / "client_jsx.jac"
        prog = JacProgram()
        module = prog.compile(str(fixture))

        self.assertTrue(
            module.gen.js.strip(), "Expected JavaScript output for client declarations"
        )
        self.assertIn("function component", module.gen.js)
        self.assertIn("__jacJsx(", module.gen.js)

        # Client Python code should be omitted in js_only mode
        self.assertNotIn("def component", module.gen.py)

        # Metadata should be stored in module.gen.client_manifest
        self.assertNotIn("__jac_client_manifest__", module.gen.py)
        manifest = module.gen.client_manifest
        self.assertTrue(manifest, "Client manifest should be available in module.gen")
        self.assertIn("component", manifest.exports)
        self.assertIn("ButtonProps", manifest.exports)
        self.assertIn("API_URL", manifest.globals)

        # Module.gen.client_manifest should have the metadata
        self.assertIn("component", module.gen.client_manifest.exports)
        self.assertIn("ButtonProps", module.gen.client_manifest.exports)
        self.assertIn("API_URL", module.gen.client_manifest.globals)
        self.assertEqual(module.gen.client_manifest.params.get("component", []), [])
        self.assertNotIn("ButtonProps", module.gen.client_manifest.params)

        # Bug fixes
        self.assertIn(
            'let component = new MyComponent({title: "Custom Title"});', module.gen.js
        )

    def test_compilation_skips_python_stubs(self) -> None:
        """Test that client Python definitions are intentionally omitted."""
        fixture = FIXTURE_DIR / "client_jsx.jac"
        prog = JacProgram()
        module = prog.compile(str(fixture))

        self.assertTrue(
            module.gen.js.strip(), "Expected JavaScript output when emitting both"
        )
        self.assertIn("function component", module.gen.js)
        self.assertIn("__jacJsx(", module.gen.js)

        # Client Python definitions are intentionally omitted
        self.assertNotIn("def component", module.gen.py)
        self.assertNotIn("__jac_client__", module.gen.py)
        self.assertNotIn("class ButtonProps", module.gen.py)

        # Manifest data should be in module.gen.client_manifest
        self.assertNotIn("__jac_client_manifest__", module.gen.py)
        manifest = module.gen.client_manifest
        self.assertTrue(manifest, "Client manifest should be available in module.gen")
        self.assertIn("component", manifest.exports)
        self.assertIn("ButtonProps", manifest.exports)
        self.assertIn("API_URL", manifest.globals)

        # Module.gen.client_manifest should have the metadata
        self.assertIn("component", module.gen.client_manifest.exports)
        self.assertIn("ButtonProps", module.gen.client_manifest.exports)
        self.assertIn("API_URL", module.gen.client_manifest.globals)
        self.assertEqual(module.gen.client_manifest.params.get("component", []), [])

    def test_type_to_typeof_conversion(self) -> None:
        """Test that type() calls are converted to typeof in JavaScript."""
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

        with NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f:
            f.write(test_code)
            f.flush()

            prog = JacProgram()
            module = prog.compile(f.name)

            self.assertTrue(
                module.gen.js.strip(), "Expected JavaScript output for client code"
            )

            # Verify type() was converted to typeof
            self.assertIn(
                "typeof", module.gen.js, "type() should be converted to typeof"
            )
            self.assertEqual(
                module.gen.js.count("typeof"), 4, "Should have 4 typeof expressions"
            )

            # Verify no type() calls remain
            self.assertNotIn(
                "type(", module.gen.js, "No type() calls should remain in JavaScript"
            )

            # Verify the typeof expressions are correctly formed
            self.assertIn("typeof x", module.gen.js)
            self.assertIn("typeof y", module.gen.js)
            self.assertIn("typeof z", module.gen.js)
            self.assertIn('typeof "world"', module.gen.js)

            # Clean up
            os.unlink(f.name)

    def test_spawn_operator_supports_positional_and_spread(self) -> None:
        """Ensure spawn lowering handles positional args and **kwargs."""
        test_code = """walker MixedWalker {
    has label: str;
    has count: int;
    has meta: dict = {};
    can execute with `root entry;
}

cl def spawn_client() {
    let node_id = "abcd";
    let extra = {"meta": {"source": "client"}};
    let positional = node_id spawn MixedWalker("First", 3);
    let spread = MixedWalker("Second", 1, **extra) spawn root;
    return {"positional": positional, "spread": spread};
}
"""

        with NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f:
            f.write(test_code)
            f.flush()

            prog = JacProgram()
            module = prog.compile(f.name)
            js = module.gen.js

            self.assertIn(
                '__jacSpawn("MixedWalker", node_id, {"label": "First", "count": 3})',
                js,
            )
            self.assertIn(
                '__jacSpawn("MixedWalker", "", {"label": "Second", "count": 1, ...extra})',
                js,
            )

            os.unlink(f.name)
