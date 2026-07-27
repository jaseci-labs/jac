---
name: jac-cl-routing
description: Multi-page navigation on the client - pages/ directory routing, [id] params, layouts, route groups, redirects, and programmatic navigation. Load when adding pages or multi-screen flows. Pair with `jac-cl-components` (the components being routed), `jac-cl-auth` (protected routes).
---

Two routing systems, both client-side (URL changes, no full reload). **File-based routing is the recommended default**: files in a `pages/` directory become routes by convention - no Router wiring at all. Manual `<Router>`/`<Routes>` is the explicit alternative for apps that want one file of route declarations.

> **Pick ONE system and stay with it - do NOT mix them or switch mid-build.** Default to file-based routing. If you choose manual `<Router>`, keep route components OUT of `pages/`: a `pages/` directory and a manual `<Router>` fight over the URL, and manually importing `pages/foo.jac` breaks (the compiled JS resolves `./pages/foo.js`, which file-based routing never emits).

**The choice decides `main.jac`'s `app` export** (see below). The `web-app` template ships the single-page shape - `main.jac` exports `def:pub app` returning `<ClientApp/>` from `frontend.jac` - which is NOT routing. Converting it:

| | `main.jac` exports | route components live in | delete |
|---|---|---|---|
| **File-based** (default) | `def:pub app(children)` that renders `children` | `pages/` (shell = `pages/layout.jac`) | `frontend.jac`, `frontend.impl.jac` |
| **Manual** | `def:pub app()` returning your `<Router>` shell | anywhere OUTSIDE `pages/` | - (repurpose `frontend.jac` as the shell) |

Keeping the template's `app()` while adding `pages/` is the classic mix: it compiles, it serves, and every route is silently discarded.

Client placement is inferred: a `pages/*.jac` file whose export returns `JsxPage` (or carries an npm import) compiles client automatically - no wrapper or prefix needed (see `jac-codespaces`). The page, layout, and `main.jac` examples below are plain markerless `.jac`.

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

**Which files become routes: the return type decides.** A `pages/` file is a route when a public export returns **`JsxPage`**, and a layout when one returns **`JsxLayout`**. `JsxPage` and `JsxLayout` are ambient builtin types (no import, like `JsxElement`), and `JsxElement` is assignable to both, so a component body returning JSX satisfies them.

The **export name is free** - the router imports whatever the `JsxPage`-returning export is called. A co-located component returns `JsxElement`, so it is never a route and needs no marker. `.impl.` and `.test.` sidecars are skipped structurally (module roles, not route modules).

| File | export returns | Becomes a route? | Purpose |
|---|---|---|---|
| `pages/about.jac` | `JsxPage` | yes | page (any export name) |
| `pages/layout.jac` | `JsxLayout` | layout | wraps the directory via `<Outlet/>` |
| `pages/about_ui.jac` | `JsxElement` | **no** | co-located component |
| `pages/about.impl.jac` | - | **no** | jac impl-separation sidecar |
| `pages/about.test.jac` | - | **no** | test sidecar |

Naming a def `page` or `layout` marks nothing on its own - only the return type does.

**Co-location pattern** - a thin route returning `JsxPage` plus a plain component returning `JsxElement`, both in `pages/`. Import the sibling by stem: `budget_ui.jac` → `import from .budget_ui { BudgetUI }`.

```
pages/
├── budget.jac               # /budget  - returns Page
└── budget_ui.jac            # not a route - returns JsxElement, imported by budget.jac
```

A page returns **`JsxPage`**; a layout returns **`JsxLayout`** and contains `<Outlet />` where child routes render. Both can be named anything:

```jac
# pages/users/[id].jac
import from "@jac/runtime" { Link, useParams }

def:pub UserDetail() -> JsxPage {
    params = useParams();
    userId = params["id"];                  # subscript, NOT params.id (E1030)
    if not userId { return <p>Not found</p>; }   # truthy check catches undefined
    return <div><Link to="/users">← Back</Link><h1>User {userId}</h1></div>;
}
```

```jac
# pages/layout.jac - shared shell; nest one per directory to scope it
import from "@jac/runtime" { Outlet, Link }

def:pub Shell() -> JsxLayout {
    return <div className="app">
        <nav><Link to="/">Home</Link><Link to="/dashboard">Dashboard</Link></nav>
        <main><Outlet /></main>
    </div>;
}
```

