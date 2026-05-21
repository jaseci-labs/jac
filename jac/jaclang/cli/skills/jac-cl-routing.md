---
name: jac-cl-routing
description: Multi-page navigation on the client - defining routes, redirecting, and navigating between pages from handlers. Load when adding pages or multi-screen flows. Pair with `jac-cl-components` (the components being routed), `jac-cl-auth` (protected routes).
---

Client routing in Jac uses React-Router v6 primitives re-exported from `@jac/runtime`. `<Router>` wraps the app; `<Routes>` groups a list of `<Route>` entries; each `<Route path="..." element={<Page />}>` renders its element when the path matches. Redirects use `<Navigate to="..." />`. Imperative navigation from a handler uses `useNavigate()`. Protected pages guard themselves inline with `jacIsLoggedIn()`.

```jac
import from "@jac/runtime" { Navigate, jacIsLoggedIn, useNavigate }

def:pub LoginPage() -> JsxElement {
    nav = useNavigate();                 # imperative navigation - call nav("/dashboard") from a handler

    def go_home(e: MouseEvent) {
        nav("/dashboard");
    }

    return <div className="p-4">
        <button onClick={go_home}>home</button>
    </div>;
}

def:pub DashboardPage() -> JsxElement {
    # Protected route: inline guard. Components with no `has` / no hooks can
    # put the guard at the top; components WITH hooks or `has` must put the
    # guard AFTER those (see `jac-cl-components` rules-of-hooks pitfall).
    if not jacIsLoggedIn() {
        return <Navigate to="/login" replace={True} />;
    }
    return <div className="p-4">Dashboard</div>;
}
```

## Router / Routes / Route wiring

Typically in `AppShell.cl.jac` or `main.jac`.

```
import from "@jac/runtime" { Router, Routes, Route, Navigate }
import from .pages.LoginPage { LoginPage }
import from .pages.DashboardPage { DashboardPage }

def:pub AppShell() -> JsxElement {
    return <Router>
        <Routes>
            <Route path="/" element={<Navigate to="/dashboard" replace={True} />} />
            <Route path="/login" element={<LoginPage />} />
            <Route path="/dashboard" element={<DashboardPage />} />
        </Routes>
    </Router>;
}
```

## Routing-relevant `@jac/runtime` exports

`Router`, `Routes`, `Route`, `Link`, `Navigate`, `Outlet`, `useNavigate`, `useLocation`, `useParams`, `useRouter`. For the full client export list, see `jac-cl-components`.

## Pitfalls

- `useNavigate()` returns a function. Use it imperatively in handlers: `nav = useNavigate(); ... nav("/target");`. NOT inside JSX attribute values.
- **Use `<Link to="/path">label</Link>` for in-app navigation.** For programmatic navigation from a handler, use `useNavigate()` instead. NOT `<a href="/path">` - that triggers a full page reload and loses client state.
- For querystrings, parse `useLocation().search` manually - there is no `useSearchParams` hook.
- Protected-route guards with `has`/hooks above - see the hook-ordering rule in `jac-cl-components`.
