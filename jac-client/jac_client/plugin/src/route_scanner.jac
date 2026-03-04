"""File-based route scanner for pages/ directory convention."""
import from pathlib { Path }

"""A single route entry derived from a file in pages/."""
obj RouteEntry {
    has path: str,
        component_import: str,
        file_path: Path,
        auth_required: bool = False,
        is_layout: bool = False,
        is_catch_all: bool = False,
        children: list[RouteEntry] = [];
}

"""Scans a pages/ directory and produces a route tree."""
obj RouteScanner {
    with entry {
        PAGES_DIR_NAME = 'pages';
        LAYOUT_FILENAME = 'layout';
        INDEX_FILENAME = 'index';
        AUTH_GROUP_NAME = 'auth';
        COMPONENT_PREFIX = 'Pages';
        SKIP_SUFFIXES = ['.cl.', '.impl.', '.test.'];
    }

    has project_root: Path,
        pages_dir: Path by postinit,
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
