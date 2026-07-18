obj RuntimeSymbol {
    has name: str,
        source: str = "@jac/runtime",
        prepend: bool = False;
}

glob _REACT_RUNTIME_SURFACE: list[RuntimeSymbol] = [
         RuntimeSymbol(name="__jacJsx", prepend=True),
         RuntimeSymbol(name="__jacSpawn", prepend=True),
         RuntimeSymbol(name="useRef", source="react"),
         RuntimeSymbol(name="forwardRef", source="react")
     ];

def runtime_symbol(name: str) -> (RuntimeSymbol | None) {
    for sym in _REACT_RUNTIME_SURFACE {
        if sym.name == name {
            return sym;
        }
    }
    return None;
}

def runtime_import_source(name: str, backend: (object | None) = None) -> str {
    if backend is not None {
        src = backend.import_source(name);
        if isinstance(src, str) and src {
            return src;
        }
    }
    sym = runtime_symbol(name);
    if sym is not None {
        return sym.source;
    }
    return "@jac/runtime";
}

def backend_jsx_factory_name(backend: (object | None) = None) -> str {
    if backend is not None {
        name = backend.jsx_factory_name();
        if isinstance(name, str) and name {
            return name;
        }
    }
    return "__jacJsx";
}

def _required_runtime_globals(
    backend: (object | None) = None
) -> tuple[list[str], str] {
    if backend is not None {
        names = backend.required_globals();
        src = backend.runtime_module();
        if isinstance(names, list) and names and isinstance(src, str) and src {
            return (names, src);
        }
    }
    default_names = [
        sym.name
        for sym in _REACT_RUNTIME_SURFACE
        if sym.prepend
    ];
    return (default_names, "@jac/runtime");
}

def with_runtime_globals(js_code: str, backend: (object | None) = None) -> str {
    (names, src) = _required_runtime_globals(backend);
    missing = [
        name
        for name in names
        if f"function {name}(" not in js_code
    ];
    if not missing {
        return js_code;
    }
    line = 'import {' + ", ".join(missing) + '} from "' + src + '";';
    if line in js_code {
        return js_code;
    }
    return line + '\n' + js_code;
}

def prepend_active_runtime_globals(js_code: str) -> str {
    import from jaclang.compiler.passes.ecmascript.backends.registry {
        resolve_active_backend
    }
    return with_runtime_globals(js_code, resolve_active_backend());
}
