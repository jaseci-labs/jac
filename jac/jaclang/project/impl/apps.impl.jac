impl _norm_path(path: str) -> str {
    return os.path.normcase(os.path.realpath(path));
}

impl AppConfig.entry_path(project_root: str) -> str {
    import from jaclang.project.app_kinds { kind_entry }
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
    import from jaclang.compiler.driver.modresolver { resolve_local_module }
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
    import from jaclang.project.app_kinds { kind_ui }
    return kind_ui(self.kind);
}

impl AppConfig.contains(project_root: str, abs_path: str) -> bool {
    return _norm_path(abs_path) == _norm_path(self.entry_path(project_root));
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

impl parse_apps(project_data: dict, apps_data: dict) -> dict[str, AppConfig] {
    import from jaclang.project.app_kinds { KIND_SPECS }
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
        kind = str(fields.get("kind", "")).strip();
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
        if not entry_point {
            raise ValueError(f"[apps.{name}] requires an explicit entry-point module");
        }
        validate_entry_point(entry_point);
        platform = str(fields.get("platform", "")).strip();
        route = str(fields.get("route", "")).strip();
        if route and not route.startswith("/") {
            raise ValueError(f"[apps.{name}] route='{route}' must start with '/'");
        }
        apps[name] = AppConfig(
            name=name,
            kind=kind,
            entry_point=entry_point,
            platform=platform,
            route=route,
            overlays=overlays
        );
    }
    entries: dict[str, str] = {};
    for app in apps.values() {
        identity = app.entry_point;
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
