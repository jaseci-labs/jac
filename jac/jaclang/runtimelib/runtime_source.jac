"""Resolve the canonical client runtime `.cl.jac` for the active framework."""

import os;

"""Basename of the client runtime source file for `framework`."""
def client_runtime_cl_basename(framework: str = "") -> str {
    fw = framework;
    if not fw {
        import from jaclang.project.config { get_config }
        cfg = get_config();
        fw = cfg.client.framework if (cfg and cfg.client) else "react";
    }
    if fw == "preact" {
        return "preact_runtime.cl.jac";
    }
    return "client_runtime.cl.jac";
}

"""Absolute path to the client runtime `.cl.jac` for `framework`."""
def resolve_client_runtime_cl_path(framework: str = "") -> str {
    import jaclang.runtimelib as _runtimelib;
    runtime_dir = os.path.dirname(_runtimelib.__file__);
    return os.path.join(runtime_dir, client_runtime_cl_basename(framework));
}
