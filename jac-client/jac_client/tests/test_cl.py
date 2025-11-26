"""Tests for Vite client bundle generation."""

from __future__ import annotations

from pathlib import Path
import json
import tempfile
import subprocess

from jaclang.runtimelib.machine import JacMachine as Jac
from jaclang.utils.test import TestCase
from jac_client.plugin.vite_client_bundle import ViteClientBundleBuilder


class ViteClientBundleBuilderTests(TestCase):
    """Validate Vite-powered client bundle compilation."""

    def setUp(self) -> None:
        Jac.reset_machine()
        return super().setUp()

    def tearDown(self) -> None:
        Jac.reset_machine()
        return super().tearDown()

    def _create_test_project_with_vite(
        self, temp_path: Path, include_antd: bool = False
    ) -> tuple[Path, Path]:
        """Create a minimal test project with Vite installed.

        Args:
            temp_path: Path to the temporary directory
            include_antd: If True, includes antd in dependencies
        """
        # Create package.json with base dependencies
        dependencies = {
            "react": "^19.2.0",
            "react-dom": "^19.2.0",
            "react-router-dom": "^7.3.0",
        }

        # Add antd if requested
        if include_antd:
            dependencies["antd"] = "^5.0.0"

        # Create package.json structure
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
            "dependencies": dependencies,
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

    def test_build_bundle_with_vite(self) -> None:
        """Test that Vite bundling produces optimized output with proper structure."""
        # Create a temporary directory for our test project
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)

            package_json, output_dir = self._create_test_project_with_vite(temp_path)
            runtime_path = (
                Path(__file__).parent.parent / "plugin" / "client_runtime.jac"
            )
            # Initialize the Vite builder
            builder = ViteClientBundleBuilder(
                runtime_path=runtime_path,
                vite_package_json=package_json,
                vite_output_dir=output_dir,
                vite_minify=False,  # Disable minification for easier inspection
            )
            # Import the test module
            fixtures_dir = Path(__file__).parent / "fixtures" / "basic-app"
            (module,) = Jac.jac_import("app", str(fixtures_dir))
            # Build the bundle
            bundle = builder.build(module, force=True)

            self.assertIsNotNone(bundle)
            self.assertEqual(bundle.module_name, "app")
            self.assertIn("app", bundle.client_functions)
            self.assertIn("ButtonProps", bundle.client_functions)
            self.assertIn("API_LABEL", bundle.client_globals)
            self.assertGreater(len(bundle.hash), 10)

            # Verify bundle code contains expected content
            self.assertIn("function app()", bundle.code)
            self.assertIn('API_LABEL = "Runtime Test";', bundle.code)

            # Verify bundle was written to output directory
            bundle_files = list(output_dir.glob("client.*.js"))
            self.assertGreater(
                len(bundle_files), 0, "Expected at least one bundle file"
            )

            # Verify cached bundle is identical
            cached = builder.build(module, force=False)
            self.assertEqual(bundle.hash, cached.hash)
            self.assertEqual(bundle.code, cached.code)

    def test_vite_bundle_without_package_json(self) -> None:
        """Test that missing package.json raises appropriate error."""
        fixtures_dir = Path(__file__).parent / "fixtures" / "basic-app"
        (module,) = Jac.jac_import("app", str(fixtures_dir))

        runtime_path = Path(__file__).parent.parent / "plugin" / "client_runtime.jac"

        # Create builder without package.json
        builder = ViteClientBundleBuilder(
            runtime_path=runtime_path,
            vite_package_json=Path("/nonexistent/package.json"),
            vite_output_dir=Path("/tmp/output"),
        )

        # Building should raise an error
        from jaclang.runtimelib.client_bundle import ClientBundleError

        with self.assertRaises(ClientBundleError) as cm:
            builder.build(module, force=True)

        self.assertIn("Vite package.json not found", str(cm.exception))

    def test_build_bundle_with_antd(self) -> None:
        """Test that Vite bundling works with Ant Design components."""
        with tempfile.TemporaryDirectory() as temp_dir:

            temp_path = Path(temp_dir)

            # Create project with Vite and Ant Design installed
            package_json, output_dir = self._create_test_project_with_vite(
                temp_path, include_antd=True
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

            # Import the test module with Ant Design
            fixtures_dir = Path(__file__).parent / "fixtures" / "client_app_with_antd"
            (module,) = Jac.jac_import("app", str(fixtures_dir))

            # Build the bundle
            bundle = builder.build(module, force=True)

            # Verify bundle structure
            self.assertIsNotNone(bundle)
            self.assertEqual(bundle.module_name, "app")
            self.assertIn("ButtonTest", bundle.client_functions)
            self.assertIn("CardTest", bundle.client_functions)
            self.assertIn("APP_NAME", bundle.client_globals)

            # Verify bundle code contains expected content
            self.assertIn("function ButtonTest()", bundle.code)
            self.assertIn("function CardTest()", bundle.code)
            self.assertIn('APP_NAME = "Ant Design Test";', bundle.code)

            # verify antd components are present
            self.assertIn("ButtonGroup", bundle.code)

            # Verify the Ant Design fixture content is present
            self.assertIn("Testing Ant Design integration", bundle.code)

            # Verify bundle was written to output directory
            bundle_files = list(output_dir.glob("client.*.js"))
            self.assertGreater(
                len(bundle_files), 0, "Expected at least one bundle file"
            )

            # Cleanup
            builder.cleanup_temp_dir()

    def test_relative_import(self) -> None:
        """Test that relative imports work correctly in Vite bundling."""
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)

            # Create project with Vite installed
            package_json, output_dir = self._create_test_project_with_vite(
                temp_path, include_antd=True
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

            # Import the test module with relative import
            fixtures_dir = Path(__file__).parent / "fixtures" / "relative_import"
            (module,) = Jac.jac_import("app", str(fixtures_dir))

            # Build the bundle
            bundle = builder.build(module, force=True)

            # Verify bundle structure
            self.assertIsNotNone(bundle)
            self.assertEqual(bundle.module_name, "app")
            self.assertIn("RelativeImport", bundle.client_functions)
            self.assertIn("app", bundle.client_functions)
            self.assertIn("CustomButton", bundle.code)

            # Verify bundle code contains expected content
            self.assertIn("function RelativeImport()", bundle.code)
            self.assertIn("function app()", bundle.code)

            # Verify that the relative import (Button from .button) is properly resolved
            self.assertIn("ButtonGroup", bundle.code)

            # Verify bundle was written to output directory
            bundle_files = list(output_dir.glob("client.*.js"))
            self.assertGreater(
                len(bundle_files), 0, "Expected at least one bundle file"
            )

            # Cleanup
            builder.cleanup_temp_dir()

    def test_js_import(self) -> None:
        """Test that JavaScript file imports work correctly in Vite bundling."""
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            # Create project with Vite installed
            package_json, output_dir = self._create_test_project_with_vite(temp_path)
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

            # Import the test module with JavaScript import
            fixtures_dir = Path(__file__).parent / "fixtures" / "js_import"
            (module,) = Jac.jac_import("app", str(fixtures_dir))

            # Build the bundle
            bundle = builder.build(module, force=True)

            # Verify bundle structure
            self.assertIsNotNone(bundle)
            self.assertEqual(bundle.module_name, "app")
            self.assertIn("JsImportTest", bundle.client_functions)
            self.assertIn("app", bundle.client_functions)
            self.assertIn("JS_IMPORT_LABEL", bundle.client_globals)

            # Verify bundle code contains expected content
            self.assertIn("function JsImportTest()", bundle.code)
            self.assertIn("function app()", bundle.code)
            self.assertIn('JS_IMPORT_LABEL = "JavaScript Import Test";', bundle.code)

            # Verify JavaScript imports are present in the bundle
            # The JavaScript functions should be available in the bundle
            self.assertIn("formatMessage", bundle.code)
            self.assertIn("calculateSum", bundle.code)
            self.assertIn("JS_CONSTANT", bundle.code)
            self.assertIn("MessageFormatter", bundle.code)

            # Verify the JavaScript utility code is included
            self.assertIn("Hello,", bundle.code)  # From formatMessage function
            self.assertIn("Imported from JavaScript", bundle.code)  # From JS_CONSTANT

            # Verify bundle was written to output directory
            bundle_files = list(output_dir.glob("client.*.js"))
            self.assertGreater(
                len(bundle_files), 0, "Expected at least one bundle file"
            )

            # Cleanup
            builder.cleanup_temp_dir()

    def test_jsx_fragments_and_spread_props(self) -> None:
        """Test that JSX fragments and spread props work correctly."""
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)

            # Create project with Vite installed
            package_json, output_dir = self._create_test_project_with_vite(temp_path)
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

            # Import the test module with fragments and spread props
            fixtures_dir = Path(__file__).parent / "fixtures" / "test_fragments_spread"
            (module,) = Jac.jac_import("app", str(fixtures_dir))

            # Build the bundle
            bundle = builder.build(module, force=True)

            # Verify bundle structure
            self.assertIsNotNone(bundle)
            self.assertEqual(bundle.module_name, "app")
            self.assertIn("FragmentTest", bundle.client_functions)
            self.assertIn("SpreadPropsTest", bundle.client_functions)
            self.assertIn("MixedTest", bundle.client_functions)
            self.assertIn("NestedFragments", bundle.client_functions)

            # Verify spread props handling (Object.assign is used by compiler)
            self.assertIn("Object.assign", bundle.code)

            # Verify fragment test function exists
            self.assertIn("function FragmentTest()", bundle.code)

            # Verify spread props test function exists
            self.assertIn("function SpreadPropsTest()", bundle.code)

            # Verify bundle was written to output directory
            bundle_files = list(output_dir.glob("client.*.js"))
            self.assertGreater(
                len(bundle_files), 0, "Expected at least one bundle file"
            )

            # Cleanup
            builder.cleanup_temp_dir()

    def test_spawn_operator(self) -> None:
        """Test that spawn operator generates correct __jacSpawn calls for both orderings and node types (root and UUID)."""
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)

            # Create project with Vite installed
            package_json, output_dir = self._create_test_project_with_vite(temp_path)
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

            # Import the test module with both spawn operator orderings
            fixtures_dir = Path(__file__).parent / "fixtures" / "spawn_test"
            (module,) = Jac.jac_import("app", str(fixtures_dir))

            # Build the bundle
            bundle = builder.build(module, force=True)

            # Verify bundle structure
            self.assertIsNotNone(bundle)
            self.assertEqual(bundle.module_name, "app")
            self.assertIn("app", bundle.client_functions)

            # Verify complete __jacSpawn calls for root spawn scenarios
            # Standard order: root spawn test_walker()
            self.assertIn('__jacSpawn("test_walker", "", {})', bundle.code)

            # Standard order: root spawn parameterized_walker(value=42)
            self.assertIn('__jacSpawn("parameterized_walker", "", {', bundle.code)
            self.assertIn('"value": 42', bundle.code)

            # Reverse order: test_walker(message="Reverse spawn!") spawn root
            # Should generate: __jacSpawn("test_walker", "", {message: "Reverse spawn!"})
            self.assertRegex(
                bundle.code,
                r'__jacSpawn\("test_walker",\s*"",\s*\{[^}]*"message":\s*"Reverse spawn!"[^}]*\}\)',
            )

            # Verify UUID spawn scenarios with complete calls
            # Standard UUID spawn: node_id spawn test_walker()
            # Should generate: __jacSpawn("test_walker", node_id, {})
            self.assertIn('__jacSpawn("test_walker", node_id, {})', bundle.code)
            self.assertIn('"550e8400-e29b-41d4-a716-446655440000"', bundle.code)

            # Reverse UUID spawn: parameterized_walker(value=100) spawn another_node_id
            # Should generate: __jacSpawn("parameterized_walker", another_node_id, {value: 100})
            self.assertRegex(
                bundle.code,
                r'__jacSpawn\("parameterized_walker",\s*another_node_id,\s*\{[^}]*"value":\s*100[^}]*\}\)',
            )
            self.assertIn('"6ba7b810-9dad-11d1-80b4-00c04fd430c8"', bundle.code)

            # Verify positional argument mapping for walkers
            self.assertRegex(
                bundle.code,
                r'__jacSpawn\("positional_walker",\s*node_id,\s*\{[^}]*"label":\s*"Node positional"[^}]*"count":\s*2',
            )
            # Verify spread (**kwargs) handling when walker is on left-hand side
            self.assertRegex(
                bundle.code,
                r'__jacSpawn\("positional_walker",\s*"",\s*_objectSpread\(\{\s*"label":\s*"Spread order"[^}]*"count":\s*5\s*\},\s*extra_fields\)',
            )

            # Verify we have at least 7 __jacSpawn calls (previous cases + new positional/spread)
            self.assertTrue(
                bundle.code.count("__jacSpawn") >= 7,
                "Expected at least 7 __jacSpawn calls in bundle",
            )

            # Verify bundle was written to output directory
            bundle_files = list(output_dir.glob("client.*.js"))
            self.assertGreater(
                len(bundle_files), 0, "Expected at least one bundle file"
            )

            # Cleanup
            builder.cleanup_temp_dir()

    def test_serve_cl_file(self) -> None:
        """Test that serving a .cl file works correctly."""
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)

            # Create project with Vite installed
            package_json, output_dir = self._create_test_project_with_vite(temp_path)
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

            # Import the test module with both spawn operator orderings
            fixtures_dir = Path(__file__).parent / "fixtures" / "cl_file"
            (module,) = Jac.jac_import("app", str(fixtures_dir))

            # Build the bundle
            bundle = builder.build(module, force=True)
            # Verify bundle structure
            self.assertIsNotNone(bundle)
            self.assertEqual(bundle.module_name, "app")
            self.assertIn("app", bundle.client_functions)

            self.assertIn("function app()", bundle.code)
            self.assertIn(
                '__jacJsx("div", {}, [__jacJsx("h2", {}, ["My Todos"])', bundle.code
            )
            self.assertIn("root.render(/* @__PURE__ */ React.c", bundle.code)
            self.assertIn(
                "ar _useState = reactExports.useState([]), _useStat", bundle.code
            )
            self.assertIn('turn __jacSpawn("create_todo", ', bundle.code)
            # Cleanup
            builder.cleanup_temp_dir()
