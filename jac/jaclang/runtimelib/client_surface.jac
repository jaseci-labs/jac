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

def prepend_symbol_names(backend: (object | None) = None) -> list[str] {
    if backend is not None {
        names = backend.required_globals();
        if isinstance(names, list) and names {
            return names;
        }
    }
    return [
        sym.name
        for sym in _REACT_RUNTIME_SURFACE
        if sym.prepend
    ];
}

def runtime_module_source(backend: (object | None) = None) -> str {
    if backend is not None {
        src = backend.runtime_module();
        if isinstance(src, str) and src {
            return src;
        }
    }
    return "@jac/runtime";
}

def _runtime_import_line(names: list[str], backend: (object | None) = None) -> str {
    src = runtime_module_source(backend);
    return 'import {' + ", ".join(names) + '} from "' + src + '";';
}

def prepended_runtime_import(backend: (object | None) = None) -> str {
    return _runtime_import_line(prepend_symbol_names(backend), backend);
}

def with_runtime_globals(js_code: str, backend: (object | None) = None) -> str {
    names = [
        name
        for name in prepend_symbol_names(backend)
        if f"function {name}(" not in js_code
    ];
    if not names {
        return js_code;
    }
    line = _runtime_import_line(names, backend);
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
