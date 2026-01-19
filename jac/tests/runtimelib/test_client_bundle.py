"""Tests for client bundle generation."""

from __future__ import annotations

from collections.abc import Generator
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest

from jaclang import JacRuntime as Jac
from jaclang.pycore.program import JacProgram


@pytest.fixture(scope="class", autouse=True)
def setup_jac_class(
    tmp_path_factory: pytest.TempPathFactory,
) -> Generator[None, None, None]:
    """Set up fresh Jac context once for all tests in this class."""
    tmp_dir = tmp_path_factory.mktemp("client_bundle")
    # Close existing context if any
    if Jac.exec_ctx is not None:
        Jac.exec_ctx.mem.close()
    Jac.loaded_modules.clear()
    Jac.base_path_dir = str(tmp_dir)
    Jac.program = JacProgram()
    Jac.pool = ThreadPoolExecutor()
    Jac.exec_ctx = Jac.create_j_context(user_root=None)
    yield
    if Jac.exec_ctx is not None:
        Jac.exec_ctx.mem.close()
    Jac.loaded_modules.clear()


def test_build_bundle_for_module():
    """Compile a Jac module and ensure client bundle metadata is emitted."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    (module,) = Jac.jac_import("client_app", str(fixtures_dir))

    builder = Jac.get_client_bundle_builder()
    bundle = builder.build(module)

    assert "function __jacJsx" in bundle.code
    # Check that registration mechanism is present
    assert "moduleFunctions[funcName] = funcRef;" in bundle.code
    assert "scope[funcName] = funcRef;" in bundle.code
    assert "moduleGlobals[gName] = existing;" in bundle.code
    assert "scope[gName] = defaultValue;" in bundle.code
    # Check that actual client functions and globals are defined
    assert "function client_page()" in bundle.code
    assert "class ButtonProps" in bundle.code
    assert 'let API_LABEL = "Runtime Test";' in bundle.code
    # Check hydration logic is present
    assert "__jacHydrateFromDom" in bundle.code
    assert "__jacEnsureHydration" in bundle.code
    assert 'getElementById("__jac_init__")' in bundle.code
    assert 'getElementById("__jac_root")' in bundle.code
    # Check globals iteration logic
    assert "for (const gName of __objectKeys(payloadGlobals))" in bundle.code
    assert "client_page" in bundle.client_functions
    assert "ButtonProps" in bundle.client_functions
    assert "API_LABEL" in bundle.client_globals
    assert len(bundle.hash) > 10

    cached = builder.build(module)
    assert bundle.hash == cached.hash
    assert bundle.code == cached.code


def test_build_bundle_with_cl_import():
    """Test that cl import statements are properly bundled."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    (module,) = Jac.jac_import("client_app_with_import", str(fixtures_dir))

    builder = Jac.get_client_bundle_builder()
    bundle = builder.build(module)

    # Check that client_runtime functions are included in the bundle
    assert "function renderJsxTree" in bundle.code
    assert "function jacLogin" in bundle.code

    # Check that our client code is present
    assert "function test_page()" in bundle.code
    assert 'let APP_TITLE = "Import Test App";' in bundle.code

    # Verify the imported module comment is present
    assert "// Imported .jac module: client_runtime" in bundle.code

    # IMPORTANT: Ensure no ES6 import statements are in the bundle
    # (since everything is bundled together, we don't need module imports)
    assert "import {" not in bundle.code
    assert 'from "client_runtime"' not in bundle.code

    # Check that client functions are registered
    assert "test_page" in bundle.client_functions
    assert "APP_TITLE" in bundle.client_globals

    # Ensure the bundle has a valid hash
    assert len(bundle.hash) > 10


