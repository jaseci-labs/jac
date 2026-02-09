# Routing

Build multi-page applications with client-side routing.

> **Prerequisites**
>
> - Completed: [Authentication](auth.md)
> - Time: ~20 minutes

---

## Overview

Jac-client provides React Router-style routing:

```jac
cl {
    import from jac_client { Router, Route, Link }

    def:pub app() -> any {
        return <Router>
            <Route path="/" element={<Home />} />
            <Route path="/about" element={<About />} />
            <Route path="/contact" element={<Contact />} />
        </Router>;
    }
}
```

---

## Basic Routing

### Setting Up Routes

```jac
cl {
    import from jac_client { Router, Route, Link }

    def:pub Home() -> any {
        return <div>
            <h1>Home Page</h1>
            <p>Welcome to our site!</p>
        </div>;
    }

    def:pub About() -> any {
        return <div>
            <h1>About Us</h1>
            <p>Learn more about our company.</p>
        </div>;
    }

    def:pub Contact() -> any {
        return <div>
            <h1>Contact</h1>
            <p>Get in touch with us.</p>
        </div>;
    }

    def:pub app() -> any {
        return <Router>
            <nav>
                <Link to="/">Home</Link>
                <Link to="/about">About</Link>
                <Link to="/contact">Contact</Link>
            </nav>

            <main>
                <Route path="/" element={<Home />} />
                <Route path="/about" element={<About />} />
                <Route path="/contact" element={<Contact />} />
            </main>
        </Router>;
    }
}
```

### Link vs Anchor

```jac
cl {
    # Navigation example showing Link vs anchor
    def:pub NavExample() -> any {
        return <div>
            <Link to="/about">About</Link>
            <a href="https://example.com">External Site</a>
        </div>;
    }
}
```

---

## Dynamic Routes

### URL Parameters

```jac
cl {
    import from jac_client { Router, Route, useParams }

    def:pub UserProfile() -> any {
        # Get URL parameters
        params = useParams();
        user_id = params["id"];

        return <div>
            <h1>User Profile</h1>
            <p>Viewing user: {user_id}</p>
        </div>;
    }

    def:pub app() -> any {
        return <Router>
            <Route path="/user/:id" element={<UserProfile />} />
        </Router>;
    }
}
```

### Multiple Parameters

```jac
cl {
    import from jac_client { useParams }

    def:pub BlogPost() -> any {
        params = useParams();

        return <div>
            <p>Category: {params["category"]}</p>
            <p>Post ID: {params["postId"]}</p>
        </div>;
    }

    # Route: /blog/:category/:postId
    # URL: /blog/tech/123
    # params = {"category": "tech", "postId": "123"}
}
```

---

## Nested Routes

### Layout Pattern

```jac
cl {
    import from jac_client { Router, Route, Outlet }

    def:pub DashboardLayout() -> any {
        return <div className="dashboard">
            <aside>
                <Link to="/dashboard">Overview</Link>
                <Link to="/dashboard/settings">Settings</Link>
                <Link to="/dashboard/profile">Profile</Link>
            </aside>

            <main>
                <Outlet />
            </main>
        </div>;
    }

    def:pub DashboardHome() -> any {
        return <h2>Dashboard Overview</h2>;
    }

    def:pub DashboardSettings() -> any {
        return <h2>Settings</h2>;
    }

    def:pub DashboardProfile() -> any {
        return <h2>Profile</h2>;
    }

    def:pub app() -> any {
        return <Router>
            <Route path="/dashboard" element={<DashboardLayout />}>
                <Route index element={<DashboardHome />} />
                <Route path="settings" element={<DashboardSettings />} />
                <Route path="profile" element={<DashboardProfile />} />
            </Route>
        </Router>;
    }
}
```

---

## Programmatic Navigation

### useNavigate Hook

