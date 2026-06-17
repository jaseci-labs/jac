"""Shared builder for the Solid mount entry script.

Mirrors `react_entry.jac` / `preact_entry.jac` but uses Solid's `render` from
`solid-js/web` with the hyperscript factory `h` from `solid-js/h`. Solid's
`render` takes a thunk returning the component tree, matching the once-run
component model. The exported `app` is wrapped in `JacClientErrorBoundary` (the
Solid shim's React-shaped API over `solid-js`'s `ErrorBoundary`), matching the
React/Preact simple entries.
"""

def build_simple_solid_entry_script(
    entry_module: str, install_global_handlers: bool = True
) -> str {
    runtime_imports: list[str] = ['JacClientErrorBoundary', 'ErrorFallback'];
    if install_global_handlers {
        runtime_imports.append('__jacInstallErrorHandlers');
    }
    runtime_imports.append('__jacReactErrorHandler');

    lines: list[str] = [
        'import { render } from "solid-js/web";',
        'import h from "solid-js/h";',
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
            '\t() => h(JacClientErrorBoundary, { FallbackComponent: ErrorFallback, onError: __jacReactErrorHandler }, h(App, {})),',
            '\t__jacMountEl',
            ');',
            ''
        ]
    );
    return "\n".join(lines);
}

"""Build the file-based-routing entry script for Solid.

The Solid analogue of `build_pages_react_entry_script`: it consumes the same
framework-neutral `./_routes.js` manifest (`routes` / `layouts`) and assembles an
equivalent `<Router><Routes>...` tree, but through the Solid runtime shim's
adapters (`Router`/`Routes`/`Route`/`AuthGuard` from `@jac/runtime`, which bridge
`@solidjs/router`) and Solid's `solid-js/web` `render` + `solid-js/h` hyperscript
factory — so the bundle resolves **no** React-ecosystem package. Element creation
uses `h(C, {})` in place of React's `React.createElement(C, null)`; the route
shape (`{ path, element }`) and auth-guard/layout/app-wrapper wiring mirror the
React builder one-for-one.

Known gaps (best-effort, pending browser e2e):
`@solidjs/router` expects `<Route>` as a direct child of `<Router>` and has no
`<Outlet>`, so the passthrough `Routes` and the `AuthGuard`→`Outlet` nesting cover
the flat case but deeply nested matching / true layout outlets need a running
Solid build to validate.
"""
def build_pages_solid_entry_script(
    entry_module: str, auth_redirect: str, has_app_wrapper: bool
) -> str {
    lines: list[str] = [
        'import { render } from "solid-js/web";',
        'import h from "solid-js/h";',
        'import { Router, Routes, Route, AuthGuard, JacClientErrorBoundary, ErrorFallback, __jacInstallErrorHandlers, __jacReactErrorHandler } from "@jac/runtime";',
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
            '\t\th(Route, { path: r.path, element: h(r.element, {}) })',
            '\t);',
            '}',
            ''
        ]
    );
    # AuthGuard is a runtime function compiled with a plain `redirect` parameter
    # (not props destructuring), so wrap it in a component that passes the redirect
    # string directly — identical to the React builder.
    lines.extend(
        [
            f'function _AuthGuardRoute() {{ return AuthGuard("{auth_redirect}"); }}',
            'const authGuardElement = h(_AuthGuardRoute, {});',
            '',
            'function App() {',
            '\tconst routeChildren = [',
            '\t\t...renderRoutes(publicRoutes),',
            '\t\th(Route, { element: authGuardElement },',
            '\t\t\t...renderRoutes(authRoutes)',
            '\t\t),',
            '\t];',
            '',
            '\tconst routeTree = RootLayout',
            '\t\t? h(Route, { element: h(RootLayout, {}) }, ...routeChildren)',
            '\t\t: routeChildren;',
            '',
            '\treturn h(Router, {},',
            '\t\th(Routes, {},',
            '\t\t\t...(Array.isArray(routeTree) ? routeTree : [routeTree])',
            '\t\t)',
            '\t);',
            '}',
            ''
        ]
    );
    if has_app_wrapper {
        lines.append('const appElement = h(AppWrapper, {}, h(App, {}));');
    } else {
        lines.append('const appElement = h(App, {});');
    }
    lines.extend(
        [
            '',
            'const __jacMountEl = document.getElementById("root")',
            '\t?? document.getElementById("__jac_root");',
            'render(',
            '\t() => h(JacClientErrorBoundary, { FallbackComponent: ErrorFallback, onError: __jacReactErrorHandler }, appElement),',
            '\t__jacMountEl',
            ');',
            ''
        ]
    );
    return "\n".join(lines);
}
