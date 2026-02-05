import re;
import from pathlib { Path }
import from operator { attrgetter }
import from jaclang.runtimelib.client_bundle { ClientBundleError }

impl RouteEntry.init(
    self: RouteEntry,
    path: str,
    component_import: str,
    file_path: Path,
    auth_required: bool = False,
    is_layout: bool = False,
    is_catch_all: bool = False,
    children: (list[RouteEntry] | None) = None
) {
    self.path = path;
    self.component_import = component_import;
    self.file_path = file_path;
    self.auth_required = auth_required;
    self.is_layout = is_layout;
    self.is_catch_all = is_catch_all;
    self.children = children if children is not None else [];
}

impl RouteScanner.init(self: RouteScanner, project_root: Path) {
    self.project_root = project_root;
    self.pages_dir = project_root / self.PAGES_DIR_NAME;
    self._routes: list[RouteEntry] = [];
    self._layouts: dict[(str, RouteEntry)] = {};
    self._page_files: list[Path] = [];
}

impl RouteScanner.has_pages_dir(self: RouteScanner) -> bool {
    return self.pages_dir.exists() and self.pages_dir.is_dir();
}

impl RouteScanner.scan(self: RouteScanner) -> list[RouteEntry] {
    if not self.has_pages_dir() {
        return [];
    }
    self._routes = [];
    self._layouts = {};
    self._page_files = [];
    self._routes = self._scan_directory(self.pages_dir);
    self._detect_collisions(self._routes);
    return self._routes;
}

"""Return layouts discovered during the last scan, keyed by URL prefix."""
impl RouteScanner.get_layouts(self: RouteScanner) -> dict[(str, RouteEntry)] {
    return self._layouts;
}

impl RouteScanner.get_page_files(self: RouteScanner) -> list[Path] {
    return self._page_files;
}

impl RouteScanner._scan_directory(
    self: RouteScanner,
    dir_path: Path,
    url_prefix: str = "",
    auth_required: bool = False
) -> list[RouteEntry] {
    routes: list[RouteEntry] = [];
    # Collect and sort entries for deterministic route ordering
    entries = sorted(dir_path.iterdir(), key=attrgetter('name'));
    for entry in entries {
        if entry.is_dir() {
            dir_name = entry.name;
            # Route groups: (public), (auth), etc.
            group_match = re.match(r'^\((\w+)\)$', dir_name);
            if group_match {
                group_name = group_match.group(1);
                group_auth = auth_required or (group_name == self.AUTH_GROUP_NAME);
                # Route groups don't add to the URL path
                child_routes = self._scan_directory(entry, url_prefix, group_auth);
                routes.extend(child_routes);
            } else {
                # Regular subdirectory — adds to URL path
                child_prefix = f"{url_prefix}/{dir_name}";
                child_routes = self._scan_directory(entry, child_prefix, auth_required);
                routes.extend(child_routes);
            }
        } elif entry.is_file() and entry.suffix == '.jac' {
            if any(suffix in entry.name for suffix in self.SKIP_SUFFIXES) {
                continue;
            }
            stem = entry.stem;
            # layout.jac — not a route, it's a layout wrapper
            if stem == self.LAYOUT_FILENAME {
                layout_key = url_prefix or "/";
                if layout_key in self._layouts {
                    raise ClientBundleError(
                        f"Layout collision: '{layout_key}' has layouts from both "
                        f"'{self._layouts[layout_key].file_path}' and '{entry}'. "
                        f"Remove one of them."
                    ) ;
                }
                component_name = self._file_to_component_name(entry);
                layout_entry = RouteEntry(
                    path=layout_key,
                    component_import=component_name,
                    file_path=entry,
                    is_layout=True
                );
                self._layouts[layout_key] = layout_entry;
                self._page_files.append(entry);
                continue;
            }
            route_segment = self._file_to_route_path(stem);
            is_catch_all = stem.startswith('[...');
            if stem == self.INDEX_FILENAME {
                # index.jac maps to the directory path
                route_path = url_prefix or "/";
            } else {
                route_path = f"{url_prefix}/{route_segment}";
            }
            component_name = self._file_to_component_name(entry);
            route = RouteEntry(
                path=route_path,
                component_import=component_name,
                file_path=entry,
                auth_required=auth_required,
                is_catch_all=is_catch_all
            );
            routes.append(route);
            self._page_files.append(entry);
        }
    }
    return routes;
}

"""Convert a filename stem to a React Router route path segment.

    index       → (empty, handled by caller)
    about       → about
    [id]        → :id
    [...slug]   → *
"""
impl RouteScanner._file_to_route_path(self: RouteScanner, filename: str) -> str {
    # Catch-all: [...slug] → *
    catch_all_match = re.match(r'^\[\.\.\.(\w+)\]$', filename);
    if catch_all_match {
        return "*";
    }
    # Dynamic segment: [id] → :id
    dynamic_match = re.match(r'^\[(\w+)\]$', filename);
    if dynamic_match {
        return f":{dynamic_match.group(1)}";
    }
    # Static segment
    return filename;
}

"""Generate a unique component import name from a page file path.

    pages/index.jac             → PagesIndex
    pages/about.jac             → PagesAbout
    pages/(auth)/dashboard.jac  → PagesDashboard
    pages/users/[id].jac        → PagesUsersId
    pages/[...slug].jac         → PagesSlug
"""
impl RouteScanner._file_to_component_name(self: RouteScanner, file_path: Path) -> str {
    try {
        relative = file_path.relative_to(self.pages_dir);
    } except ValueError {
        relative = Path(file_path.name);
    }
    parts: list[str] = [];
    for part in relative.with_suffix('').parts {
        # Skip route group directories like (auth), (public)
        if re.match(r'^\(\w+\)$', part) {
            continue;
        }
        # Strip catch-all prefix: [...slug] → slug
        clean = re.sub(r'^\[\.\.\.(\w+)\]$', r'\1', part);
        # Strip dynamic brackets: [id] → id
        clean = re.sub(r'^\[(\w+)\]$', r'\1', clean);
        parts.append(clean[0].upper() + clean[1:] if len(clean) > 0 else clean);
    }
    return self.COMPONENT_PREFIX + "".join(parts);
}

impl RouteScanner._detect_collisions(
    self: RouteScanner, routes: list[RouteEntry]
) -> None {
    seen: dict[(str, Path)] = {};
    for route in routes {
        if route.is_layout {
            continue;
        }
        if route.path in seen {
            raise ClientBundleError(
                f"Route collision: '{route.path}' is defined by both "
                f"'{seen[route.path]}' and '{route.file_path}'. "
                f"Remove one of them."
            ) ;
        }
        seen[route.path] = route.file_path;
    }
}
