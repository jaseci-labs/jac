import os;

def client_runtime_cl_basename(framework: str = "", module: any = None) -> str {
    import from jaclang.compiler.passes.ecmascript.backends.registry {
        resolve_framework_backend,
        resolve_module_backend
    }
    backend = resolve_framework_backend(framework)
        if framework
        else resolve_module_backend(module);
    return backend.runtime_source_basename();
}

def resolve_client_runtime_cl_path(framework: str = "", module: any = None) -> str {
    import jaclang.runtimelib as _runtimelib;
    runtime_dir = os.path.dirname(_runtimelib.__file__);
    return os.path.join(runtime_dir, client_runtime_cl_basename(framework, module));
}
