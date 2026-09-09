import os;
import from jaclang.cli.console { console }


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

def colocate_services(cfg: any, served: any, base: str) -> None {
    if cfg is None or served is None or os.environ.get("JAC_SV_SIBLING") == "1" {
        return;
    }
    services = service_apps(cfg, served);
    if not services {
        return;
    }
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.jac0core.ext_registry { base_stem }
    import from jaclang.server.sv_client { register_local }

    project_root = str(cfg.project_root) if cfg.project_root else base;
    for svc in services {
        entry_file = svc.entry_path(project_root);
        if not entry_file or not os.path.isfile(entry_file) {
            console.warning(
                f"Service app '{svc.name}' has no entry_file file; not colocated."
            );
            continue;
        }
        (svc_base, svc_file) = os.path.split(entry_file);
        loaded = Jac.jac_import(
            target=base_stem(svc_file),
            base_path=svc_base or "./",
            lng=entry_file.split(".")[-1]
        );
        module = loaded[0] if loaded else None;
        if module is None {
            raise RuntimeError(
                f"Service app '{svc.name}' failed to load from {entry_file}"
            );
        }
        register_local(svc.name, module);
        console.print(
            f"  ✔ colocated service '{svc.name}' "
            f"({os.path.relpath(entry_file, project_root)})",
            style="muted"
        );
    }
}


def assemble_served_program(cfg: any, served: any, base: str) {
    colocate_services(cfg, served, base);
    if served is not None {
        import from jaclang.server.sv_client { set_consumer_app }
        set_consumer_app(served.name);
    }
}
