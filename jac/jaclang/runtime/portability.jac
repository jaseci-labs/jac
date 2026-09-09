import from jaclang.compiler.frontend.codeinfo { NATIVE_SUPPORTED_STDLIB }

glob PY_STDLIB_BY_KIND: dict[str, (set[str] | None)] = {
         "web-app": set(),
         "web-static": set(),
         "mobile": set(),
         "desktop": set(),
         "js-package": set()
     },
     CLIENT_KINDS: tuple = ("web-app", "web-static", "mobile", "desktop", "js-package");

def py_root_module(name: str) -> str {
    return name.split('.')[0] if name else name;
}

def supports(module: str, space: str, kind: str) -> bool {
    if space == 'server' {
        return True;
    }
    if space == 'native' {
        return native_supports_py_module(module);
    }
    allowed = PY_STDLIB_BY_KIND.get(kind, set());
    if allowed is None {
        return True;
    }
    return py_root_module(module) in allowed;
}

def client_supports_py_module(name: str, kind: str = "web-app") -> bool {
    return supports(name, 'client', kind);
}

def native_supports_py_module(name: str) -> bool {
    return py_root_module(name) in NATIVE_SUPPORTED_STDLIB;
}
