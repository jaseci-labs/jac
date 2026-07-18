import hashlib;
import os;
import from collections.abc { Iterable }
import from pathlib { Path }
import from types { ModuleType }
import from typing { Any }
import type from jaclang.jac0core.codeinfo { ClientManifest }
import type from jaclang.jac0core.unitree { Module }

class ClientBundleError(RuntimeError) {}

class MissingBunError(ClientBundleError) {}

def _lookup_module_in_hub(path_key: str, hub: dict) -> (Module | None);

def _ensure_js_generated(mod: Module, program: any) -> None;

def _prebuilt_bundle(module: ModuleType, source_path: Path) -> (ClientBundle | None);

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

obj ClientBundleBuilder {
    has runtime_path: (Path | None) = None,
        _cache: dict[(str, _CachedBundle)] = {};

    def postinit -> None;
    def build(module: ModuleType, force: bool = False) -> ClientBundle;
    def _extract_client_exports(manifest: (ClientManifest | None)) -> list[str];
    def _extract_client_globals(
        manifest: (ClientManifest | None), module: ModuleType
    ) -> dict[str, any];

    def _compile_bundle(module: ModuleType, module_path: Path) -> ClientBundle;
    def _compile_to_js(source_path: Path) -> tuple[str, Module];
    static def _signature(paths: Iterable[Path]) -> str;
}
