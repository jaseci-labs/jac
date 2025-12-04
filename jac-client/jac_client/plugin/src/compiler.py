"""Main compilation orchestration module."""

from __future__ import annotations

import contextlib
from collections.abc import Callable
from pathlib import Path
from types import ModuleType
from typing import TYPE_CHECKING, Any

from jaclang.runtimelib.client_bundle import ClientBundleError

from .asset_processor import AssetProcessor
from .babel_processor import BabelProcessor
from .import_processor import ImportProcessor
from .jac_to_js import JacToJSCompiler
from .vite_bundler import ViteBundler

if TYPE_CHECKING:
    pass


class ViteCompiler:
    """Orchestrates the compilation process for Vite client bundles."""

    # React Router exports that are variable declarations (not functions)
    ROUTER_EXPORTS = [
        "Router",
        "Routes",
        "Route",
        "Link",
        "Navigate",
        "useNavigate",
        "useLocation",
        "useParams",
    ]

    def __init__(
        self,
        vite_package_json: Path,
        vite_output_dir: Path | None = None,
        vite_minify: bool = False,
        runtime_path: Path | None = None,
        compile_to_js_func: Callable[[Path], tuple[str, ModuleType | None]]
        | None = None,
        extract_exports_func: Callable[[Any], list[str]] | None = None,
        extract_globals_func: Callable[[Any, ModuleType], dict[str, Any]] | None = None,
    ):
        """Initialize the Vite compiler.

        Args:
            vite_package_json: Path to package.json for Vite (required)
            vite_output_dir: Output directory for Vite builds
            vite_minify: Whether to enable minification in Vite build
            runtime_path: Path to client runtime file
            compile_to_js_func: Function to compile Jac to JS
            extract_exports_func: Function to extract client exports
            extract_globals_func: Function to extract client globals
        """
        if not vite_package_json or not vite_package_json.exists():
            raise ClientBundleError(
                "Vite package.json not found. Set vite_package_json when using ViteCompiler"
            )

        if (
            compile_to_js_func is None
            or extract_exports_func is None
            or extract_globals_func is None
        ):
            raise ClientBundleError(
                "compile_to_js_func, extract_exports_func, and extract_globals_func are required"
            )

        self.vite_package_json = vite_package_json
        self.project_dir = vite_package_json.parent
        self.runtime_path = runtime_path
        self.compiled_dir = self.project_dir / "compiled"

        # Initialize processors
        self.jac_compiler = JacToJSCompiler(
            compile_to_js_func, extract_exports_func, extract_globals_func
        )
        self.import_processor = ImportProcessor()
        self.asset_processor = AssetProcessor()
        self.babel_processor = BabelProcessor(self.project_dir)
        self.vite_bundler = ViteBundler(self.project_dir, vite_output_dir, vite_minify)

    def compile_runtime_utils(self) -> tuple[str, list[str]]:
        """Compile client runtime utilities.

        Returns:
            Tuple of (js_code, exports_list)
        """
        if not self.runtime_path:
            raise ClientBundleError("Runtime path not set")

        runtime_utils_path = self.runtime_path.parent / "client_runtime.jac"
        runtimeutils_js, mod, runtimeutils_manifest = self.jac_compiler.compile_module(
            runtime_utils_path
        )
        runtimeutils_exports_list = self.jac_compiler.extract_exports(
            runtimeutils_manifest
        )

        # Combine manifest exports with router exports
        all_exports = sorted(set(runtimeutils_exports_list + self.ROUTER_EXPORTS))
        export_block = self.jac_compiler.generate_export_block(all_exports)

        combined_runtime_utils_js = f"{runtimeutils_js}\n{export_block}"

        # Write to compiled directory
        self.compiled_dir.mkdir(parents=True, exist_ok=True)
        (self.compiled_dir / "client_runtime.js").write_text(
            combined_runtime_utils_js, encoding="utf-8"
        )

        return combined_runtime_utils_js, all_exports

    def compile_dependencies_recursively(
        self,
        module_path: Path,
        visited: set[Path] | None = None,
        collected_exports: set[str] | None = None,
        collected_globals: dict[str, Any] | None = None,
        source_root: Path | None = None,
    ) -> None:
        """Recursively compile/copy .jac/.js imports to temp, skipping bundling.

        Only prepares dependency JS artifacts for Vite by writing compiled JS (.jac)
        or copying local JS (.js) into the temp directory. Bare specifiers are left
        untouched for Vite to resolve.

        Args:
            module_path: Path to the module being compiled
            visited: Set of already visited paths to avoid cycles
            collected_exports: Set to accumulate exported symbols
            collected_globals: Dict to accumulate global values
            source_root: Root directory of the source files (for preserving folder structure)
        """
        if visited is None:
            visited = set()
        if collected_exports is None:
            collected_exports = set()
        if collected_globals is None:
            collected_globals = {}

        module_path = module_path.resolve()
        if module_path in visited:
            return
        visited.add(module_path)

        # Set source_root on first call (root module's parent directory)
        if source_root is None:
            source_root = module_path.parent.resolve()

        # Compile current module to JS
        module_js, mod, manifest = self.jac_compiler.compile_module(module_path)

        # Extract exports from manifest
        exports_list = self.jac_compiler.extract_exports(manifest)
        collected_exports.update(exports_list)

        # Build globals map using manifest.globals_values only for non-root
        non_root_globals: dict[str, Any] = {}
        if manifest:
            for name in manifest.globals:
                non_root_globals[name] = manifest.globals_values.get(name)
        collected_globals.update(non_root_globals)

        export_block = self.jac_compiler.generate_export_block(exports_list)
        combined_js = self.jac_compiler.add_runtime_imports(module_js)
        combined_js = f"{combined_js}\n{export_block}"

        # Write compiled JS to output directory
        try:
            relative_path = module_path.relative_to(source_root)
            output_path = self.compiled_dir / relative_path.with_suffix(".js")
        except ValueError:
            # If file is outside source_root, fall back to just filename
            output_path = self.compiled_dir / f"{module_path.stem}.js"

        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(combined_js, encoding="utf-8")

        if not manifest or not manifest.imports:
            return

        # Process dependencies
        for _name, import_path in manifest.imports.items():
            path_obj = Path(import_path).resolve()
            if path_obj in visited:
                continue

            if path_obj.suffix == ".jac":
                # Recurse into transitive deps
                self.compile_dependencies_recursively(
                    path_obj,
                    visited,
                    collected_exports=collected_exports,
                    collected_globals=collected_globals,
                    source_root=source_root,
                )
            elif path_obj.suffix == ".js":
                self._copy_js_file(path_obj, source_root)
            elif path_obj.suffix in {".ts", ".tsx"}:
                # Copy TypeScript files to compiled directory for Vite to process
                self._copy_ts_file(path_obj, source_root)
            else:
                # Bare specifiers or other assets handled by Vite
                if path_obj.is_file():
                    self._copy_asset_file(path_obj, source_root)

    def _copy_js_file(self, js_path: Path, source_root: Path) -> None:
        """Copy a JavaScript file to the compiled directory.

        Args:
            js_path: Path to the JavaScript file
            source_root: Root directory for preserving folder structure
        """
        try:
            js_code = js_path.read_text(encoding="utf-8")
            try:
                relative_path = js_path.relative_to(source_root)
                output_path = self.compiled_dir / relative_path
            except ValueError:
                output_path = self.compiled_dir / js_path.name

            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(js_code, encoding="utf-8")
        except FileNotFoundError:
            pass

    def _copy_ts_file(self, ts_path: Path, source_root: Path) -> None:
        """Copy a TypeScript file to the compiled directory.

        Args:
            ts_path: Path to the TypeScript file
            source_root: Root directory for preserving folder structure
        """
        if not ts_path.exists():
            return

        try:
            ts_code = ts_path.read_text(encoding="utf-8")
            try:
                relative_path = ts_path.relative_to(source_root)
                output_path = self.compiled_dir / relative_path
            except ValueError:
                output_path = self.compiled_dir / ts_path.name

            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(ts_code, encoding="utf-8")
        except (FileNotFoundError, OSError):
            pass

    def _copy_asset_file(self, asset_path: Path, source_root: Path) -> None:
        """Copy an asset file to the compiled directory.

        Args:
            asset_path: Path to the asset file
            source_root: Root directory for preserving folder structure
        """
        if not asset_path.exists():
            return

        try:
            relative_path = asset_path.relative_to(source_root)
            output_path = self.compiled_dir / relative_path
        except ValueError:
            output_path = self.compiled_dir / asset_path.name

        output_path.parent.mkdir(parents=True, exist_ok=True)
        with contextlib.suppress(FileNotFoundError, OSError):
            output_path.write_text(
                asset_path.read_text(encoding="utf-8"), encoding="utf-8"
            )

    def copy_root_assets(self) -> None:
        """Copy assets from root assets/ folder to compiled/assets/ for @jac-client/assets alias."""
        root_assets_dir = self.project_dir / "assets"
        compiled_assets_dir = self.compiled_dir / "assets"
        if root_assets_dir.exists() and root_assets_dir.is_dir():
            self.asset_processor.copy_assets(root_assets_dir, compiled_assets_dir)

    def create_entry_file(self) -> None:
        """Create the main entry file for Vite bundling."""
        entry_file = self.compiled_dir / "main.js"
        entry_content = """import React from "react";
import { createRoot } from "react-dom/client";
import { app as App } from "./app.js";

const root = createRoot(document.getElementById("root"));
root.render(<App />);
"""
        entry_file.write_text(entry_content, encoding="utf-8")

    def compile_and_bundle(
        self, module: ModuleType, module_path: Path
    ) -> tuple[str, str, list[str], list[str]]:
        """Compile module and dependencies, then bundle with Vite.

        Args:
            module: The Python module
            module_path: Path to the Jac module

        Returns:
            Tuple of (bundle_code, bundle_hash, client_exports, client_globals)
        """
        # Compile runtime utils
        self.compile_runtime_utils()

        # Compile main module and dependencies
        module_js, mod, module_manifest = self.jac_compiler.compile_module(module_path)
        collected_exports: set[str] = set(
            self.jac_compiler.extract_exports(module_manifest)
        )

        client_globals_map = self.jac_compiler.extract_globals(module_manifest, module)
        collected_globals: dict[str, Any] = dict(client_globals_map)

        # Recursively prepare dependencies and accumulate symbols
        self.compile_dependencies_recursively(
            module_path,
            collected_exports=collected_exports,
            collected_globals=collected_globals,
        )

        # Copy assets
        self.copy_root_assets()

        # Create entry file
        self.create_entry_file()

        # Run Babel compilation
        self.babel_processor.compile()

        # Copy assets after Babel (Babel only transpiles JS)
        self.babel_processor.copy_assets_after_compile(
            self.compiled_dir, self.project_dir / "build", self.asset_processor
        )

        # Run Vite build (config will be generated in .jac-client.configs/)
        entry_file = self.project_dir / "build" / "main.js"
        self.vite_bundler.build(entry_file=entry_file)

        # Read bundle
        bundle_code, bundle_hash = self.vite_bundler.read_bundle()

        client_exports = sorted(collected_exports)
        client_globals = list(collected_globals.keys())

        return bundle_code, bundle_hash, client_exports, client_globals
