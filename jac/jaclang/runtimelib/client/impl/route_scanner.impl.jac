import re;
import from pathlib { Path }
import from operator { attrgetter }
import from jaclang.runtimelib.client_bundle { ClientBundleError }

impl RouteScanner.postinit{
    self.pages_dir = self.project_root / self.PAGES_DIR_NAME;
}

impl RouteScanner.has_pages_dir -> bool {
    return self.pages_dir.exists() and self.pages_dir.is_dir();
}

impl RouteScanner.scan -> list[RouteEntry] {
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

impl RouteScanner.get_layouts -> dict[(str, RouteEntry)] {
    return self._layouts;
}

impl RouteScanner.get_page_files -> list[Path] {
    return self._page_files;
}

impl RouteScanner._scan_directory(
    dir_path: Path, url_prefix: str = "", auth_required: bool = False
) -> list[RouteEntry] {
    routes: list[RouteEntry] = [];

    entries = sorted(dir_path.iterdir(), key=attrgetter('name'));
    for entry in entries {
        if entry.is_dir() {
            dir_name = entry.name;

            group_match = re.match(r'^\((\w+)\)$', dir_name);
            if group_match {
                group_name = group_match.group(1);
                group_auth = auth_required or (group_name == self.AUTH_GROUP_NAME);

                child_routes = self._scan_directory(entry, url_prefix, group_auth);
                routes.extend(child_routes);
            } else {
                child_prefix = f"{url_prefix}/{dir_name}";
                child_routes = self._scan_directory(entry, child_prefix, auth_required);
                routes.extend(child_routes);
            }
        } elif entry.is_file() and entry.suffix == '.jac' {
            if any(suffix in entry.name for suffix in self.MODULE_ROLE_SUFFIXES) {
                continue;
            }
            (page_export, layout_export) = self.route_exports_of(entry);
            stem = entry.stem;
            if layout_export is not None {
                layout_key = url_prefix or "/";
                if layout_key in self._layouts {
                    raise ClientBundleError(
                        f"Layout collision: '{layout_key}' has layouts from both "
                        f"'{self._layouts[layout_key].file_path}' and '{entry}'. "
                        f"Remove one of them."
                    );
                }
                component_name = self._file_to_component_name(entry);
                layout_entry = RouteEntry(
                    path=layout_key,
                    component_import=component_name,
                    file_path=entry,
                    source_export=layout_export,
                    is_layout=True
                );
                self._layouts[layout_key] = layout_entry;
                self._page_files.append(entry);
                continue;
            }
            if page_export is None {
                continue;
            }
            route_segment = self._file_to_route_path(stem);
            is_catch_all = stem.startswith('[...');
            if stem == self.INDEX_FILENAME {
                route_path = url_prefix or "/";
            } else {
                route_path = f"{url_prefix}/{route_segment}";
            }
            component_name = self._file_to_component_name(entry);
            route = RouteEntry(
                path=route_path,
                component_import=component_name,
                file_path=entry,
                source_export=page_export,
                auth_required=auth_required,
                is_catch_all=is_catch_all
            );
            routes.append(route);
            self._page_files.append(entry);
        }
    }
    return routes;
}

impl RouteScanner._file_to_route_path(filename: str) -> str {
    catch_all_match = re.match(r'^\[\.\.\.(\w+)\]$', filename);
    if catch_all_match {
        return "*";
    }

    dynamic_match = re.match(r'^\[(\w+)\]$', filename);
    if dynamic_match {
        return f":{dynamic_match.group(1)}";
    }

    return filename;
}

def _sanitize_segment(segment: str) -> list[str] {
    fragments: list[str] = [];
    for fragment in re.split(r'[^0-9A-Za-z]+', segment) {
        if len(fragment) > 0 {
            fragments.append(fragment[0].upper() + fragment[1:]);
        }
    }
    return fragments;
}

impl RouteScanner._file_to_component_name(file_path: Path) -> str {
    try {
        relative = file_path.relative_to(self.pages_dir);
    } except ValueError {
        relative = Path(file_path.name);
    }
    parts: list[str] = [];
    for part in relative.with_suffix('').parts {
        if re.match(r'^\(\w+\)$', part) {
            continue;
        }

        clean = re.sub(r'^\[\.\.\.(\w+)\]$', r'\1', part);
        clean = re.sub(r'^\[(\w+)\]$', r'\1', clean);
        parts.extend(_sanitize_segment(clean));
    }
    return self.COMPONENT_PREFIX + "".join(parts);
}

impl RouteScanner._detect_collisions(routes: list[RouteEntry]) -> None {
    seen_paths: dict[(str, Path)] = {};
    seen_imports: dict[(str, Path)] = {};
    all_entries = routes + list(self._layouts.values());
    for entry in all_entries {
        if (not entry.is_layout) and (entry.path in seen_paths) {
            raise ClientBundleError(
                f"Route collision: '{entry.path}' is defined by both "
                f"'{seen_paths[entry.path]}' and '{entry.file_path}'. "
                f"Remove one of them."
            );
        }
        if not entry.is_layout {
            seen_paths[entry.path] = entry.file_path;
        }
        other = seen_imports.get(entry.component_import);
        if other {
            raise ClientBundleError(
                f"Route import-name collision: '{other}' and '{entry.file_path}' "
                f"both sanitize to the JS identifier '{entry.component_import}'. "
                f"Rename one of the files."
            );
        }
        seen_imports[entry.component_import] = entry.file_path;
    }
}

impl resolve_route_exports(module_path: Path) -> tuple[((str | None), (str | None))] {
    import from jaclang { JacRuntime as Jac }
    program = Jac.program;
    if program is None {
        return (None, None);
    }
    try {
        mod = program.compile(str(module_path.resolve()));
    } except Exception {
        return (None, None);
    }
    if mod is None {
        return (None, None);
    }
    manifest = mod.gen.client_manifest;
    page_name = manifest.page_export if manifest else None;
    layout_name = manifest.layout_export if manifest else None;
    if page_name is None and layout_name is None {
        (page_name, layout_name) = _route_exports_from_ast(mod);
    }
    return (page_name, layout_name);
}

impl _route_exports_from_ast(mod: any) -> tuple[((str | None), (str | None))] {
    import jaclang.jac0core.unitree as uni;
    page_name: (str | None) = None;
    layout_name: (str | None) = None;
    try {
        abilities = mod.get_all_sub_nodes(uni.Ability);
    } except Exception {
        return (None, None);
    }
    for nd in abilities {
        if nd.is_method or not isinstance(nd.signature, uni.FuncSignature) {
            continue;
        }
        rt = nd.signature.return_type;
        if not isinstance(rt, uni.Name) or nd.name_ref is None {
            continue;
        }
        if rt.value == 'JsxPage' and page_name is None {
            page_name = nd.name_ref.sym_name;
        } elif rt.value == 'JsxLayout' and layout_name is None {
            layout_name = nd.name_ref.sym_name;
        }
    }
    return (page_name, layout_name);
}
