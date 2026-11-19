impl _norm_path(path: str) -> str {
    return os.path.normcase(os.path.realpath(path));
}

impl AppConfig.entry_path(project_root: str) -> str {
    return resolve_entry_path(self.entry_point or kind_entry(self.kind), project_root);
}

impl validate_entry_point(module: str) -> str {
    if not isinstance(module, str)
        or not module
        or module.endswith(('.jac', '.py'))
        or not all(part.isidentifier() for part in module.split('.')) {
        raise ValueError(
            f"Invalid entry-point '{module}': expected a dotted module name "
            'such as "core.social_graph" or "desktop.main", without a file extension or path separators'
        );
    }
    return module;
}

impl resolve_entry_path(module: str, project_root: str) -> str {
    validate_entry_point(module);
    base = os.path.abspath(project_root);
    parts = module.split('.');
    candidate = resolve_local_module(base, parts);
    if candidate is not None and candidate[1] in ('jac', 'py') {
        return os.path.abspath(candidate[0]);
    }

    return os.path.join(base, *parts) + '.jac';
}

impl AppConfig.effective_route -> str {
    return self.route or f"/api/{self.name}";
}

impl AppConfig.ui -> str {
    return kind_ui(self.kind);
}

impl AppConfig.contains(project_root: str, abs_path: str) -> bool {
    return _norm_path(abs_path) == _norm_path(self.entry_path(project_root));
}

impl _desktop_overlay(
    fields: dict[str, any], overlays: dict[str, any], arch_app: any
) -> None {
    desktop: dict[str, any] = dict(overlays.get("desktop") or {});
    raw_profiles = fields.get("profiles");
    profiles = [str(p) for p in raw_profiles]
        if isinstance(raw_profiles, list) and raw_profiles
        else ["default"];
    remote = overlays.get("remote") if isinstance(overlays.get("remote"), dict) else {};
    remote_url = str(next(iter(remote.values()), "") or "") if remote else "";
    backends: dict[str, str] = {};
    for profile in profiles {
        runs = arch_app.arrangements.get(profile);
        if runs is None {
            continue;
        }
        embedded = any(
            [
                arch_app.hosts.get(space, "") in ("native", "cpython", "node")
                for space in runs
            ]
        );
        if embedded {
            backends[profile] = "embedded";
        } elif remote_url {
            backends[profile] = remote_url;
        }
    }
    if "backend" not in desktop and "backends" not in desktop {
        if len(backends) > 1 {
            desktop["backends"] = backends;
            desktop.setdefault("default_backend", profiles[0]);
        } elif backends {
            desktop["backend"] = next(iter(backends.values()));
        }
    }
    if fields.get("local_users") is True {
        desktop.setdefault("profiles", True);
    }
    for key in ("name", "identifier", "version") {
        value = fields.get(key);
        if isinstance(value, str) and value and key not in desktop {
            desktop[key] = value;
        }
    }
    window = overlays.get("window");
    if isinstance(window, dict) and "window" not in desktop {
        desktop["window"] = dict(window);
    }
    if desktop {
        overlays["desktop"] = desktop;
    }
}

impl app_npm_tree(raw_config: dict[str, any], app: AppConfig) -> str {
    trees = raw_config.get("npm");
    if not isinstance(trees, dict) or not trees {
        return "";
    }
    spaces_raw = raw_config.get("spaces");
    for space in app.spaces {
        table = spaces_raw.get(space) if isinstance(spaces_raw, dict) else None;
        tree = table.get("npm") if isinstance(table, dict) else None;
        if isinstance(tree, str) and tree in trees {
            return tree;
        }
    }
    if len(trees) == 1 {
        return str(next(iter(trees.keys())));
    }
    return "";
}

impl has_spaces_block(root_dir: str) -> bool {
    arch = os.path.join(root_dir, "archwire.jac");
    if not os.path.isfile(arch) {
        return False;
    }
    try {
        with open(arch, encoding="utf-8") as fh {
            return re.search(r"\bgraph\s+spaces\b", fh.read()) is not None;
        }
    } except OSError {
        return False;
    }
}

impl validate_app_name(name: str) -> None {
    if not name or not name.strip() {
        raise ValueError("[apps] has an app with an empty name");
    }
    if "/" in name or "\\" in name {
        raise ValueError(f"[apps.{name}] app names cannot contain path separators");
    }
    if name.endswith(".jac") {
        raise ValueError(f"[apps.{name}] app names cannot end in '.jac'");
    }
}

