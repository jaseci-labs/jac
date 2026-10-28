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
