import contextlib;
import from collections.abc { Callable }
import from pathlib { Path }
import from types { ModuleType }
import from typing { TYPE_CHECKING, Any }
import from jaclang.runtimelib.client_bundle { ClientBundleError }
import from jaclang.runtimelib.client.jac_to_js { JacToJSCompiler }
import from jaclang.runtimelib.client.jac_client_compiler { JacClientCompiler }
import from jaclang.runtimelib.client.vite_bundler { ViteBundler }

with entry {
    if TYPE_CHECKING { }
}

class ViteCompiler {
    def init(
        self: ViteCompiler,
        vite_package_json: Path,
        vite_output_dir: (Path | None) = None,
        vite_minify: bool = False,
        runtime_path: (Path | None) = None,
        compile_to_js_func: Callable[([Path], tuple[(str, (ModuleType | None))])],
        extract_exports_func: Callable[([any], list[str])],
        extract_globals_func: Callable[([any, ModuleType], dict[(str, Any)])]
    );

    def compile_runtime_utils(self: ViteCompiler) -> tuple[str, list[str]];
    def compile_desktop_sdk(self: ViteCompiler);
    def create_entry_file(self: ViteCompiler, module_path: Path) -> None;
    def _create_pages_entry_content(self: ViteCompiler, module_path: Path) -> str;
    def _emit_na_wasm(self: ViteCompiler, module_path: Path) -> None;
    def compile_and_bundle(
        self: ViteCompiler, module: ModuleType, module_path: Path
    ) -> tuple[str, str, list[str], list[str]];

    def compile(
        self: ViteCompiler, module: ModuleType, module_path: Path
    ) -> tuple[list[str], list[str]];
}
