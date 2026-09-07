import os;

glob JAC_VIRTUAL_MODULE_SOURCES: dict[str, str] = {
         "mobui": "client_mobui",
         "pwa": "pwa_runtime",
         "wasm_host": "wasm_host",
         "webgl": "webgl"
     };

def jac_virtual_module_basenames(module_name: str) -> list[str] {
    source = JAC_VIRTUAL_MODULE_SOURCES.get(module_name);
    if source is None or source == module_name {
        return [module_name];
    }
    return [source, module_name];
}

def client_runtime_cl_basename(framework: str = "") -> str {
    import from jaclang.compiler.backends.es.backends.registry {
        resolve_framework_backend,
        resolve_active_backend
    }
    backend = resolve_framework_backend(framework)
        if framework
        else resolve_active_backend();
    return backend.runtime_source_basename();
}

def resolve_client_runtime_cl_path(framework: str = "") -> str {
    import jaclang.client as _client_pkg;
    runtime_dir = os.path.dirname(str(_client_pkg.__file__));
    return os.path.join(runtime_dir, client_runtime_cl_basename(framework));
}
