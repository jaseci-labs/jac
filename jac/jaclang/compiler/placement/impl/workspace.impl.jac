impl AppSpec.effective_route -> str {
    return self.route or f"/api/{self.name}";
}

impl WorkspaceSpec.app(name: str) -> (AppSpec | None) {
    return self.apps.get(name);
}

impl WorkspaceSpec.app_for_path(abs_path: str) -> (AppSpec | None) {
    if not abs_path {
        return None;
    }
    resolved = _real(abs_path);
    for app in self.apps.values() {
        if resolved == _real(app.`entry) {
            return app;
        }
    }
    return None;
}

impl WorkspaceSpec.serving_apps -> list[AppSpec] {
    return [
        a
        for a in self.apps.values()
        if a.has_server
    ];
}

impl WorkspaceSpec.module_dot_path(abs_path: str) -> str {
    if not abs_path {
        return '';
    }
    real = os.path.realpath(os.path.abspath(abs_path));
    rel = os.path.relpath(real, os.path.realpath(self.project_root));
    if rel.startswith('..') {
        rel = os.path.basename(real);
    }
    if rel.endswith('.jac') {
        rel = rel[:-4];
    }
    return rel.replace(os.sep, '.');
}

impl _real(path: str) -> str {
    return os.path.normcase(os.path.realpath(os.path.abspath(path)));
}

impl _read_toml(toml_path: str) -> dict {
    import tomllib;
    try {
        with open(toml_path, 'rb') as f {
            doc = tomllib.load(f);
        }
    } except Exception {
        return {};
    }
    return doc if isinstance(doc, dict) else {};
}

impl _table(raw: any, *keys: str) -> dict {
    cur = raw;
    for key in keys {
        if not isinstance(cur, dict) {
            return {};
        }
        cur = cur.get(key, {});
    }
    return cur if isinstance(cur, dict) else {};
}

impl _pins_of(raw: any) -> dict[str, str] {
    pins: dict[str, str] = {};
    if isinstance(raw, dict) {
        for (key, value) in raw.items() {
            pins[str(key)] = str(value);
        }
    }
    return pins;
}

impl _npm_names_of(raw: any) -> set[str] {
    names: set[str] = set();
    if not isinstance(raw, dict) {
        return names;
    }
    for k in raw {
        key = str(k);
        if key == 'dev' {
            continue;
        }
        names.add(key);
    }
    dev = raw.get('dev', {});
    if isinstance(dev, dict) {
        for k in dev {
            names.add(str(k));
        }
    }
    return names;
}

impl _chain_stamp(root_dir: str) -> tuple {
    stamps: list[float] = [];
    cur: (str | None) = root_dir;
    seen: set[str] = set();
    while cur {
        key = _real(cur);
        if key in seen {
            break;
        }
        seen.add(key);
        try {
            stamps.append(os.path.getmtime(os.path.join(cur, 'jac.toml')));
        } except OSError {
            stamps.append(-1.0);
        }
        parent = os.path.dirname(os.path.realpath(cur));
        if not parent or parent == os.path.realpath(cur) {
            break;
        }
        cur = find_jac_project_root(parent);
    }
    return tuple(stamps);
}

impl _implicit_kind(root_dir: str, project: dict) -> str {
    kind = str(project.get('kind', '') or '');
    if kind {
        return kind;
    }
    parent = os.path.dirname(os.path.realpath(root_dir));
    if not parent or parent == os.path.realpath(root_dir) {
        return '';
    }
    outer = workspace_for_path(parent);
    if outer is None or outer.explicit {
        return '';
    }
    outer_app = outer.apps.get(outer.default_app);
    return outer_app.kind if outer_app is not None else '';
}

impl _build_workspace(root_dir: str, toml_path: str, doc: dict) -> WorkspaceSpec {
    project = _table(doc, 'project');
    apps_raw = doc.get('apps', {});
    explicit = isinstance(apps_raw, dict) and len(apps_raw) > 0;
    base_pins = _pins_of(_table(doc, 'placement', 'pins'));
    base_npm = _npm_names_of(_table(doc, 'dependencies', 'npm'));
    apps: dict[str, AppSpec] = {};
    if explicit {
        import from jaclang.project.apps { parse_apps }
        declarations = parse_apps(project, apps_raw);
        entries: dict[str, str] = {};
        for (name, declaration) in declarations.items() {
            entry_abs = _real(declaration.entry_path(root_dir));
            if entry_abs in entries {
                raise ValueError(
                    f"Apps '{name}' and '{entries[
                        entry_abs
                    ]}' declare the same entry-point"
                );
            }
            entries[entry_abs] = name;
            raw = declaration.overlays;
            pins = dict(base_pins);
            pins.update(_pins_of(_table(raw, 'placement', 'pins')));
            npm = set(base_npm) | _npm_names_of(_table(raw, 'dependencies', 'npm'));
            apps[name] = AppSpec(
                name=name,
                kind=declaration.kind,
                `entry=entry_abs,
                ui=kind_ui(declaration.kind),
                platform=declaration.platform,
                route=declaration.route,
                pins=pins,
                npm_names=npm,
                has_server=kind_has_server(declaration.kind),
                codespace=kind_codespace(declaration.kind)
            );
        }
    } else {
        name = str(project.get('name', '') or 'main');
        kind = _implicit_kind(root_dir, project);
        import from jaclang.project.apps { resolve_entry_path }
        entry_module = str(project.get('entry-point', '') or '');
        apps[name] = AppSpec(
            name=name,
            kind=kind,
            `entry=resolve_entry_path(entry_module or kind_entry(kind), root_dir),
            ui=kind_ui(kind),
            pins=dict(base_pins),
            npm_names=set(base_npm),
            has_server=kind_has_server(kind),
            codespace=kind_codespace(kind),
            implicit=True
        );
    }
    default_app = str(
        project.get('default-app', '') or project.get('default_app', '') or ''
    );
    if not default_app and len(apps) == 1 {
        default_app = next(iter(apps));
    }
    h = hashlib.sha256();
    h.update(
        json.dumps(
            [explicit, default_app, [app_fact_digest(a) for a in apps.values()]],
            sort_keys=True
        ).encode()
    );
    return WorkspaceSpec(
        project_root=root_dir,
        toml_path=toml_path,
        apps=apps,
        default_app=default_app,
        explicit=explicit,
        digest=h.hexdigest()[:12],
        base_pins=base_pins,
        base_npm_names=base_npm
    );
}

impl workspace_for_path(path: str) -> (WorkspaceSpec | None) {
    if not path {
        return None;
    }
    root_dir = find_jac_project_root(path);
    if not root_dir {
        return None;
    }
    toml_path = os.path.join(root_dir, 'jac.toml');
    stamp = _chain_stamp(root_dir);
    key = _real(root_dir);
    cached = _ws_cache.get(key);
    if cached is not None and cached[0] == stamp {
        return cached[1];
    }
    ws = _build_workspace(root_dir, toml_path, _read_toml(toml_path));
    _ws_cache[key] = (stamp, ws);
    return ws;
}

impl app_for_path(path: str) -> (AppSpec | None) {
    ws = workspace_for_path(path);
    return ws.app_for_path(path) if ws is not None else None;
}

impl app_fact_digest(app: (AppSpec | None)) -> str {
    if app is None {
        return '';
    }
    anchor = os.path.dirname(app.`entry) if app.`entry else '';
    ws_root = (find_jac_project_root(anchor) if anchor else None) or '';

    def _rel(path: str, base: str) -> str {
        if not path {
            return '';
        }
        if base {
            try {
                return os.path.relpath(path, base).replace(os.sep, '/');
            } except ValueError {}
        }
        return os.path.normpath(path).replace(os.sep, '/');
    }
    h = hashlib.sha256();
    h.update(
        json.dumps(
            [
                app.name,
                app.kind,
                _rel(app.`entry, ws_root),
                app.effective_route(),
                app.platform,
                sorted(app.pins.items()),
                sorted(app.npm_names)
            ]
        ).encode()
    );
    return h.hexdigest()[:12];
}

impl serving_apps(ws: WorkspaceSpec) -> list[AppSpec] {
    return ws.serving_apps();
}
