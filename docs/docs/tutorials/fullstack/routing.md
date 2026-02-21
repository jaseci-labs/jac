# Routing

Build multi-page applications with client-side routing.

> **Prerequisites**
>
> - Completed: [Authentication](auth.md)
> - Time: ~20 minutes

---

## Overview

!!! info "Single-page vs multi-page"
    If your app is a single-page application (like the [AI Day Planner tutorial](../first-app/build-ai-day-planner.md)), you don't need routing -- a single `def:pub app -> JsxElement` entry point is sufficient. Add routing when your app needs multiple distinct pages (e.g., dashboard, settings, profile).

Jac-client supports two routing approaches:

1. **File-Based Routing** (Recommended) - Convention over configuration
2. **Manual Routing** - React Router-style explicit routes

---

## File-Based Routing (Recommended)

Create a `pages/` directory with `.jac` files that automatically become routes.

### Project Structure

```
myapp/
├── main.jac
└── pages/
    ├── layout.jac            # Root layout (wraps all pages)
    ├── index.jac             # / (home page)
    ├── about.jac             # /about
    ├── users/
    │   ├── index.jac         # /users
    │   └── [id].jac          # /users/:id (dynamic)
    ├── posts/
    │   ├── index.jac         # /posts
    │   └── [slug].jac        # /posts/:slug (dynamic)
    ├── (public)/             # Route group (no auth required)
    │   ├── login.jac         # /login
    │   └── signup.jac        # /signup
    ├── (auth)/               # Route group (auth required)
    │   ├── index.jac         # / (protected home)
    │   └── dashboard.jac     # /dashboard
    └── [...notFound].jac     # Catch-all 404 page
```

### Route Mapping Reference

| File | Route | Description |
|------|-------|-------------|
| `pages/index.jac` | `/` | Home page |
| `pages/about.jac` | `/about` | Static page |
| `pages/users/index.jac` | `/users` | Users list |
| `pages/users/[id].jac` | `/users/:id` | Dynamic user profile |
| `pages/posts/[slug].jac` | `/posts/:slug` | Dynamic blog post |
| `pages/[...notFound].jac` | `*` | Catch-all 404 |

### Basic Page

Each page file exports a `page` function:

```jac
# pages/about.jac
cl {
    def:pub page() -> JsxElement {
        return <div>
            <h1>About Us</h1>
            <p>Learn more about our company.</p>
        </div>;
    }
}
```

### Dynamic Routes with `[param]`

Use square brackets for dynamic URL segments:

```jac
# pages/users/[id].jac
cl import from "@jac/runtime" { Link, useParams }

cl {
    def:pub page() -> JsxElement {
        params = useParams();
        userId = params.id;

        # Mock data lookup
        users = {
            "1": {"name": "Alice", "role": "Admin"},
            "2": {"name": "Bob", "role": "Developer"}
        };

        user = users[userId];

        if not user {
            return <div>
                <h1>User Not Found</h1>
                <Link to="/users">Back to Users</Link>
            </div>;
        }

        return <div>
            <Link to="/users">← Back</Link>
            <h1>User: {user["name"]}</h1>
            <p>Role: {user["role"]}</p>
        </div>;
    }
}
```

### Slug-Based Routes

```jac
# pages/posts/[slug].jac
cl import from "@jac/runtime" { Link, useParams }

cl {
    def:pub page() -> JsxElement {
        params = useParams();
        slug = params.slug;  # e.g., "getting-started-with-jac"

        return <article>
            <Link to="/posts">← All Posts</Link>
            <h1>Blog Post</h1>
            <p>Slug: {slug}</p>
        </article>;
    }
}
```

### Catch-All Routes with `[...param]`

Use `[...param]` for catch-all routes (404 pages, docs, etc.):

