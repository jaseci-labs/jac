import type from jaclang.compiler.driver.program { JacProgram }
import hashlib;
import os;
import from pathlib { Path }
import from types { ModuleType }
import from jaclang.client.artifact {
    ClientBundle,
    ClientBundleError,
    MissingBunError,
    prebuilt_bundle
}
import type from jaclang.compiler.frontend.codeinfo { ClientArtifact, ClientManifest }
import type from jaclang.compiler.frontend.unitree { Module }

def _client_target_module(source_key: str, program: any) -> (Module | None);

def _ensure_js_generated(mod: Module, program: any) -> None;

obj ClientBuildInputs {
    has module_name: str,
        client_functions: list[str],
        client_globals: list[str],
        assets: dict[str, bytes] = {};
}

obj _CachedBundle {
    has signature: str,
        bundle: ClientBundle;
}

obj ClientBundleBuilder {
    has runtime_path: (Path | None) = None,
        program: JacProgram | None = None,
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


def client_program(program: JacProgram | None) -> JacProgram {
    if program is not None {
        return program;
    }
    import from jaclang.runtime.runtime { JacRuntime }
    current = JacRuntime.program;
    if current is None {
        raise ClientBundleError('No active compilation program for client products');
    }
    return current;
}