```jac
cl {
    import from jac_client { useNavigate }

    def:pub LoginForm() -> any {
        has email: str = "";
        has password: str = "";

        navigate = useNavigate();

        async def handle_login() -> None {
            success = await do_login(email, password);

            if success {
                # Redirect to dashboard
                navigate("/dashboard");
            }
        }

        return <form>
            <input
                value={email}
                onChange={lambda e: any -> None { email = e.target.value; }}
            />
            <button onClick={lambda -> None { handle_login(); }}>
                Login
            </button>
        </form>;
    }
}
```

### Navigation Options

```jac
cl {
    import from jac_client { useNavigate }

    def:pub NavExample() -> any {
        navigate = useNavigate();

        return <div>
            <button onClick={lambda -> None { navigate("/home"); }}>
                Go Home
            </button>

            <button onClick={lambda -> None { navigate("/login", {"replace": True}); }}>
                Login (replace)
            </button>

            <button onClick={lambda -> None { navigate(-1); }}>
                Back
            </button>

            <button onClick={lambda -> None { navigate(1); }}>
                Forward
            </button>
        </div>;
    }
}
```

---

## Route Guards

### Protected Routes

```jac
cl {
    import from jac_client { useNavigate }

    def:pub ProtectedRoute(props: dict) -> any {
        auth = use_auth();
        navigate = useNavigate();

        if auth.loading {
            return <div>Loading...</div>;
        }

        if not auth.isAuthenticated {
            # Redirect to login
            navigate("/login", {"replace": True});
            return None;
        }

        return <div>{props.children}</div>;
    }

    def:pub app() -> any {
        return <Router>
            <Route path="/login" element={<Login />} />

            <Route path="/dashboard" element={
                <ProtectedRoute>
                    <Dashboard />
                </ProtectedRoute>
            } />
        </Router>;
    }
}
```

### Role-Based Access

```jac
cl {
    def:pub AdminRoute(props: dict) -> any {
        auth = use_auth();

        if not auth.isAuthenticated {
            return <Navigate to="/login" />;
        }

        if auth.user.role != "admin" {
            return <div className="error">
                <h2>Access Denied</h2>
                <p>You need admin privileges to view this page.</p>
            </div>;
        }

        return <>{props.children}</>;
    }
}
```

---

## Query Parameters

### useSearchParams Hook

```jac
cl {
    import from jac_client { useSearchParams }

    def:pub SearchResults() -> any {
        (searchParams, setSearchParams) = useSearchParams();

        query = searchParams.get("q") or "";
        page = int(searchParams.get("page") or "1");

        def update_page(new_page: int) -> None {
            setSearchParams({"q": query, "page": str(new_page)});
        }

        return <div>
            <h2>Results for: {query}</h2>
            <p>Page: {page}</p>

            <button
                onClick={lambda -> None { update_page(page - 1); }}
                disabled={page <= 1}
            >
                Previous
            </button>

            <button onClick={lambda -> None { update_page(page + 1); }}>
                Next
            </button>
        </div>;
    }

    # URL: /search?q=hello&page=2
}
```

---

## 404 Not Found

```jac
cl {
    import from jac_client { Router, Route }

    def:pub NotFound() -> any {
        return <div className="error-page">
            <h1>404</h1>
            <p>Page not found</p>
            <Link to="/">Go Home</Link>
        </div>;
    }

    def:pub app() -> any {
        return <Router>
            <Route path="/" element={<Home />} />
            <Route path="/about" element={<About />} />

            <Route path="*" element={<NotFound />} />
        </Router>;
    }
}
```

---

## Active Link Styling

```jac
cl {
    import from jac_client { NavLink }

    def:pub Navigation() -> any {
        return <nav>
            <NavLink
                to="/"
                className={lambda info: any -> str {
                    return "nav-link " + ("active" if info.isActive else "");
                }}
            >
                Home
            </NavLink>

            <NavLink
                to="/about"
                className={lambda info: any -> str {
                    return "nav-link " + ("active" if info.isActive else "");
                }}
            >
                About
            </NavLink>
        </nav>;
    }
}
```

