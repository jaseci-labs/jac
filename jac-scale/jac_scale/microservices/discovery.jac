import jaclang.jac0core.unitree as uni;
import from pathlib { Path }
import from jaclang.jac0core.parser { parse }
import from jac_scale.microservices.setup { derive_prefix }

glob _SV_PREFIX_TOK: str = "KW_SERVER";


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
    services: set[str] = set();

    for jac_file in sorted(root_dir.glob("*.jac")) {
        try {
            text = jac_file.read_text(encoding="utf-8");
        } except Exception {
            continue;
        }
        markers = scan_markers(text, str(jac_file));
        if markers is None {
            continue;
        }
        for target in markers.sv_import_targets {
            services.add(target);
        }
        if markers.is_service {
            services.add(jac_file.stem);
        }
    }

    services.discard(entry_stem);

    routes: dict[str, str] = {};
    for name in sorted(services) {
        routes[name] = derive_prefix(name);
    }
    return routes;
}
