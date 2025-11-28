"""Client bundle generation utilities for Jac web front-ends."""

from __future__ import annotations

import hashlib
import json
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from pathlib import Path
from types import ModuleType
from typing import TYPE_CHECKING, Any, NamedTuple

from jaclang.utils import convert_to_js_import_path

if TYPE_CHECKING:
    from jaclang.compiler.codeinfo import ClientManifest
    from jaclang.compiler.unitree import Module


class ClientBundleError(RuntimeError):
    """Raised when the client bundle cannot be generated."""


class ProcessedImports(NamedTuple):
    """Result of processing client imports."""

    import_pieces: list[str]  # JavaScript code pieces from imports
    bundled_module_names: set[str]  # Names of modules being bundled


@dataclass(slots=True)
class ClientBundle:
    """Container for a compiled client bundle."""

    module_name: str
    code: str
    client_functions: list[str]
    client_globals: list[str]
    hash: str


@dataclass(slots=True)
class _CachedBundle:
    signature: str
    bundle: ClientBundle


class ClientBundleBuilder:
    """Compile Jac modules and runtime support into a browser-ready bundle."""

    def __init__(self, runtime_path: Path | None = None) -> None:
        """Initialise the builder with an optional override for the runtime path."""
        self.runtime_path = runtime_path or Path(__file__).with_name(
            "client_runtime.jac"
        )
        self._cache: dict[str, _CachedBundle] = {}

    def build(self, module: ModuleType, force: bool = False) -> ClientBundle:
        """Build (or reuse) a client bundle for the supplied module."""
        # Derive source path from module __file__ (replace .py with .jac)
        if not hasattr(module, "__file__") or not module.__file__:
            raise ClientBundleError(
                f"Module '{module.__name__}' has no __file__ attribute"
            )
        module_path = module.__file__.replace(".py", ".jac")

        source_path = Path(module_path).resolve()

        # Get the manifest to determine which files will be included
        from jaclang.runtimelib.runtime import JacRuntime as Jac

        mod = Jac.program.mod.hub.get(str(source_path))
        manifest = mod.gen.client_manifest if mod else None

        # Build list of all files that will be in the bundle for cache signature
        bundle_paths = [source_path]
        if manifest and manifest.imports:
            for import_path in manifest.imports.values():
                bundle_paths.append(Path(import_path))

        signature = self._signature(bundle_paths)

        cached = self._cache.get(module.__name__)
        if not force and cached and cached.signature == signature:
            return cached.bundle

        bundle = self._compile_bundle(module, source_path)
        self._cache[module.__name__] = _CachedBundle(signature=signature, bundle=bundle)
        return bundle

    def _process_imports(
        self, manifest: ClientManifest | None, module_path: Path
    ) -> ProcessedImports:
        """Process client imports and return import pieces and bundled module names.

        Args:
            manifest: The client manifest containing import information, or None
            module_path: Path to the module being processed

        Returns:
            ProcessedImports containing JavaScript code pieces and bundled module names
        """
        import_pieces: list[str] = []
        bundled_module_names: set[str] = set()

        if manifest and manifest.imports:
            for import_name, import_path in manifest.imports.items():
                bundled_module_names.add(import_name)
                import_path_obj = Path(import_path)
                if import_path_obj.suffix == ".js":
                    # For .js files, read and include as-is
                    try:
                        with open(import_path_obj, encoding="utf-8") as f:
                            js_code = f.read()
                            import_pieces.append(
                                f"// Imported .js module: {import_name}"
                            )
                            import_pieces.append(js_code)
                            import_pieces.append("")
                    except FileNotFoundError:
                        import_pieces.append(
                            f"// Warning: Could not find {import_path}"
                        )
                elif import_path_obj.suffix == ".jac":
                    # For .jac files, compile to JS and recursively process transitive imports
                    try:
                        compiled_js, imported_mod = self._compile_to_js(import_path_obj)

                        # Get the manifest of the imported module to recursively process its imports
                        transitive_imports: set[str] = set()
                        if imported_mod and imported_mod.gen.client_manifest:
                            # Process transitive imports (imports from the imported module)
                            for (
                                sub_import_name,
                                sub_import_path,
                            ) in imported_mod.gen.client_manifest.imports.items():
                                bundled_module_names.add(sub_import_name)
                                transitive_imports.add(sub_import_name)

                                # Recursively include the transitive import in the bundle
                                sub_import_path_obj = Path(sub_import_path)
                                if (
                                    sub_import_path_obj.suffix == ".jac"
                                    and sub_import_path_obj.exists()
                                ):
                                    try:
                                        sub_compiled_js, _ = self._compile_to_js(
                                            sub_import_path_obj
                                        )
                                        import_pieces.append(
                                            f"// Imported .jac module: {sub_import_name}"
                                        )
                                        import_pieces.append(sub_compiled_js)
                                        import_pieces.append("")
                                    except ClientBundleError:
                                        pass

                        # Strip import statements from the imported module
                        compiled_js = self._strip_import_statements(
                            compiled_js, transitive_imports
                        )

                        import_pieces.append(f"// Imported .jac module: {import_name}")
                        import_pieces.append(compiled_js)
                        import_pieces.append("")
                    except ClientBundleError:
                        import_pieces.append(
                            f"// Warning: Could not compile {import_path}"
                        )

        return ProcessedImports(import_pieces, bundled_module_names)

    def _extract_client_exports(self, manifest: ClientManifest | None) -> list[str]:
        """Extract client exports from manifest.

        Args:
            manifest: The client manifest, or None

        Returns:
            Sorted list of client export names
        """
        return sorted(dict.fromkeys(manifest.exports)) if manifest else []

    def _extract_client_globals(
        self, manifest: ClientManifest | None, module: ModuleType
    ) -> dict[str, Any]:
        """Extract client globals from manifest and module.

        Args:
            manifest: The client manifest, or None
            module: The Python module

        Returns:
            Dictionary of global names to their values
        """
        client_globals_map: dict[str, Any] = {}
        if manifest:
            for name in manifest.globals:
                if name in manifest.globals_values:
                    client_globals_map[name] = manifest.globals_values[name]
                elif hasattr(module, name):
                    client_globals_map[name] = getattr(module, name)
                else:
                    client_globals_map[name] = None
        return {key: client_globals_map[key] for key in sorted(client_globals_map)}

    def _compile_bundle(
        self,
        module: ModuleType,
        module_path: Path,
    ) -> ClientBundle:
        """Compile bundle pieces and stitch them together."""
        # Get manifest from JacProgram first to check for imports
        from jaclang.runtimelib.runtime import JacRuntime as Jac

        mod = Jac.program.mod.hub.get(str(module_path))
        manifest = mod.gen.client_manifest if mod else None

        # Process client imports and track which modules are being bundled
        import_pieces, bundled_module_names = self._process_imports(
            manifest, module_path
        )

        # Compile main module and strip import statements for bundled modules
        module_js, _ = self._compile_to_js(module_path)
        module_js = self._strip_import_statements(module_js, bundled_module_names)

        client_exports = self._extract_client_exports(manifest)
        client_globals_map = self._extract_client_globals(manifest, module)

        registration_js = self._generate_registration_js(
            module.__name__, client_exports, client_globals_map
        )

        bundle_pieces = []

        # Add imported modules (which may include client_runtime if explicitly imported)
        if import_pieces:
            bundle_pieces.extend(import_pieces)

        # Add main module
        bundle_pieces.extend(
            [
                f"// Client module: {module.__name__}",
                module_js,
                "",
                registration_js,
            ]
        )

        bundle_code = "\n".join(piece for piece in bundle_pieces if piece is not None)
        bundle_hash = hashlib.sha256(bundle_code.encode("utf-8")).hexdigest()

        return ClientBundle(
            module_name=module.__name__,
            code=bundle_code,
            client_functions=client_exports,
            client_globals=list(client_globals_map.keys()),
            hash=bundle_hash,
        )

    def _compile_to_js(self, source_path: Path) -> tuple[str, Module]:
        """Compile the provided Jac file into JavaScript.

        Returns:
            Tuple of (js_code, compiled_module) where compiled_module contains the client_manifest
        """
        from jaclang.runtimelib.runtime import JacRuntime as Jac

        # Reuse the global program to leverage cached compilations
        program = Jac.program
        source_key = str(source_path)

        # Check if already compiled in the global program's cache
        if source_key in program.mod.hub:
            mod = program.mod.hub[source_key]
            return mod.gen.js or "", mod

        # Compile only if not in cache
        mod = program.compile(source_key)
        if program.errors_had:
            formatted = "\n".join(str(err) for err in program.errors_had)
            raise ClientBundleError(
                f"Failed to compile '{source_path}' for client bundle:\n{formatted}"
            )
        return mod.gen.js or "", mod

    @staticmethod
    def _strip_import_statements(js_code: str, bundled_modules: set[str]) -> str:
        """Remove ES6 import statements for modules that are bundled.

        Args:
            js_code: The JavaScript code
            bundled_modules: Set of module names that are being bundled

        Returns:
            JavaScript code with bundled imports removed
        """
        import re

        # Convert bundled module names to their JS import paths for matching
        bundled_js_paths = {convert_to_js_import_path(mod) for mod in bundled_modules}
        # Also keep the original names for backward compatibility
        all_bundled = bundled_modules | bundled_js_paths

        lines = js_code.split("\n")
        filtered_lines = []

        for line in lines:
            # Match ES6 import statements: import { ... } from "module_name";
            import_match = re.match(
                r'^\s*import\s+.*\s+from\s+["\']([^"\']+)["\'];?\s*$', line
            )
            if import_match:
                module_name = import_match.group(1)
                # Skip this line if the module is being bundled
                if module_name in all_bundled:
                    continue
            filtered_lines.append(line)

        return "\n".join(filtered_lines)

    @staticmethod
    def _signature(paths: Iterable[Path]) -> str:
        """Compute a cache signature based on file modification times."""
        parts: list[str] = []
        for path in paths:
            try:
                stat = path.stat()
                parts.append(f"{path}:{stat.st_mtime_ns}")
            except FileNotFoundError:
                parts.append(f"{path}:missing")
        return hashlib.sha256("|".join(parts).encode("utf-8")).hexdigest()

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
