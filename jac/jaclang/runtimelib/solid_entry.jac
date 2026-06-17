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
framework-neutral `./_routes.js` manifest (`routes` / `layouts`) but assembles the
route tree against `@solidjs/router` **natively** — there is no `<Routes>`, routes
are `<Route>` children of `<Router>` directly, each uses `component={Page}` (not
`element={<Page/>}`), a pathless `component={AuthGuard}` route groups the protected
routes (Solid passes the matched child in as `props.children`), and a root layout
rides `<Router root={Layout}>`. Mounting is Solid's `solid-js/web` `render` +
`solid-js/h` hyperscript (`h(C, {})` in place of `React.createElement(C, null)`),
so the bundle resolves **no** React-ecosystem package. The app-wrapper and error
boundary wiring mirror the React builder.
"""
def build_pages_solid_entry_script(
    entry_module: str, auth_redirect: str, has_app_wrapper: bool
) -> str {
    lines: list[str] = [
        'import { render } from "solid-js/web";',
        'import h from "solid-js/h";',
        'import { Router, Route, AuthGuard, __jacMakeLayoutRoot, JacClientErrorBoundary, ErrorFallback, __jacInstallErrorHandlers, __jacReactErrorHandler } from "@jac/runtime";',
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
            '// `@solidjs/router` takes <Route> children directly (no <Routes>) and a',
            '// `component` (not a prebuilt `element`); page components then receive',
            '// nested/auth route content as `props.children`.',
            'function renderRoutes(routeList) {',
            '\treturn routeList.map(r =>',
            '\t\th(Route, { path: r.path, component: r.element })',
            '\t);',
            '}',
            ''
        ]
    );
    # The protected routes nest under a pathless `component={_AuthGuardRoute}`
    # route; `@solidjs/router` hands the matched child to that component as
    # `props.children`, which `AuthGuard` renders when authenticated (else it
    # redirects). The root layout, when present, rides the router's `root` prop.
    lines.extend(
        [
            f'function _AuthGuardRoute(props) {{ return AuthGuard({{ redirect: "{auth_redirect}", children: props.children }}); }}',
            '',
            'const routeChildren = [',
            '\t...renderRoutes(publicRoutes),',
            '\th(Route, { component: _AuthGuardRoute },',
            '\t\t...renderRoutes(authRoutes)',
            '\t),',
            '];',
            '',
            'const routerProps = RootLayout ? { root: __jacMakeLayoutRoot(RootLayout) } : {};',
            '',
            'function App() {',
            '\treturn h(Router, routerProps, ...routeChildren);',
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
