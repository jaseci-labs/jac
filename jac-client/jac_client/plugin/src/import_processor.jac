"""Import processing for Vite bundling."""
import from pathlib { Path }
import from typing { TYPE_CHECKING }
import from jaclang.runtimelib.client_bundle { ClientBundleError }

with entry {
    if TYPE_CHECKING {
        import from jaclang.compiler.codeinfo { ClientManifest }
    }
}

"""Processes client imports for Vite bundling."""
class ImportProcessor {
    def process_vite_imports(
        self: ImportProcessor, manifest: (ClientManifest | None), module_path: Path
    ) -> list[(Path | None)];

    def should_process_import(self: ImportProcessor, import_path: Path) -> bool;
}
