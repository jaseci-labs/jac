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
    """Process client imports for Vite bundling."""
    def process_vite_imports(
        self: ImportProcessor, manifest: (ClientManifest | None), module_path: Path
    ) -> list[(Path | None)] {
        imported_js_modules: list[(Path | None)] = [];
        if (manifest and manifest.imports) {
            for (_, import_path) in manifest.imports.items() {
                import_path_obj = Path(import_path);
                if (import_path_obj.suffix == '.js') {
                    try {
                        imported_js_modules.append(import_path_obj);
                    } except FileNotFoundError {
                        imported_js_modules.append(None);
                    }
                } elif (import_path_obj.suffix == '.jac') {
                    try {
                        imported_js_modules.append(import_path_obj);
                    } except ClientBundleError {
                        imported_js_modules.append(None);
                    }
                }
            }
        }
        return imported_js_modules;
    }

    """Check if an import should be processed (compiled/copied) vs left for Vite."""
    def should_process_import(self: ImportProcessor, import_path: Path) -> bool {
        return (import_path.suffix in {'.jac','.js'});
    }
}
