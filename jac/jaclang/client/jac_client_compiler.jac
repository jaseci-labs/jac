import contextlib;
import from pathlib { Path }
import from types { ModuleType }
import from typing { TYPE_CHECKING }
import from jaclang.client.client_bundle { ClientBundleError }
import from jaclang.client.asset_processor { AssetProcessor }
import from jaclang.client.import_processor { ImportProcessor }
import from jaclang.client.jac_to_js { JacToJSCompiler }
import from jaclang.client.route_scanner { RouteScanner, resolve_route_exports }
import from jaclang.jac0core.ext_registry { ANNEX_SUFFIXES }
import type from jaclang.compiler.frontend.codeinfo { ClientArtifact, ClientManifest }

with entry {
    if TYPE_CHECKING {}
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

        COMPOUND_EXTENSIONS = ['.native.jac'] + list(ANNEX_SUFFIXES);

        NATIVE_RUNTIME_FILE = "client_runtime_native.jac";

        SELF_COMPILED_VIRTUAL_MODULES = {"@jac/mobui", "@jac/pwa"};
    }

    def init(
        self: JacClientCompiler,
        project_dir: Path,
        runtime_path: (Path | None),
        compile_to_js_func: Callable[[Path], ClientArtifact],
        extract_exports_func: Callable[[ClientManifest | None], list[str]],
        extract_globals_func:
            Callable[[ClientManifest | None, ModuleType | None], dict[str, any]],
        compiled_dir: (Path | None) = None
    );

    def _get_client_dir(self: JacClientCompiler) -> Path;
    def _client_app_dir(self: JacClientCompiler) -> Path;
    def _app_root(self: JacClientCompiler) -> Path;
    def _collect_na_modules(self: JacClientCompiler, artifact: ClientArtifact) -> None;
    def _jac_path_to_js(self: JacClientCompiler, rel_str: str) -> str;
    def _native_variant(self: JacClientCompiler, path: Path) -> Path;
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
        collected_globals: (dict[(str, any)] | None) = None,
        source_root: (Path | None) = None,
        native: bool = False,
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
        entry_manifest: any = None,
        visited: (set[Path] | None) = None,
        collected_exports: (set[str] | None) = None,
        collected_globals: (dict[(str, any)] | None) = None,
        native: bool = False
    ) -> bool;

    def rescan_pages(self: JacClientCompiler) -> bool;
    def _check_entry_renders_routes(
        self: JacClientCompiler, entry_manifest: any
    ) -> None;

    def _warn_pages_without_routes(
        self: JacClientCompiler, scanner: RouteScanner
    ) -> None;

    def _generate_routes_manifest(self: JacClientCompiler) -> bool;
    def _write_source_map(
        self: JacClientCompiler,
        artifact: ClientArtifact,
        source_file: str,
        output_path: Path,
        full_output: str
    ) -> None;

    def compile(
        self: JacClientCompiler,
        module: (ModuleType | None),
        module_path: Path,
        native: bool = False
    ) -> tuple[list[str], list[str]];
}
