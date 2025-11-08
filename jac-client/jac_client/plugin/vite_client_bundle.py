"""Vite-enhanced client bundle generation for Jac web front-ends."""

from __future__ import annotations

import contextlib
import hashlib
import json
import shutil
import subprocess
from pathlib import Path
from types import ModuleType
from typing import Any, Sequence, TYPE_CHECKING

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
        # TODO: return pure js files separately
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
        is_root: bool = False,
        collected_exports: set[str] | None = None,
        collected_globals: dict[str, Any] | None = None,
        runtime_js: str | None = None,
    ) -> None:
        """Recursively compile/copy .jac/.js imports to temp, skipping bundling.

        Only prepares dependency JS artifacts for Vite by writing compiled JS (.jac)
        or copying local JS (.js) into the temp directory. Bare specifiers are left
        untouched for Vite to resolve.
        """
        from jaclang.runtimelib.machine import JacMachine as Jac

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
        if not is_root:
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

            exposure_js = self._generate_global_exposure_code(exports_list)
            registration_js = self._generate_registration_js(
                module_path.stem,
                exports_list,
                non_root_globals,
            )
            export_block = (
                f"export {{ {', '.join(exports_list)} }};\n" if exports_list else ""
            )

            combined_js = f"{module_js}\n{exposure_js}\n{registration_js}\n{runtime_js}\n{export_block}"
            if self.vite_package_json is not None:
                (
                    self.vite_package_json.parent / "temp" / f"{module_path.stem}.js"
                ).write_text(combined_js, encoding="utf-8")
        else:
            mod = Jac.program.mod.hub.get(str(module_path))
            manifest = mod.gen.client_manifest if mod else None

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
                    is_root=False,
                    collected_exports=collected_exports,
                    collected_globals=collected_globals,
                    runtime_js=runtime_js,
                )
            elif path_obj.suffix == ".js":
                try:
                    js_code = path_obj.read_text(encoding="utf-8")
                    if self.vite_package_json is not None:
                        (
                            self.vite_package_json.parent / "temp" / path_obj.name
                        ).write_text(js_code, encoding="utf-8")
                except FileNotFoundError:
                    pass
            else:
                # Bare specifiers or other assets handled by Vite
                continue

    def _compile_bundle(
        self,
        module: ModuleType,
        module_path: Path,
    ) -> ClientBundle:
        """Override to use Vite bundling instead of simple concatenation."""
        # Get manifest from JacProgram first to check for imports
        from jaclang.runtimelib.machine import JacMachine as Jac

        mod = Jac.program.mod.hub.get(str(module_path))
        manifest = mod.gen.client_manifest if mod else None

        module_js, _ = self._compile_to_js(module_path)

        # Compile runtime to JS and add to temp for Vite to consume
        runtime_js, mod = self._compile_to_js(self.runtime_path)

        # Collect exports/globals across root and recursive deps
        collected_exports: set[str] = set(self._extract_client_exports(manifest))
        client_globals_map = self._extract_client_globals(manifest, module)
        collected_globals: dict[str, Any] = dict(client_globals_map)

        # Recursively prepare dependencies and accumulate symbols
        self._compile_dependencies_recursively(
            module_path,
            is_root=True,
            collected_exports=collected_exports,
            collected_globals=collected_globals,
            runtime_js=runtime_js,
        )

        client_exports = sorted(collected_exports)
        client_globals_map = collected_globals

        bundle_pieces = []

        # Add main module (without registration_js - we'll handle that in Jac init script)
        bundle_pieces.extend(
            [
                "// Runtime module:",
                runtime_js,
                f"// Client module: {module.__name__}",
                module_js,
                "",
            ]
        )

        # Add global exposure code first (before Jac initialization)
        global_exposure_code = self._generate_global_exposure_code(client_exports)
        bundle_pieces.append(global_exposure_code)

        # Add Jac runtime initialization script (includes globals)
        jac_init_script = self._generate_jac_init_script(
            module_path.stem, client_exports, client_globals_map
        )
        bundle_pieces.append(jac_init_script)

        # Do not add export block for root since output is iife

        # Use Vite bundling instead of simple concatenation
        bundle_code, bundle_hash = self._bundle_with_vite(
            bundle_pieces, module.__name__, client_exports
        )

        return ClientBundle(
            module_name=module.__name__,
            code=bundle_code,
            client_functions=client_exports,
            client_globals=list(client_globals_map.keys()),
            hash=bundle_hash,
        )

    def _bundle_with_vite(
        self, bundle_pieces: list[str], module_name: str, client_functions: list[str]
    ) -> tuple[str, str]:
        """Bundle JavaScript code using Vite for optimization.

        Args:
            bundle_pieces: List of JavaScript code pieces to bundle
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
        temp_dir = project_dir / "temp"
        temp_dir.mkdir(exist_ok=True)

        # Create entry file with stitched content
        entry_file = temp_dir / "app.js"

        entry_content = "\n".join(piece for piece in bundle_pieces if piece is not None)
        entry_file.write_text(entry_content, encoding="utf-8")

        # Create Vite config in the project directory (where node_modules exists)
        vite_config = project_dir / "temp_vite.config.js"
        output_dir = self.vite_output_dir or temp_dir / "dist"
        output_dir.mkdir(exist_ok=True)

        config_content = self._generate_vite_config(entry_file, output_dir)
        vite_config.write_text(config_content, encoding="utf-8")

        try:
            # Run Vite build from project directory
            # need to install packages you told in package.json inside here
            command = ["npx", "vite", "build", "--config", str(vite_config)]
            subprocess.run(
                command, cwd=project_dir, check=True, capture_output=True, text=True
            )
        except subprocess.CalledProcessError as e:
            raise ClientBundleError(f"Vite build failed: {e.stderr}") from e
        except FileNotFoundError:
            raise ClientBundleError(
                "npx or vite command not found. Ensure Node.js and npm are installed."
            )
        finally:
            # Clean up temp config file
            if vite_config.exists():
                vite_config.unlink()

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

    def _find_vite_bundle(self, output_dir: Path) -> Path | None:
        """Find the generated Vite bundle file."""
        for file in output_dir.glob("client.*.js"):
            return file
        return None

    def _generate_jac_init_script(
        self,
        module_name: str,
        client_functions: list[str],
        client_globals: dict[str, Any],
    ) -> str:
        """Generate Jac runtime initialization script."""
        if not client_functions:
            return ""

        # Generate function map dynamically
        map_entries = []
        for func_name in client_functions:
            map_entries.append(f'    "{func_name}": {func_name}')
        function_map_str = "{\n" + ",\n".join(map_entries) + "\n}"

        # Generate globals map
        globals_entries = []
        for name, value in client_globals.items():
            identifier = json.dumps(name)
            try:
                value_literal = json.dumps(value)
            except TypeError:
                value_literal = "null"
            globals_entries.append(f"{identifier}: {value_literal}")
        globals_literal = (
            "{ " + ", ".join(globals_entries) + " }" if globals_entries else "{}"
        )

        # Find the main app function (usually the last function or one ending with '_app')
        main_app_func = (
            "jac_app"  # this need to be always same and defined by our run time
        )
        # for func_name in reversed(client_functions):
        #     if func_name.endswith('_app') or func_name == 'App':
        #         main_app_func = func_name
        #         break

        return f"""
            // --- JAC CLIENT INITIALIZATION SCRIPT ---
            // Expose functions globally for Jac runtime registration
            const clientFunctions = {client_functions};
            const functionMap = {function_map_str};
            for (const funcName of clientFunctions) {{
                globalThis[funcName] = functionMap[funcName];
            }}
            __jacRegisterClientModule("{module_name}", clientFunctions, {globals_literal});
            globalThis.start_app = {main_app_func};
            // Call the start function immediately if we're not hydrating from the server
            if (!document.getElementById('__jac_init__')) {{
                globalThis.start_app();
            }}
            // --- END JAC CLIENT INITIALIZATION SCRIPT ---
        """

    def _generate_global_exposure_code(self, client_functions: list[str]) -> str:
        """Generate code to expose functions globally for Vite IIFE."""
        if not client_functions:
            return ""

        # Generate function map dynamically
        map_entries = []
        for func_name in client_functions:
            map_entries.append(f'    "{func_name}": {func_name}')
        function_map_str = "{\n" + ",\n".join(map_entries) + "\n}"

        return f"""
            // --- GLOBAL EXPOSURE FOR VITE IIFE ---
            // Expose functions globally so they're available on globalThis
            const globalClientFunctions = {client_functions};
            const globalFunctionMap = {function_map_str};
            for (const funcName of globalClientFunctions) {{
                globalThis[funcName] = globalFunctionMap[funcName];
            }}
            // --- END GLOBAL EXPOSURE ---
        """

    def cleanup_temp_dir(self) -> None:
        """Clean up the temp directory and its contents."""
        if not self.vite_package_json or not self.vite_package_json.exists():
            return

        project_dir = self.vite_package_json.parent
        temp_dir = project_dir / "temp"

        if temp_dir.exists():
            with contextlib.suppress(OSError):
                shutil.rmtree(temp_dir)

    @staticmethod
    def _generate_registration_js(
        module_name: str,
        client_functions: Sequence[str],
        client_globals: dict[str, Any],
    ) -> str:
        """Generate registration code that exposes client symbols globally."""
        globals_entries: list[str] = []
        for name, value in client_globals.items():
            identifier = json.dumps(name)
            try:
                value_literal = json.dumps(value)
            except TypeError:
                value_literal = "null"
            globals_entries.append(f"{identifier}: {value_literal}")

        globals_literal = (
            "{ " + ", ".join(globals_entries) + " }" if globals_entries else "{}"
        )
        functions_literal = json.dumps(list(client_functions))
        module_literal = json.dumps(module_name)

        # Use the registration function from client_runtime.jac
        return f"__jacRegisterClientModule({module_literal}, {functions_literal}, {globals_literal});"
