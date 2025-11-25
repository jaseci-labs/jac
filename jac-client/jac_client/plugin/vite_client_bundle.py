"""Vite-enhanced client bundle generation for Jac web front-ends."""

from __future__ import annotations

import contextlib
import hashlib
import shutil
import subprocess
from pathlib import Path
from types import ModuleType
from typing import Any, TYPE_CHECKING

from jaclang.runtimelib.client_bundle import (
    ClientBundle,
    ClientBundleBuilder,
    ClientBundleError,
)

if TYPE_CHECKING:
    from jaclang.compiler.codeinfo import ClientManifest


class ViteClientBundleBuilder(ClientBundleBuilder):
    """Enhanced ClientBundleBuilder that uses Vite for optimized bundling."""

    def __init__(
        self,
        runtime_path: Path | None = None,
        vite_output_dir: Path | None = None,
        vite_package_json: Path | None = None,
        vite_minify: bool = False,
    ) -> None:
        """Initialize the Vite-enhanced bundle builder.

        Args:
            runtime_path: Path to client runtime file
            vite_output_dir: Output directory for Vite builds (defaults to temp/dist)
            vite_package_json: Path to package.json for Vite (required)
            vite_minify: Whether to enable minification in Vite build
        """
        super().__init__(runtime_path)
        self.vite_output_dir = vite_output_dir
        self.vite_package_json = vite_package_json
        self.vite_minify = vite_minify

    def _process_imports(
        self, manifest: ClientManifest | None, module_path: Path
    ) -> list[Path | None]:  # type: ignore[override]
        """Process client imports for Vite bundling.

        Only mark modules as bundled when we actually inline their code (.jac files we compile
        and local .js files we embed). Bare package specifiers (e.g., "antd") are left as real
        ES imports so Vite can resolve and bundle them.
        """
        imported_js_modules: list[Path | None] = []

        if manifest and manifest.imports:
            for _, import_path in manifest.imports.items():
                import_path_obj = Path(import_path)

                if import_path_obj.suffix == ".js":
                    # Inline local JS files and mark as bundled
                    try:

                        imported_js_modules.append(import_path_obj)
                    except FileNotFoundError:
                        imported_js_modules.append(None)

                elif import_path_obj.suffix == ".jac":
                    # Compile .jac imports and include transitive .jac imports
                    try:
                        imported_js_modules.append(import_path_obj)
                    except ClientBundleError:
                        imported_js_modules.append(None)

                else:
                    # Non .jac/.js entries (likely bare specifiers) should be handled by Vite.
                    # Do not inline or mark as bundled so their import lines are preserved.
                    pass

        return imported_js_modules

    def _compile_dependencies_recursively(
        self,
        module_path: Path,
        visited: set[Path] | None = None,
        collected_exports: set[str] | None = None,
        collected_globals: dict[str, Any] | None = None,
    ) -> None:
        """Recursively compile/copy .jac/.js imports to temp, skipping bundling.

        Only prepares dependency JS artifacts for Vite by writing compiled JS (.jac)
        or copying local JS (.js) into the temp directory. Bare specifiers are left
        untouched for Vite to resolve.
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
        manifest = None

        # Compile current module to JS and append registration
        module_js, mod = self._compile_to_js(module_path)
        manifest = mod.gen.client_manifest if mod else None

        # Extract exports from manifest
        exports_list = self._extract_client_exports(manifest)
        collected_exports.update(exports_list)

        # Build globals map using manifest.globals_values only for non-root
        non_root_globals: dict[str, Any] = {}
        if manifest:
            for name in manifest.globals:
                non_root_globals[name] = manifest.globals_values.get(name)
        collected_globals.update(non_root_globals)
        export_block = (
            f"export {{ {', '.join(exports_list)} }};\n" if exports_list else ""
        )

        # inport jacJsx from client_runtime_utils.jac
        jac_jsx_path = 'import {__jacJsx, __jacSpawn} from "@jac-client/utils";'

        combined_js = f"{jac_jsx_path}\n{module_js}\n{export_block}"
        if self.vite_package_json is not None:
            (
                self.vite_package_json.parent / "src" / f"{module_path.stem}.js"
            ).write_text(combined_js, encoding="utf-8")

        if not manifest or not manifest.imports:
            return

        for _name, import_path in manifest.imports.items():
            path_obj = Path(import_path).resolve()
            # Avoid re-processing
            if path_obj in visited:
                continue
            if path_obj.suffix == ".jac":
                # Recurse into transitive deps
                self._compile_dependencies_recursively(
                    path_obj,
                    visited,
                    collected_exports=collected_exports,
                    collected_globals=collected_globals,
                )
            elif path_obj.suffix == ".js":
                try:
                    js_code = path_obj.read_text(encoding="utf-8")
                    if self.vite_package_json is not None:
                        (
                            self.vite_package_json.parent / "src" / path_obj.name
                        ).write_text(js_code, encoding="utf-8")
                except FileNotFoundError:
                    pass
            else:
                # Bare specifiers or other assets handled by Vite
                if self.vite_package_json is not None and path_obj.is_file():
                    (self.vite_package_json.parent / "src" / path_obj.name).write_text(
                        path_obj.read_text(encoding="utf-8"), encoding="utf-8"
                    )
                continue

    def _compile_bundle(
        self,
        module: ModuleType,
        module_path: Path,
    ) -> ClientBundle:
        """Override to use Vite bundling instead of simple concatenation."""

        # Check if package.json exists before proceeding
        if not self.vite_package_json or not self.vite_package_json.exists():
            raise ClientBundleError(
                "Vite package.json not found. Set vite_package_json when using ViteClientBundleBuilder"
            )

        # client_runtime for jac client utils
        runtime_utils_path = self.runtime_path.parent / "client_runtime.jac"
        runtimeutils_js, mod = self._compile_to_js(runtime_utils_path)
        runtimeutils_manifest = mod.gen.client_manifest if mod else None
        runtimeutils_exports_list = self._extract_client_exports(runtimeutils_manifest)

        # Add React Router exports that are variable declarations (not functions)
        # These need to be manually added since they're 'let' declarations, not 'def' functions
        router_exports = [
            "Router",
            "Routes",
            "Route",
            "Link",
            "Navigate",
            "useNavigate",
            "useLocation",
            "useParams",
        ]

        # Combine manifest exports with router exports
        all_exports = sorted(set(runtimeutils_exports_list + router_exports))

        export_block = (
            f"export {{ {', '.join(all_exports)} }};\n" if all_exports else ""
        )

        combined_runtime_utils_js = f"{runtimeutils_js}\n{export_block}"
        (self.vite_package_json.parent / "src" / "client_runtime.js").write_text(
            combined_runtime_utils_js, encoding="utf-8"
        )

        # Get manifest from JacProgram first to check for imports
        # Collect exports/globals across root and recursive deps
        module_js, mod = self._compile_to_js(module_path)
        module_manifest = mod.gen.client_manifest if mod else None
        collected_exports: set[str] = set(self._extract_client_exports(module_manifest))
        client_globals_map = self._extract_client_globals(module_manifest, module)
        collected_globals: dict[str, Any] = dict(client_globals_map)

        # Recursively prepare dependencies and accumulate symbols
        self._compile_dependencies_recursively(
            module_path,
            collected_exports=collected_exports,
            collected_globals=collected_globals,
        )

        # Copy assets from root assets/ folder to src/assets/ for @jac-client/assets alias
        project_dir = self.vite_package_json.parent
        root_assets_dir = project_dir / "assets"
        src_assets_dir = project_dir / "src" / "assets"
        if root_assets_dir.exists() and root_assets_dir.is_dir():
            self._copy_asset_files(root_assets_dir, src_assets_dir)

        client_exports = sorted(collected_exports)
        client_globals_map = collected_globals

        entry_file = self.vite_package_json.parent / "src" / "main.js"

        entry_content = """import React from "react";
