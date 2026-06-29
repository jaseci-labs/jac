import os;
import jaclang.jac0core.unitree as uni;
import from pathlib { Path }
import from jaclang.jac0core.parser { parse }
import from jaclang.jac0core.modresolver { find_jac_project_root }
import from jac_scale.runtime.discovery.route_policy {
    derive_route_prefix,
    guard_route_name
}

glob _SV_PREFIX_TOK: str = "KW_SERVER",
     _PRUNE_DIRS: set[str] = {
         "node_modules",
         "__pycache__",
         "dist",
         "build",
         "venv",
         ".venv",
         "site-packages"
     };


obj ModuleMarkers {
    has sv_import_targets: list[str],
        is_service: bool;
}


def scan_markers(text: str, file_path: str) -> ModuleMarkers | None {
    try {
        (mod, _had_error) = parse(text, file_path=file_path);
    } except Exception {
        return None;
    }
    if mod is None {
        return None;
    }
    targets: list[str] = [];
    for imp in mod.get_all_sub_nodes(uni.Import) {
        first = imp.kid[0] if imp.kid else None;
        is_sv = (
            (first is not None)
            and (first?.name == _SV_PREFIX_TOK)
            and (imp.from_loc is not None)
        );
        if is_sv {
            name = imp.from_loc.base_module_name;
            if name {
                targets.append(name);
            }
        }
    }
    is_service = len(mod.get_all_sub_nodes(uni.ServerBlock)) > 0;
    return ModuleMarkers(sv_import_targets=targets, is_service=is_service);
}


def should_enter_local_ms(
    enabled: bool | None, is_sv_sibling: bool, scale_flag: bool, has_services: bool
) -> bool {
    if is_sv_sibling or scale_flag or (enabled is False) {
        return False;
    }
    if enabled is True {
        return True;
    }
    return has_services;
}


def discover_sv_services(entry_file: str) -> dict[str, str] {
    entry_path = Path(entry_file);
    if entry_path.is_dir() {
        root_dir = entry_path;
        entry_stem: str = "";
    } else {
        root_dir = entry_path.parent;
        entry_stem: str = entry_path.stem;
    }
    if not root_dir.is_dir() {
        return {};
    }

    project_root = find_jac_project_root(str(entry_path));
    scan_root = Path(project_root) if project_root else root_dir;
    scan_root_str = str(scan_root);

    services: set[str] = set();

    for (cur_root, dirnames, filenames) in os.walk(scan_root_str) {
        kept: list[str] = [];
        for d in dirnames {
            if d.startswith(".") or (d in _PRUNE_DIRS) {
                continue;
            }
            if os.path.isfile(os.path.join(cur_root, d, "jac.toml")) {
                continue;
            }
            kept.append(d);
        }
        dirnames.clear();
        for d in sorted(kept) {
            dirnames.append(d);
        }
        for fn in sorted(filenames) {
            if not fn.endswith(".jac") {
                continue;
            }
            jac_path = os.path.join(cur_root, fn);
            try {
                text = Path(jac_path).read_text(encoding="utf-8");
            } except Exception {
                continue;
            }
            markers = scan_markers(text, jac_path);
            if markers is None {
                continue;
            }
            for target in markers.sv_import_targets {
                services.add(target);
            }
            if markers.is_service {
                services.add(Path(jac_path).stem);
            }
        }
    }

    services.discard(entry_stem);

    routes: dict[str, str] = {};
    for name in sorted(services) {
        guard_route_name(name);

        routes[name] = derive_route_prefix(name);
    }
    return routes;
}


def resolve_routes(entry_file: str, explicit_routes: dict[str, str]) -> dict[str, str] {
    merged: dict[str, str] = dict(discover_sv_services(entry_file));
    merged.update(explicit_routes);
    return merged;
}
