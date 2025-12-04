"""Import processing for Vite bundling."""

from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING

from jaclang.runtimelib.client_bundle import ClientBundleError

if TYPE_CHECKING:
    from jaclang.compiler.codeinfo import ClientManifest


class ImportProcessor:
    """Processes client imports for Vite bundling.

    Only marks modules as bundled when we actually inline their code (.jac files we compile
    and local .js files we embed). Bare package specifiers (e.g., "antd") are left as real
    ES imports so Vite can resolve and bundle them.
    """

    def process_vite_imports(
        self, manifest: ClientManifest | None, module_path: Path
    ) -> list[Path | None]:
        """Process client imports for Vite bundling.

        Args:
            manifest: The client manifest containing imports
            module_path: Path to the module being processed

        Returns:
            List of imported module paths (or None for failed imports)
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

    def should_process_import(self, import_path: Path) -> bool:
        """Check if an import should be processed (compiled/copied) vs left for Vite.

        Args:
            import_path: Path to the import

        Returns:
            True if the import should be processed, False if left for Vite
        """
        return import_path.suffix in {".jac", ".js"}
