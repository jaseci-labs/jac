"""Main compilation orchestration module."""
import contextlib;
import from collections.abc { Callable }
import from pathlib { Path }
import from types { ModuleType }
import from typing { TYPE_CHECKING, Any }
import from jaclang.runtimelib.client_bundle { ClientBundleError }
import from .asset_processor { AssetProcessor }
import from .babel_processor { BabelProcessor }
import from .import_processor { ImportProcessor }
import from .jac_to_js { JacToJSCompiler }
import from .vite_bundler { ViteBundler }

with entry {
    if TYPE_CHECKING { }
}

"""Orchestrates the compilation process for Vite client bundles."""
class ViteCompiler {
    with entry {
        ROUTER_EXPORTS = [
            'Router',
            'Routes',
            'Route',
            'Link',
            'Navigate',
            'useNavigate',
            'useLocation',
            'useParams'
        ];
    }

    def init(
        self: ViteCompiler,
        vite_package_json: Path,
        vite_output_dir: (Path | None) = None,
        vite_minify: bool = False,
        runtime_path: (Path | None) = None,
        compile_to_js_func:
            (Callable[([Path], tuple[(str, (ModuleType | None))])] | None) = None,
        extract_exports_func: (Callable[([Any], list[str])] | None) = None,
        extract_globals_func: (Callable[([Any, ModuleType], dict[(str, Any)])] | None) = None
    );

    def compile_runtime_utils(self: ViteCompiler) -> tuple[str, list[str]];
    def compile_dependencies_recursively(
        self: ViteCompiler,
        module_path: Path,
        visited: (set[Path] | None) = None,
        collected_exports: (set[str] | None) = None,
        collected_globals: (dict[(str, Any)] | None) = None,
        source_root: (Path | None) = None
    ) -> None;

    def _get_client_dir(self: ViteCompiler) -> Path;
    def _copy_js_file(self: ViteCompiler, js_path: Path, source_root: Path) -> None;
    def _copy_ts_file(self: ViteCompiler, ts_path: Path, source_root: Path) -> None;
    def _copy_asset_file(
        self: ViteCompiler, asset_path: Path, source_root: Path
    ) -> None;

    def copy_root_assets(self: ViteCompiler) -> None;
    def create_entry_file(self: ViteCompiler, module_path: Path) -> None;
    def compile_and_bundle(
        self: ViteCompiler, module: ModuleType, module_path: Path
    ) -> tuple[str, str, list[str], list[str]];
}
