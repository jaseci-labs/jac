impl AppSpec.effective_route -> str {
    return self.route or f"/api/{self.name}";
}

impl AppSpec.contains(abs_path: str) -> bool {
    if not abs_path {
        return False;
    }
    real = _real(abs_path);
    if self.file_rooted {
        return bool(self.`entry) and real == _real(self.`entry);
    }
    if not self.root_dir {
        return False;
    }
    root_dir = _real(self.root_dir);
    return real == root_dir or real.startswith(root_dir + os.sep);
}

impl AppSpec.claims_module(mod_dot: str) -> bool {
    if not mod_dot {
        return False;
    }
    for (pattern, space) in self.own_pins.items() {
        if space != 'server' {
            continue;
        }
        if fnmatch.fnmatchcase(mod_dot, pattern) or pattern.startswith(mod_dot + '.') {
            return True;
        }
    }
    return False;
}

impl WorkspaceSpec.app(name: str) -> (AppSpec | None) {
    return self.apps.get(name);
}

impl WorkspaceSpec.app_for_path(abs_path: str) -> (AppSpec | None) {
    if not abs_path {
        return None;
    }
    best: (AppSpec | None) = None;
    best_len = -1;
    for app in self.apps.values() {
        if not app.contains(abs_path) {
            continue;
        }
        if app.file_rooted {
            return app;
        }
        depth = len(_real(app.root_dir));
        if depth > best_len {
            best = app;
            best_len = depth;
        }
    }
    return best;
}

impl WorkspaceSpec.owner_app_for_path(abs_path: str) -> tuple[(AppSpec | None), bool] {
    app = self.app_for_path(abs_path);
    if app is not None {
        return (app, False);
    }
    mod_dot = self.module_dot_path(abs_path);
    claimers = [
        a
        for a in self.apps.values()
        if a.claims_module(mod_dot)
    ];
    if len(claimers) == 1 {
        return (claimers[0], False);
    }
    if len(claimers) > 1 {
        return (None, True);
    }
    serving = self.serving_apps();
    if len(serving) == 1 {
        return (serving[0], False);
    }
    import from jaclang.compiler.placement.ownership { consumer_graph }
    (consumers, _) = consumer_graph(self);
    users = consumers.get(_real(abs_path), set());
    if len(users) == 1 {
        return (self.apps[next(iter(users))], False);
    }
    default_app = self.apps.get(self.default_app) if self.default_app else None;
    if default_app is not None and default_app.has_server {
        return (default_app, False);
    }
    return (None, len(serving) > 1);
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

impl kind_codespace(kind: str) -> str {
    return KIND_CODESPACE.get(kind, '');
}

impl kind_has_server(kind: str) -> bool {
    return kind == '' or kind in KIND_HAS_SERVER;
}

impl kind_entry(kind: str) -> str {
    return KIND_ENTRY.get(kind, DEFAULT_ENTRY);
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
        for (raw_name, raw) in apps_raw.items() {
            if not isinstance(raw, dict) {
                continue;
            }
            name = str(raw_name);
            kind = str(raw.get('kind', '') or '');
            rel = str(raw.get('path', '') or '');
            entry_rel = str(
                raw.get('entry-point', '') or raw.get('entry_point', '') or ''
            );
            file_rooted = rel == '' and entry_rel != '';
            app_root = ''
                if file_rooted
                else os.path.normpath(os.path.join(root_dir, rel));
            entry_abs = os.path.normpath(
                os.path.join(root_dir, rel, entry_rel or kind_entry(kind))
            );
            own_pins = _pins_of(_table(raw, 'placement', 'pins'));
            pins = dict(base_pins);
            pins.update(own_pins);
            npm = set(base_npm) | _npm_names_of(_table(raw, 'dependencies', 'npm'));
            apps[name] = AppSpec(
                name=name,
                kind=kind,
                root_dir=app_root,
                `entry=entry_abs,
                file_rooted=file_rooted,
                ui=kind_ui(kind),
                platform=str(raw.get('platform', '') or ''),
                route=str(raw.get('route', '') or ''),
                pins=pins,
                own_pins=own_pins,
                npm_names=npm,
                has_server=kind_has_server(kind),
                codespace=kind_codespace(kind)
            );
        }
    } else {
        name = str(project.get('name', '') or 'main');
        kind = _implicit_kind(root_dir, project);
        entry_rel = str(project.get('entry-point', '') or '');
        apps[name] = AppSpec(
            name=name,
            kind=kind,
            root_dir=root_dir,
            `entry=os.path.normpath(
                os.path.join(root_dir, entry_rel or kind_entry(kind))
            ),
            file_rooted=False,
            ui=kind_ui(kind),
            pins=dict(base_pins),
            own_pins={},
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

impl owner_app_for_path(path: str) -> tuple[(AppSpec | None), bool] {
    ws = workspace_for_path(path);
    if ws is None {
        return (None, False);
    }
    return ws.owner_app_for_path(path);
}

impl app_fact_digest(app: (AppSpec | None)) -> str {
    if app is None {
        return '';
    }
    anchor = app.root_dir or (os.path.dirname(app.`entry) if app.`entry else '');
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
                _rel(app.root_dir, ws_root),
                _rel(app.`entry, app.root_dir or ws_root),
                app.file_rooted,
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
