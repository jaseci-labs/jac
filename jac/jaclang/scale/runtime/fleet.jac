import os;
import json;
import logging;
import from pathlib { Path }
import from jaclang.server { sv_client }
import from jaclang.scale.runtime.routing { guard_route_prefix }

glob logger = logging.getLogger(__name__),
     FLEET_ENV: str = "JAC_SV_FLEET",
     ROOT_PREFIX: str = "/",
     SERVICE_KINDS: tuple = ("service", "service-mesh");


obj FleetMember {
    has app: str,
        route: str = "",
        file: str = "",
        is_root: bool = False,
        client: bool = False;

    def to_dict -> dict[str, any] {
        return {
            "app": self.app,
            "route": self.route,
            "file": self.file,
            "root": self.is_root,
            "client": self.client
        };
    }

    static def from_dict(raw: dict[str, any]) -> FleetMember {
        return FleetMember(
            app=str(raw.get("app", "")),
            route=str(raw.get("route", "")),
            file=str(raw.get("file", "")),
            is_root=bool(raw.get("root", False)),
            client=bool(raw.get("client", False))
        );
    }
}


obj FleetSpec {
    has root_app: str = "",
        members: dict[str, FleetMember] = {},
        overrides: dict[str, dict[str, any]] = {};

    def add(member: FleetMember) {
        self.members[member.app] = member;
        if member.is_root {
            self.root_app = member.app;
        }
    }

    def member(app: str) -> FleetMember | None {
        return self.members.get(app);
    }

    def root_member -> FleetMember | None {
        return self.members.get(self.root_app) if self.root_app else None;
    }

    def names -> list[str] {
        return list(self.members.keys());
    }

    def service_names -> list[str] {
        return [
            name
            for (name, member) in self.members.items()
            if not member.is_root
        ];
    }

    def routes -> dict[str, str] {
        return {
            name: member.route
            for (name, member) in self.members.items()
            if not member.is_root
        };
    }

    def files -> dict[str, str] {
        return {
            name: member.file
            for (name, member) in self.members.items()
            if member.file
        };
    }

    def app_config(app: str) -> dict[str, any] {
        return dict(self.overrides.get(app, {}));
    }

    def is_empty -> bool {
        return not self.members;
    }

    def to_dict -> dict[str, any] {
        return {
            "root": self.root_app,
            "members": [m.to_dict() for m in self.members.values()]
        };
    }

    def to_env -> str {
        return json.dumps(self.to_dict(), sort_keys=True);
    }

    static def from_dict(raw: dict[str, any]) -> FleetSpec {
        fleet = FleetSpec();
        members = raw.get("members", []);
        if isinstance(members, list) {
            for item in members {
                if isinstance(item, dict) and item.get("app") {
                    fleet.add(FleetMember.from_dict(item));
                }
            }
        }
        root_name = str(raw.get("root", "") or "");
        if root_name and root_name in fleet.members {
            fleet.root_app = root_name;
            fleet.members[root_name].is_root = True;
        }
        return fleet;
    }

    static def from_env_value(raw: str) -> FleetSpec | None {
        text = (raw or "").strip();
        if not text {
            return None;
        }
        try {
            parsed = json.loads(text);
        } except Exception as e {
            logger.warning(f"Ignoring malformed {FLEET_ENV} ({e})");
            return None;
        }
        if not isinstance(parsed, dict) {
            return None;
        }
        return FleetSpec.from_dict(parsed);
    }
}


def fleet_from_env -> FleetSpec | None {
    return FleetSpec.from_env_value(os.environ.get(FLEET_ENV, ""));
}


def fleet_of(
    routes: dict[str, str],
    root_app: str = "",
    overrides: dict[str, dict[str, any]] | None = None,
    files: dict[str, str] | None = None,
    root_file: str = "main.jac",
    root_route: str = "",
    root_client: bool = False
) -> FleetSpec {
    fleet = FleetSpec();
    known_files = dict(files or {});
    for (app, route) in routes.items() {
        name = str(app);
        fleet.add(
            FleetMember(
                app=name,
                route=str(route) or f"/api/{name}",
                file=str(known_files.get(name) or f"{name}.jac")
            )
        );
    }
    if root_app {
        fleet.add(
            FleetMember(
                app=root_app,
                route=root_route or f"/api/{root_app}",
                file=str(known_files.get(root_app) or root_file),
                is_root=True,
                client=root_client
            )
        );
    }
    for (app, cfg) in (overrides or {}).items() {
        fleet.overrides[str(app)] = dict(cfg) if isinstance(cfg, dict) else {};
    }
    return fleet;
}


