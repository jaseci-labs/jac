import from jaclang.jac0core.codeinfo { NATIVE_SUPPORTED_STDLIB }

glob CLIENT_SUPPORTED_PY_STDLIB: set[str] = set();

def py_root_module(name: str) -> str {
    return name.split('.')[0] if name else name;
}

def client_supports_py_module(name: str) -> bool {
    return py_root_module(name) in CLIENT_SUPPORTED_PY_STDLIB;
}

def native_supports_py_module(name: str) -> bool {
    return py_root_module(name) in NATIVE_SUPPORTED_STDLIB;
}
