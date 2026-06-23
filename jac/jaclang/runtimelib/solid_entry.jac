"""Shared builder for the Solid mount entry script.

Mirrors `react_entry.jac` / `preact_entry.jac` but mounts with Solid's `render`
from `solid-js/web`. Solid's `render` takes a thunk returning the component tree,
matching the once-run component model. The exported `app` is wrapped in
`JacClientErrorBoundary` (the Solid shim's React-shaped API over `solid-js`'s
`ErrorBoundary`), matching the React/Preact simple entries.

**JSX entry (Branch 3).** Since `SolidBackend` now emits the dom-expressions path,
these bootstraps are written as real **JSX syntax**, not `solid-js/h` hyperscript:
`@solidjs/router`'s `<Router>` requires its `<Route>` children to be built lazily
(JSX getter children) so the route context is established before a page's `<Link>`
/ `useNavigate` runs — eager `h(Route, …)` children render router primitives
"outside a Route" and throw. The bootstrap is still a hand-assembled **string**
(soundness item 3 / view-ir-plan debt — the honest end state builds it as estree
and unparses); `jac client build` compiles it via `vite-plugin-solid` exactly like
every other `.jsx` module (the Vite plugin wiring lands in Branch 5+, alongside
the emitted-deps; until then a real Solid build is gated behind that wiring and
only the jsdom test harness — which runs `babel-preset-solid` itself — exercises
this end to end).
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
            '\t() => (',
            '\t\t<JacClientErrorBoundary FallbackComponent={ErrorFallback} onError={__jacReactErrorHandler}>',
            '\t\t\t<App />',
            '\t\t</JacClientErrorBoundary>',
            '\t),',
            '\t__jacMountEl',
            ');',
            ''
        ]
    );
    return "\n".join(lines);
}

"""Build the file-based-routing entry script for Solid.

The Solid analogue of `build_pages_react_entry_script`: it consumes the same
framework-neutral `./_routes.js` manifest (`routes` / `layouts`) and assembles the
route tree against `@solidjs/router` **natively** — there is no `<Routes>`, routes
are `<Route>` children of `<Router>` directly, each uses `component={Page}` (not
`element={<Page/>}`), a pathless `component={AuthGuard}` route groups the protected
routes (Solid passes the matched child in as `props.children`), and a root layout
rides `<Router root={Layout}>`. The tree is **JSX** (not `solid-js/h`): the route
children must be lazy so `@solidjs/router` establishes the route context before a
page's router primitives run (see the module docstring). It resolves **no**
React-ecosystem package. The app-wrapper and error boundary wiring mirror the
React builder.
"""
def build_pages_solid_entry_script(
    entry_module: str, auth_redirect: str, has_app_wrapper: bool
) -> str {
    lines: list[str] = [
        'import { render } from "solid-js/web";',
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
            '// nested/auth route content as `props.children`. The children are JSX so',
            '// the router context is established before any page <Link>/useNavigate runs.',
            'function renderRoutes(routeList) {',
            '\treturn routeList.map(r => <Route path={r.path} component={r.element} />);',
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
            'function App() {',
            '\tconst routerProps = RootLayout ? { root: __jacMakeLayoutRoot(RootLayout) } : {};',
            '\treturn (',
            '\t\t<Router {...routerProps}>',
            '\t\t\t{renderRoutes(publicRoutes)}',
            '\t\t\t<Route component={_AuthGuardRoute}>',
            '\t\t\t\t{renderRoutes(authRoutes)}',
            '\t\t\t</Route>',
            '\t\t</Router>',
            '\t);',
            '}',
            ''
        ]
    );
    if has_app_wrapper {
        app_tree = '<AppWrapper><App /></AppWrapper>';
    } else {
        app_tree = '<App />';
    }
    lines.extend(
        [
            'const __jacMountEl = document.getElementById("root")',
            '\t?? document.getElementById("__jac_root");',
            'render(',
            '\t() => (',
            '\t\t<JacClientErrorBoundary FallbackComponent={ErrorFallback} onError={__jacReactErrorHandler}>',
            f'\t\t\t{app_tree}',
            '\t\t</JacClientErrorBoundary>',
            '\t),',
            '\t__jacMountEl',
            ');',
            ''
        ]
    );
    return "\n".join(lines);
}
