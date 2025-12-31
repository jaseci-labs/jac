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
class JacToJSCompiler {
    def init(
        self: JacToJSCompiler,
        compile_to_js_func: Callable[([Path], tuple[(str, (ModuleType | None))])],
        extract_exports_func: Callable[([Any], list[str])],
        extract_globals_func: Callable[([Any, ModuleType], dict[(str, Any)])]
    );

    def compile_module(
        self: JacToJSCompiler, module_path: Path
    ) -> tuple[str, (ModuleType | None), (ClientManifest | None)];

    def extract_exports(
        self: JacToJSCompiler, manifest: (ClientManifest | None)
    ) -> list[str];

    def extract_globals(
        self: JacToJSCompiler, manifest: (ClientManifest | None), module: ModuleType
    ) -> dict[str, Any];

    def add_runtime_imports(self: JacToJSCompiler, js_code: str) -> str;
}