```jac
# pages/[...notFound].jac
cl import from "@jac/runtime" { Link }

cl {
    def:pub page() -> JsxElement {
        return <div style={{"textAlign": "center", "padding": "2rem"}}>
            <h1>404 - Page Not Found</h1>
            <p>The page you are looking for does not exist.</p>
            <Link to="/">Back to Home</Link>
        </div>;
    }
}
```

### Route Groups with `(groupName)`

Route groups organize pages **without affecting the URL**:

| Directory | Effect |
|-----------|--------|
| `(public)/` | Groups public pages, no URL segment added |
| `(auth)/` | Groups protected pages, auto-requires login |

```
pages/
├── (public)/
│   ├── login.jac      # Route: /login
│   └── signup.jac     # Route: /signup
├── (auth)/
│   ├── index.jac      # Route: / (protected)
│   └── settings.jac   # Route: /settings (protected)
```

The `(auth)` group automatically wraps pages with authentication checks.

### Layout Files

Create `layout.jac` to wrap pages with shared UI:

```jac
# pages/layout.jac
cl import from "@jac/runtime" { Outlet }
cl import from ..components.navigation { Navigation }

cl {
    def:pub layout() -> JsxElement {
        return <>
            <Navigation />
            <main style={{"maxWidth": "960px", "margin": "0 auto"}}>
                <Outlet />  # Child routes render here
            </main>
            <footer>Footer content</footer>
        </>;
    }
}
```

### Index Files

`index.jac` represents the default page for a directory:

| File | Route |
|------|-------|
| `pages/index.jac` | `/` |
| `pages/users/index.jac` | `/users` |
| `pages/posts/index.jac` | `/posts` |

---

## Manual Routing

For explicit route configuration, import from `@jac/runtime`:

```jac
cl import from "@jac/runtime" { Router, Routes, Route, Link }

cl {
    def:pub app() -> any {
        return <Router>
            <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/about" element={<About />} />
                <Route path="/contact" element={<Contact />} />
            </Routes>
        </Router>;
    }
}
```

---

## Basic Routing

### Setting Up Routes

```jac
cl import from "@jac/runtime" { Router, Routes, Route, Link }

cl {
    def:pub Home() -> JsxElement {
        return <div>
            <h1>Home Page</h1>
            <p>Welcome to our site!</p>
        </div>;
    }

    def:pub About() -> JsxElement {
        return <div>
            <h1>About Us</h1>
            <p>Learn more about our company.</p>
        </div>;
    }

    def:pub Contact() -> JsxElement {
        return <div>
            <h1>Contact</h1>
            <p>Get in touch with us.</p>
        </div>;
    }

    def:pub app() -> JsxElement {
        return <Router>
            <nav>
                <Link to="/">Home</Link>
                <Link to="/about">About</Link>
                <Link to="/contact">Contact</Link>
            </nav>

            <main>
                <Routes>
                    <Route path="/" element={<Home />} />
                    <Route path="/about" element={<About />} />
                    <Route path="/contact" element={<Contact />} />
                </Routes>
            </main>
        </Router>;
    }
}
```

### Link vs Anchor

```jac
cl {
    # Use Link for internal navigation, anchor for external
    def:pub NavExample() -> JsxElement {
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

**File-Based Approach:**

Create a file with brackets for dynamic segments:

```
pages/users/[id].jac  # Matches /users/:id
```

```jac
# pages/users/[id].jac
cl import from "@jac/runtime" { useParams }

cl {
    def:pub page() -> JsxElement {
        params = useParams();
        user_id = params["id"];

        return <div>
            <h1>User Profile</h1>
            <p>Viewing user: {user_id}</p>
        </div>;
    }
}
```

**Manual Route Approach:**

```jac
cl import from "@jac/runtime" { Router, Routes, Route, useParams }

cl {
    def:pub UserProfile() -> JsxElement {
        params = useParams();
        user_id = params["id"];

        return <div>
            <h1>User Profile</h1>
            <p>Viewing user: {user_id}</p>
        </div>;
    }

    def:pub app() -> JsxElement {
        return <Router>
            <Routes>
                <Route path="/user/:id" element={<UserProfile />} />
            </Routes>
        </Router>;
    }
}
```

### Multiple Parameters

```jac
cl import from "@jac/runtime" { useParams }