def test_build_bundle_with_relative_import():
    """Test that cl import from relative paths works correctly."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    (module,) = Jac.jac_import("client_app_with_relative_import", str(fixtures_dir))

    builder = Jac.get_client_bundle_builder()
    bundle = builder.build(module)

    # Check that the imported module (client_ui_components) is included
    assert "// Imported .jac module: .client_ui_components" in bundle.code
    assert "function Button(" in bundle.code
    assert "function Card(" in bundle.code
    assert "function handleClick(" in bundle.code

    # Check that main_page is present
    assert "function main_page()" in bundle.code

    # Check that transitive imports (client_runtime) are included
    assert "// Imported .jac module: client_runtime" in bundle.code
    assert "function createState(" in bundle.code
    assert "function navigate(" in bundle.code

    # IMPORTANT: Ensure NO import statements remain
    assert "import {" not in bundle.code
    assert 'from "' not in bundle.code
    assert "from './" not in bundle.code
    assert 'from "./' not in bundle.code

    # Check that all modules are bundled in the correct order
    # client_runtime should come first (transitive import)
    # then client_ui_components (direct import)
    # then main module code
    client_runtime_pos = bundle.code.find("// Imported .jac module: client_runtime")
    ui_components_pos = bundle.code.find(
        "// Imported .jac module: .client_ui_components"
    )
    main_page_pos = bundle.code.find("function main_page()")

    assert ui_components_pos > client_runtime_pos
    assert main_page_pos > ui_components_pos

    # Verify client functions are registered
    assert "main_page" in bundle.client_functions


def test_no_import_statements_in_bundle():
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
    assert len(import_lines) == 0, (
        f"Found {len(import_lines)} import statement(s) in bundle: {import_lines[:3]}"
    )

    # Also verify using regex pattern
    import re

    import_pattern = r'^\s*import\s+.*\s+from\s+["\'].*["\'];?\s*$'
    import_matches = [line for line in lines if re.match(import_pattern, line)]
    assert len(import_matches) == 0, (
        f"Found import statements matching pattern: {import_matches[:3]}"
    )


def test_transitive_imports_included():
    """Test that transitive imports (imports from imported modules) are included."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    (module,) = Jac.jac_import("client_app_with_relative_import", str(fixtures_dir))

    builder = Jac.get_client_bundle_builder()
    bundle = builder.build(module)

    # client_app_with_relative_import imports from client_ui_components
    # client_ui_components imports from client_runtime
    # So client_runtime should be included as a transitive import

    # Check that all three modules are present
    assert "// Imported .jac module: client_runtime" in bundle.code
    assert "// Imported .jac module: .client_ui_components" in bundle.code

    # Verify runtime functions are defined (not just referenced)
    assert "function createState(" in bundle.code
    assert "function navigate(" in bundle.code

    # Verify that createState is actually callable (definition before usage)
    create_state_def_pos = bundle.code.find("function createState(")
    create_state_usage_pos = bundle.code.find("createState(")
    assert create_state_def_pos < create_state_usage_pos, (
        "createState must be defined before it's used"
    )


def test_bundle_size_reasonable():
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
    assert len(import_bundle.code) > len(simple_bundle.code), (
        "Bundle with imports should be larger than simple bundle"
    )

    # But not unreasonably large (should be less than 10x)
    assert len(import_bundle.code) < len(simple_bundle.code) * 10, (
        "Bundle should not be unreasonably large"
    )


def test_import_path_conversion():
    """Test that Jac-style import paths are converted to JS paths."""
    from jaclang.pycore.modresolver import convert_to_js_import_path

    # Test single dot (current directory)
    assert convert_to_js_import_path(".module") == "./module.js"

    # Test double dot (parent directory)
    assert convert_to_js_import_path("..module") == "../module.js"

    # Test triple dot (grandparent directory)
    assert convert_to_js_import_path("...module") == "../../module.js"

    # Test absolute import (no dots)
    assert convert_to_js_import_path("module") == "module"


def test_cl_block_functions_exported():
    """Test that functions inside cl blocks are properly exported."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    (module,) = Jac.jac_import("client_ui_components", str(fixtures_dir))

    builder = Jac.get_client_bundle_builder()
    bundle = builder.build(module)

    # Functions defined inside cl block should be in client_functions
    assert "Button" in bundle.client_functions
    assert "Card" in bundle.client_functions
    assert "handleClick" in bundle.client_functions

    # Check that functions are actually defined in the bundle
    assert "function Button(" in bundle.code
    assert "function Card(" in bundle.code
    assert "function handleClick(" in bundle.code


def test_bundle_caching_with_imports():
    """Test that bundle caching works correctly with imports."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    (module,) = Jac.jac_import("client_app_with_relative_import", str(fixtures_dir))

    builder = Jac.get_client_bundle_builder()

    # Build bundle first time
    bundle1 = builder.build(module)

    # Build bundle second time (should use cache)
    bundle2 = builder.build(module)

    # Should be identical
    assert bundle1.hash == bundle2.hash
    assert bundle1.code == bundle2.code
    assert bundle1.client_functions == bundle2.client_functions

    # Force rebuild
    bundle3 = builder.build(module, force=True)

    # Should still be identical
    assert bundle1.hash == bundle3.hash
    assert bundle1.code == bundle3.code
