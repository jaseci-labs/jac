"""Single source of truth for how the compiler imports `@jac/runtime` symbols.

`@jac/runtime` is the virtual module backed by the canonical client runtime at
`jaclang/runtimelib/client_runtime.cl.jac` (React-backed). Two pieces derive
from here so the rule lives in one place:

  * the ECMAScript pass asks the active backend where each emitted runtime
    symbol is imported from;
  * the `eject` and HMR bundle paths build their prepended JSX-runtime import
    from `prepended_runtime_import`.
"""

"""A `@jac/runtime` symbol that needs special compiler handling.

`source` is the module the compiler imports the symbol from. `prepend` marks
bare global identifiers the compiler emits without an explicit import node;
the bundle paths prepend a single import statement covering them.
"""
obj RuntimeSymbol {
    has name: str,
        source: str = "@jac/runtime",
        prepend: bool = False;
}

# Static React surface for backward-compatible callers that have no backend.
glob _REACT_RUNTIME_SURFACE: list[RuntimeSymbol] = [
         RuntimeSymbol(name="__jacJsx", prepend=True),
         RuntimeSymbol(name="__jacSpawn", prepend=True),
         # `useRef` is imported straight from `react`, so it never resolves
         # through the runtime: `Ref[T]` fields take it directly from React.
         RuntimeSymbol(name="useRef", source="react"),
         # `forwardRef` is likewise taken straight from `react`: a component that
         # declares a trailing `ref: Ref` param lowers to
         # `forwardRef(function C(props, ref) {...})` so it can *be* a ref target.
         RuntimeSymbol(name="forwardRef", source="react")
     ];

"""The declared symbol for `name`, or `None` if it needs no special handling."""
def runtime_symbol(name: str) -> (RuntimeSymbol | None) {
    for sym in _REACT_RUNTIME_SURFACE {
        if sym.name == name {
            return sym;
        }
    }
    return None;
}

"""Module the compiler imports `name` from.

When `backend` is provided, delegates to the backend's `import_source`. Falls
back to the hard-coded React surface when backend is None.
"""
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

"""JSX factory identifier for `backend`, defaulting to React's `__jacJsx`."""
def backend_jsx_factory_name(backend: (object | None) = None) -> str {
    if backend is not None {
        name = backend.jsx_factory_name();
        if isinstance(name, str) and name {
            return name;
        }
    }
    return "__jacJsx";
}

"""The single import statement bundle paths prepend for bare globals.

When `backend` is provided, uses the backend's `required_globals` and
`runtime_module`. Otherwise falls back to React defaults.
"""
def prepended_runtime_import(backend: (object | None) = None) -> str {
    if backend is not None {
        names = backend.required_globals();
        src = backend.runtime_module();
        if (isinstance(names, list) and names and isinstance(src, str) and src) {
            return 'import {' + ", ".join(names) + '} from "' + src + '";';
        }
    }
    names = [
        sym.name
        for sym in _REACT_RUNTIME_SURFACE
        if sym.prepend
    ];
    return 'import {' + ", ".join(names) + '} from "@jac/runtime";';
}

"""Prepend the runtime-global import to a compiled-JS module.

When `backend` is provided, uses the backend's requirements. Otherwise falls
back to React defaults. Skips the runtime module itself, which defines the
globals, and is idempotent.
"""
def with_runtime_globals(js_code: str, backend: (object | None) = None) -> str {
    # The runtime module defines the JSX factory; importing it there is circular.
    # Detect the factory function signature so any backend's runtime is recognised.
    factory_name = backend_jsx_factory_name(backend);
    if f"function {factory_name}(" in js_code {
        return js_code;
    }
    line = prepended_runtime_import(backend);
    if line in js_code {
        return js_code;
    }
    return line + '\n' + js_code;
}

"""Resolve the active backend and prepend its runtime-global import.

Shared by `JacToJSCompiler.add_runtime_imports`, eject, HMR, and the cl test
harness so runtime-import behavior stays in one place.
"""
def prepend_active_runtime_globals(js_code: str) -> str {
    import from jaclang.compiler.passes.ecmascript.backends.registry {
        resolve_active_backend
    }
    return with_runtime_globals(js_code, resolve_active_backend());
}
