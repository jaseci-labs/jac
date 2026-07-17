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
