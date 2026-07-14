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

def build_pages_react_entry_script(
    entry_module: str, auth_redirect: str, has_app_wrapper: bool
) -> str {
    lines: list[str] = [
        'import React from "react";',
        'import { createRoot } from "react-dom/client";',
        'import { BrowserRouter, Routes, Route } from "react-router-dom";',
        'import { JacClientErrorBoundary, ErrorFallback, AuthGuard, __jacInstallErrorHandlers, __jacReactErrorHandler } from "@jac/runtime";',
        'import { routes, layouts } from "./_routes.js";'
    ];
    if has_app_wrapper {
        lines.append(f'import {{ app as AppWrapper }} from "./{entry_module}.js";');
    }
    lines.extend(
        [
            '',
            '__jacInstallErrorHandlers();',
            '',
            'const publicRoutes = routes.filter(r => !r.auth);',
            'const authRoutes = routes.filter(r => r.auth);',
            'const RootLayout = layouts["/"] || null;',
            '',
            'function renderRoutes(routeList) {',
            '\treturn routeList.map(r =>',
            '\t\tReact.createElement(Route, { key: r.path, path: r.path, element: React.createElement(r.element, null) })',
            '\t);',
            '}',
            ''
        ]
    );

    lines.extend(
        [
            f'function _AuthGuardRoute() {{ return AuthGuard("{auth_redirect}"); }}',
            'const authGuardElement = React.createElement(_AuthGuardRoute, null);',
            '',
            'function App() {',
            '\tconst routeChildren = [',
            '\t\t...renderRoutes(publicRoutes),',
            '\t\tReact.createElement(Route, { key: "__auth", element: authGuardElement },',
            '\t\t\t...renderRoutes(authRoutes)',
            '\t\t),',
            '\t];',
            '',
            '\tconst routeTree = RootLayout',
            '\t\t? React.createElement(Route, { element: React.createElement(RootLayout, null) }, ...routeChildren)',
            '\t\t: routeChildren;',
            '',
            '\treturn React.createElement(BrowserRouter, null,',
            '\t\tReact.createElement(Routes, null,',
            '\t\t\t...(Array.isArray(routeTree) ? routeTree : [routeTree])',
            '\t\t)',
            '\t);',
            '}',
            ''
        ]
    );
    if has_app_wrapper {
        lines.append(
            'const appElement = React.createElement(AppWrapper, null, React.createElement(App, null));'
        );
    } else {
        lines.append('const appElement = React.createElement(App, null);');
    }
    lines.extend(
        [
            '',
            'const root = createRoot(document.getElementById("root"));',
            'root.render(',
            '\tReact.createElement(JacClientErrorBoundary, { FallbackComponent: ErrorFallback, onError: __jacReactErrorHandler }, appElement)',
            ');',
            ''
        ]
    );
    return "\n".join(lines);
}
