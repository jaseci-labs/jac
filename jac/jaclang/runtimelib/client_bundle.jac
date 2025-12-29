"""Client bundle generation utilities for Jac web front-ends."""
import hashlib;
import json;
import from collections.abc { Iterable, Sequence }
import from pathlib { Path }
import from types { ModuleType }
import from typing { TYPE_CHECKING, Any, NamedTuple }
import from jaclang.pycore.modresolver { convert_to_js_import_path }

with entry {
    if TYPE_CHECKING {
        import from jaclang.pycore.codeinfo { ClientManifest }
        import from jaclang.pycore.unitree { Module }
    }
}

"""Raised when the client bundle cannot be generated."""
class ClientBundleError(RuntimeError) {}

"""Result of processing client imports."""
class ProcessedImports(NamedTuple) {
    has import_pieces: list[str],
        bundled_module_names: set[str];
}

"""Container for a compiled client bundle."""
obj ClientBundle {
    has module_name: str,
        code: str,
        client_functions: list[str],
        client_globals: list[str],
        hash: str;
}

obj _CachedBundle {
    has signature: str,
        bundle: ClientBundle;
}

"""Compile Jac modules and runtime support into a browser-ready bundle."""
obj ClientBundleBuilder {
    has runtime_path: (Path | None) = None,
        _cache: dict[(str, _CachedBundle)] = {};

    def postinit -> None;
    def build(module: ModuleType, force: bool = False) -> ClientBundle;
    def _process_imports(
        manifest: (ClientManifest | None), module_path: Path
    ) -> ProcessedImports;

    def _extract_client_exports(manifest: (ClientManifest | None)) -> list[str];
    def _extract_client_globals(
        manifest: (ClientManifest | None), module: ModuleType
    ) -> dict[str, Any];

    def _compile_bundle(module: ModuleType, module_path: Path) -> ClientBundle;
    def _compile_to_js(source_path: Path) -> tuple[str, Module];
    static def _strip_import_statements(js_code: str, bundled_modules: set[str]) -> str;
    static def _signature(paths: Iterable[Path]) -> str;
    static def _generate_registration_js(
        module_name: str,
        client_functions: Sequence[str],
        client_globals: dict[(str, Any)]
    ) -> str;
}