The filename still decides the **URL** (`index.jac` → the directory root, `[id].jac` → `:id`, `[...rest].jac` → catch-all); the return type only decides **what is a route**. A layout is scoped to the directory its file sits in, so `layout.jac` remains the conventional filename even though any filename with a `JsxLayout`-returning export works.

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
[client.routing]
auth_redirect = "/signin"
```

**`main.jac` MUST export `def:pub app(children)`.** The generated client entry does `import { app as AppWrapper } from "./main.js"` and renders `<AppWrapper>{<App/>}</AppWrapper>`, where `<App/>` is the router built from `pages/`. So `app` receives the router tree as `children` and **must render it**. With no global providers, that is the whole file:

```
# main.jac - server imports at top (if any), then:
def:pub app(children: any) -> JsxElement {
    return <>{children}</>;    # JSX places app client; the fragment renders the router children
}
```

Wrap `children` to add global providers (theme, query client, auth context, etc.):

```
# main.jac
import from .providers.ThemeProvider { ThemeProvider }

def:pub app(children: any) -> JsxElement {
    return <ThemeProvider>{children}</ThemeProvider>;
}
```

⚠ Two failure modes, both easy to hit:

- **Omitting the export** fails the build: `"app" is not exported by "compiled/main.js"` (in dev, the browser shows `SyntaxError: ... does not provide an export named 'app'`). A JSX-less `app` is just as bad: `def:pub app(children) { return children as JsxElement; }` carries no client signal, so inference places it **server** and it is never exported to the client entry - the same failure. Wrap `children` in JSX (`<>{children}</>` or a provider) so `app` is placed client. A `pages/` directory still needs `main.jac` to export a client `app`; the entry imports it by name.
- **An `app` that ignores `children`** - e.g. the single-page shape `def:pub app -> JsxElement { return <Home/>; }` - **silently drops every route.** `jac check` passes, the bundle builds, the server starts, no error anywhere, and `pages/` simply never renders. This is the most common way a file-based app ends up stuck showing one stale page.

Also note `return children;` alone fails `jac check` with `E1002: Cannot return Any, expected JsxElement` - cast it (`children as JsxElement`) or wrap it in JSX.

> **Do not place a `layout.jac` inside `(auth)/`.** Route groups do not add a URL segment, so `pages/(auth)/layout.jac` maps to the same layout key (`"/"`) as `pages/layout.jac`. Having both causes a **layout collision error** at build time. If only `pages/(auth)/layout.jac` exists, it becomes the root layout and wraps all routes - including public ones like `/login` - behind `AuthGuard`, causing an infinite redirect loop.

## Navigation

- **Links:** `<Link to="/about">About</Link>`. NOT `<a href>` for in-app paths (full reload, loses state); plain `<a>` only for external URLs.
- **Programmatic:** `nav = useNavigate();` then from a handler: `nav("/dashboard")`, `nav("/login", {"replace": True})` (no history entry), `nav(-1)` (back), `nav(1)` (forward). Call the hook at component top, the function in handlers - never inside JSX attribute values.
- **Redirect as render:** `return <Navigate to="/login" replace={True} />;`.
- **Query params:** no `useSearchParams` hook - parse `useLocation().search` with the browser's `URLSearchParams`. `URLSearchParams` is a constructor, not a plain function - build it with the `new()` builtin (see `jac-cl-js-interop`); a bare `URLSearchParams(...)` call throws `TypeError: ... cannot be invoked without 'new'` at runtime:

```
location = useLocation();
searchParams = new(URLSearchParams, location.search);
query = searchParams.get("q") or "";
page = int(searchParams.get("page") or "1");
# update: nav(f"/search?q={query}&page={page + 1}");
```

- **Active link styling:** compare `useLocation().pathname == path` and switch `className`.

## Manual routing (secondary)

Explicit route table in one `.jac` component (e.g. `AppShell.jac`) which `main.jac` mounts with the no-argument `def:pub app() -> JsxElement { return <AppShell/>; }`. With no `pages/` directory the generated entry renders `app` directly (`React.createElement(App, null)`) instead of wrapping a router in it, so the no-argument form is correct and `children` need not be declared. Components live OUTSIDE `pages/`. Nested routes render into the parent's `<Outlet />`:

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
