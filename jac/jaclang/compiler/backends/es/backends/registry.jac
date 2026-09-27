import from jaclang.compiler.backends.es.framework_backend { FrameworkBackend }
import from jaclang.compiler.frontend.diagnostics { E5081 }

glob _BACKENDS: dict[str, FrameworkBackend] = {};

def resolve_framework_backend(framework: str) -> FrameworkBackend {
    backend = _BACKENDS.get(framework);
    if backend is not None {
        return backend;
    }
    if framework == "react" {
        import from jaclang.compiler.backends.es.backends.react { ReactBackend }
        backend = ReactBackend();
        _BACKENDS["react"] = backend;
        return backend;
    }
    if framework == "preact" {
        import from jaclang.compiler.backends.es.backends.preact { PreactBackend }
        backend = PreactBackend();
        _BACKENDS["preact"] = backend;
        return backend;
    }
    if framework == "solid" {
        import from jaclang.compiler.backends.es.backends.solid { SolidBackend }
        backend = SolidBackend();
        _BACKENDS["solid"] = backend;
        return backend;
    }
    raise ValueError(f"[{E5081.code}] {E5081.format_message(framework=framework)}");
}

def active_framework -> str {
    import from jaclang.compiler.frontend.host { active_host }
    defaults = active_host().project_defaults();
    return defaults.client_framework if defaults is not None else "react";
}

def resolve_active_backend -> FrameworkBackend {
    return resolve_framework_backend(active_framework());
}