```css
/* styles.css */
.nav-link {
    color: gray;
    text-decoration: none;
}

.nav-link.active {
    color: blue;
    font-weight: bold;
}
```

---

## Complete Example

```jac
cl {
    import from jac_client { Router, Route, Link, Outlet, useParams, useNavigate }

    # Layout
    def:pub Layout() -> any {
        return <div className="app">
            <header>
                <nav>
                    <Link to="/">Home</Link>
                    <Link to="/products">Products</Link>
                    <Link to="/about">About</Link>
                </nav>
            </header>

            <main>
                <Outlet />
            </main>

            <footer>
                <p>© 2024 My App</p>
            </footer>
        </div>;
    }

    # Pages
    def:pub Home() -> any {
        return <div>
            <h1>Welcome!</h1>
            <Link to="/products">Browse Products</Link>
        </div>;
    }

    def:pub Products() -> any {
        products = [
            {"id": 1, "name": "Widget A"},
            {"id": 2, "name": "Widget B"},
            {"id": 3, "name": "Widget C"}
        ];

        return <div>
            <h1>Products</h1>
            <ul>
                {products.map(lambda p: any -> any {
                    return <li key={p["id"]}>
                        <Link to={f"/products/{p['id']}"}>
                            {p["name"]}
                        </Link>
                    </li>;
                })}
            </ul>
        </div>;
    }

    def:pub ProductDetail() -> any {
        params = useParams();
        navigate = useNavigate();

        product_id = params["id"];

        return <div>
            <button onClick={lambda -> None { navigate(-1); }}>
                ← Back
            </button>
            <h1>Product {product_id}</h1>
            <p>Details about product {product_id}</p>
        </div>;
    }

    def:pub About() -> any {
        return <div>
            <h1>About Us</h1>
            <p>We make great products.</p>
        </div>;
    }

    def:pub NotFound() -> any {
        return <div>
            <h1>404 - Not Found</h1>
            <Link to="/">Go Home</Link>
        </div>;
    }

    # App
    def:pub app() -> any {
        return <Router>
            <Route path="/" element={<Layout />}>
                <Route index element={<Home />} />
                <Route path="products" element={<Products />} />
                <Route path="products/:id" element={<ProductDetail />} />
                <Route path="about" element={<About />} />
                <Route path="*" element={<NotFound />} />
            </Route>
        </Router>;
    }
}
```

---

## File-Based Routing

Instead of manually defining `<Route>` components, you can use a **`pages/` directory convention** to generate routes automatically from your file structure.

### Directory Structure

Create a `pages/` directory in your project root. Each `.jac` file becomes a route:

```
my-app/
├── main.jac
├── jac.toml
└── pages/
    ├── layout.jac           # Root layout (Navigation + Outlet)
    ├── index.jac            # → /
    ├── about.jac            # → /about
    ├── landing.jac          # → /landing
    ├── users/
    │   └── [id].jac         # → /users/:id  (dynamic segment)
    ├── [...notFound].jac    # → /*  (catch-all 404)
    ├── (auth)/
    │   ├── dashboard.jac    # → /dashboard  (protected)
    │   └── settings.jac     # → /settings   (protected)
    └── (public)/
        ├── login.jac        # → /login
        └── signup.jac       # → /signup
```

### Page Files

Each page file must export `def:pub page`:

```jac
cl {
    def:pub page -> any {
        return <div>
            <h1>About Us</h1>
            <p>Welcome to our site.</p>
        </div>;
    }
}
```

### Layout Files

Layout files export `def:pub layout` and use `<Outlet />` to render child routes:

```jac
cl import from "@jac/runtime" { Outlet, Link }

cl {
    def:pub layout -> any {
        return <>
            <nav>
                <Link to="/">Home</Link>
                <Link to="/about">About</Link>
                <Link to="/dashboard">Dashboard</Link>
            </nav>
            <main>
                <Outlet />
            </main>
        </>;
    }
}
```

### Protected Pages with `(auth)/`

