import from pathlib { Path }

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
