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
