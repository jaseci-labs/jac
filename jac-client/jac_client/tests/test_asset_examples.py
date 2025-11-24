"""Tests for asset-serving and css-styling examples."""

from __future__ import annotations

from pathlib import Path
import json
import shutil
import tempfile
import subprocess

from jaclang.runtimelib.machine import JacMachine as Jac
from jaclang.utils.test import TestCase
from jac_client.plugin.vite_client_bundle import ViteClientBundleBuilder


class AssetServingExampleTests(TestCase):
    """Test asset-serving examples."""

    def setUp(self) -> None:
        Jac.reset_machine()
        return super().setUp()

    def tearDown(self) -> None:
        Jac.reset_machine()
        return super().tearDown()

    def _create_test_project_with_vite(
        self, temp_path: Path, include_assets: bool = False
    ) -> tuple[Path, Path]:
        """Create a minimal test project with Vite installed.

        Args:
            temp_path: Path to the temporary directory
            include_assets: If True, includes asset handling setup
        """
        # Create package.json with base dependencies
        package_data = {
            "name": "test-client",
            "version": "0.0.1",
            "type": "module",
            "scripts": {
                "build": "npm run compile && vite build",
                "dev": "vite dev",
                "preview": "vite preview",
                "compile": 'babel src --out-dir build --extensions ".jsx,.js" --out-file-extension .js',
            },
            "dependencies": {
                "react": "^19.2.0",
                "react-dom": "^19.2.0",
                "react-router-dom": "^7.3.0",
            },
            "devDependencies": {
                "vite": "^6.4.1",
                "@babel/cli": "^7.28.3",
                "@babel/core": "^7.28.5",
                "@babel/preset-env": "^7.28.5",
                "@babel/preset-react": "^7.28.5",
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

        # Create vite.config.js file
        vite_config = temp_path / "vite.config.js"
        if include_assets:
            vite_config.write_text(
                """import { defineConfig } from "vite";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
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
    minify: false,
  },
  publicDir: false,
  resolve: {
    alias: {
      "@jac-client/utils": path.resolve(__dirname, "src/client_runtime.js"),
      "@jac-client/assets": path.resolve(__dirname, "src/assets"),
    },
  },
});
""",
                encoding="utf-8",
            )
        else:
            vite_config.write_text(
                """import { defineConfig } from "vite";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
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
    minify: false,
  },
  publicDir: false,
  resolve: {
    alias: {
      "@jac-client/utils": path.resolve(__dirname, "src/client_runtime.js"),
    },
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
        output_dir = temp_path / "dist"
        output_dir.mkdir(parents=True, exist_ok=True)

        src_dir = temp_path / "src"
        src_dir.mkdir(parents=True, exist_ok=True)

        build_dir = temp_path / "build"
        build_dir.mkdir(parents=True, exist_ok=True)

        return package_json, output_dir

    def test_image_asset_example(self) -> None:
        """Test image-asset example with static asset paths."""
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)

            package_json, output_dir = self._create_test_project_with_vite(
                temp_path, include_assets=True
            )
            runtime_path = (
                Path(__file__).parent.parent / "plugin" / "client_runtime.jac"
            )

            # Initialize the Vite builder
            builder = ViteClientBundleBuilder(
                runtime_path=runtime_path,
                vite_package_json=package_json,
                vite_output_dir=output_dir,
                vite_minify=False,
            )

            # Import the image-asset example
            examples_dir = (
                Path(__file__).parent.parent
                / "examples"
                / "asset-serving"
                / "image-asset"
            )
            (module,) = Jac.jac_import("app", str(examples_dir))

            # Build the bundle
            bundle = builder.build(module, force=True)

            # Verify bundle structure
            self.assertIsNotNone(bundle)
            self.assertEqual(bundle.module_name, "app")
            self.assertIn("app", bundle.client_functions)

            # Verify image path is in the bundle
            self.assertIn("/static/assets/burger.png", bundle.code)

            # Verify bundle was written to output directory
            bundle_files = list(output_dir.glob("client.*.js"))
            self.assertGreater(
                len(bundle_files), 0, "Expected at least one bundle file"
            )

            # Cleanup
            builder.cleanup_temp_dir()

    def test_css_with_image_example(self) -> None:
        """Test css-with-image example with CSS and image assets."""
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)

            package_json, output_dir = self._create_test_project_with_vite(
                temp_path, include_assets=True
            )
            runtime_path = (
                Path(__file__).parent.parent / "plugin" / "client_runtime.jac"
            )

            # Initialize the Vite builder
            builder = ViteClientBundleBuilder(
                runtime_path=runtime_path,
                vite_package_json=package_json,
                vite_output_dir=output_dir,
                vite_minify=False,
            )

            # Import the css-with-image example
            examples_dir = (
                Path(__file__).parent.parent
                / "examples"
                / "asset-serving"
                / "css-with-image"
            )
            (module,) = Jac.jac_import("app", str(examples_dir))

            # Build the bundle
            bundle = builder.build(module, force=True)

            # Verify bundle structure
            self.assertIsNotNone(bundle)
            self.assertEqual(bundle.module_name, "app")
            self.assertIn("app", bundle.client_functions)

            # Verify CSS import is present (CSS should be extracted to separate file)
            # The bundle should reference the CSS file
            self.assertIn("import", bundle.code.lower())

            # Verify image paths are in the bundle
            self.assertIn("/static/assets/burger.png", bundle.code)

            # Verify CSS file was extracted
            css_files = list(output_dir.glob("*.css"))
            self.assertGreater(len(css_files), 0, "Expected at least one CSS file")

            # Verify bundle was written to output directory
            bundle_files = list(output_dir.glob("client.*.js"))
            self.assertGreater(
                len(bundle_files), 0, "Expected at least one bundle file"
            )

            # Cleanup
            builder.cleanup_temp_dir()

    def test_import_alias_example(self) -> None:
        """Test import-alias example with @jac-client/assets alias."""
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            package_json, output_dir = self._create_test_project_with_vite(
                temp_path, include_assets=True
            )
            runtime_path = (
                Path(__file__).parent.parent / "plugin" / "client_runtime.jac"
            )

            # Initialize the Vite builder
            builder = ViteClientBundleBuilder(
                runtime_path=runtime_path,
                vite_package_json=package_json,
                vite_output_dir=output_dir,
                vite_minify=False,
            )

            # Import the import-alias example
            examples_dir = (
                Path(__file__).parent.parent
                / "examples"
                / "asset-serving"
                / "import-alias"
            )
            (module,) = Jac.jac_import("app", str(examples_dir))

            # Copy assets from example directory to temp project's src/assets/
            # This is needed because @jac-client/assets alias points to src/assets
            example_assets_dir = examples_dir / "assets"
            temp_assets_dir = temp_path / "src" / "assets"
            if example_assets_dir.exists():
                temp_assets_dir.mkdir(parents=True, exist_ok=True)
                # Copy all files from example assets to temp assets
                for asset_file in example_assets_dir.iterdir():
                    if asset_file.is_file():
                        shutil.copy2(asset_file, temp_assets_dir / asset_file.name)

            # Build the bundle
            bundle = builder.build(module, force=True)

            # Verify bundle structure
            self.assertIsNotNone(bundle)
            self.assertEqual(bundle.module_name, "app")
            self.assertIn("app", bundle.client_functions)

            # Verify the import alias was processed by Vite
            # Vite should have resolved the asset import
            # The bundle should contain the processed asset URL
            self.assertIn("burgerImage", bundle.code)

            # Verify bundle was written to output directory
            bundle_files = list(output_dir.glob("client.*.js"))
            self.assertGreater(
                len(bundle_files), 0, "Expected at least one bundle file"
            )

            # Cleanup
            builder.cleanup_temp_dir()
