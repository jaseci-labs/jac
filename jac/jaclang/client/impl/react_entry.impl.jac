impl build_simple_react_entry_script(
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

impl build_pages_react_entry_script(
    entry_module: str, auth_redirect: str, has_app_wrapper: bool
) -> str {
    lines: list[str] = [
        'import React from "react";',
        'import { createRoot } from "react-dom/client";',
        'import { BrowserRouter, Routes, Route } from "react-router-dom";',
        'import { useParams } from "react-router-dom";',
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
            '// A page whose `page` function takes parameters gets the URL\'s segments as',
            '// its props: `page(id: str)` sees `id`, and `*rest: str` the rest, split.',
            'function JacRouteParams({ C, names, rest }) {',
            '\tconst found = useParams();',
            '\tconst props = {};',
            '\tfor (const name of names) { if (name !== rest) props[name] = found[name]; }',
            '\tif (rest) props[rest] = (found["*"] || "").split("/").filter(Boolean);',
            '\treturn React.createElement(C, props);',
            '}',
            '',
            'function routeElement(r) {',
            '\tif (r.params && r.params.length) {',
            '\t\treturn React.createElement(JacRouteParams, { C: r.element, names: r.params, rest: r.rest || "" });',
            '\t}',
            '\treturn React.createElement(r.element, null);',
            '}',
            '',
            'function renderRoutes(routeList) {',
            '\treturn routeList.map(r =>',
            '\t\tReact.createElement(Route, { key: r.path, path: r.path, element: routeElement(r) })',
            '\t);',
            '}',
            ''
        ]
    );

    lines.extend(
        [
            f'const authGuardElement = React.createElement(AuthGuard, {{ redirect: "{auth_redirect}" }});',
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
