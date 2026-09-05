import os;
import from pathlib { Path }

glob PAGES_DIR_NAME: str = "pages",
     MODULE_ROLE_SUFFIXES: list[str] = ['.impl.', '.test.'],
     ROUTE_RETURN_TYPE_NAMES: list[str] = ['JsxPage', 'JsxLayout'];

def pages_dir_in(project_root: Path) -> Path {
    return Path(project_root) / PAGES_DIR_NAME;
}

def has_pages_dir(project_root: Path) -> bool {
    pages = pages_dir_in(project_root);
    return pages.exists() and pages.is_dir();
}

def route_module_candidates(pages_dir: Path) -> list[Path] {
    try {
        return [
            f
            for f in sorted(Path(pages_dir).rglob('*.jac'))
            if not any(suffix in f.name for suffix in MODULE_ROLE_SUFFIXES)
        ];
    } except OSError {
        return [];
    }
}

def declares_route(module_path: Path) -> bool {
    import jaclang.compiler.frontend.unitree as uni;
    import from jaclang.compiler.frontend.parser { parse as parse_jac }

    try {
        source = Path(module_path).read_text(encoding='utf-8');
        (mod, _had_errors) = parse_jac(source, str(module_path));
    } except Exception {
        return False;
    }
    for nd in mod.get_all_sub_nodes(uni.Ability) {
        if nd.is_method or not isinstance(nd.signature, uni.FuncSignature) {
            continue;
        }
        rt = nd.signature.return_type;
        if isinstance(rt, uni.Name) and rt.value in ROUTE_RETURN_TYPE_NAMES {
            return True;
        }
    }
    return False;
}

def has_route_modules(project_root: Path) -> bool {
    for f in route_module_candidates(pages_dir_in(project_root)) {
        if declares_route(f) {
            return True;
        }
    }
    return False;
}

def is_pages_routing_entry(mod_path: str) -> bool {
    if not mod_path {
        return False;
    }
    try {
        import from jaclang.project.config { get_config_for_dir }
        cfg = get_config_for_dir(os.path.dirname(os.path.abspath(mod_path)));
    } except ImportError {
        return False;
    }
    if not cfg or cfg.project_root is None {
        return False;
    }
    proj_root = Path(str(cfg.project_root));
    entry_point = cfg.project.entry_point or "main.jac";
    try {
        if Path(mod_path).resolve() != (proj_root / entry_point).resolve() {
            return False;
        }
    } except OSError {
        return False;
    }
    return has_pages_dir(proj_root) and has_route_modules(proj_root);
}
