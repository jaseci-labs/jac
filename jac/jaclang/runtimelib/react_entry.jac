"""Shared builder for the React mount-and-wrap entry script.

A Jac client app's bundle is a per-module `<name>.js` that *exports* an `app`
component but never renders it. A separate entry script imports `app`, wraps
it in `JacClientErrorBoundary`, calls `createRoot`, and mounts at `#root`.
That script is generated from at least three places (eject, HMR, the
ViteCompiler), so the canonical body lives here — every coordinated change
to the boundary wiring (e.g. adding `onError`) only touches one location.
"""

"""Build the entry script that mounts an exported `app` under
`JacClientErrorBoundary`.

Args:
    entry_module: Module basename (no extension) whose `app` export to mount.
    install_global_handlers: Emit `__jacInstallErrorHandlers()`. Pass False
        from HMR re-mounts where the handlers were installed by the initial
        bundle and still bound to `window`.
"""
def build_simple_react_entry_script(
    entry_module: str, install_global_handlers: bool = True
) -> str {
    runtime_imports: list[str] = ['JacClientErrorBoundary', 'ErrorFallback'];
    if install_global_handlers {
        runtime_imports.append('__jacInstallErrorHandlers');
    }
    runtime_imports.append('__jacReactErrorHandler');

    lines: list[str] = [
        'import React from "react";',
        'import { createRoot } from "react-dom/client";',
        f'import {{ app as App }} from "./{entry_module}.js";',
        f'import {{ {", ".join(runtime_imports)} }} from "@jac/runtime";',
        ''
    ];
    if install_global_handlers {
        lines.append('__jacInstallErrorHandlers();');
    }
    lines.extend(
        [
            'const root = createRoot(document.getElementById("root"));',
            'root.render(',
            '\tReact.createElement(',
            '\t\tJacClientErrorBoundary,',
            '\t\t{ FallbackComponent: ErrorFallback, onError: __jacReactErrorHandler },',
            '\t\tReact.createElement(App, null)',
            '\t)',
            ');',
            ''
        ]
    );
    return "\n".join(lines);
}
