"""Tests for client bundle generation."""

from __future__ import annotations

from pathlib import Path

from jaclang.runtimelib.machine import JacMachine as Jac
from jaclang.utils.test import TestCase


class ClientBundleBuilderTests(TestCase):
    """Validate client bundle compilation."""

    def setUp(self) -> None:
        Jac.reset_machine()
        return super().setUp()

    def tearDown(self) -> None:
        Jac.reset_machine()
        return super().tearDown()

    def test_build_bundle_for_module(self) -> None:
        """Compile a Jac module and ensure client bundle metadata is emitted."""
        fixtures_dir = Path(__file__).parent / "fixtures"
        (module,) = Jac.jac_import("client_app", str(fixtures_dir))

        builder = Jac.get_client_bundle_builder()
        bundle = builder.build(module)

        self.assertIn("function __jacJsx", bundle.code)
        # Check that registration mechanism is present
        self.assertIn("moduleFunctions[funcName] = funcRef;", bundle.code)
        self.assertIn("scope[funcName] = funcRef;", bundle.code)
        self.assertIn("moduleGlobals[gName] = existing;", bundle.code)
        self.assertIn("scope[gName] = defaultValue;", bundle.code)
        # Check that actual client functions and globals are defined
        self.assertIn("function client_page()", bundle.code)
        self.assertIn("class ButtonProps", bundle.code)
        self.assertIn('const API_LABEL = "Runtime Test";', bundle.code)
        # Check hydration logic is present
        self.assertIn("__jacHydrateFromDom", bundle.code)
        self.assertIn("__jacEnsureHydration", bundle.code)
        self.assertIn('getElementById("__jac_init__")', bundle.code)
        self.assertIn('getElementById("__jac_root")', bundle.code)
        # Check globals iteration logic
        self.assertIn("for (const gName of __objectKeys(payloadGlobals))", bundle.code)
        self.assertIn("client_page", bundle.client_functions)
        self.assertIn("ButtonProps", bundle.client_functions)
        self.assertIn("API_LABEL", bundle.client_globals)
        self.assertGreater(len(bundle.hash), 10)

        cached = builder.build(module)
        self.assertEqual(bundle.hash, cached.hash)
        self.assertEqual(bundle.code, cached.code)

    def test_build_bundle_with_cl_import(self) -> None:
        """Test that cl import statements are properly bundled."""
        fixtures_dir = Path(__file__).parent / "fixtures"
        (module,) = Jac.jac_import("client_app_with_import", str(fixtures_dir))

        builder = Jac.get_client_bundle_builder()
        bundle = builder.build(module)

        # Check that client_runtime functions are included in the bundle
        self.assertIn("function renderJsxTree", bundle.code)
        self.assertIn("function jacLogin", bundle.code)

        # Check that our client code is present
        self.assertIn("function test_page()", bundle.code)
        self.assertIn('const APP_TITLE = "Import Test App";', bundle.code)

        # Verify the imported module comment is present
        self.assertIn("// Imported .jac module: client_runtime", bundle.code)

        # IMPORTANT: Ensure no ES6 import statements are in the bundle
        # (since everything is bundled together, we don't need module imports)
        self.assertNotIn("import {", bundle.code)
        self.assertNotIn('from "client_runtime"', bundle.code)

        # Check that client functions are registered
        self.assertIn("test_page", bundle.client_functions)
        self.assertIn("APP_TITLE", bundle.client_globals)

        # Ensure the bundle has a valid hash
        self.assertGreater(len(bundle.hash), 10)

    def test_build_bundle_with_relative_import(self) -> None:
        """Test that cl import from relative paths works correctly."""
        fixtures_dir = Path(__file__).parent / "fixtures"
        (module,) = Jac.jac_import("client_app_with_relative_import", str(fixtures_dir))

        builder = Jac.get_client_bundle_builder()
        bundle = builder.build(module)

        # Check that the imported module (client_ui_components) is included
        self.assertIn("// Imported .jac module: .client_ui_components", bundle.code)
        self.assertIn("function Button(", bundle.code)
        self.assertIn("function Card(", bundle.code)
        self.assertIn("function handleClick(", bundle.code)

        # Check that main_page is present
        self.assertIn("function main_page()", bundle.code)

        # Check that transitive imports (client_runtime) are included
        self.assertIn("// Imported .jac module: client_runtime", bundle.code)
        self.assertIn("function createState(", bundle.code)
        self.assertIn("function navigate(", bundle.code)

        # IMPORTANT: Ensure NO import statements remain
        self.assertNotIn("import {", bundle.code)
        self.assertNotIn('from "', bundle.code)
        self.assertNotIn("from './", bundle.code)
        self.assertNotIn('from "./', bundle.code)

        # Check that all modules are bundled in the correct order
        # client_runtime should come first (transitive import)
        # then client_ui_components (direct import)
        # then main module code
        client_runtime_pos = bundle.code.find("// Imported .jac module: client_runtime")
        ui_components_pos = bundle.code.find(
            "// Imported .jac module: .client_ui_components"
        )
        main_page_pos = bundle.code.find("function main_page()")

        self.assertGreater(ui_components_pos, client_runtime_pos)
        self.assertGreater(main_page_pos, ui_components_pos)

        # Verify client functions are registered
        self.assertIn("main_page", bundle.client_functions)

    def test_no_import_statements_in_bundle(self) -> None:
        """Test that all import statements are stripped from the final bundle."""
        fixtures_dir = Path(__file__).parent / "fixtures"
        (module,) = Jac.jac_import("client_app_with_relative_import", str(fixtures_dir))

        builder = Jac.get_client_bundle_builder()
        bundle = builder.build(module)

        # Split bundle into lines and check for any import statements
        lines = bundle.code.split("\n")
        import_lines = [
            line
            for line in lines
            if line.strip().startswith("import ") and " from " in line
        ]

        # Should be exactly 0 import statements
        self.assertEqual(
            len(import_lines),
            0,
            f"Found {len(import_lines)} import statement(s) in bundle: {import_lines[:3]}",
        )

        # Also verify using regex pattern
        import re

        import_pattern = r'^\s*import\s+.*\s+from\s+["\'].*["\'];?\s*$'
        import_matches = [line for line in lines if re.match(import_pattern, line)]
        self.assertEqual(
            len(import_matches),
            0,
            f"Found import statements matching pattern: {import_matches[:3]}",
        )

    def test_transitive_imports_included(self) -> None:
        """Test that transitive imports (imports from imported modules) are included."""
        fixtures_dir = Path(__file__).parent / "fixtures"
        (module,) = Jac.jac_import("client_app_with_relative_import", str(fixtures_dir))

        builder = Jac.get_client_bundle_builder()
        bundle = builder.build(module)

        # client_app_with_relative_import imports from client_ui_components
        # client_ui_components imports from client_runtime
        # So client_runtime should be included as a transitive import

        # Check that all three modules are present
        self.assertIn("// Imported .jac module: client_runtime", bundle.code)
        self.assertIn("// Imported .jac module: .client_ui_components", bundle.code)

        # Verify runtime functions are defined (not just referenced)
        self.assertIn("function createState(", bundle.code)
        self.assertIn("function navigate(", bundle.code)

        # Verify that createState is actually callable (definition before usage)
        createState_def_pos = bundle.code.find("function createState(")
        createState_usage_pos = bundle.code.find("createState(")
        self.assertLess(
            createState_def_pos,
            createState_usage_pos,
            "createState must be defined before it's used",
        )

    def test_bundle_size_reasonable(self) -> None:
        """Test that bundles with imports are reasonably sized."""
        fixtures_dir = Path(__file__).parent / "fixtures"

        # Simple module without imports
        (simple_module,) = Jac.jac_import("client_app", str(fixtures_dir))
        builder = Jac.get_client_bundle_builder()
        simple_bundle = builder.build(simple_module)

        # Module with imports
        (import_module,) = Jac.jac_import(
            "client_app_with_relative_import", str(fixtures_dir)
        )
        import_bundle = builder.build(import_module)

        # Bundle with imports should be larger (includes additional modules)
        self.assertGreater(
            len(import_bundle.code),
            len(simple_bundle.code),
            "Bundle with imports should be larger than simple bundle",
        )

        # But not unreasonably large (should be less than 10x)
        self.assertLess(
            len(import_bundle.code),
            len(simple_bundle.code) * 10,
            "Bundle should not be unreasonably large",
        )

    def test_import_path_conversion(self) -> None:
        """Test that Jac-style import paths are converted to JS paths."""
        from jaclang.utils import convert_to_js_import_path

        # Test single dot (current directory)
        self.assertEqual(convert_to_js_import_path(".module"), "./module.js")

        # Test double dot (parent directory)
        self.assertEqual(convert_to_js_import_path("..module"), "../module.js")

        # Test triple dot (grandparent directory)
        self.assertEqual(convert_to_js_import_path("...module"), "../../module.js")

        # Test absolute import (no dots)
        self.assertEqual(convert_to_js_import_path("module"), "module")

    def test_cl_block_functions_exported(self) -> None:
        """Test that functions inside cl blocks are properly exported."""
        fixtures_dir = Path(__file__).parent / "fixtures"
        (module,) = Jac.jac_import("client_ui_components", str(fixtures_dir))

        builder = Jac.get_client_bundle_builder()
        bundle = builder.build(module)

        # Functions defined inside cl block should be in client_functions
        self.assertIn("Button", bundle.client_functions)
        self.assertIn("Card", bundle.client_functions)
        self.assertIn("handleClick", bundle.client_functions)

        # Check that functions are actually defined in the bundle
        self.assertIn("function Button(", bundle.code)
        self.assertIn("function Card(", bundle.code)
        self.assertIn("function handleClick(", bundle.code)

    def test_bundle_caching_with_imports(self) -> None:
        """Test that bundle caching works correctly with imports."""
        fixtures_dir = Path(__file__).parent / "fixtures"
        (module,) = Jac.jac_import("client_app_with_relative_import", str(fixtures_dir))

        builder = Jac.get_client_bundle_builder()

        # Build bundle first time
        bundle1 = builder.build(module)

        # Build bundle second time (should use cache)
        bundle2 = builder.build(module)

        # Should be identical
        self.assertEqual(bundle1.hash, bundle2.hash)
        self.assertEqual(bundle1.code, bundle2.code)
        self.assertEqual(bundle1.client_functions, bundle2.client_functions)

        # Force rebuild
        bundle3 = builder.build(module, force=True)

        # Should still be identical
        self.assertEqual(bundle1.hash, bundle3.hash)
        self.assertEqual(bundle1.code, bundle3.code)
