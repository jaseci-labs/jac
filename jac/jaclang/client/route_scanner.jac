import re;
import from pathlib { Path }

glob _ROUTE_ROLE_SUFFIXES: list[str] = ['.impl.', '.test.'],
     _JSX_ELEMENT_EXPORT_RE: str = (
         r'def(?::\w+)?\s+(\w+)\s*(?:\([^)]*\))?\s*->\s*JsxElement\b'
     ),
     _ROUTE_TYPE_MENTION_RE: str = r'\b(?:JsxPage|JsxLayout)\b';

def _describe_unrouted_page(f: Path) -> list[str];

def describe_pages_without_routes(pages_dir: Path) -> list[str];

def describe_unrouted_pages(files: list[Path]) -> list[str];

obj RouteEntry {
    has path: str,
        component_import: str,
        file_path: Path,
        source_export: str,
        auth_required: bool = False,
        is_layout: bool = False,
        is_catch_all: bool = False,
        children: list[RouteEntry] = [];
}

obj RouteScanner {
    with entry {
        PAGES_DIR_NAME = 'pages';
        INDEX_FILENAME = 'index';
        AUTH_GROUP_NAME = 'auth';
        COMPONENT_PREFIX = 'Pages';
        MODULE_ROLE_SUFFIXES = ['.impl.', '.test.'];
    }

    has project_root: Path,
        route_exports_of: Callable[([Path], tuple[((str | None), (str | None))])],
        pages_dir: Path postinit,
        _routes: list[RouteEntry] = [],
        _layouts: dict[(str, RouteEntry)] = {},
        _page_files: list[Path] = [],
        _unrouted_files: list[Path] = [];

    def postinit;
    def has_pages_dir -> bool;
    def scan -> list[RouteEntry];
    def get_layouts -> dict[(str, RouteEntry)];
    def get_page_files -> list[Path];
    def get_unrouted_files -> list[Path];
    def _scan_directory(
        dir_path: Path, url_prefix: str = "", auth_required: bool = False
    ) -> list[RouteEntry];

    def _file_to_route_path(filename: str) -> str;
    def _file_to_component_name(file_path: Path) -> str;
    def _detect_collisions(routes: list[RouteEntry]) -> None;
}

def resolve_route_exports(module_path: Path) -> tuple[((str | None), (str | None))];
def entry_drops_route_children(manifest: any) -> bool;
