import from pathlib { Path }
import from types { ModuleType }
import type from jaclang.compiler.frontend.codeinfo { ClientArtifact, ClientManifest }

obj JacToJSCompiler {
    has _compile_to_js: Callable[[Path], ClientArtifact],
        _extract_client_exports: Callable[[ClientManifest | None], list[str]],
        _extract_client_globals:
            Callable[[ClientManifest | None, ModuleType | None], dict[str, any]],
        boundary_contracts: dict[str, dict] = {};

    def compile_module(module_path: Path) -> ClientArtifact;
    def extract_exports(manifest: (ClientManifest | None)) -> list[str];
    def extract_globals(
        manifest: (ClientManifest | None), module: (ModuleType | None)
    ) -> dict[str, any];

    def add_runtime_imports(js_code: str) -> str;
}