Place pages inside a `(auth)/` directory to mark them as **protected**. These routes are automatically wrapped in an `AuthGuard` that checks `jacIsLoggedIn()` and redirects unauthenticated users to `/login`:

```
pages/
├── (auth)/
│   ├── dashboard.jac    # → /dashboard  (requires login)
│   ├── profile.jac      # → /profile    (requires login)
│   └── settings.jac     # → /settings   (requires login)
```

The `(auth)` directory name does **not** appear in the URL -- it only controls authentication. `pages/(auth)/dashboard.jac` maps to `/dashboard`, not `/auth/dashboard`.

No additional code is needed in the page file itself -- the `AuthGuard` handles the redirect automatically:

```jac
# pages/(auth)/dashboard.jac
# No need for jacIsLoggedIn() checks -- AuthGuard handles it
cl {
    def:pub page -> any {
        return <div>
            <h1>Dashboard</h1>
            <p>This content is only visible to logged-in users.</p>
        </div>;
    }
}
```

### Public Pages with `(public)/`

Place pages inside a `(public)/` directory to explicitly mark them as **public** (no authentication required). Like `(auth)/`, the directory name does not appear in the URL:

```
pages/
├── (public)/
│   ├── login.jac     # → /login   (no auth required)
│   └── signup.jac    # → /signup  (no auth required)
```

Pages at the root of `pages/` (not inside any group directory) are also public by default.

### Dynamic Routes

Use `[param]` syntax in filenames for dynamic URL segments:

```
pages/users/[id].jac       # → /users/:id
pages/blog/[slug].jac      # → /blog/:slug
```

Access parameters with `useParams()`:

```jac
cl import from "@jac/runtime" { useParams }

cl {
    def:pub page -> any {
        params = useParams();
        return <h1>User: {params.id}</h1>;
    }
}
```

### Catch-All Routes

Use `[...name]` syntax for catch-all routes (404 pages):

```jac
# pages/[...notFound].jac → matches any unmatched URL
cl import from "@jac/runtime" { Link }

cl {
    def:pub page -> any {
        return <div>
            <h1>404 - Page Not Found</h1>
            <Link to="/">Go Home</Link>
        </div>;
    }
}
```

### Simplifying `main.jac`

With file-based routing, `main.jac` no longer needs explicit `Router`/`Routes`/`Route` setup. If `app()` is exported, it wraps the auto-generated router as a parent container:

```jac
# Global styles
cl import ".styles/styles.css";

cl {
    def:pub app(children: any = None) -> any {
        return <div style={{"fontFamily": "system-ui, sans-serif"}}>
            {children}
        </div>;
    }
}
```

### Auth Redirect Configuration

By default, unauthenticated users are redirected to `/login`. Configure this in `jac.toml`:

```toml
[plugins.client.routing]
auth_redirect = "/signin"
```

---

## Key Takeaways

| Concept | Usage |
|---------|-------|
| Define routes | `<Route path="/..." element={<Comp />} />` |
| Navigation links | `<Link to="/path">Text</Link>` |
| URL parameters | `useParams()` returns `{param: value}` |
| Programmatic nav | `navigate("/path")` or `navigate(-1)` |
| Query strings | `useSearchParams()` |
| Nested routes | `<Outlet />` renders child routes |
| 404 handling | `<Route path="*" element={<NotFound />} />` |
| File-based routes | `pages/about.jac` → `/about` |
| Protected pages | `pages/(auth)/dashboard.jac` → requires login |
| Public pages | `pages/(public)/login.jac` → no auth needed |
| Dynamic segments | `pages/users/[id].jac` → `/users/:id` |
| Catch-all | `pages/[...slug].jac` → `*` |
| Page export | `def:pub page -> any { ... }` |
| Layout export | `def:pub layout -> any { ... }` with `<Outlet />` |

---

## Next Steps

- [Backend Integration](backend.md) - Connect to walker APIs
- [Authentication](auth.md) - Add protected routes
