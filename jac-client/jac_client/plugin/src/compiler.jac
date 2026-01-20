"""Main compilation orchestration module."""
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
    def _get_client_dir(self: ViteCompiler) -> Path;
    def copy_root_assets(self: ViteCompiler) -> None;
    def create_entry_file(self: ViteCompiler, module_path: Path) -> None;
    def compile_and_bundle(
        self: ViteCompiler, module: ModuleType, module_path: Path
    ) -> tuple[str, str, list[str], list[str]];

    # Source Discovery
    def discover_source_files(
        self: ViteCompiler,
        source_root: Path,
        exclude_patterns: (list[str] | None) = None
    ) -> tuple[list[Path], list[Path]];
    def _is_jac_file(self: ViteCompiler, file_path: Path) -> bool;
    def _should_compile_jac_file(
        self: ViteCompiler, file_path: Path, all_jac_files: set[Path]
    ) -> bool;

    # Alias Resolution
    def load_aliases(self: ViteCompiler, source_root: Path) -> dict[str, Path];

    # Unified file copying
    def copy_file_to_compiled(
        self: ViteCompiler, source_path: Path, source_root: Path
    ) -> None;

    # Upfront compilation
    def compile_all_source_files(
        self: ViteCompiler,
        module: ModuleType,
        module_path: Path
    ) -> tuple[set[str], dict[str, Any]];
}
