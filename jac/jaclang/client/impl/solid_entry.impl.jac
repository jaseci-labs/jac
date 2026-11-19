impl build_simple_solid_entry_script(
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

impl build_pages_solid_entry_script(
    entry_module: str, auth_redirect: str, has_app_wrapper: bool
) -> str {
    lines: list[str] = [
        'import { render } from "solid-js/web";',
        'import { createComponent, Show } from "solid-js";',
        'import { Router, Route, AuthGuard, __jacMakeLayoutRoot, JacClientErrorBoundary, ErrorFallback, __jacInstallErrorHandlers, __jacReactErrorHandler, useParams } from "@jac/runtime";',
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
            'function JacRouteParams(props) {',
            '\tconst found = useParams();',
            '\tconst given = () => {',
            '\t\tconst out = {};',
            '\t\tfor (const name of props.names) { if (name !== props.rest) out[name] = found[name]; }',
            '\t\tif (props.rest) out[props.rest] = (found["*"] || "").split("/").filter(Boolean);',
            '\t\treturn out;',
            '\t};',
            '\t// The page reads its arguments once, so a new URL recreates it.',
            '\treturn <Show when={JSON.stringify(given())} keyed>{() => createComponent(props.C, { ...given(), children: props.children })}</Show>;',
            '}',
            'function routeComponent(r) {',
            '\tif (r.params && r.params.length) {',
            '\t\treturn (p) => <JacRouteParams C={r.element} names={r.params} rest={r.rest || ""} children={p.children} />;',
            '\t}',
            '\treturn r.element;',
            '}',
            '',
            '// `@solidjs/router` takes <Route> children directly (no <Routes>) and a',
            '// `component` (not a prebuilt `element`); page components then receive',
            '// nested/auth route content as `props.children`. The children are JSX so',
            '// the router context is established before any page <Link>/useNavigate runs.',
            'function renderRoutes(routeList) {',
            '\treturn routeList.map(r => <Route path={r.path} component={routeComponent(r)} />);',
            '}',
            ''
        ]
    );

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