import { createRoot } from "react-dom/client";
import { app as App } from "./app.js";

const root = createRoot(document.getElementById("root"));
root.render(<App />);
"""
        entry_file.write_text(entry_content, encoding="utf-8")

        bundle_code, bundle_hash = self._bundle_with_vite(
            module.__name__, client_exports
        )

        return ClientBundle(
            module_name=module.__name__,
            code=bundle_code,
            client_functions=client_exports,
            client_globals=list(client_globals_map.keys()),
            hash=bundle_hash,
        )

    def _bundle_with_vite(
        self, module_name: str, client_functions: list[str]
    ) -> tuple[str, str]:
        """Bundle JavaScript code using Vite for optimization.

        Args:
            module_name: Name of the module being bundled
            client_functions: List of client function names

        Returns:
            Tuple of (bundle_code, bundle_hash)

        Raises:
            ClientBundleError: If Vite bundling fails
        """
        if not self.vite_package_json or not self.vite_package_json.exists():
            raise ClientBundleError(
                "Vite package.json not found. Set vite_package_json when using ViteClientBundleBuilder"
            )

        # Create temp directory for Vite build
        project_dir = self.vite_package_json.parent
        src_dir = project_dir / "src"
        src_dir.mkdir(exist_ok=True)

        output_dir = self.vite_output_dir or src_dir / "dist" / "assets"
        output_dir.mkdir(parents=True, exist_ok=True)

        try:
            # Run Vite build from project directory
            # need to install packages you told in package.json inside here
            # first compile the code
            command = ["npm", "run", "compile"]
            subprocess.run(
                command, cwd=project_dir, check=True, capture_output=True, text=True
            )
            # Copy CSS and other asset files from src/ to build/ after Babel compilation
            # Babel only transpiles JS, so we need to manually copy assets
            self._copy_asset_files(project_dir / "src", project_dir / "build")
            # then build the code
            command = ["npm", "run", "build"]
            subprocess.run(
                command, cwd=project_dir, check=True, capture_output=True, text=True
            )
        except subprocess.CalledProcessError as e:
            raise ClientBundleError(f"Vite build failed: {e.stderr}") from e
        except FileNotFoundError:
            raise ClientBundleError(
                "npx or vite command not found. Ensure Node.js and npm are installed."
            )
        # Find the generated bundle file
        bundle_file = self._find_vite_bundle(output_dir)
        if not bundle_file:
            raise ClientBundleError("Vite build completed but no bundle file found")

        # Read the bundled code
        bundle_code = bundle_file.read_text(encoding="utf-8")
        bundle_hash = hashlib.sha256(bundle_code.encode("utf-8")).hexdigest()

        return bundle_code, bundle_hash

    def _generate_vite_config(self, entry_file: Path, output_dir: Path) -> str:
        """Generate Vite configuration for bundling."""
        entry_name = entry_file.as_posix()
        output_dir_name = output_dir.as_posix()
        minify_setting = "true" if self.vite_minify else "false"

        return f"""
            import {{ defineConfig }} from 'vite';
            import {{ resolve }} from 'path';

            export default defineConfig({{
            build: {{
                outDir: '{output_dir_name}',
                emptyOutDir: true,
                rollupOptions: {{
                input: {{
                    main: resolve(__dirname, '{entry_name}'),
                }},
                output: {{
                    entryFileNames: 'client.[hash].js',
                    format: 'iife',
                    name: 'JacClient',
                }},
                }},
                minify: {minify_setting}, // Configurable minification
            }},
            resolve: {{
            }}
            }});
        """

    def _copy_asset_files(self, src_dir: Path, build_dir: Path) -> None:
        """Copy CSS and other asset files from src/ to build/ directory recursively.

        Babel only transpiles JavaScript files, so CSS and other assets need to be
        manually copied to the build directory for Vite to resolve them.
        This method recursively copies assets from subdirectories (e.g., src/assets/)
        while preserving the directory structure.
        """
        if not src_dir.exists():
            return

        # Ensure build directory exists
        build_dir.mkdir(parents=True, exist_ok=True)

        # Asset file extensions to copy
        asset_extensions = {
            ".css",
            ".scss",
            ".sass",
            ".less",
            ".svg",
            ".png",
            ".jpg",
            ".jpeg",
            ".gif",
            ".webp",
            ".ico",
            ".woff",
            ".woff2",
            ".ttf",
            ".eot",
            ".otf",
            ".mp4",
            ".webm",
            ".mp3",
            ".wav",
        }

        def copy_recursive(
            source: Path, destination: Path, base: Path | None = None
        ) -> None:
            """Recursively copy asset files from source to destination.

            Args:
                source: Source directory to copy from
                destination: Destination directory to copy to
                base: Base directory for calculating relative paths (defaults to source)
            """
            if not source.exists():
                return

            if base is None:
                base = source

            for item in source.iterdir():
                if item.is_file() and item.suffix.lower() in asset_extensions:
                    # Preserve relative path structure from base
                    relative_path = item.relative_to(base)
                    dest_file = destination / relative_path
                    dest_file.parent.mkdir(parents=True, exist_ok=True)
                    with contextlib.suppress(OSError, shutil.Error):
                        shutil.copy2(item, dest_file)
                elif item.is_dir():
                    # Recursively process subdirectories
                    copy_recursive(item, destination, base)

        # Copy files from src_dir root and recursively from subdirectories
        copy_recursive(src_dir, build_dir)

    def _find_vite_bundle(self, output_dir: Path) -> Path | None:
        """Find the generated Vite bundle file."""
        for file in output_dir.glob("client.*.js"):
            return file
        return None

    def _find_vite_css(self, output_dir: Path) -> Path | None:
        """Find the generated Vite CSS file."""
        # Vite typically outputs CSS as main.css or with a hash
        # Try main.css first (most common), then any .css file
        css_file = output_dir / "main.css"
        if css_file.exists():
            return css_file
        # Fallback: find any CSS file
        for file in output_dir.glob("*.css"):
            return file
        return None

    def cleanup_temp_dir(self) -> None:
        """Clean up the src directory and its contents."""
        if not self.vite_package_json or not self.vite_package_json.exists():
            return

        project_dir = self.vite_package_json.parent
        temp_dir = project_dir / "src"

        if temp_dir.exists():
            with contextlib.suppress(OSError, shutil.Error):
                shutil.rmtree(temp_dir)
