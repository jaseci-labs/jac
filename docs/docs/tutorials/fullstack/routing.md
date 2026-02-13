# Routing

Build multi-page applications with client-side routing.

> **Prerequisites**
>
> - Completed: [Authentication](auth.md)
> - Time: ~20 minutes

---

## Overview

Jac-client supports two routing approaches:

1. **File-Based Routing** (Recommended) - Convention over configuration
2. **Manual Routing** - React Router-style explicit routes

---

## File-Based Routing (Recommended)

Create a `pages/` directory with `.jac` files that automatically become routes:

```
myapp/
├── main.jac
└── pages/
    ├── index.jac          # /
    ├── about.jac          # /about
    ├── contact.jac        # /contact
    ├── users/
    │   ├── index.jac      # /users
    │   └── [id].jac       # /users/:id (dynamic route)
    └── (auth)/            # Route group (parentheses)
        ├── layout.jac     # Shared layout for auth routes
        ├── login.jac      # /login
        └── signup.jac     # /signup
```

Each page file exports a `page` function:

```jac
# pages/about.jac
cl {
    def:pub page() -> any {
        return <div>
            <h1>About Us</h1>
            <p>Learn more about our company.</p>
        </div>;
    }
}
```

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

---

## Basic Routing

### Setting Up Routes

```jac
cl import from "@jac/runtime" { Router, Routes, Route, Link }

cl {
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

**File-Based Approach:**

Create a file with brackets for dynamic segments:

```
pages/users/[id].jac  # Matches /users/:id
```

```jac
# pages/users/[id].jac
cl import from "@jac/runtime" { useParams }

cl {
    def:pub page() -> any {
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
    def:pub UserProfile() -> any {
        params = useParams();
        user_id = params["id"];

        return <div>
            <h1>User Profile</h1>
            <p>Viewing user: {user_id}</p>
        </div>;
    }

    def:pub app() -> any {
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
    def:pub layout() -> any {
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

---

## Programmatic Navigation

### useNavigate Hook

```jac
cl import from "@jac/runtime" { useNavigate }

cl {
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
cl import from "@jac/runtime" { useNavigate }

cl {
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
    def:pub ProtectedRoute(props: dict) -> any {
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

### Role-Based Access

```jac
cl import from "@jac/runtime" { Navigate, jacIsLoggedIn }

cl {
    def:pub AdminRoute(props: dict) -> any {
        has user: dict = {};

        isAuthenticated = jacIsLoggedIn();

        if not isAuthenticated {
            return <Navigate to="/login" />;
        }

        if user.get("role") != "admin" {
            return <div className="error">
                <h2>Access Denied</h2>
                <p>You need admin privileges to view this page.</p>
            </div>;
        }

        return <>{props.children}</>;
    }
}

---

## Query Parameters

### Using useLocation

Access query parameters using `useLocation` and standard URL parsing:

```jac
cl import from "@jac/runtime" { useLocation, useNavigate }

cl {
    def:pub SearchResults() -> any {
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

---

## 404 Not Found

```jac
cl import from "@jac/runtime" { Router, Routes, Route, Link }

cl {
    def:pub NotFound() -> any {
        return <div className="error-page">
            <h1>404</h1>
            <p>Page not found</p>
            <Link to="/">Go Home</Link>
        </div>;
    }

    def:pub app() -> any {
        return <Router>
            <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/about" element={<About />} />
                <Route path="*" element={<NotFound />} />
            </Routes>
        </Router>;
    }
}

---

## Active Link Styling

Use `useLocation` with `Link` to create active link styling:

```jac
cl import from "@jac/runtime" { Link, useLocation }

cl {
    def:pub Navigation() -> any {
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

---

## Complete Example

```jac
cl import from "@jac/runtime" { Router, Routes, Route, Link, Outlet, useParams, useNavigate }

cl {
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

---

## Key Takeaways

| Concept | Usage |
|---------|-------|
| File-based routing | Create files in `pages/` directory |
| Define routes | `<Route path="/..." element={<Comp />} />` |
| Navigation links | `<Link to="/path">Text</Link>` |
| URL parameters | `useParams()` returns `{param: value}` |
| Programmatic nav | `navigate("/path")` or `navigate(-1)` |
| Query strings | `useLocation().search` + `URLSearchParams` |
| Nested routes | `<Outlet />` renders child routes |
| Protected routes | Use `AuthGuard` component |
| 404 handling | `<Route path="*" element={<NotFound />} />` |

---

## Next Steps

- [Backend Integration](backend.md) - Connect to walker APIs
- [Authentication](auth.md) - Add protected routes
