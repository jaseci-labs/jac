"""Vite-enhanced client bundle generation for Jac web front-ends."""

from __future__ import annotations

import contextlib
import shutil
from collections.abc import Callable
from pathlib import Path
from types import ModuleType
from typing import cast

from jaclang.runtimelib.client_bundle import (
    ClientBundle,
    ClientBundleBuilder,
    ClientBundleError,
)

from .src import ViteCompiler


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
        self._compiler: ViteCompiler | None = None

    def _get_compiler(self) -> ViteCompiler:
        """Get or create the Vite compiler instance."""
        if self._compiler is None:
            if not self.vite_package_json or not self.vite_package_json.exists():
                raise ClientBundleError(
                    "Vite package.json not found. Set vite_package_json when using ViteClientBundleBuilder"
                )
            # Type cast to match expected signature (actual returns Module from jaclang, not ModuleType)
            compile_to_js_func: Callable[[Path], tuple[str, ModuleType | None]] = cast(
                Callable[[Path], tuple[str, ModuleType | None]], self._compile_to_js
            )
            self._compiler = ViteCompiler(
                vite_package_json=self.vite_package_json,
                vite_output_dir=self.vite_output_dir,
                vite_minify=self.vite_minify,
                runtime_path=self.runtime_path,
                compile_to_js_func=compile_to_js_func,
                extract_exports_func=self._extract_client_exports,
                extract_globals_func=self._extract_client_globals,
            )
        return self._compiler

    def _compile_bundle(
        self,
        module: ModuleType,
        module_path: Path,
    ) -> ClientBundle:
        """Override to use Vite bundling instead of simple concatenation."""
        compiler = self._get_compiler()

        # Compile and bundle using the compiler
        bundle_code, bundle_hash, client_exports, client_globals = (
            compiler.compile_and_bundle(module, module_path)
        )

        return ClientBundle(
            module_name=module.__name__,
            code=bundle_code,
            client_functions=client_exports,
            client_globals=client_globals,
            hash=bundle_hash,
        )

    def cleanup_temp_dir(self) -> None:
        """Clean up the compiled directory and its contents."""
        if not self.vite_package_json or not self.vite_package_json.exists():
            return

        project_dir = self.vite_package_json.parent
        temp_dir = project_dir / "compiled"

        if temp_dir.exists():
            with contextlib.suppress(OSError, shutil.Error):
                shutil.rmtree(temp_dir)
