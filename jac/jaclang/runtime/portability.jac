glob PY_STDLIB_BY_KIND: dict[str, (set[str] | None)] = {
         "web-app": set(),
         "web-static": set(),
         "mobile": set(),
         "desktop": set(),
         "js-package": set()
     },
     CLIENT_KINDS: tuple[str, ...] = (
         "web-app",
         "web-static",
         "mobile",
         "desktop",
         "js-package"
     );

def py_root_module(name: str) -> str;

def supports(module: str, space: str, kind: str) -> bool;

def client_supports_py_module(name: str, kind: str = "web-app") -> bool;

def native_supports_py_module(name: str) -> bool;
