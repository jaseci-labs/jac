"""Manual-routing `AuthGuard` fixture for the React jsdom auth test.

Every shape the guard is used in outside file-based routing, side by side:

  /wrapped         `<AuthGuard>...</AuthGuard>` as a route `element` -- must
                   render its children, not an `<Outlet/>` resolving to nothing.
  /nested          `<AuthGuard/>` as a pathless PARENT route -- no children, so
                   it falls back to `<Outlet/>` and the child route renders.
  /layout-guarded  a layout wrapping `<Outlet/>` in the guard -- the
                   `(auth)/layout.jac` shape, written manually.
  /bare            neither children nor child routes -- renders nothing, no crash.

`chrome` sits outside `<Routes>` so "the guard rendered nothing" is
distinguishable from "the app never mounted".
"""

import from "@jac/runtime" { Router, Routes, Route, AuthGuard, Outlet }

def:pub LoginPage -> JsxElement {
    <div data-testid="login">Login</div>
}

def:pub Dashboard -> JsxElement {
    <div data-testid="dashboard">Dashboard</div>
}

def:pub NestedPage -> JsxElement {
    <div data-testid="nested">Nested</div>
}

def:pub AuthShell -> JsxElement {
    <AuthGuard redirect="/login">
        <Outlet/>
    </AuthGuard>
}

def:pub app -> JsxElement {
    <Router>
        <div data-testid="chrome">chrome</div>
        <Routes>
            <Route path="/login" element={<LoginPage/>}/>
            <Route
                path="/wrapped"
                element={<AuthGuard redirect="/login">
                    <Dashboard/>
                </AuthGuard>}
            />
            <Route element={<AuthGuard redirect="/login"/>}>
                <Route path="/nested" element={<NestedPage/>}/>
            </Route>
            <Route element={<AuthShell/>}>
                <Route path="/layout-guarded" element={<Dashboard/>}/>
            </Route>
            <Route path="/bare" element={<AuthGuard redirect="/login"/>}/>
        </Routes>
    </Router>
}
