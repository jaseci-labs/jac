# Routing in Jac: Building Multi-Page Applications

Learn how to use `initRouter()` to create multi-page applications with navigation, route guards, and dynamic routing.

---

## 📚 Table of Contents

- [What is Routing?](#what-is-routing)
- [Basic Routing Setup](#basic-routing-setup)
- [Route Configuration](#route-configuration)
- [Navigation](#navigation)
- [Route Guards](#route-guards)
- [Complete Example](#complete-example)
- [Advanced Patterns](#advanced-patterns)

---

## What is Routing?

Routing allows you to create multi-page applications where different URLs display different components. In Jac, routing is handled by the `initRouter()` function, which manages navigation using hash-based routing (e.g., `#/login`, `#/todos`).

**Key Benefits:**
- **Single Page Application (SPA)**: No page refreshes when navigating
- **URL-based Navigation**: Each view has its own URL
- **Browser History**: Back/forward buttons work automatically
- **Route Guards**: Protect routes with authentication checks
- **Reactive Updates**: Route changes automatically update components

---

## Basic Routing Setup

### Setting Up the Router

```jac
cl {
    def App() -> any {
        # Define routes
        routes = [
            {"path": "/", "component": lambda -> any { return HomeView(); }, "guard": None},
            {"path": "/about", "component": lambda -> any { return AboutView(); }, "guard": None}
        ];

        # Initialize router with default route
        router = initRouter(routes, "/");

        # Render the router
        return <div>
            {router.render()}
        </div>;
    }

    def jac_app() -> any {
        return App();
    }
}
```

**Key Components:**
- **`routes`**: Array of route configurations
- **`initRouter()`**: Creates the router instance
- **`router.render()`**: Renders the component for the current route

---

## Route Configuration

Each route is a dictionary with three properties:

### Route Structure

```jac
route = {
    "path": "/todos",                    # URL path
    "component": lambda -> any {         # Component to render
        return TodoApp();
    },
    "guard": jacIsLoggedIn              # Optional: route guard function
};
```

### Route Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `path` | `str` | ✅ Yes | URL path (must start with `/`) |
| `component` | `function` | ✅ Yes | Function that returns a JSX component |
| `guard` | `function` | ❌ No | Function that returns `True` if route is accessible |

### Example: Multiple Routes

```jac
cl {
    def App() -> any {
        # Define all routes
        home_route = {
            "path": "/",
            "component": lambda -> any { return HomeView(); },
            "guard": None
        };

        login_route = {
            "path": "/login",
            "component": lambda -> any { return LoginForm(); },
            "guard": None
        };

        todos_route = {
            "path": "/todos",
            "component": lambda -> any { return TodoApp(); },
            "guard": jacIsLoggedIn  # Requires authentication
        };

        profile_route = {
            "path": "/profile",
            "component": lambda -> any { return ProfileView(); },
            "guard": jacIsLoggedIn  # Requires authentication
        };

        # Combine all routes
        routes = [home_route, login_route, todos_route, profile_route];

        # Initialize router with default route
        router = initRouter(routes, "/");

        return <div>
            {Nav(router.path())}
            {router.render()}
        </div>;
    }
}
```

---

## Navigation

Jac provides multiple ways to navigate between routes.

### Using the `navigate()` Runtime Function

```jac
cl {
    async def handleLogin(e: any) -> None {
        e.preventDefault();
        success = await jacLogin(username, password);
        if success {
            navigate("/todos");  # Global navigate function
        }
    }
}
```

### Using the `Link` Component

The `Link` component creates clickable links that navigate to routes:

```jac
cl {
    def Nav() -> any {
        return <nav>
            <Link href="/">Home</Link>
            <Link href="/todos">Todos</Link>
            <Link href="/profile">Profile</Link>
        </nav>;
    }
}
```

**Link Component Features:**
- Automatic hash-based navigation
- Updates URL without page refresh
- Triggers route changes and component updates

### Complete Navigation Example

```jac
cl {
    def Nav(currentPath: str) -> any {
        return <nav style={{
            "display": "flex",
            "gap": "16px",
            "padding": "12px"
        }}>
            <Link href="/" style={{
                "color": ("#7C3AED" if currentPath == "/" else "#111827"),
                "textDecoration": "none",
                "fontWeight": ("700" if currentPath == "/" else "500")
            }}>
                Home
            </Link>
            <Link href="/todos" style={{
                "color": ("#7C3AED" if currentPath == "/todos" else "#111827"),
                "textDecoration": "none",
                "fontWeight": ("700" if currentPath == "/todos" else "500")
            }}>
                Todos
            </Link>
            <button onClick={lambda -> None {
                navigate("/login");
            }}>
                Logout
            </button>
        </nav>;
    }

    def App() -> any {
        routes = [/* routes */];
        router = initRouter(routes, "/");
        currentPath = router.path();

        return <div>
            {Nav(currentPath)}
            {router.render()}
        </div>;
    }
}
```

---

## Route Guards

Route guards protect routes by checking conditions (like authentication) before allowing access.

### How Guards Work

1. **Guard Function**: A function that returns `True` (allow) or `False` (deny)
2. **Automatic Check**: Router checks the guard when the route matches
3. **Access Denied**: If guard returns `False`, shows "Access Denied" instead of the component

### Basic Guard Example

```jac
cl {
    def App() -> any {
        public_route = {
            "path": "/public",
            "component": lambda -> any { return PublicView(); },
            "guard": None  # No guard - always accessible
        };

        protected_route = {
            "path": "/private",
            "component": lambda -> any { return PrivateView(); },
            "guard": jacIsLoggedIn  # Requires authentication
        };

        routes = [public_route, protected_route];
        router = initRouter(routes, "/");

        return <div>{router.render()}</div>;
    }
}
```

### Custom Guard Functions

You can create custom guard functions:

```jac
cl {
    # Check if user is admin
    def isAdmin() -> bool {
        if not jacIsLoggedIn() {
            return False;
        }
        user = getCurrentUser();  # Your custom function
        return user.role == "admin";
    }

    # Check if user has specific permission
    def hasPermission(permission: str) -> bool {
        if not jacIsLoggedIn() {
            return False;
        }
        user = getCurrentUser();
        return permission in user.permissions;
    }

    def App() -> any {
        admin_route = {
            "path": "/admin",
            "component": lambda -> any { return AdminView(); },
            "guard": isAdmin  # Custom guard
        };

        settings_route = {
            "path": "/settings",
            "component": lambda -> any { return SettingsView(); },
            "guard": lambda -> bool { return hasPermission("settings:edit"); }  # Inline guard
        };

        routes = [admin_route, settings_route];
        router = initRouter(routes, "/");

        return <div>{router.render()}</div>;
    }
}
```

### Redirecting on Guard Failure

You can automatically redirect when a guard fails:

```jac
cl {
    def protectedGuard() -> bool {
        if not jacIsLoggedIn() {
            navigate("/login");  # Redirect to login
            return False;
        }
        return True;
    }

    def App() -> any {
        protected_route = {
            "path": "/todos",
            "component": lambda -> any { return TodoApp(); },
            "guard": protectedGuard
        };

        routes = [protected_route];
        router = initRouter(routes, "/login");

        return <div>{router.render()}</div>;
    }
}
```

---

## Complete Example

Here's a complete routing example from the Todo App:

```jac
cl {
    def Nav(route: str) -> any {
        if not jacIsLoggedIn() or route == "/login" or route == "/signup" {
            return None;
        }
        return <nav style={{
            "background": "#FFFFFF",
            "padding": "12px",
            "boxShadow": "0 1px 2px rgba(17,24,39,0.06)"
        }}>
            <div style={{
                "maxWidth": "960px",
                "margin": "0 auto",
                "display": "flex",
                "gap": "16px",
                "alignItems": "center"
            }}>
                <Link href="/todos" style={{"textDecoration": "none"}}>
                    <span style={{
                        "color": "#111827",
                        "fontWeight": "800",
                        "fontSize": "18px"
                    }}>📝 My Todos</span>
                </Link>
                <button
                    onClick={logout_action}
                    style={{
                        "marginLeft": "auto",
                        "padding": "8px 12px",
                        "background": "#FFFFFF",
                        "color": "#374151",
                        "border": "1px solid #E5E7EB",
                        "borderRadius": "18px",
                        "cursor": "pointer"
                    }}
                >
                    Logout
                </button>
            </div>
        </nav>;
    }

    def App() -> any {
        # Define routes
        login_route = {
            "path": "/login",
            "component": lambda -> any { return LoginForm(); },
            "guard": None
        };

        signup_route = {
            "path": "/signup",
            "component": lambda -> any { return SignupForm(); },
            "guard": None
        };

        todos_route = {
            "path": "/todos",
            "component": lambda -> any { return TodoApp(); },
            "guard": jacIsLoggedIn  # Protected route
        };

        # Initialize router
        routes = [login_route, signup_route, todos_route];
        router = initRouter(routes, "/login");  # Default to login page

        # Get current path for navigation
        currentPath = router.path();

        return <div style={{
            "minHeight": "95vh",
            "background": "#F7F8FA",
            "padding": "24px"
        }}>
            {Nav(currentPath)}
            <div style={{
                "maxWidth": "960px",
                "margin": "0 auto",
                "padding": "20px"
            }}>
                {router.render()}
            </div>
        </div>;
    }

    def jac_app() -> any {
        return App();
    }
}
```

---

## Advanced Patterns

### Getting Current Route

Use `router.path()` to get the current route:

```jac
cl {
    def App() -> any {
        routes = [/* routes */];
        router = initRouter(routes, "/");

        currentPath = router.path();  # Get current route

        # Use currentPath for conditional rendering
        return <div>
            {Nav(currentPath)}
            {router.render()}
        </div>;
    }
}
```

### Programmatic Navigation

Navigate programmatically from anywhere:

```jac
cl {
    async def handleLogin(e: any) -> None {
        e.preventDefault();
        success = await jacLogin(username, password);
        if success {
            router = __jacReactiveContext.router;
            if router {
                router.navigate("/todos");
            }
        }
    }

    def logout_action() -> None {
        jacLogout();
        navigate("/login");  # Or use router.navigate()
    }
}
```

### Dynamic Route Parameters (Future)

While Jac's router uses hash-based routing without path parameters, you can pass state through navigation:

```jac
cl {
    def navigateToTodo(id: str) -> None {
        # Store ID in state before navigating
        setTodoId(id);
        navigate("/todo-detail");
    }

    def TodoDetailView() -> any {
        id = todoId();
        todo = getTodoById(id);  # Fetch todo by ID
        return <div>{todo.text}</div>;
    }
}
```

### 404 Handling

The router automatically shows a 404 message if no route matches:

```jac
# If user navigates to /unknown-route
# Router automatically renders: "404 - Route not found: /unknown-route"
```

---

## Best Practices

1. **Default Route**: Always provide a sensible default route in `initRouter()`
2. **Route Guards**: Use guards for protected routes instead of checking in components
3. **Link Components**: Use `Link` component instead of manual hash manipulation
4. **Guard Functions**: Keep guard functions simple and focused
5. **Navigation**: Use `navigate()` for programmatic navigation
6. **Current Path**: Use `router.path()` for conditional rendering based on current route

---

## Summary

- **Routing**: Use `initRouter()` to create multi-page applications
- **Routes**: Configure routes with `path`, `component`, and optional `guard`
- **Navigation**: Use `Link` component or `navigate()` function
- **Guards**: Protect routes with guard functions
- **Current Route**: Access current route with `router.path()`

Routing in Jac is simple, reactive, and powerful! 🚀

