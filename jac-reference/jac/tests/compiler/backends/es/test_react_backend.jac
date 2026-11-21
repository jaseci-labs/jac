"""Tests for the React FrameworkBackend's generated file-based-routing entry.

The Solid entry has had string-level coverage since it shipped
(`test_solid_backend.jac`); the React entry had none, which is how it came to
call `AuthGuard` positionally. `AuthGuard` compiles to `function AuthGuard(props)`,
so `AuthGuard("/signin")` destructures a string, finds no `redirect`, and falls
back to `/login` -- `[client.routing] auth_redirect` never reaches the guard.

These pin the calling convention; the behavioral proof lives in
`tests/runtimelib/test_react_auth_jsdom.jac`.
"""

import from jaclang.compiler.backends.es.backends.react { ReactBackend }
import from jaclang.client.react_entry {
    build_pages_react_entry_script,
    build_simple_react_entry_script
}

test "react file-based-routing entry mounts via react-dom + react-router" {
    script = build_pages_react_entry_script("main", "/login", False);
    assert 'import { createRoot } from "react-dom/client";' in script;
    assert 'import { BrowserRouter, Routes, Route } from "react-router-dom";' in script;
    assert 'solid-js' not in script;
    assert '@solidjs/router' not in script;
    assert 'import { routes, layouts } from "./_routes.js";' in script;
    assert 'React.createElement(Route, { key: "__auth", element: authGuardElement },'
        in script;
    assert 'const RootLayout = layouts["/"] || null;' in script;
    assert 'getElementById("root")' in script;
    assert 'app as AppWrapper' not in script;
}

test "react entry passes auth_redirect to AuthGuard as a prop, not positionally" {
    script = build_pages_react_entry_script("main", "/signin", False);
    assert 'const authGuardElement = React.createElement(AuthGuard, { redirect: "/signin" });'
        in script;
    assert 'AuthGuard("' not in script;
    assert '_AuthGuardRoute' not in script;
}

test "react file-based-routing entry honors the app wrapper" {
    script = build_pages_react_entry_script("main", "/login", True);
    assert 'import { app as AppWrapper } from "./main.js";' in script;
    assert 'React.createElement(AppWrapper, null, React.createElement(App, null));'
        in script;
}

test "react simple entry mounts the module app under the error boundary" {
    script = build_simple_react_entry_script("main");
    assert 'import { app as App } from "./main.js";' in script;
    assert '__jacInstallErrorHandlers();' in script;
    assert 'JacClientErrorBoundary' in script;
    # No routing surface in the non-`pages/` entry.
    assert 'react-router-dom' not in script;
    assert 'AuthGuard' not in script;
}

test "backend.build_pages_entry_script routes through the react entry builder" {
    direct = build_pages_react_entry_script("main", "/signin", False);
    via_backend = ReactBackend().build_pages_entry_script("main", "/signin", False);
    assert via_backend == direct;
}
