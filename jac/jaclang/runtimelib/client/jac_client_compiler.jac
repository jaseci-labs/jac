import contextlib;
import from collections.abc { Callable }
import from pathlib { Path }
import from types { ModuleType }
import from typing { TYPE_CHECKING, Any }
import from jaclang.runtimelib.client_bundle { ClientBundleError }
import from jaclang.runtimelib.client.asset_processor { AssetProcessor }
import from jaclang.runtimelib.client.import_processor { ImportProcessor }
import from jaclang.runtimelib.client.jac_to_js { JacToJSCompiler }
import from jaclang.runtimelib.client.route_scanner { RouteScanner }
import from jaclang.jac0core.ext_registry { CLIENT_SUFFIX, ANNEX_SUFFIXES }

with entry {
    if TYPE_CHECKING { }
}

class JacClientCompiler {
    with entry {
        ROUTER_EXPORTS = [
            'Router',
            'Routes',
            'Route',
            'Link',
            'Navigate',
            'Outlet',
            'useNavigate',
            'useLocation',
            'useParams',
            'AuthGuard',
            'JacClientErrorBoundary'
        ];

        COMPOUND_EXTENSIONS = ['.native.cl.jac', CLIENT_SUFFIX] + list(ANNEX_SUFFIXES);

        PLATFORM_RUNTIME_FILES = {"react-native": "client_runtime_native.cl.jac"};
    }

    def init(
        self: JacClientCompiler,
        project_dir: Path,
        runtime_path: (Path | None),
        compile_to_js_func: Callable[([Path], tuple[(str, (ModuleType | None))])],
        extract_exports_func: Callable[([any], list[str])],
        extract_globals_func: Callable[([any, ModuleType], dict[(str, Any)])],
        compiled_dir: (Path | None) = None
    );

    def _get_client_dir(self: JacClientCompiler) -> Path;
    def _jac_path_to_js(self: JacClientCompiler, rel_str: str) -> str;
    def compile_runtime_utils(
        self: JacClientCompiler, runtime_filename: str
    ) -> tuple[str, list[str]];

    def compile_pwa_runtime(self: JacClientCompiler) -> tuple[str, list[str]];
    def compile_mobui_utils(self: JacClientCompiler) -> tuple[str, list[str]];
    def compile_dependencies_recursively(
        self: JacClientCompiler,
        module_path: Path,
        visited: (set[Path] | None) = None,
        collected_exports: (set[str] | None) = None,
        collected_globals: (dict[(str, Any)] | None) = None,
        source_root: (Path | None) = None,
        target_name: str = "web",
        skip_existing: bool = False
    ) -> None;

    def _output_path_for(
        self: JacClientCompiler, module_path: Path, source_root: Path
    ) -> Path;

    def _copy_js_file(
        self: JacClientCompiler, js_path: Path, source_root: Path
    ) -> None;

    def _copy_ts_file(
        self: JacClientCompiler, ts_path: Path, source_root: Path
    ) -> None;

    def _copy_asset_file(
        self: JacClientCompiler, asset_path: Path, source_root: Path
    ) -> None;

    def copy_root_assets(self: JacClientCompiler) -> None;
    def _scan_and_compile_pages(
        self: JacClientCompiler,
        visited: (set[Path] | None) = None,
        collected_exports: (set[str] | None) = None,
        collected_globals: (dict[(str, Any)] | None) = None,
        target_name: str = "web"
    ) -> bool;

    def rescan_pages(self: JacClientCompiler) -> bool;
    def _generate_routes_manifest(self: JacClientCompiler) -> None;
    def _write_source_map(
        self: JacClientCompiler,
        mod: Any,
        source_file: str,
        output_path: Path,
        full_output: str
    ) -> None;

    def compile(
        self: JacClientCompiler,
        module: ModuleType,
        module_path: Path,
        target_name: str = "web"
    ) -> tuple[list[str], list[str]];
}
