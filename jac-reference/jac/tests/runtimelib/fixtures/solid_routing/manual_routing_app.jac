"""Manual-routing `AuthGuard` shapes the generated `pages/` entry never writes
(Solid mirror of `fixtures/react_auth/manual_routing_app.jac`):

  /nested          guard as a pathless `element=` parent route, child from the router
  /layout-guarded  a layout wrapping `<Outlet/>` in the guard
  /bare            neither children nor child routes

`chrome` renders outside every route, so "guard rendered nothing" is
distinguishable from "app never mounted"."""

import from "@jac/runtime" { Router, Routes, Route, AuthGuard, Outlet }

def:pub Shell(props: any) -> JsxElement {
    <div>
        <div data-testid="chrome">chrome</div>
        {props.children}
    </div>
}

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
    <Router root={Shell}>
        <Routes>
            <Route path="/login" element={<LoginPage/>}/>
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
