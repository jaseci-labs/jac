import type from jaclang.compiler.backends.es.framework_backend { FrameworkBackend }

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

glob WASM_HOST_MODULE: str = "@jac/wasm_host";

def injected_virtual_modules(backend: FrameworkBackend) -> list[str] {
    return [backend.runtime_module(), WASM_HOST_MODULE];
}

def runtime_import_source(name: str, backend: (FrameworkBackend | None) = None) -> str {
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

def backend_jsx_factory_name(backend: (FrameworkBackend | None) = None) -> str {
    if backend is not None {
        name = backend.jsx_factory_name();
        if isinstance(name, str) and name {
            return name;
        }
    }
    return "__jacJsx";
}

def _required_runtime_globals(
    backend: (FrameworkBackend | None) = None
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

def with_runtime_globals(
    js_code: str, backend: (FrameworkBackend | None) = None
) -> str {
    import from jaclang.compiler.backends.es.free_ident_audit {
        js_identifiers,
        js_top_level_declarations
    }
    (names, src) = _required_runtime_globals(backend);
    referenced = set(js_identifiers(js_code));
    declared = js_top_level_declarations(js_code);
    missing: list[str] = [];
    for name in names {
        if name in referenced and name not in declared {
            missing.append(name);
        }
    }
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
    import from jaclang.compiler.backends.es.backends.registry {
        resolve_active_backend
    }
    return with_runtime_globals(js_code, resolve_active_backend());
}
