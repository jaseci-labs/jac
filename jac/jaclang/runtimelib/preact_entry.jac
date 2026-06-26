"""Shared builder for the Preact mount-and-wrap entry script.

Mirrors `react_entry.jac` but uses Preact's `render`/`h` instead of
`react-dom/client`'s `createRoot`.
"""

def build_simple_preact_entry_script(
    entry_module: str, install_global_handlers: bool = True
) -> str {
    runtime_imports: list[str] = ['JacClientErrorBoundary', 'ErrorFallback'];
    if install_global_handlers {
        runtime_imports.append('__jacInstallErrorHandlers');
    }
    runtime_imports.append('__jacReactErrorHandler');

    lines: list[str] = [
        'import { render, h } from "preact";',
        f'import {{ app as App }} from "./{entry_module}.js";',
        f'import {{ {", ".join(runtime_imports)} }} from "@jac/runtime";',
        ''
    ];
    if install_global_handlers {
        lines.append('__jacInstallErrorHandlers();');
    }
    lines.extend(
        [
            'const __jacMountEl = document.getElementById("root")',
            '\t?? document.getElementById("__jac_root");',
            'render(',
            '\th(',
            '\t\tJacClientErrorBoundary,',
            '\t\t{ FallbackComponent: ErrorFallback, onError: __jacReactErrorHandler },',
            '\t\th(App, null)',
            '\t),',
            '\t__jacMountEl',
            ');',
            ''
        ]
    );
    return "\n".join(lines);
}
