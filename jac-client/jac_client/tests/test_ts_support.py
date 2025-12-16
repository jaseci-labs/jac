"""Tests for TypeScript support in Jac client."""

from __future__ import annotations

import json
import shutil
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


def _copy_ts_support_project(temp_path: Path) -> tuple[Path, Path]:
    """Copy the ts-support example project to temp directory.

    Args:
        temp_path: Path to the temporary directory

    Returns:
        Tuple of (package_json_path, output_dir_path)
    """
    # Get the source directory
    source_dir = Path(__file__).parent.parent / "examples" / "ts-support"

    # Copy the entire project directory
    for item in source_dir.iterdir():
        # Skip node_modules, dist, build, compiled directories to avoid copying large/generated files
        if item.name in ("node_modules", "dist", "build", "compiled", "__pycache__"):
            continue
        dest = temp_path / item.name
        if item.is_dir():
            shutil.copytree(item, dest, dirs_exist_ok=True)
        else:
            shutil.copy2(item, dest)

    # Ensure config.json exists with minify: false for tests
    config_json = temp_path / "config.json"
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
    }
    with config_json.open("w", encoding="utf-8") as f:
        json.dump(config_data, f, indent=2)

    # Install dependencies
    result = subprocess.run(
        ["npm", "install"],
        cwd=temp_path,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        error_msg = f"npm install failed with exit code {result.returncode}\n"
        error_msg += f"stdout: {result.stdout}\n"
        error_msg += f"stderr: {result.stderr}\n"
        raise RuntimeError(error_msg)

    # Create output directory (Vite outputs to dist/, not dist/assets/)
    output_dir = temp_path / "dist"
    output_dir.mkdir(parents=True, exist_ok=True)

    return temp_path / "package.json", output_dir


def test_typescript_fixture_example() -> None:
    """Test ts-support example project with TypeScript component."""
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)

        package_json, output_dir = _copy_ts_support_project(temp_path)
        runtime_path = Path(__file__).parent.parent / "plugin" / "client_runtime.jac"

        # Initialize the Vite builder
        builder = ViteClientBundleBuilder(
            runtime_path=runtime_path,
            vite_package_json=package_json,
            vite_output_dir=output_dir,
            vite_minify=False,
        )

        # Import the app from the copied ts-support project
        (module,) = Jac.jac_import("app", str(temp_path), reload_module=True)

        # Build the bundle
        bundle = builder.build(module, force=True)

        # Verify bundle structure
        assert bundle is not None
        assert bundle.module_name == "app"
        assert "app" in bundle.client_functions

        # Verify TypeScript component is referenced in bundle
        assert bundle.code is not None
        assert len(bundle.code) > 0

        # Verify TypeScript file was copied to compiled directory
        compiled_components = package_json.parent / "compiled" / "components"
        compiled_button = compiled_components / "Button.tsx"
        assert compiled_button.exists(), "TypeScript file should be copied to compiled/"

        # Verify TypeScript file was copied to build directory
        build_components = package_json.parent / "build" / "components"
        build_button = build_components / "Button.tsx"
        assert build_button.exists(), "TypeScript file should be copied to build/"

        # Verify bundle was written to output directory
        bundle_files = list(output_dir.glob("client.*.js"))
        assert len(bundle_files) > 0, "Expected at least one bundle file"

        # Cleanup
        builder.cleanup_temp_dir()