cl {
    def:pub BlogPost() -> JsxElement {
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

### Layout Pattern (File-Based)

Create a `layout.jac` file in a route group:

```

pages/
└── (dashboard)/           # Route group
    ├── layout.jac         # Shared layout
    ├── index.jac          # /dashboard
    ├── settings.jac       # /dashboard/settings
    └── profile.jac        # /dashboard/profile

```

```jac
# pages/(dashboard)/layout.jac
cl import from "@jac/runtime" { Outlet, Link }

cl {
    def:pub layout() -> JsxElement {
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
}
```

### Layout Pattern (Manual)

```jac
cl import from "@jac/runtime" { Router, Routes, Route, Outlet, Link }

cl {
    def:pub DashboardLayout() -> JsxElement {
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

    def:pub DashboardHome() -> JsxElement {
        return <h2>Dashboard Overview</h2>;
    }

    def:pub DashboardSettings() -> JsxElement {
        return <h2>Settings</h2>;
    }

    def:pub DashboardProfile() -> JsxElement {
        return <h2>Profile</h2>;
    }

    def:pub app() -> JsxElement {
        return <Router>
            <Routes>
                <Route path="/dashboard" element={<DashboardLayout />}>
                    <Route index element={<DashboardHome />} />
                    <Route path="settings" element={<DashboardSettings />} />
                    <Route path="profile" element={<DashboardProfile />} />
                </Route>
            </Routes>
        </Router>;
    }
}
```

---

## Programmatic Navigation

### useNavigate Hook

```jac
cl import from "@jac/runtime" { useNavigate }

cl {
    def:pub LoginForm() -> JsxElement {
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
cl import from "@jac/runtime" { useNavigate }

cl {
    def:pub NavExample() -> JsxElement {
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

### Using AuthGuard (Recommended)

For file-based routing, use the built-in `AuthGuard` component in a layout file:

```jac
# pages/(protected)/layout.jac
cl import from "@jac/runtime" { AuthGuard, Outlet }

cl {
    def:pub layout() -> any {
        return <AuthGuard redirect="/login">
            <Outlet />
        </AuthGuard>;
    }
}
```

Any pages in the `(protected)` group will require authentication.

### Custom Protected Routes

```jac
cl import from "@jac/runtime" { useNavigate, jacIsLoggedIn }

cl {
    def:pub ProtectedRoute(props: dict) -> JsxElement {
        navigate = useNavigate();
        isAuthenticated = jacIsLoggedIn();

        can with entry {
            if not isAuthenticated {
                navigate("/login", {"replace": True});
            }
        }

        if not isAuthenticated {
            return <div>Redirecting...</div>;
        }

        return <div>{props.children}</div>;
    }
}
```

---

## Query Parameters

### Using useLocation

Access query parameters using `useLocation` and standard URL parsing:

```jac
cl import from "@jac/runtime" { useLocation, useNavigate }

cl {
    def:pub SearchResults() -> JsxElement {
        location = useLocation();
        navigate = useNavigate();

        # Parse query parameters from location.search
        searchParams = URLSearchParams(location.search);
        query = searchParams.get("q") or "";
        page = parseInt(searchParams.get("page") or "1");

        def updatePage(newPage: int) -> None {
            navigate(f"/search?q={query}&page={newPage}");
        }

        return <div>
            <h2>Results for: {query}</h2>
            <p>Page: {page}</p>

            <button
                onClick={lambda -> None { updatePage(page - 1); }}
                disabled={page <= 1}
            >
                Previous
            </button>

            <button onClick={lambda -> None { updatePage(page + 1); }}>
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
cl import from "@jac/runtime" { Router, Routes, Route, Link }

cl {
    def:pub NotFound() -> JsxElement {
        return <div className="error-page">
            <h1>404</h1>
            <p>Page not found</p>
            <Link to="/">Go Home</Link>
        </div>;
    }

    def:pub app() -> JsxElement {
        return <Router>
            <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/about" element={<About />} />
                <Route path="*" element={<NotFound />} />
            </Routes>
        </Router>;
    }
}
```

---

## Active Link Styling

Use `useLocation` with `Link` to create active link styling:

```jac
cl import from "@jac/runtime" { Link, useLocation }

cl {
    def:pub Navigation() -> JsxElement {
        location = useLocation();

        def isActive(path: str) -> bool {
            return location.pathname == path;
        }

        return <nav>
            <Link
                to="/"
                className={"nav-link " + ("active" if isActive("/") else "")}
            >
                Home
            </Link>

            <Link
                to="/about"
                className={"nav-link " + ("active" if isActive("/about") else "")}
            >
                About
            </Link>
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
cl import from "@jac/runtime" { Router, Routes, Route, Link, Outlet, useParams, useNavigate }

cl {
    # Layout
    def:pub Layout() -> JsxElement {
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
    def:pub Home() -> JsxElement {
        return <div>
            <h1>Welcome!</h1>
            <Link to="/products">Browse Products</Link>
        </div>;
    }

    def:pub Products() -> JsxElement {
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

    def:pub ProductDetail() -> JsxElement {
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

    def:pub About() -> JsxElement {
        return <div>
            <h1>About Us</h1>
            <p>We make great products.</p>
        </div>;
    }

    def:pub NotFound() -> JsxElement {
        return <div>
            <h1>404 - Not Found</h1>
            <Link to="/">Go Home</Link>
        </div>;
    }

    # App
    def:pub app() -> JsxElement {
        return <Router>
            <Routes>
                <Route path="/" element={<Layout />}>
                    <Route index element={<Home />} />
                    <Route path="products" element={<Products />} />
                    <Route path="products/:id" element={<ProductDetail />} />
                    <Route path="about" element={<About />} />
                    <Route path="*" element={<NotFound />} />
                </Route>
            </Routes>
        </Router>;
    }
}
```

---

## Routing Hooks Reference

Import from `@jac/runtime`:

```jac
cl import from "@jac/runtime" {
    Link,           # Navigation link component
    useNavigate,    # Programmatic navigation
    useParams,      # Access URL parameters
    useLocation,    # Get current location info
    Navigate,       # Redirect component
    Outlet          # Render child routes (for layouts)
}
```

| Hook | Returns | Usage |
|------|---------|-------|
| `useParams()` | `dict` | `params.id`, `params.slug` |
| `useNavigate()` | function | `navigate("/path")`, `navigate(-1)` |
| `useLocation()` | object | `location.pathname`, `location.search` |

---

## Key Takeaways

### File-Based Routing Patterns

| Pattern | File | Route |
|---------|------|-------|
| Static page | `about.jac` | `/about` |
| Index page | `users/index.jac` | `/users` |
| Dynamic param | `users/[id].jac` | `/users/:id` |
| Slug param | `posts/[slug].jac` | `/posts/:slug` |
| Catch-all | `[...notFound].jac` | `*` (404) |
| Route group | `(auth)/dashboard.jac` | `/dashboard` |
| Layout | `layout.jac` | Wraps child routes |

### Quick Reference

| Concept | Usage |
|---------|-------|
| Navigation links | `<Link to="/path">Text</Link>` |
| URL parameters | `params = useParams(); params.id` |
| Programmatic nav | `navigate("/path")` or `navigate(-1)` |
| Query strings | `useLocation().search` + `URLSearchParams` |
| Nested routes | `<Outlet />` renders child routes |
| Protected routes | Use `(auth)/` group or `AuthGuard` |
| 404 handling | `[...notFound].jac` or `path="*"` |

---

## Next Steps

- [Backend Integration](backend.md) - Connect to walker APIs
- [Authentication](auth.md) - Add protected routes
