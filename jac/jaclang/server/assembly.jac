import os;
import from jaclang.cli.console { console }
import type from jaclang.runtime.prepared { PreparedApplication }


def service_apps(cfg: any, served: any) -> list {
    return [
        a
        for a in cfg.serving_apps()
        if a.kind in ("service", "service-mesh") and a.name != served.name
    ];
}

def gateway_colocates(cfg: any) -> bool {
    scale_cfg = cfg.get_plugin_config("scale") or {};
    gateway = scale_cfg.get("gateway", {}) if isinstance(scale_cfg, dict) else {};
    return not (isinstance(gateway, dict) and gateway.get("colocate") is False);
}

def colocate_services(
    cfg: any, served: any, base: str, application: PreparedApplication | None = None
) -> None {
    if cfg is None or served is None or os.environ.get("JAC_SV_SIBLING") == "1" {
        return;
    }
    services = service_apps(cfg, served);
    if not services {
        return;
    }
    import from jaclang.runtime.prepared { load_prepared_module }
    import from jaclang.server.sv_client { register_local }

    project_root = str(cfg.project_root) if cfg.project_root else base;
    for svc in services {
        prepared = next(
            (
                child
                for child in application.applications
                if child.name == svc.name
            ),
            None
        )
            if application is not None
            else None;
        entry_file = prepared.entry
            if prepared is not None
            else svc.entry_path(project_root);
        if not entry_file or not os.path.isfile(entry_file) {
            console.warning(
                f"Service app '{svc.name}' has no entry_file file; not colocated."
            );
            continue;
        }
        module = load_prepared_module(entry_file);
        register_local(svc.name, module);
        console.print(
            f"  ✔ colocated service '{svc.name}' "
            f"({os.path.relpath(entry_file, project_root)})",
            style="muted"
        );
    }
}


def assemble_served_program(
    cfg: any, served: any, base: str, application: PreparedApplication | None = None
) {
    colocate_services(cfg, served, base, application);
    if served is not None {
        import from jaclang.server.sv_client { set_consumer_app }
        set_consumer_app(served.name);
    }
}
