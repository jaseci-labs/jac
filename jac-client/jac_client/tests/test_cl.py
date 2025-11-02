"""Tests for Vite client bundle generation."""

from __future__ import annotations

from pathlib import Path
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
    
    def _create_test_project_with_vite(self, temp_path: Path, include_antd: bool = False) -> tuple[Path, Path]:
        """Create a minimal test project with Vite installed.
        
        Args:
            temp_path: Path to the temporary directory
            include_antd: If True, includes antd in dependencies
        """
        # Create package.json with base dependencies
        dependencies = {
            "react": "^18.0.0",
            "react-dom": "^18.0.0"
        }
        
        # Add antd if requested
        if include_antd:
            dependencies["antd"] = "^5.0.0"
        
        # Format dependencies for JSON
        deps_str = ",\n".join(f'                "{k}": "{v}"' for k, v in dependencies.items())
        
        package_json = temp_path / "package.json"
        package_json.write_text(f"""{{
            "name": "test-client",
            "version": "0.0.1",
            "dependencies": {{
{deps_str}
            }},
            "devDependencies": {{
                "vite": "^5.0.0"
            }}
        }}""", encoding="utf-8")
        
        # Install dependencies
        subprocess.run(
            ["npm", "install"],
            cwd=temp_path,
            check=True,
            capture_output=True,
        )
        
        # Create output directory
        output_dir = temp_path / "static" / "client" / "js"
        output_dir.mkdir(parents=True, exist_ok=True)
        
        temp_dir = temp_path / "temp"
        temp_dir.mkdir(parents=True, exist_ok=True)
        
        return package_json, output_dir

    def test_build_bundle_with_vite(self) -> None:
        """Test that Vite bundling produces optimized output with proper structure."""
        # Create a temporary directory for our test project
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            
            # Create project with Vite installed
            package_json, output_dir = self._create_test_project_with_vite(temp_path)
            
            # Initialize the Vite builder
            builder = ViteClientBundleBuilder(
                vite_package_json=package_json,
                vite_output_dir=output_dir,
                vite_minify=False,  # Disable minification for easier inspection
            )
            
            # Import the test module
            fixtures_dir = Path(__file__).parent / "fixtures"
            (module,) = Jac.jac_import("client_app", str(fixtures_dir))
            
            # Build the bundle
            bundle = builder.build(module, force=True)
            
            # Verify bundle structure
            self.assertIsNotNone(bundle)
            self.assertEqual(bundle.module_name, "client_app")
            self.assertIn("client_page", bundle.client_functions)
            self.assertIn("ButtonProps", bundle.client_functions)
            self.assertIn("API_LABEL", bundle.client_globals)
            self.assertGreater(len(bundle.hash), 10)
            
            # Verify bundle code contains expected content
            self.assertIn("function client_page()", bundle.code)
            self.assertIn('const API_LABEL = "Runtime Test";', bundle.code)
            
            # Verify the Jac initialization is present
            self.assertIn("__jacRegisterClientModule", bundle.code)
            self.assertIn("globalThis.start_app", bundle.code)
            
            # Verify bundle was written to output directory
            bundle_files = list(output_dir.glob("client.*.js"))
            self.assertGreater(len(bundle_files), 0, "Expected at least one bundle file")
            
            # Verify cached bundle is identical
            cached = builder.build(module, force=False)
            self.assertEqual(bundle.hash, cached.hash)
            self.assertEqual(bundle.code, cached.code)

    def test_vite_bundle_without_package_json(self) -> None:
        """Test that missing package.json raises appropriate error."""
        fixtures_dir = Path(__file__).parent / "fixtures"
        (module,) = Jac.jac_import("client_app", str(fixtures_dir))
        
        # Create builder without package.json
        builder = ViteClientBundleBuilder(
            vite_package_json=Path("/nonexistent/package.json"),
            vite_output_dir=Path("/tmp/output"),
        )
        
        # Building should raise an error
        from jaclang.runtimelib.client_bundle import ClientBundleError
        with self.assertRaises(ClientBundleError) as cm:
            builder.build(module, force=True)
        
        self.assertIn("Vite package.json not found", str(cm.exception))

    def test_global_exposure_in_bundle(self) -> None:
        """Test that client functions are properly exposed globally for Vite IIFE."""
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            
            # Create project with Vite installed
            package_json, output_dir = self._create_test_project_with_vite(temp_path)
            
            # Initialize the Vite builder
            builder = ViteClientBundleBuilder(
                vite_package_json=package_json,
                vite_output_dir=output_dir,
            )
            
            # Import the test module
            fixtures_dir = Path(__file__).parent / "fixtures"
            (module,) = Jac.jac_import("client_app", str(fixtures_dir))
            
            # Build the bundle
            bundle = builder.build(module, force=True)
            
            # Verify global exposure code is present
            # Note: Variable names may be minified, so we check for the concept rather than exact strings
            self.assertIn("__jacEnsureHydration", bundle.code)
            self.assertIn("globalThis.start_app()", bundle.code)
            
            # Cleanup
            builder.cleanup_temp_dir()

    def test_build_bundle_with_antd(self) -> None:
        """Test that Vite bundling works with Ant Design components."""
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            
            # Create project with Vite and Ant Design installed
            package_json, output_dir = self._create_test_project_with_vite(temp_path, include_antd=True)
            
            # Initialize the Vite builder
            builder = ViteClientBundleBuilder(
                vite_package_json=package_json,
                vite_output_dir=output_dir,
                vite_minify=False,
            )
            
            # Import the test module with Ant Design
            fixtures_dir = Path(__file__).parent / "fixtures"
            (module,) = Jac.jac_import("client_app_with_antd", str(fixtures_dir))
            
            # Build the bundle
            bundle = builder.build(module, force=True)
            
            # Verify bundle structure
            self.assertIsNotNone(bundle)
            self.assertEqual(bundle.module_name, "client_app_with_antd")
            self.assertIn("ButtonTest", bundle.client_functions)
            self.assertIn("CardTest", bundle.client_functions)
            self.assertIn("APP_NAME", bundle.client_globals)
            
            # Verify bundle code contains expected content
            self.assertIn("function ButtonTest()", bundle.code)
            self.assertIn("function CardTest()", bundle.code)
            self.assertIn('const APP_NAME = "Ant Design Test";', bundle.code)
            
            # verify antd components are present
            self.assertIn("ButtonGroup", bundle.code)

            # Verify the Ant Design fixture content is present
            self.assertIn("Testing Ant Design integration", bundle.code)
            
            # Verify bundle was written to output directory
            bundle_files = list(output_dir.glob("client.*.js"))
            self.assertGreater(len(bundle_files), 0, "Expected at least one bundle file")
            
            # Cleanup
            builder.cleanup_temp_dir()

    def test_relative_import(self) -> None:
        """Test that relative imports work correctly in Vite bundling."""
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            
            # Create project with Vite installed
            package_json, output_dir = self._create_test_project_with_vite(temp_path, include_antd=True)
            
            # Initialize the Vite builder
            builder = ViteClientBundleBuilder(
                vite_package_json=package_json,
                vite_output_dir=output_dir,
                vite_minify=False,
            )
            
            # Import the test module with relative import
            fixtures_dir = Path(__file__).parent / "fixtures"
            (module,) = Jac.jac_import("relative_import", str(fixtures_dir))
            
            # Build the bundle
            bundle = builder.build(module, force=True)
            
            # Verify bundle structure
            self.assertIsNotNone(bundle)
            self.assertEqual(bundle.module_name, "relative_import")
            self.assertIn("RelativeImport", bundle.client_functions)
            self.assertIn("main", bundle.client_functions)
            self.assertIn("CustomButton", bundle.code)
            
            # Verify bundle code contains expected content
            self.assertIn("function RelativeImport()", bundle.code)
            self.assertIn("function main()", bundle.code)
            
            # Verify that the relative import (Button from .button) is properly resolved
            self.assertIn("ButtonGroup", bundle.code)
            
            # Verify the Jac initialization is present
            self.assertIn("__jacRegisterClientModule", bundle.code)
            
            # Verify bundle was written to output directory
            bundle_files = list(output_dir.glob("client.*.js"))
            self.assertGreater(len(bundle_files), 0, "Expected at least one bundle file")
            
            # Cleanup
            builder.cleanup_temp_dir()

    def test_js_import(self) -> None:
        """Test that JavaScript file imports work correctly in Vite bundling."""
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            # Create project with Vite installed
            package_json, output_dir = self._create_test_project_with_vite(temp_path)
            
            # Initialize the Vite builder
            builder = ViteClientBundleBuilder(
                vite_package_json=package_json,
                vite_output_dir=output_dir,
                vite_minify=False,
            )
            
            # Import the test module with JavaScript import
            fixtures_dir = Path(__file__).parent / "fixtures"
            (module,) = Jac.jac_import("js_import", str(fixtures_dir))
            
            # Build the bundle
            bundle = builder.build(module, force=True)
            
            # Verify bundle structure
            self.assertIsNotNone(bundle)
            self.assertEqual(bundle.module_name, "js_import")
            self.assertIn("JsImportTest", bundle.client_functions)
            self.assertIn("Main", bundle.client_functions)
            self.assertIn("JS_IMPORT_LABEL", bundle.client_globals)
            
            # Verify bundle code contains expected content
            self.assertIn("function JsImportTest()", bundle.code)
            self.assertIn("function Main()", bundle.code)
            self.assertIn('const JS_IMPORT_LABEL = "JavaScript Import Test";', bundle.code)
            
            # Verify JavaScript imports are present in the bundle
            # The JavaScript functions should be available in the bundle
            self.assertIn("formatMessage", bundle.code)
            self.assertIn("calculateSum", bundle.code)
            self.assertIn("JS_CONSTANT", bundle.code)
            self.assertIn("MessageFormatter", bundle.code)
            
            # Verify the JavaScript utility code is included
            self.assertIn("Hello,", bundle.code)  # From formatMessage function
            self.assertIn("Imported from JavaScript", bundle.code)  # From JS_CONSTANT
            
            # Verify the Jac initialization is present
            self.assertIn("__jacRegisterClientModule", bundle.code)
            
            # Verify bundle was written to output directory
            bundle_files = list(output_dir.glob("client.*.js"))
            self.assertGreater(len(bundle_files), 0, "Expected at least one bundle file")
            
            # Cleanup
            builder.cleanup_temp_dir()
            
    def test_jsx_fragments_and_spread_props(self) -> None:
        """Test that JSX fragments and spread props work correctly."""
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            
            # Create project with Vite installed
            package_json, output_dir = self._create_test_project_with_vite(temp_path)
            
            # Initialize the Vite builder
            builder = ViteClientBundleBuilder(
                vite_package_json=package_json,
                vite_output_dir=output_dir,
                vite_minify=False,
            )
            
            # Import the test module with fragments and spread props
            fixtures_dir = Path(__file__).parent / "fixtures"
            (module,) = Jac.jac_import("test_fragments_spread", str(fixtures_dir))
            
            # Build the bundle
            bundle = builder.build(module, force=True)
            
            # Verify bundle structure
            self.assertIsNotNone(bundle)
            self.assertEqual(bundle.module_name, "test_fragments_spread")
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
            self.assertGreater(len(bundle_files), 0, "Expected at least one bundle file")
            
            # Cleanup
            builder.cleanup_temp_dir()
