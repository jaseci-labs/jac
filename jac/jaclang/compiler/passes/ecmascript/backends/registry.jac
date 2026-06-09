"""Backend registry — resolves framework name to FrameworkBackend instance."""

import from jaclang.compiler.passes.ecmascript.framework_backend { FrameworkBackend }
import from jaclang.jac0core.diagnostics { E5081 }

# Lazily populated so the compiler can import this module during its own
# bootstrap without triggering compilation of concrete backends.
glob _BACKENDS: dict[str, FrameworkBackend] = {};

"""Return a FrameworkBackend for `framework`, or raise E5081 if unknown."""
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
    raise E5081.format_message(framework=framework);
}