def solo_fleet(app_name: str, entry_file: str, client: bool = False) -> FleetSpec {
    fleet = FleetSpec();
    fleet.add(
        FleetMember(
            app=app_name, route="", file=entry_file, is_root=True, client=client
        )
    );
    return fleet;
}


def guard_fleet_routes(fleet: FleetSpec) {
    owners: dict[str, str] = {};
    for (name, member) in fleet.members.items() {
        if member.is_root {
            continue;
        }
        prefix = "/" + member.route.strip("/");
        if prefix == "/" {
            raise ValueError(
                f"service app '{name}' has an empty route; set [apps.{name}] route"
            );
        }
        guard_route_prefix(name, prefix);
        if prefix in owners {
            raise ValueError(
                f"apps '{owners[prefix]}' and '{name}' both resolve to route "
                f"'{prefix}'; every service app needs a distinct route"
            );
        }
        owners[prefix] = name;
    }
}


def format_fleet_lines(fleet: FleetSpec) -> list[str] {
    lines: list[str] = [];
    root_member = fleet.root_member();
    if root_member is not None {
        lines.append(f"{root_member.app} -> / (gateway host)");
    }
    for name in fleet.service_names() {
        lines.append(f"{name} -> {fleet.members[name].route}");
    }
    return lines;
}


def order_by_edges(names: list[str], edges: list[tuple[str, str]]) -> list[str] {
    providers_of: dict[str, set[str]] = {name: set() for name in names};
    for (consumer, provider) in edges {
        if consumer in providers_of
            and provider in providers_of
            and consumer != provider {
            providers_of[consumer].add(provider);
        }
    }
    placed: list[str] = [];
    done: set[str] = set();
    while len(placed) < len(names) {
        ready = [
            name
            for name in names
            if name not in done and providers_of[name] <= done
        ];
        if not ready {
            rest = [
                name
                for name in names
                if name not in done
            ];
            logger.warning(
                f"app dependency cycle among {rest}; booting them in declaration order"
            );
            placed.extend(rest);
            break;
        }
        placed.append(ready[0]);
        done.add(ready[0]);
    }
    return placed;
}


def _dedup_edges(edges: list[tuple[str, str]]) -> list[tuple[str, str]] {
    seen: set[tuple[str, str]] = set();
    out: list[tuple[str, str]] = [];
    for app_edge in edges {
        if app_edge not in seen {
            seen.add(app_edge);
            out.append(app_edge);
        }
    }
    return out;
}


def _compiled_app_edges(
    entry_path: str, app_name: str, app_kind: str, project_root: str
) -> list[tuple[str, str]] {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.driver.schedules { get_boundary_analysis_sched }
    prog = JacProgram();
    prog.compile(
        entry_path,
        options=CompileOptions(
            no_cgen=True,
            target_app=app_name,
            app_kind=app_kind,
            project_root=project_root
        )
    );
    if prog.errors_had {
        first = prog.errors_had[0];
        raise ValueError(
            f"app '{app_name}' entry '{entry_path}' does not compile: {first}"
        );
    }
    edges: list[tuple[str, str]] = [];
    seen: set[int] = set();
    while True {
        fresh: list[any] = [];
        for hub in list(prog._search_hubs()) {
            for mod in list(hub.values()) {
                if id(mod) not in seen {
                    seen.add(id(mod));
                    fresh.append(mod);
                }
            }
        }
        if not fresh {
            break;
        }
        for mod in fresh {
            if not (mod and mod.gen) {
                continue;
            }
            man = mod.gen.interop_manifest;
            if man is None {
                continue;
            }
            if not man.app_edges and not (man.walker_access or man.func_access) {
                try {
                    prog.run_schedule(mod, get_boundary_analysis_sched());
                    man = mod.gen.interop_manifest;
                } except Exception {
                    continue;
                }
                if man is None {
                    continue;
                }
            }
            for (consumer, provider) in list(man.app_edges) {
                edges.append((str(consumer), str(provider)));
            }
        }
    }
    return edges;
}


