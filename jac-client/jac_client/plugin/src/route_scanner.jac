"""File-based route scanner for pages/ directory convention."""
import from pathlib { Path }

"""A single route entry derived from a file in pages/."""
class RouteEntry {
    def init(
        self: RouteEntry,
        path: str,
        component_import: str,
        file_path: Path,
        auth_required: bool = False,
        is_layout: bool = False,
        is_catch_all: bool = False,
        children: (list[RouteEntry] | None) = None
    );
}

"""Scans a pages/ directory and produces a route tree."""
class RouteScanner {
    with entry {
        PAGES_DIR_NAME = 'pages';
        LAYOUT_FILENAME = 'layout';
        INDEX_FILENAME = 'index';
        AUTH_GROUP_NAME = 'auth';
        COMPONENT_PREFIX = 'Pages';
        SKIP_SUFFIXES = ['.cl.', '.impl.', '.test.'];
    }

    def init(self: RouteScanner, project_root: Path);
    def has_pages_dir(self: RouteScanner) -> bool;
    def scan(self: RouteScanner) -> list[RouteEntry];
    def get_layouts(self: RouteScanner) -> dict[(str, RouteEntry)];
    def get_page_files(self: RouteScanner) -> list[Path];
    def _scan_directory(
        self: RouteScanner,
        dir_path: Path,
        url_prefix: str = "",
        auth_required: bool = False
    ) -> list[RouteEntry];

    def _file_to_route_path(self: RouteScanner, filename: str) -> str;
    def _file_to_component_name(self: RouteScanner, file_path: Path) -> str;
    def _detect_collisions(self: RouteScanner, routes: list[RouteEntry]) -> None;
}
