"""Tests for TypeScript support in Jac client."""

from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

import pytest

from jac_client.plugin.vite_client_bundle import ViteClientBundleBuilder
from jaclang.runtimelib.runtime import JacRuntime as Jac


@pytest.fixture(autouse=True)
def reset_jac_machine():
    """Reset Jac machine before and after each test."""
    Jac.reset_machine()
    yield
    Jac.reset_machine()


def _create_test_project_with_typescript(temp_path: Path) -> tuple[Path, Path]:
    """Create a minimal test project with TypeScript support.

    Args:
        temp_path: Path to the temporary directory

    Returns:
        Tuple of (package_json_path, output_dir_path)
    """
    # Create package.json with TypeScript dependencies
    package_data = {
        "name": "test-ts-client",
        "version": "0.0.1",
        "type": "module",
        "scripts": {
            "build": "npm run compile && vite build",
            "dev": "vite dev",
            "preview": "vite preview",
            "compile": 'babel compiled --out-dir build --extensions ".jsx,.js" --out-file-extension .js',
        },
        "dependencies": {
            "react": "^19.2.0",
            "react-dom": "^19.2.0",
            "react-router-dom": "^6.30.1",
        },
        "devDependencies": {
            "vite": "^6.4.1",
            "@babel/cli": "^7.28.3",
            "@babel/core": "^7.28.5",
            "@babel/preset-env": "^7.28.5",
            "@babel/preset-react": "^7.28.5",
            "@vitejs/plugin-react": "^4.2.1",
            "typescript": "^5.3.3",
            "@types/react": "^18.2.45",
            "@types/react-dom": "^18.2.18",
        },
    }

    package_json = temp_path / "package.json"
    with package_json.open("w", encoding="utf-8") as f:
        json.dump(package_data, f, indent=2)

    # Create .babelrc file
    babelrc = temp_path / ".babelrc"
    babelrc.write_text(
        """{
    "presets": [[
        "@babel/preset-env",
        {
            "modules": false
        }
    ], "@babel/preset-react"]
}
""",
        encoding="utf-8",
    )

    # Create vite.config.js with TypeScript support
    vite_config = temp_path / "vite.config.js"
    vite_config.write_text(
        """import { defineConfig } from "vite";
import path from "path";
import { fileURLToPath } from "url";
import react from "@vitejs/plugin-react";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  plugins: [react()],
  root: ".",
  build: {
    rollupOptions: {
      input: "build/main.js",
      output: {
        entryFileNames: "client.[hash].js",
        assetFileNames: "[name].[ext]",
      },
    },
    outDir: "dist",
    emptyOutDir: true,
  },
  publicDir: false,
  resolve: {
    alias: {
      "@jac-client/utils": path.resolve(__dirname, "compiled/client_runtime.js"),
      "@jac-client/assets": path.resolve(__dirname, "compiled/assets"),
    },
    extensions: [".mjs", ".js", ".mts", ".ts", ".jsx", ".tsx", ".json"],
  },
});
""",
        encoding="utf-8",
    )

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

    # Create output directory
    output_dir = temp_path / "dist" / "assets"
    output_dir.mkdir(parents=True, exist_ok=True)

    compiled_dir = temp_path / "compiled"
    compiled_dir.mkdir(parents=True, exist_ok=True)

    build_dir = temp_path / "build"
    build_dir.mkdir(parents=True, exist_ok=True)

    return package_json, output_dir


def test_typescript_fixture_example() -> None:
    """Test with-ts fixture example with TypeScript component."""
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)

        package_json, output_dir = _create_test_project_with_typescript(temp_path)
        runtime_path = Path(__file__).parent.parent / "plugin" / "client_runtime.jac"

        # Initialize the Vite builder
        builder = ViteClientBundleBuilder(
            runtime_path=runtime_path,
            vite_package_json=package_json,
            vite_output_dir=output_dir,
            vite_minify=False,
        )

        # Import the with-ts fixture
        fixtures_dir = Path(__file__).parent / "fixtures" / "with-ts"
        (module,) = Jac.jac_import("app", str(fixtures_dir), reload_module=True)

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
