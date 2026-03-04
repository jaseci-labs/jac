"""Jac to JavaScript compilation module."""
import from collections.abc { Callable }
import from pathlib { Path }
import from types { ModuleType }
import from typing { TYPE_CHECKING, Any }

with entry {
    if TYPE_CHECKING {
        import from jaclang.compiler.codeinfo { ClientManifest }
    }
}

"""Handles compilation of Jac files to JavaScript."""
obj JacToJSCompiler {
    has _compile_to_js: Callable[([Path], tuple[(str, (ModuleType | None))])],
        _extract_client_exports: Callable[([Any], list[str])],
        _extract_client_globals: Callable[([Any, ModuleType], dict[(str, Any)])];

    def compile_module(
        module_path: Path
    ) -> tuple[str, (ModuleType | None), (ClientManifest | None)];

    def extract_exports(manifest: (ClientManifest | None)) -> list[str];
    def extract_globals(
        manifest: (ClientManifest | None), module: ModuleType
    ) -> dict[str, Any];

    def add_runtime_imports(js_code: str) -> str;
}
