import re;
import from pathlib { Path }

glob _ROUTE_ROLE_SUFFIXES: list = ['.impl.', '.test.'],
     _JSX_ELEMENT_EXPORT_RE: str = (
         r'def(?::\w+)?\s+(\w+)\s*(?:\([^)]*\))?\s*->\s*JsxElement\b'
     ),
     _ROUTE_TYPE_RE: str = r'->\s*(?:JsxPage|JsxLayout)\b';

def describe_pages_without_routes(pages_dir: Path) -> list[str] {
    candidates: list[Path] = [];
    try {
        for f in sorted(pages_dir.rglob('*.jac')) {
            if any(suffix in f.name for suffix in _ROUTE_ROLE_SUFFIXES) {
                continue;
            }
            candidates.append(f);
        }
    } except OSError {
        return [];
    }
    if not candidates {
        return [];
    }
    lines: list[str] = [
        f"{pages_dir} contains {len(candidates)} module(s) but no recognized " + "routes — the app will mount without a router and render a blank page.",
        "A route is an export returning JsxPage (JsxLayout for layouts); " + "the export name and filename are free."
    ];
    for f in candidates {
        try {
            source = f.read_text(encoding='utf-8');
        } except OSError {
            continue;
        }
        if re.search(_ROUTE_TYPE_RE, source) {
            continue;
        }
        for hit in re.finditer(_JSX_ELEMENT_EXPORT_RE, source) {
            kind = 'JsxLayout' if 'layout' in hit.group(1).lower() else 'JsxPage';
            lines.append(
                f"  {f}: '{hit.group(1)}' returns JsxElement — change the " + f"return type to {kind} to make it a route."
            );
        }
    }
    return lines;
}

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
        _page_files: list[Path] = [];

    def postinit;
    def has_pages_dir -> bool;
    def scan -> list[RouteEntry];
    def get_layouts -> dict[(str, RouteEntry)];
    def get_page_files -> list[Path];
    def _scan_directory(
        dir_path: Path, url_prefix: str = "", auth_required: bool = False
    ) -> list[RouteEntry];

    def _file_to_route_path(filename: str) -> str;
    def _file_to_component_name(file_path: Path) -> str;
    def _detect_collisions(routes: list[RouteEntry]) -> None;
}

def resolve_route_exports(module_path: Path) -> tuple[((str | None), (str | None))];

def _route_exports_from_ast(mod: any) -> tuple[((str | None), (str | None))];
