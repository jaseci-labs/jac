"""Tests for nested folder structure examples."""

from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

import pytest

from jac_client.plugin.vite_client_bundle import ViteClientBundleBuilder
from jaclang.pycore.runtime import JacRuntime as Jac


@pytest.fixture(autouse=True)
def reset_jac_machine():
    """Reset Jac machine before and after each test."""
    Jac.reset_machine()
    yield
    Jac.reset_machine()


def _create_test_project_with_vite(temp_path: Path) -> tuple[Path, Path]:
    """Create a minimal test project with Vite installed using config.json.

    Args:
        temp_path: Path to the temporary directory
    """
    # Create config.json with package dependencies
    # Note: React, React-DOM, React-Router-DOM, Vite, and Babel packages
    # are automatically added during build time, so we only include custom packages
    config_data = {
        "vite": {
            "plugins": [],
            "lib_imports": [],
            "build": {
                "minify": False,
            },
            "server": {},
            "resolve": {},
        },
        "ts": {},
        "package": {
            "name": "test-client",
            "version": "0.0.1",
            "description": "Test client project",
            "dependencies": {
                "antd": "^6.0.0",
            },
            "devDependencies": {},
        },
    }

    config_json = temp_path / "config.json"
    with config_json.open("w", encoding="utf-8") as f:
        json.dump(config_data, f, indent=2)

    # Install packages from config.json using jac add --cl
    # This generates package.json in .jac-client.configs/ and runs npm install
    result = subprocess.run(
        ["jac", "add", "--cl"],
        cwd=temp_path,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        error_msg = f"jac add --cl failed with exit code {result.returncode}\n"
        error_msg += f"stdout: {result.stdout}\n"
        error_msg += f"stderr: {result.stderr}\n"
        raise RuntimeError(error_msg)

    # Package.json is generated in .jac-client.configs/ directory
    package_json = temp_path / ".jac-client.configs" / "package.json"
    if not package_json.exists():
        raise RuntimeError(
            f"package.json not generated at {package_json}. "
            "jac add --cl should have created it."
        )

    # Create output directory
    output_dir = temp_path / "dist"
    output_dir.mkdir(parents=True, exist_ok=True)

    compiled_dir = temp_path / "compiled"
    compiled_dir.mkdir(parents=True, exist_ok=True)

    build_dir = temp_path / "build"
    build_dir.mkdir(parents=True, exist_ok=True)

    return package_json, output_dir


def test_nested_advance_example() -> None:
    """Test nested-advance example with multiple folder levels."""
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)

        package_json, output_dir = _create_test_project_with_vite(temp_path)
        runtime_path = Path(__file__).parent.parent / "plugin" / "client_runtime.cl.jac"

        # Initialize the Vite builder
        builder = ViteClientBundleBuilder(
            runtime_path=runtime_path,
            vite_package_json=package_json,
            vite_output_dir=output_dir,
            vite_minify=False,
        )

        # Import the nested-advance example
        examples_dir = (
            Path(__file__).parent.parent
            / "examples"
            / "nested-folders"
            / "nested-advance"
        )
        (module,) = Jac.jac_import("app", str(examples_dir))

        # Build the bundle
        bundle = builder.build(module, force=True)

        # Verify bundle structure
        assert bundle is not None
        assert bundle.module_name == "app"
        assert "app" in bundle.client_functions

        # Verify all expected components are in client_functions
        expected_exports = {
            "app",
            "ButtonRoot",
            "ButtonSecondL",
            "ButtonThirdL",
            "Card",
        }
        for export_name in expected_exports:
            assert export_name in bundle.client_functions, (
                f"Expected {export_name} to be in client_functions"
            )

        # Verify bundle was written to output directory
        bundle_files = list(output_dir.glob("client.*.js"))
        assert len(bundle_files) > 0, "Expected at least one bundle file"

        # Cleanup
        builder.cleanup_temp_dir()


