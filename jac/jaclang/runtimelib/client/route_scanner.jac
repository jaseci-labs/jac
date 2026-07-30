import re;
import from pathlib { Path }

glob _ROUTE_ROLE_SUFFIXES: list = ['.impl.', '.test.'],
     _JSX_ELEMENT_EXPORT_RE: str = (
         r'def(?::\w+)?\s+(\w+)\s*(?:\([^)]*\))?\s*->\s*JsxElement\b'
     );

def _unrouted_jsx_exports(pages_dir: Path, skip_paths: set[Path]) -> list[str] {
    try {
        entries = sorted(pages_dir.rglob('*.jac'));
    } except OSError {
        return [];
    }
    lines: list[str] = [];
    for f in entries {
        if any(suffix in f.name for suffix in _ROUTE_ROLE_SUFFIXES) {
            continue;
        }
        if f.resolve() in skip_paths {
            continue;
        }
        try {
            source = f.read_text(encoding='utf-8');
        } except OSError {
            continue;
        }
        is_layout = f.stem == 'layout';
        for hit in re.finditer(_JSX_ELEMENT_EXPORT_RE, source) {
            kind = 'JsxLayout'
                if (is_layout or 'layout' in hit.group(1).lower())
                else 'JsxPage';
            lines.append(
                f"  {f}: '{hit.group(1)}' returns JsxElement and is not a route" + f" — return {kind} to route it, or leave it if it is a co-located component."
            );
        }
    }
    return lines;
}

def describe_pages_without_routes(pages_dir: Path) -> list[str] {
    try {
        candidates = [
            f
            for f in sorted(pages_dir.rglob('*.jac'))
            if not any(suffix in f.name for suffix in _ROUTE_ROLE_SUFFIXES)
        ];
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
    lines.extend(_unrouted_jsx_exports(pages_dir, set()));
    return lines;
}

def describe_unmigrated_pages(pages_dir: Path, routed_files: list[Path]) -> list[str] {
    skip_paths: set[Path] = set();
    for rf in routed_files {
        skip_paths.add(rf.resolve());
    }
    lines = _unrouted_jsx_exports(pages_dir, skip_paths);
    if not lines {
        return [];
    }
    lines.insert(0, f"{pages_dir}: some modules are not registered as routes:");
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
