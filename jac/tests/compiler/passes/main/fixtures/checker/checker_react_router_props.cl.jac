"""Regression: React Router props (`Route element`, `Link to`) typecheck under jac-client.

When the jac-client plugin is installed, `@jac/runtime` exposes the
React Router v6 surface. The type checker must resolve `@jac/runtime` to the
jac-client plugin's `client_runtime.cl.jac` (matching the Vite alias used at
bundle time) so JSX prop validation accepts React Router's prop names
(`element`, `to`, …) instead of the legacy bare-serve router's
(`component`, `props: dict`).

Tracking: GitHub issue #5847.
"""

cl import from "@jac/runtime" { Route, Link }

def DashboardPage -> JsxElement {
    return <div>Dashboard</div>;
}

def App -> JsxElement {
    return <div>
        <Route path="/dashboard" element={<DashboardPage />} />
        <Link to="/login">Log in</Link>
    </div>;
}
