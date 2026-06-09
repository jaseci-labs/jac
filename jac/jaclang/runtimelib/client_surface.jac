"""Single source of truth for how the compiler imports `@jac/runtime` symbols.

`@jac/runtime` is the virtual module backed by the canonical client runtime at
`jaclang/runtimelib/client_runtime.cl.jac` (React-backed). Two pieces derive
from here so the rule lives in one place:

  * the ECMAScript pass asks `runtime_import_source` where each emitted runtime
    symbol is imported from (`@jac/runtime`, or `react` for primitives taken
    straight from React like `useRef`);
  * the `eject` and HMR bundle paths build their prepended JSX-runtime import
    from `prepended_runtime_import`.
"""

"""A `@jac/runtime` symbol that needs special compiler handling.

`source` is the module the compiler imports the symbol from - `@jac/runtime` for
everything the runtime backs, `react` for primitives (e.g. `useRef`) taken
straight from React. `prepend` marks the bare global identifiers the compiler
emits without an explicit import node; the bundle paths prepend a single import
statement covering them.
"""
obj RuntimeSymbol {
    has name: str,
        source: str = "@jac/runtime",
        prepend: bool = False;
}

glob CLIENT_RUNTIME_SURFACE: list[RuntimeSymbol] = [
         # JSX factory + walker spawn - emitted as bare globals, prepended as a
         # single bundle import.
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
    for sym in CLIENT_RUNTIME_SURFACE {
        if sym.name == name {
            return sym;
        }
    }
    return None;
}

"""Module the compiler imports `name` from.

Returns the declared source (`@jac/runtime`, or `react` for React primitives).
Undeclared names fall back to `@jac/runtime` - the historical default - so an
unforeseen emission never breaks a build.
"""
def runtime_import_source(name: str) -> str {
    sym = runtime_symbol(name);
    if sym is not None {
        return sym.source;
    }
    return "@jac/runtime";
}

"""The single import statement the bundle paths prepend for the bare global
identifiers the compiler emits (`__jacJsx`, `__jacSpawn`)."""
def prepended_runtime_import -> str {
    names = [
        sym.name
        for sym in CLIENT_RUNTIME_SURFACE
        if sym.prepend
    ];
    return 'import {' + ", ".join(names) + '} from "@jac/runtime";';
}

"""Prepend the runtime-global import to a compiled-JS module.

`JacProgram(...).gen.js` emits the `prepend` globals (`__jacJsx`, `__jacSpawn`)
as bare free identifiers; every path that assembles runnable JS from that output
-- the jac2js build, `eject`, HMR, and the cl test harness -- must add the one
covering import. This is that single operation, so the rule cannot drift between
them (e.g. emitting a `__jacSpawn` spawn without the import). Skips the runtime
module itself, which defines the globals, and is idempotent.
"""
def with_runtime_globals(js_code: str) -> str {
    # The runtime module defines these globals; importing them there is circular.
    if "function __jacJsx(" in js_code {
        return js_code;
    }
    line = prepended_runtime_import();
    if line in js_code {
        return js_code;
    }
    return line + '\n' + js_code;
}
