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
    raise ValueError(f"[{E5081.code}] {E5081.format_message(framework=framework)}");
}

def resolve_active_backend -> FrameworkBackend {
    import from jaclang.project.config { get_config }
    cfg = get_config();
    fw = cfg.client.framework if (cfg and cfg.client) else "react";
    return resolve_framework_backend(fw);
}
