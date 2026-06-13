"""Resolve the canonical client runtime `.cl.jac` for the active framework."""

import os;

"""Basename of the client runtime source file for `framework`."""
def client_runtime_cl_basename(framework: str = "") -> str {
    import from jaclang.compiler.passes.ecmascript.backends.registry {
        resolve_framework_backend,
        resolve_active_backend
    }
    backend = resolve_framework_backend(framework)
        if framework
        else resolve_active_backend();
    return backend.runtime_source_basename();
}

"""Absolute path to the client runtime `.cl.jac` for `framework`."""
def resolve_client_runtime_cl_path(framework: str = "") -> str {
    import jaclang.runtimelib as _runtimelib;
    runtime_dir = os.path.dirname(_runtimelib.__file__);
    return os.path.join(runtime_dir, client_runtime_cl_basename(framework));
}
