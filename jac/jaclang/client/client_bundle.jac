import hashlib;
import os;
import from pathlib { Path }
import from types { ModuleType }
import type from jaclang.compiler.frontend.codeinfo { ClientArtifact, ClientManifest }
import type from jaclang.compiler.frontend.unitree { Module }

class ClientBundleError(RuntimeError) {}

class MissingBunError(ClientBundleError) {}

def _client_target_module(source_key: str, program: any) -> (Module | None);

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
        manifest: (ClientManifest | None), module: (ModuleType | None)
    ) -> dict[str, any];

    def _compile_bundle(module: ModuleType, module_path: Path) -> ClientBundle;
    def _compile_to_js(source_path: Path) -> ClientArtifact;
    def _emitted_digest -> str;
    static def _signature(paths: Iterable[Path]) -> str;
}

def emitted_tree_digest(tree_root: Path) -> str;
