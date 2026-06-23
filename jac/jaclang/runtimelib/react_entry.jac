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

"""Build the file-based-routing entry script for React.

Unlike `build_simple_react_entry_script` (which mounts a single exported `app`),
this assembles a `<BrowserRouter><Routes>...` tree from the generated
`./_routes.js` manifest — `routes` (an array of `{path, element, auth}`) and
`layouts` (a prefix→component map). Public routes mount directly; `auth: true`
routes mount under an `AuthGuard` that redirects unauthenticated visits to
`auth_redirect`. A root layout (`layouts["/"]`) wraps everything when present, and
the entry module's top-level `app` export wraps the router when `has_app_wrapper`.

Preact rides this same builder unchanged — its Vite config aliases `react` /
`react-dom` / `react-router-dom` onto `preact/compat`, so `createRoot` and friends
resolve through compat at bundle time.
"""
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
    # AuthGuard uses the props-destructure
    # Must use React.createElement with a props object to pass the redirect prop
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