def consumer_provider_edges(
    config: any, project_root: str, apps: list, entries: dict[str, str] | None = None
) -> list[tuple[str, str]] {
    names: set[str] = {a.name for a in apps};
    edges: list[tuple[str, str]] = [];
    for app in apps {
        for provider in sv_client.get_consumer_providers(app.name) {
            if provider in names {
                edges.append((app.name, provider));
            }
        }
    }
    if edges {
        return _dedup_edges(edges);
    }
    known = dict(entries or {});
    for app in apps {
        entry_path = known.get(app.name) or app.entry_path(project_root);
        if not entry_path or not os.path.isfile(entry_path) {
            continue;
        }
        try {
            kind = config.resolved_kind(app) if config is not None else app.kind;
            for (consumer, provider) in _compiled_app_edges(
                entry_path, app.name, kind, project_root
            ) {
                if (consumer == app.name or not consumer) and provider in names {
                    edges.append((app.name, provider));
                }
            }
        } except ValueError {
            raise;
        } except Exception as e {
            logger.warning(
                f"could not read app edges for '{app.name}' ({type(e).__name__}: "
                f"{e}); booting it in declaration order"
            );
        }
    }
    return _dedup_edges(edges);
}


def _member_file(entry_path: str, relative_to: str) -> str {
    if not relative_to {
        return os.path.abspath(entry_path);
    }
    base = Path(relative_to).resolve();
    try {
        return Path(entry_path).resolve().relative_to(base).as_posix();
    } except ValueError {
        raise ValueError(
            f"entry '{entry_path}' resolves outside the deployed tree '{base}', "
            "so the bundle cannot ship it. Deploy from the project root."
        );
    }
}


def _has_client(config: any, app: any) -> bool {
    import from jaclang.project.kinds { kind_has_client }
    kind = config.resolved_kind(app) if config is not None else app.kind;
    return kind_has_client(kind);
}


def _build_fleet(
    config: any,
    project_root: str,
    served: any,
    services: list,
    entries: dict[str, str],
    relative_to: str
) -> FleetSpec {
    import from jaclang.scale.config.config_loader { app_scale_overrides }
    by_name: dict[str, any] = {a.name: a for a in services};
    by_name[served.name] = served;
    ordered = order_by_edges(
        [a.name for a in services] + [served.name],
        consumer_provider_edges(config, project_root, services + [served], entries)
    );
    fleet = FleetSpec();
    for name in ordered {
        app = by_name[name];
        entry_path = entries.get(name) or app.entry_path(project_root);
        try {
            file = _member_file(entry_path, relative_to) if entry_path else "";
        } except ValueError as e {
            raise ValueError(f"app '{name}': {e}");
        }
        if name == served.name {
            fleet.add(
                FleetMember(
                    app=name,
                    route=served.effective_route(),
                    file=file,
                    is_root=True,
                    client=_has_client(config, served)
                )
            );
        } else {
            fleet.add(FleetMember(app=name, route=app.effective_route(), file=file));
        }
        fleet.overrides[name] = app_scale_overrides(config, name);
    }
    guard_fleet_routes(fleet);
    return fleet;
}


def service_apps_of(config: any, served: any) -> list {
    return [
        a
        for a in config.serving_apps()
        if config.resolved_kind(a) in SERVICE_KINDS and a.name != served.name
    ];
}


def fleet_from_config(
    config: any, served_app: str = "", project_root: str = "", relative_to: str = ""
) -> FleetSpec {
    root_dir = project_root
        or (str(config.project_root) if config.project_root else os.getcwd());
    served = config.resolve_app(served_app);
    return _build_fleet(
        config, root_dir, served, service_apps_of(config, served), {}, relative_to
    );
}


def fleet_from_plans(
    config: any, project_root: str, served: any, members: list
) -> FleetSpec {
    served_app = config.resolve_app(served.app);
    entries: dict[str, str] = {};
    if served.entry_path {
        entries[served_app.name] = served.entry_path;
    }
    services: list = [];
    for plan in members {
        app = config.app(plan.app);
        if app is None {
            raise ValueError(f"fleet member '{plan.app}' is not an app in jac.toml");
        }
        services.append(app);
        if plan.entry_path {
            entries[app.name] = plan.entry_path;
        }
    }
    return _build_fleet(config, project_root, served_app, services, entries, "");
}


def fleet_member_names(project_dir: str = "") -> list[str] {
    from_env = fleet_from_env();
    if from_env is not None {
        return from_env.names();
    }
    try {
        import from jaclang.project.config { get_config, get_config_for_dir }
        cfg = get_config_for_dir(project_dir) if project_dir else get_config();
        if cfg is None or not cfg.apps {
            return [];
        }
        return fleet_from_config(cfg).names();
    } except Exception {
        return [];
    }
}
