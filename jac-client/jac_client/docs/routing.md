# Routing in Jac: Building Multi-Page Applications

Learn how to create multi-page applications with declarative routing components: `Router`, `Routes`, `Route`, and `Link`.

---

## 📚 Table of Contents

- [What is Routing?](#what-is-routing)
- [Declarative Routing API](#declarative-routing-api)
- [Basic Routing Setup](#basic-routing-setup)
- [Route Components](#route-components)
- [Navigation with Link](#navigation-with-link)
- [Programmatic Navigation](#programmatic-navigation)
- [Complete Example](#complete-example)
- [Legacy API (initRouter)](#legacy-api-initrouter)

---

## What is Routing?

Routing allows you to create multi-page applications where different URLs display different components. Jac provides a declarative routing API with React-style components for building your navigation structure.

**Key Benefits:**
- **Single Page Application (SPA)**: No page refreshes when navigating
- **Declarative Syntax**: Define routes using JSX components
- **URL-based Navigation**: Each view has its own URL
- **Browser History**: Back/forward buttons work automatically
- **Simple Integration**: Works seamlessly with Jac components

---

## Declarative Routing API

Jac provides routing components that you can import from `@jac-client/utils`:

```jac
cl import from "@jac-client/utils" { Router, Routes, Route, Link }
```

**Core Components:**
- **`<Router>`**: Container for your routing setup
- **`<Routes>`**: Groups multiple routes together
- **`<Route>`**: Defines a single route with path and component
- **`<Link>`**: Navigation links that don't refresh the page

---

## Basic Routing Setup

### Simple Three-Page App

```jac
cl import from react { useState, useEffect }
cl import from "@jac-client/utils" { Router, Routes, Route, Link }

cl {
    # Page Components
    def Home() -> any {
        return <div>
            <h1>Home Page</h1>
            <p>Welcome to the home page!</p>
        </div>;
    }

    def About() -> any {
        return <div>
            <h1>About Page</h1>
            <p>Learn more about our application.</p>
        </div>;
    }

    def Contact() -> any {
        return <div>
            <h1>Contact Page</h1>
            <p>Email: contact@example.com</p>
        </div>;
    }

    # Main App with Routing
    def app() -> any {
        return <Router defaultRoute="/">
            <div>
                <nav>
                    <Link to="/">Home</Link>
                    {" | "}
                    <Link to="/about">About</Link>
                    {" | "}
                    <Link to="/contact">Contact</Link>
                </nav>
                <Routes>
                    <Route path="/" component={Home} />
                    <Route path="/about" component={About} />
                    <Route path="/contact" component={Contact} />
                </Routes>
            </div>
        </Router>;
    }
}
```

**How It Works:**
1. **`<Router>`** wraps your entire app and manages routing state
2. **`defaultRoute`** specifies which route to show initially
3. **`<Routes>`** contains all your route definitions
4. **`<Route>`** maps a URL path to a component
5. **`<Link>`** creates clickable navigation links

---

## Route Components

### Router Component

The `<Router>` component is the top-level container for routing:

```jac
<Router defaultRoute="/">
    {/* Your app content */}
</Router>
```

**Props:**
- **`defaultRoute`**: The initial route to display (e.g., `"/"`, `"/login"`)

### Routes Component

The `<Routes>` component groups multiple routes:

```jac
<Routes>
    <Route path="/" component={Home} />
    <Route path="/about" component={About} />
    <Route path="/contact" component={Contact} />
</Routes>
```

### Route Component

Each `<Route>` defines a single route:

```jac
<Route path="/todos" component={TodoList} />
```

**Props:**
- **`path`**: The URL path (must start with `/`)
- **`component`**: The component function to render (without calling it)

### Example: Protected Routes

```jac
cl {
    def ProtectedPage() -> any {
        if not jacIsLoggedIn() {
            return <div>Please login to view this page.</div>;
        }
        return <div>
            <h1>Protected Content</h1>
            <p>You're logged in!</p>
        </div>;
    }

    def app() -> any {
        return <Router defaultRoute="/login">
            <Routes>
                <Route path="/login" component={LoginForm} />
                <Route path="/dashboard" component={ProtectedPage} />
            </Routes>
        </Router>;
    }
}
```

---

## Navigation with Link

### The Link Component

The `<Link>` component creates clickable navigation links:

```jac
<Link to="/about">About Us</Link>
```

**Props:**
- **`to`**: The destination path (e.g., `"/"`, `"/about"`)
- **`style`**: Optional CSS styles for the link
- **`className`**: Optional CSS class name

### Basic Navigation

```jac
cl {
    def Navigation() -> any {
        return <nav style={{"padding": "1rem", "backgroundColor": "#f0f0f0"}}>
            <Link to="/">Home</Link>
            {" | "}
            <Link to="/about">About</Link>
            {" | "}
            <Link to="/contact">Contact</Link>
        </nav>;
    }
}
```

### Styled Navigation

```jac
cl {
    def Navigation() -> any {
        return <nav style={{
            "display": "flex",
            "gap": "20px",
            "padding": "15px",
            "backgroundColor": "#1da1f2"
        }}>
            <Link to="/home">
                <span style={{
                    "color": "white",
                    "textDecoration": "none",
                    "fontWeight": "bold"
                }}>
                    Home
                </span>
            </Link>
            <Link to="/profile">
                <span style={{
                    "color": "white",
                    "textDecoration": "none",
                    "fontWeight": "bold"
                }}>
                    Profile
                </span>
            </Link>
        </nav>;
    }
}
```

### Link Component Features

- **No Page Refresh**: Navigation happens without reloading the page
- **Client-Side Routing**: Fast transitions between pages
- **Browser History**: Works with browser back/forward buttons
- **Styling Support**: Can be styled like any other element

---

## Programmatic Navigation

For programmatic navigation (e.g., after form submission), use the `navigate()` function:

```jac
cl {
    async def handleLogin(e: any) -> None {
        e.preventDefault();
        username = document.getElementById("username").value;
        password = document.getElementById("password").value;

        success = await jacLogin(username, password);
        if success {
            navigate("/dashboard");  # Navigate after successful login
        } else {
            alert("Login failed");
        }
    }

    def LoginForm() -> any {
        return <form onSubmit={handleLogin}>
            <input id="username" type="text" placeholder="Username" />
            <input id="password" type="password" placeholder="Password" />
            <button type="submit">Login</button>
        </form>;
    }
}
```

**Common Use Cases:**
- After form submission
- After authentication
- Conditional navigation based on logic
- In button onClick handlers

---

## Complete Example

Here's a complete example with navigation, multiple routes, and authentication:

```jac
cl import from react { useState, useEffect }
cl import from "@jac-client/utils" { Router, Routes, Route, Link }

cl {
    # Home Page
    def Home() -> any {
        return <div>
            <h1>Home Page</h1>
            <p>Welcome to the home page!</p>
            <p>This is a simple routing example.</p>
        </div>;
    }

    # About Page
    def About() -> any {
        return <div>
            <h1>About Page</h1>
            <p>Learn more about our application here.</p>
        </div>;
    }

    # Contact Page
    def Contact() -> any {
        return <div>
            <h1>Contact Page</h1>
            <p>Get in touch with us!</p>
            <p>Email: contact@example.com</p>
        </div>;
    }

    # Navigation Component
    def Navigation() -> any {
        return <nav style={{
            "padding": "1rem",
            "backgroundColor": "#f0f0f0",
            "marginBottom": "1rem"
        }}>
            <Link to="/">Home</Link>
            {" | "}
            <Link to="/about">About</Link>
            {" | "}
            <Link to="/contact">Contact</Link>
        </nav>;
    }

    # Main App with Routing
    def app() -> any {
        return <Router defaultRoute="/">
            <div>
                <Navigation />
                <div style={{"padding": "1rem"}}>
                    <Routes>
                        <Route path="/" component={Home} />
                        <Route path="/about" component={About} />
                        <Route path="/contact" component={Contact} />
                    </Routes>
                </div>
            </div>
        </Router>;
    }
}
```

---

## Best Practices

1. **Import Statement**: Always import routing components at the top
2. **Component Functions**: Pass component functions without calling them (`component={Home}`, not `component={Home()}`)
3. **Default Route**: Always specify a `defaultRoute` in `<Router>`
4. **Navigation**: Use `<Link>` for navigation, not regular `<a>` tags
5. **Protected Routes**: Check authentication inside component, not in routing config

---

## Legacy API (initRouter)

Jac also supports a legacy routing API using `initRouter()`. This API is still functional but the declarative API is recommended for new projects.

### Legacy Route Guards

The legacy API supported route guards for protecting routes:

Route guards protect routes by checking conditions (like authentication) before allowing access.

### How Legacy Guards Work

1. **Guard Function**: A function that returns `True` (allow) or `False` (deny)
2. **Automatic Check**: Router checks the guard when the route matches
3. **Access Denied**: If guard returns `False`, shows "Access Denied" instead of the component

### Legacy initRouter() Example

```jac
cl {
    def App() -> any {
        # Define routes with legacy API
        login_route = {
            "path": "/login",
            "component": lambda -> any { return LoginForm(); },
            "guard": None
        };

        todos_route = {
            "path": "/todos",
            "component": lambda -> any { return TodoApp(); },
            "guard": jacIsLoggedIn  # Protected route
        };

        # Initialize router
        routes = [login_route, todos_route];
        router = initRouter(routes, "/login");

        # Get current path
        currentPath = router.path();

        return <div>
            {Nav(currentPath)}
            {router.render()}
        </div>;
    }

    def jac_app() -> any {
        return App();
    }
}
```

**Note**: The declarative API (`<Router>`, `<Routes>`, `<Route>`) is recommended for new projects as it's more intuitive and aligns with modern React patterns.

---

## Summary

- **Declarative Routing**: Use `<Router>`, `<Routes>`, `<Route>` components for clean, JSX-based routing
- **Navigation**: Use `<Link>` component for navigation links
- **Programmatic Navigation**: Use `navigate()` function for redirects after actions
- **Protected Routes**: Check authentication inside components
- **Legacy API**: `initRouter()` is still supported but not recommended for new projects

Routing in Jac is simple, declarative, and powerful! 🚀

