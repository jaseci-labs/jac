import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.ecmascript.framework_backend { FrameworkBackend }
import from jaclang.jac0core.diagnostics { E5081 }

glob _BACKENDS: dict[str, FrameworkBackend] = {};

def resolve_framework_backend(framework: str) -> FrameworkBackend {
    backend = _BACKENDS.get(framework);
    if backend is not None {
        return backend;
    }
    if framework == "react" {
        import from jaclang.compiler.passes.ecmascript.backends.react { ReactBackend }
        backend = ReactBackend();
        _BACKENDS["react"] = backend;
        return backend;
    }
    if framework == "preact" {
        import from jaclang.compiler.passes.ecmascript.backends.preact { PreactBackend }
        backend = PreactBackend();
        _BACKENDS["preact"] = backend;
        return backend;
    }
    if framework == "solid" {
        import from jaclang.compiler.passes.ecmascript.backends.solid { SolidBackend }
        backend = SolidBackend();
        _BACKENDS["solid"] = backend;
        return backend;
    }
    if framework == "bun" {
        import from jaclang.compiler.passes.ecmascript.backends.bun { BunBackend }
        backend = BunBackend();
        _BACKENDS["bun"] = backend;
        return backend;
    }
    raise ValueError(f"[{E5081.code}] {E5081.format_message(framework=framework)}");
}

def resolve_module_backend(module: (uni.Module | None) = None) -> FrameworkBackend {
    import from jaclang.jac0core.host { framework_for_module, framework_for_host_kind }
    fw = "react";
    if module is not None {
        fw = framework_for_module(module);
    } else {
        try {
            import from jaclang.project.config { get_config }
            import from jaclang.runtimelib.client.npm_provider {
                resolve_client_target_name
            }
            cfg = get_config();
            if cfg is not None {
                import from jaclang.jac0core.host {
                    host_kind_for_target,
                    framework_for_host_kind
                }
                target = resolve_client_target_name(cfg);
                fw = framework_for_host_kind(host_kind_for_target(target));
            }
        } except Exception {
            fw = "react";
        }
    }
    return resolve_framework_backend(fw);
}
