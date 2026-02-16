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

    def:pub app() -> JsxElement {
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

```jac
cl {
    import from jac_client { Router, Route, useParams }

    def:pub UserProfile() -> JsxElement {
        # Get URL parameters
        params = useParams();
        user_id = params["id"];

        return <div>
            <h1>User Profile</h1>
            <p>Viewing user: {user_id}</p>
        </div>;
    }

    def:pub app() -> JsxElement {
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

### Layout Pattern

```jac
cl {
    import from jac_client { Router, Route, Outlet }

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
cl {
    import from jac_client { useNavigate }

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

### Protected Routes

```jac
cl {
    import from jac_client { useNavigate }

    def:pub ProtectedRoute(props: dict) -> JsxElement {
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

    def:pub app() -> JsxElement {
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
    def:pub AdminRoute(props: dict) -> JsxElement {
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

    def:pub SearchResults() -> JsxElement {
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

    def:pub NotFound() -> JsxElement {
        return <div className="error-page">
            <h1>404</h1>
            <p>Page not found</p>
            <Link to="/">Go Home</Link>
        </div>;
    }

    def:pub app() -> JsxElement {
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

    def:pub Navigation() -> JsxElement {
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

---

## Next Steps

- [Backend Integration](backend.md) - Connect to walker APIs
- [Authentication](auth.md) - Add protected routes