impl parse_apps(
    project_data: dict[str, any],
    apps_data: dict[str, any],
    derived: dict[str, DerivedApp] | None = None
) -> dict[str, AppConfig] {
    from_arch = derived or {};
    if not isinstance(apps_data, dict) {
        raise ValueError("[apps] must be a table of [apps.<name>] tables");
    }
    project = project_data if isinstance(project_data, dict) else {};
    for key in ("kind", "entry-point", "entry_point") {
        if key in project {
            raise ValueError(
                f"[project] {key} cannot be set alongside [apps]; "
                f"declare it on the app instead: [apps.<name>] {key}"
            );
        }
    }
    apps: dict[str, AppConfig] = {};
    for (raw_name, table) in apps_data.items() {
        name = str(raw_name);
        validate_app_name(name);
        if not isinstance(table, dict) {
            raise ValueError(f"[apps.{name}] must be a table");
        }
        fields: dict[str, any] = {};
        overlays: dict[str, any] = {};
        for (key, value) in table.items() {
            if isinstance(value, dict) {
                overlays[str(key)] = value;
                continue;
            }
            attr = str(key).replace("-", "_");
            if attr in REMOVED_APP_KEYS {
                raise ValueError(
                    f"[apps.{name}] '{key}' was removed: {REMOVED_APP_KEYS[attr]}"
                );
            }
            if attr not in APP_TABLE_KEYS {
                allowed = ", ".join([k.replace("_", "-") for k in APP_TABLE_KEYS]);
                raise ValueError(
                    f"[apps.{name}] has unknown key '{key}'; expected one of {allowed}"
                );
            }
            fields[attr] = value;
        }
        arch_app = from_arch.get(name);
        if arch_app is not None {
            placement = overlays.setdefault("placement", {});
            pins = dict(arch_app.pins);
            pins.update(placement.get("pins", {}));
            placement["pins"] = pins;
            if arch_app.kind == "desktop" {
                _desktop_overlay(fields, overlays, arch_app);
            }
        }
        kind = str(fields.get("kind", "")).strip();
        if not kind and arch_app is not None {
            kind = arch_app.kind;
        }
        if not kind {
            raise ValueError(f"[apps.{name}] is missing the required key 'kind'");
        }
        if kind not in KIND_SPECS {
            raise ValueError(
                f"[apps.{name}] kind='{kind}' is not one of "
                f"{', '.join(KIND_SPECS.keys())}"
            );
        }
        entry_point = str(fields.get("entry_point", "")).strip();
        if not entry_point and arch_app is not None {
            entry_point = arch_app.entry_point;
        }
        if not entry_point {
            raise ValueError(f"[apps.{name}] requires an explicit entry-point module");
        }
        validate_entry_point(entry_point);
        platform = str(fields.get("platform", "")).strip();
        route = str(fields.get("route", "")).strip();
        if route and not route.startswith("/") {
            raise ValueError(f"[apps.{name}] route='{route}' must start with '/'");
        }
        raw_profiles = fields.get("profiles", []);
        apps[name] = AppConfig(
            name=name,
            kind=kind,
            entry_point=entry_point,
            platform=platform,
            route=route,
            title=str(fields.get("name", "")).strip(),
            identifier=str(fields.get("identifier", "")).strip(),
            version=str(fields.get("version", "")).strip(),
            profiles=[str(x) for x in raw_profiles]
                if isinstance(raw_profiles, list)
                else [],
            local_users=fields.get("local_users") is True,
            spaces=list(arch_app.runs) + list(arch_app.serves)
                if arch_app is not None
                else [],
            overlays=overlays
        );
    }
    for (name, arch_app) in from_arch.items() {
        if name in apps {
            continue;
        }
        apps[name] = AppConfig(
            name=name,
            kind=arch_app.kind,
            entry_point=arch_app.entry_point,
            spaces=list(arch_app.runs) + list(arch_app.serves),
            overlays={"placement": {"pins": dict(arch_app.pins)}}
        );
    }
    if from_arch {
        ordered: dict[str, AppConfig] = {};
        for name in from_arch.keys() {
            if name in apps {
                ordered[name] = apps[name];
            }
        }
        for (name, app) in apps.items() {
            ordered.setdefault(name, app);
        }
        apps = ordered;
    }
    entries: dict[str, str] = {};
    for app in apps.values() {
        identity = app.entry_point;
        if identity in entries
            and app.name in from_arch
            and entries[identity] in from_arch {
            continue;
        }
        if identity in entries {
            raise ValueError(
                f"[apps.{app.name}] entry-point already declared by '{entries[
                    identity
                ]}'"
            );
        }
        entries[identity] = app.name;
    }
    claimed: dict[str, str] = {};
    for app in apps.values() {
        if not KIND_SPECS[app.kind].has_server {
            continue;
        }
        effective = app.effective_route();
        if effective in claimed {
            raise ValueError(
                f"[apps] route '{effective}' is claimed by both "
                f"'{claimed[effective]}' and '{app.name}'"
            );
        }
        claimed[effective] = app.name;
    }
    default_app = str(
        project.get("default-app", project.get("default_app", "")) or ""
    ).strip();
    if default_app and default_app not in apps {
        raise ValueError(
            f"[project] default-app='{default_app}' is not an app; apps: "
            f"{', '.join(apps.keys())}"
        );
    }
    return apps;
}

impl implicit_app(config: any) -> AppConfig {
    project = config.project;
    return AppConfig(
        name=str(project.name or "").strip() or "main",
        kind=str(project.kind or "").strip(),
        entry_point=str(project.entry_point or "").strip(),
        implicit=True
    );
}
