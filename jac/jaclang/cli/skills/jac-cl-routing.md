---
name: jac-cl-routing
description: Multi-page navigation on the client - pages/ directory routing, [id] params, layouts, route groups, redirects, and programmatic navigation. Load when adding pages or multi-screen flows. Pair with `jac-cl-components` (the components being routed), `jac-cl-auth` (protected routes).
---

Two routing systems, both client-side (URL changes, no full reload). **File-based routing is the recommended default**: files in a `pages/` directory become routes by convention - no Router wiring at all. Manual `<Router>`/`<Routes>` is the explicit alternative for apps that want one file of route declarations.

## File-based routing (recommended)

```
myapp/
├── main.jac
└── pages/
    ├── layout.jac           # root layout - wraps ALL pages via <Outlet/>
    ├── index.jac            # /
    ├── about.jac            # /about
    ├── users/
    │   ├── index.jac        # /users
    │   └── [id].jac         # /users/:id   (dynamic param)
    ├── posts/[slug].jac     # /posts/:slug
    ├── (public)/            # route group - organizes, adds NO URL segment
    │   └── login.jac        # /login
    ├── (auth)/              # protected group (see AuthGuard below)
    │   ├── layout.jac       # wraps the group
    │   └── dashboard.jac    # /dashboard
    └── [...notFound].jac    # * catch-all (404)
```

Each page file exports a **`def:pub page()`**; each layout file a **`def:pub layout()`** containing `<Outlet />` where child routes render:

```jac
# pages/users/[id].jac
cl import from "@jac/runtime" { Link, useParams }

cl {
    def:pub page() -> JsxElement {
        params = useParams();
        userId = params["id"];                  # subscript, NOT params.id (E1030)
        if not userId { return <p>Not found</p>; }   # truthy check catches undefined
        return <div><Link to="/users">← Back</Link><h1>User {userId}</h1></div>;
    }
}
```

```jac
# pages/layout.jac - shared shell; nest more layout.jac files per directory
cl import from "@jac/runtime" { Outlet, Link }

cl {
    def:pub layout() -> JsxElement {
        return <div className="app">
            <nav><Link to="/">Home</Link><Link to="/dashboard">Dashboard</Link></nav>
            <main><Outlet /></main>
        </div>;
    }
}
```

**Protected route group** - put an `AuthGuard` layout in a `(auth)/` group; every page inside requires login:

```jac
# pages/(auth)/layout.jac
cl import from "@jac/runtime" { AuthGuard, Outlet }

cl {
    def:pub layout() -> JsxElement {
        return <AuthGuard redirect="/login"><Outlet /></AuthGuard>;
    }
}
```

## Navigation

- **Links:** `<Link to="/about">About</Link>`. NOT `<a href>` for in-app paths (full reload, loses state); plain `<a>` only for external URLs.
- **Programmatic:** `nav = useNavigate();` then from a handler: `nav("/dashboard")`, `nav("/login", {"replace": True})` (no history entry), `nav(-1)` (back), `nav(1)` (forward). Call the hook at component top, the function in handlers - never inside JSX attribute values.
- **Redirect as render:** `return <Navigate to="/login" replace={True} />;`.
- **Query params:** no `useSearchParams` hook - parse `useLocation().search` with the browser's `URLSearchParams`:

```
location = useLocation();
searchParams = URLSearchParams(location.search);
query = searchParams.get("q") or "";
page = int(searchParams.get("page") or "1");
# update: nav(f"/search?q={query}&page={page + 1}");
```

- **Active link styling:** compare `useLocation().pathname == path` and switch `className`.

## Manual routing (secondary)

Explicit route table in one component (typically `AppShell.cl.jac` or `main.jac`). Nested routes render into the parent element's `<Outlet />`:

```jac
import from "@jac/runtime" { Router, Routes, Route, Navigate, Outlet }
import from .pages.LoginPage { LoginPage }
import from .pages.DashboardLayout { DashboardLayout }
import from .pages.DashboardHome { DashboardHome }
import from .pages.Settings { Settings }

def:pub AppShell() -> JsxElement {
    return <Router>
        <Routes>
            <Route path="/" element={<Navigate to="/dashboard" replace={True} />} />
            <Route path="/login" element={<LoginPage />} />
            <Route path="/dashboard" element={<DashboardLayout />}>   {#* has <Outlet/> *#}
                <Route index element={<DashboardHome />} />
                <Route path="settings" element={<Settings />} />     {#* /dashboard/settings *#}
            </Route>
            <Route path="/user/:id" element={<UserProfile />} />
            <Route path="*" element={<NotFound />} />
        </Routes>
    </Router>;
}
```

Don't mix the two systems: a `pages/` directory and a manual `<Router>` will fight over the URL.

## Pitfalls

- `useParams()` returns a `dict` - **subscript access only** (`params["id"]`); `params.id` fails E1030 and `params.get("id")` crashes at runtime (it's a plain JS object). Missing params come back as JS `undefined`, which `is not None` MISSES - use truthy checks (`if not userId`). See `jac-cl-components`.
- Routing uses clean BrowserRouter URLs (`/users/123`, not `#/users/123`). `jac start` handles the SPA fallback automatically (serves the app HTML for extensionless non-API paths when `[serve] base_route_app` is set - see `jac-fullstack-patterns`). **Any other production host must do the same SPA fallback** or deep links / refreshes 404.
- Guards with `has`/hooks: a component's hooks must run before any conditional `return <Navigate/>` - see the rules-of-hooks pitfall in `jac-cl-components`. Prefer the `(auth)/layout.jac` + `AuthGuard` form, which avoids per-page guard code entirely.
- Routing exports from `@jac/runtime`: `Router`, `Routes`, `Route`, `Link`, `Navigate`, `Outlet`, `AuthGuard`, `useNavigate`, `useLocation`, `useParams`, `useRouter`.