def test_nested_folder_structure_preserved() -> None:
    """Test that nested folder structure is preserved in compiled/ directory."""
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)

        package_json, output_dir = _create_test_project_with_vite(temp_path)
        runtime_path = Path(__file__).parent.parent / "plugin" / "client_runtime.cl.jac"

        # Initialize the Vite builder
        builder = ViteClientBundleBuilder(
            runtime_path=runtime_path,
            vite_package_json=package_json,
            vite_output_dir=output_dir,
            vite_minify=False,
        )

        # Import the nested-advance example
        examples_dir = (
            Path(__file__).parent.parent
            / "examples"
            / "nested-folders"
            / "nested-advance"
        )
        (module,) = Jac.jac_import("app", str(examples_dir))

        # Build the bundle (this creates files in compiled/)
        bundle = builder.build(module, force=True)

        # Verify bundle was created
        assert bundle is not None

        compiled_dir = temp_path / "compiled"

        # Verify root level file exists
        app_js = compiled_dir / "app.js"
        assert app_js.exists(), f"Expected {app_js} to exist in compiled/ directory"

        button_root_js = compiled_dir / "ButtonRoot.js"
        assert button_root_js.exists(), (
            f"Expected {button_root_js} to exist in compiled/ directory"
        )

        # Verify level1 files exist
        level1_dir = compiled_dir / "level1"
        assert level1_dir.exists(), f"Expected {level1_dir} directory to exist"

        button_second_js = level1_dir / "ButtonSecondL.js"
        assert button_second_js.exists(), (
            f"Expected {button_second_js} to exist in compiled/level1/ directory"
        )

        card_js = level1_dir / "Card.js"
        assert card_js.exists(), (
            f"Expected {card_js} to exist in compiled/level1/ directory"
        )

        # Verify level2 files exist
        level2_dir = level1_dir / "level2"
        assert level2_dir.exists(), f"Expected {level2_dir} directory to exist"

        button_third_js = level2_dir / "ButtonThirdL.js"
        assert button_third_js.exists(), (
            f"Expected {button_third_js} to exist in compiled/level1/level2/ directory"
        )

        # Cleanup
        builder.cleanup_temp_dir()


def test_relative_imports_in_compiled_files() -> None:
    """Test that relative imports are preserved correctly in compiled files."""
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)

        package_json, output_dir = _create_test_project_with_vite(temp_path)
        runtime_path = Path(__file__).parent.parent / "plugin" / "client_runtime.cl.jac"

        # Initialize the Vite builder
        builder = ViteClientBundleBuilder(
            runtime_path=runtime_path,
            vite_package_json=package_json,
            vite_output_dir=output_dir,
            vite_minify=False,
        )

        # Import the nested-advance example
        examples_dir = (
            Path(__file__).parent.parent
            / "examples"
            / "nested-folders"
            / "nested-advance"
        )
        (module,) = Jac.jac_import("app", str(examples_dir))

        # Build the bundle
        bundle = builder.build(module, force=True)

        # Verify bundle was created
        assert bundle is not None

        compiled_dir = temp_path / "compiled"

        # Check that app.js imports from level1
        app_js_content = (compiled_dir / "app.js").read_text(encoding="utf-8")
        assert "level1/ButtonSecondL" in app_js_content, (
            "Expected app.js to import from level1/ButtonSecondL"
        )
        assert "level1/level2/ButtonThirdL" in app_js_content, (
            "Expected app.js to import from level1/level2/ButtonThirdL"
        )

        # Check that ButtonSecondL.js imports from root (using ..)
        button_second_content = (
            compiled_dir / "level1" / "ButtonSecondL.js"
        ).read_text(encoding="utf-8")
        assert "../ButtonRoot" in button_second_content, (
            "Expected ButtonSecondL.js to import from ../ButtonRoot"
        )

        # Check that Card.js imports from both root and level2
        card_content = (compiled_dir / "level1" / "Card.js").read_text(encoding="utf-8")
        assert "../ButtonRoot" in card_content, (
            "Expected Card.js to import from ../ButtonRoot (above)"
        )
        assert "level2/ButtonThirdL" in card_content, (
            "Expected Card.js to import from level2/ButtonThirdL (below)"
        )

        # Check that ButtonThirdL.js imports from root and second level
        button_third_content = (
            compiled_dir / "level1" / "level2" / "ButtonThirdL.js"
        ).read_text(encoding="utf-8")
        assert "../../ButtonRoot" in button_third_content, (
            "Expected ButtonThirdL.js to import from ../../ButtonRoot"
        )
        assert "../ButtonSecondL" in button_third_content, (
            "Expected ButtonThirdL.js to import from ../ButtonSecondL"
        )

        # Cleanup
        builder.cleanup_temp_dir()


def test_nested_basic_example() -> None:
    """Test nested-basic example with simpler nested structure."""
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)

        package_json, output_dir = _create_test_project_with_vite(temp_path)
        runtime_path = Path(__file__).parent.parent / "plugin" / "client_runtime.cl.jac"

        # Initialize the Vite builder
        builder = ViteClientBundleBuilder(
            runtime_path=runtime_path,
            vite_package_json=package_json,
            vite_output_dir=output_dir,
            vite_minify=False,
        )

        # Import the nested-basic example
        examples_dir = (
            Path(__file__).parent.parent
            / "examples"
            / "nested-folders"
            / "nested-basic"
        )
        (module,) = Jac.jac_import("app", str(examples_dir))

        # Build the bundle
        bundle = builder.build(module, force=True)

        # Verify bundle structure
        assert bundle is not None
        assert bundle.module_name == "app"
        assert "app" in bundle.client_functions

        compiled_dir = temp_path / "compiled"

        # Verify nested structure is preserved
        components_dir = compiled_dir / "components"
        assert components_dir.exists(), (
            "Expected components directory to exist in compiled/"
        )

        button_js = components_dir / "button.js"
        assert button_js.exists(), "Expected button.js to exist in compiled/components/"

        # Cleanup
        builder.cleanup_temp_dir()
