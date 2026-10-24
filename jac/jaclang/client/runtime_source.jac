import os;

glob JAC_VIRTUAL_MODULE_SOURCES: dict[str, str] = {
         "mobui": "client_mobui",
         "pwa": "pwa_runtime",
         "wasm_host": "wasm_host",
         "webgl": "webgl"
     };

def jac_virtual_module_basenames(module_name: str) -> list[str];

def client_runtime_cl_basename(framework: str = "") -> str;

def resolve_client_runtime_cl_path(framework: str = "") -> str;

impl jac_virtual_module_basenames(module_name: str) -> list[str] {
    source = JAC_VIRTUAL_MODULE_SOURCES.get(module_name);
    if source is None or source == module_name {
        return [module_name];
    }
    return [source, module_name];
}

impl client_runtime_cl_basename(framework: str = "") -> str {
    return build_services().client_runtime_basename(framework);
}

impl resolve_client_runtime_cl_path(framework: str = "") -> str {
    runtime_dir = os.path.dirname(str(_client_pkg.__file__));
    return os.path.join(runtime_dir, client_runtime_cl_basename(framework));
}
