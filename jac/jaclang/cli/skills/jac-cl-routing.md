---
name: jac-cl-routing
description: Multi-page navigation on the client - pages/ directory routing, [id] params, layouts, route groups, redirects, and programmatic navigation. Load when adding pages or multi-screen flows. Pair with `jac-cl-components` (the components being routed), `jac-cl-auth` (protected routes).
---

Two routing systems, both client-side (URL changes, no full reload). **File-based routing is the recommended default**: files in a `pages/` directory become routes by convention - no Router wiring at all. Manual `<Router>`/`<Routes>` is the explicit alternative for apps that want one file of route declarations.

> **Pick ONE system and stay with it - do NOT mix them or switch mid-build.** Default to file-based routing. If you choose manual `<Router>`, keep route components OUT of `pages/`: a `pages/` directory and a manual `<Router>` fight over the URL, and manually importing `pages/foo.jac` breaks (the compiled JS resolves `./pages/foo.js`, which file-based routing never emits).

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
    ├── (public)/            # route group - adds NO URL segment; any name except 'auth' is non-protected
    │   └── login.jac        # /login
    ├── (auth)/              # protected group - AUTOMATIC auth guard, adds NO URL segment
    │   └── dashboard.jac    # /dashboard  (protected automatically)
    └── [...notFound].jac    # * catch-all (404)
```

**Which files become routes:** Only plain `.jac` files in `pages/` are treated as routes. The scanner skips files whose name contains `.cl.`, `.impl.`, or `.test.` : these are never turned into routes regardless of location.

| File | Becomes a route? | Purpose |
|---|---|---|
| `pages/about.jac` | yes | page |
| `pages/about.cl.jac` | **no** | co-located component |
| `pages/about.impl.jac` | **no** | jac impl-separation file |
| `pages/about.test.jac` | **no** | test file |

**Co-location pattern** - split into a thin `.jac` route (exports `def:pub page`) and a `.cl.jac` component. Both live in `pages/`, only `.jac` becomes a route. Import the sibling inside `cl {}` using the stem without `.cl`: `budget_ui.cl.jac` → `import from .budget_ui { BudgetUI }`.

```
pages/
├── budget.jac               # /budget  - thin route, exports page
└── budget_ui.cl.jac         # skipped  - complex UI component, exported as BudgetUI
```

Each page file exports a **`def:pub page`**; each layout file a **`def:pub layout`** containing `<Outlet />` where child routes render:

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

A `layout.jac` inside a subdirectory scopes to that directory's URL prefix only:

```
pages/
├── layout.jac          # wraps ALL routes (layout key "/")
└── users/
    ├── layout.jac      # wraps /users and /users/:id only (layout key "/users")
    ├── index.jac       # /users
    └── [id].jac        # /users/:id
```

**Protected route group** - naming a group `(auth)/` is all that is needed; the build system automatically wraps every page inside with an `AuthGuard` in the generated entry script. No layout file or manual `AuthGuard` call required.

The default redirect for unauthenticated users is `/login`. To change it, set `auth_redirect` in `jac.toml`:

```toml
[plugins.client.routing]
auth_redirect = "/signin"
```

**Global providers (`app` export)** - export `def:pub app` from `main.jac` to wrap the entire router with global providers (theme, query client, auth context, etc.). The router tree is passed as `children`:

```
# main.jac
cl import from "@jac/runtime" { ... }
cl import from .providers.ThemeProvider { ThemeProvider }

cl {
    def:pub app(children: any) -> JsxElement {
        return <ThemeProvider>{children}</ThemeProvider>;
    }
}
```

Without this export the router mounts directly. With it, `AppWrapper` wraps `<App/>` (the router tree).

> **Do not place a `layout.jac` inside `(auth)/`.** Route groups do not add a URL segment, so `pages/(auth)/layout.jac` maps to the same layout key (`"/"`) as `pages/layout.jac`. Having both causes a **layout collision error** at build time. If only `pages/(auth)/layout.jac` exists, it becomes the root layout and wraps all routes - including public ones like `/login` - behind `AuthGuard`, causing an infinite redirect loop.

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

Explicit route table in one `.cl.jac` component (e.g. `AppShell.cl.jac`). Components live OUTSIDE `pages/`. Nested routes render into the parent's `<Outlet />`:

```jac
import from "@jac/runtime" { Router, Routes, Route, Navigate, Outlet }
import from .routes.LoginPage { LoginPage }
import from .routes.DashboardLayout { DashboardLayout }
import from .routes.DashboardHome { DashboardHome }
import from .routes.Settings { Settings }
import from .routes.UserProfile { UserProfile }
import from .routes.NotFound { NotFound }

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

## Pitfalls

- `useParams()` returns a `dict` - **subscript access only** (`params["id"]`); `params.id` fails E1030 and `params.get("id")` crashes at runtime (it's a plain JS object). Missing params come back as JS `undefined`, which `is not None` MISSES - use truthy checks (`if not userId`). See `jac-cl-components`.
- Routing uses clean BrowserRouter URLs (`/users/123`, not `#/users/123`). `jac start` handles the SPA fallback automatically (serves the app HTML for extensionless non-API paths when `[serve] base_route_app` is set - see `jac-fullstack-patterns`). **Any other production host must do the same SPA fallback** or deep links / refreshes 404.
- Guards with `has`/hooks: a component's hooks must run before any conditional `return <Navigate/>` - see the rules-of-hooks pitfall in `jac-cl-components`. Prefer the `(auth)/` group convention for file-based routing, which avoids per-page guard code entirely.
- Routing exports from `@jac/runtime`: `Router`, `Routes`, `Route`, `Link`, `Navigate`, `Outlet`, `AuthGuard`, `useNavigate`, `useLocation`, `useParams`, `useRouter`.
