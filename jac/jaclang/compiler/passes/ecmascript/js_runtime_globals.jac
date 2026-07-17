glob _DEFAULT_PREPEND_NAMES: list[str] = ["__jacJsx", "__jacSpawn"],
     _DEFAULT_RUNTIME_MODULE: str = "@jac/runtime";

def with_runtime_globals(js_code: str, backend: (object | None) = None) -> str {
    names = _DEFAULT_PREPEND_NAMES;
    src = _DEFAULT_RUNTIME_MODULE;
    if backend is not None {
        bg_names = backend.required_globals();
        bg_src = backend.runtime_module();
        if isinstance(bg_names, list)
        and bg_names
        and isinstance(bg_src, str)
        and bg_src {
            names = bg_names;
            src = bg_src;
        }
    }
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

def finalize_js_for_emission(js_code: str) -> str {
    stripped = js_code.strip();
    if not stripped {
        return js_code;
    }
    import from jaclang.compiler.passes.ecmascript.backends.registry {
        resolve_active_backend
    }
    return with_runtime_globals(js_code, resolve_active_backend());
}
