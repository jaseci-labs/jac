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
    """Initialize the Jac to JS compiler."""
    def __init__(
        self: JacToJSCompiler,
        compile_to_js_func: Callable[([Path], tuple[(str, (ModuleType | None))])],
        extract_exports_func: Callable[([Any], list[str])],
        extract_globals_func: Callable[([Any, ModuleType], dict[(str, Any)])]
    ) {
        self._compile_to_js = compile_to_js_func;
        self._extract_client_exports = extract_exports_func;
        self._extract_client_globals = extract_globals_func;
    }

    """Compile a Jac module to JavaScript."""
    def compile_module(
        self: JacToJSCompiler, module_path: Path
    ) -> tuple[str, (ModuleType | None), (ClientManifest | None)] {
        (module_js, mod) = self._compile_to_js(module_path);
        manifest = mod.gen.client_manifest if mod else None;
        return (module_js, mod, manifest);
    }

    """Extract client exports from manifest."""
    def extract_exports(
        self: JacToJSCompiler, manifest: (ClientManifest | None)
    ) -> list[str] {
        return self._extract_client_exports(manifest);
    }

    """Extract client globals from manifest and module."""
    def extract_globals(
        self: JacToJSCompiler, manifest: (ClientManifest | None), module: ModuleType
    ) -> dict[str, Any] {
        return self._extract_client_globals(manifest, module);
    }

    """Generate an ES module export block."""
    def generate_export_block(self: JacToJSCompiler, exports: list[str]) -> str {
        if not exports {
            return '';
        }
        return f"export {{ {', '.join(exports)} }};\n";
    }

    """Add runtime imports to compiled JS code."""
    def add_runtime_imports(self: JacToJSCompiler, js_code: str) -> str {
        jac_jsx_import = 'import {__jacJsx, __jacSpawn} from "@jac-client/utils";';
        return f"{jac_jsx_import}\n{js_code}";
    }
}
