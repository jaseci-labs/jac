import contextlib;
import from pathlib { Path }
import from types { ModuleType }
import from typing { TYPE_CHECKING }
import from jaclang.client.client_bundle { ClientBundleError }
import from jaclang.client.jac_client_compiler { JacClientCompiler }
import from jaclang.client.vite_bundler { ViteBundler }
import type from jaclang.compiler.frontend.codeinfo { ClientArtifact, ClientManifest }

with entry {
    if TYPE_CHECKING {}
}

class ViteCompiler {
    def init(
        self: ViteCompiler,
        vite_package_json: Path,
        vite_output_dir: (Path | None) = None,
        vite_minify: bool = False,
        runtime_path: (Path | None) = None,
        compile_to_js_func: Callable[[Path], ClientArtifact],
        extract_exports_func: Callable[[ClientManifest | None], list[str]],
        extract_globals_func:
            Callable[[ClientManifest | None, ModuleType | None], dict[str, any]]
    );

    def compile_runtime_utils(self: ViteCompiler) -> tuple[str, list[str]];
    def compile_desktop_sdk(self: ViteCompiler);
    def _entry_module_name(self: ViteCompiler, module_path: Path) -> str;
    def create_entry_file(self: ViteCompiler, module_path: Path) -> None;
    def _create_pages_entry_content(self: ViteCompiler, module_path: Path) -> str;
    def _owes_wasm(self: ViteCompiler, module_path: Path) -> bool;
    def _emit_na_wasm(self: ViteCompiler, module_path: Path) -> None;
    def _emit_wasm_module(self: ViteCompiler, module_path: Path) -> bool;
    def compile_and_bundle(
        self: ViteCompiler, module: ModuleType, module_path: Path
    ) -> tuple[str, str, list[str], list[str]];

    def compile(
        self: ViteCompiler, module: (ModuleType | None), module_path: Path
    ) -> tuple[list[str], list[str]];
}
