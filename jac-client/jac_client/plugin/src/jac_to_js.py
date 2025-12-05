"""Jac to JavaScript compilation module."""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path
from types import ModuleType
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from jaclang.compiler.codeinfo import ClientManifest


class JacToJSCompiler:
    """Handles compilation of Jac files to JavaScript."""

    def __init__(
        self,
        compile_to_js_func: Callable[[Path], tuple[str, ModuleType | None]],
        extract_exports_func: Callable[[Any], list[str]],
        extract_globals_func: Callable[[Any, ModuleType], dict[str, Any]],
    ):
        """Initialize the Jac to JS compiler.

        Args:
            compile_to_js_func: Function to compile Jac to JS (from ClientBundleBuilder)
            extract_exports_func: Function to extract client exports (from ClientBundleBuilder)
            extract_globals_func: Function to extract client globals (from ClientBundleBuilder)
        """
        self._compile_to_js = compile_to_js_func
        self._extract_client_exports = extract_exports_func
        self._extract_client_globals = extract_globals_func

    def compile_module(
        self, module_path: Path
    ) -> tuple[str, ModuleType | None, ClientManifest | None]:
        """Compile a Jac module to JavaScript.

        Args:
            module_path: Path to the Jac module

        Returns:
            Tuple of (js_code, compiled_module, manifest)
        """
        module_js, mod = self._compile_to_js(module_path)
        manifest = mod.gen.client_manifest if mod else None
        return module_js, mod, manifest

    def extract_exports(self, manifest: ClientManifest | None) -> list[str]:
        """Extract client exports from manifest.

        Args:
            manifest: The client manifest

        Returns:
            List of exported symbol names
        """
        return self._extract_client_exports(manifest)

    def extract_globals(
        self, manifest: ClientManifest | None, module: ModuleType
    ) -> dict[str, Any]:
        """Extract client globals from manifest and module.

        Args:
            manifest: The client manifest
            module: The Python module

        Returns:
            Dictionary of global names to their values
        """
        return self._extract_client_globals(manifest, module)

    def generate_export_block(self, exports: list[str]) -> str:
        """Generate an ES module export block.

        Args:
            exports: List of export names

        Returns:
            Export statement string
        """
        if not exports:
            return ""
        return f"export {{ {', '.join(exports)} }};\n"

    def add_runtime_imports(self, js_code: str) -> str:
        """Add runtime imports to compiled JS code.

        Args:
            js_code: The compiled JavaScript code

        Returns:
            JavaScript code with runtime imports added
        """
        jac_jsx_import = 'import {__jacJsx, __jacSpawn} from "@jac-client/utils";'
        return f"{jac_jsx_import}\n{js_code}"
