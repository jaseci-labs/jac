"""Shared builder for the Solid mount entry script.

Mirrors `react_entry.jac` / `preact_entry.jac` but uses Solid's `render` from
`solid-js/web` with the hyperscript factory `h` from `solid-js/h`. Solid's
`render` takes a thunk returning the component tree, matching the once-run
component model.

v1 mounts the app directly. The React-flavored `JacClientErrorBoundary` wrapper
used on the React/Preact entries is not applied here — error-boundary parity for
Solid (`ErrorBoundary` from `solid-js`) is a documented follow-up. Global error
handlers are still installed when requested.
"""

def build_simple_solid_entry_script(
    entry_module: str, install_global_handlers: bool = True
) -> str {
    lines: list[str] = [
        'import { render } from "solid-js/web";',
        'import h from "solid-js/h";',
        f'import {{ app as App }} from "./{entry_module}.js";'
    ];
    if install_global_handlers {
        lines.append('import { __jacInstallErrorHandlers } from "@jac/runtime";');
    }
    lines.append('');
    if install_global_handlers {
        lines.append('__jacInstallErrorHandlers();');
    }
    lines.extend(
        [
            'const __jacMountEl = document.getElementById("root")',
            '\t?? document.getElementById("__jac_root");',
            'render(() => h(App, {}), __jacMountEl);',
            ''
        ]
    );
    return "\n".join(lines);
}
