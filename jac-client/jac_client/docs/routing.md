# Routing in Jac: Building Multi-Page Applications

> **️ Version Compatibility Warning**
>
> **For jac-client < 0.2.4:**
>
> - All `def` functions are **automatically exported** - no `:pub` needed
>
> **For jac-client >= 0.2.4:**
>
> - Functions **must be explicitly exported** with `:pub` to be importable
> - This documentation assumes version 0.2.4 or later

Learn how to create multi-page applications with client-side routing using Jac's declarative routing API.

---

## Table of Contents

- [What is Routing?](#what-is-routing)
- [Getting Started](#getting-started)
- [Basic Routing Setup](#basic-routing-setup)
- [Route Components](#route-components)
- [Navigation with Link](#navigation-with-link)
- [Programmatic Navigation with useNavigate](#programmatic-navigation-with-usenavigate)
- [URL Parameters with useParams](#url-parameters-with-useparams)
- [Current Location with useLocation](#current-location-with-uselocation)
- [Protected Routes Pattern](#protected-routes-pattern)
- [Complete Examples](#complete-examples)
- [Best Practices](#best-practices)

---

## What is Routing?

Routing allows you to create multi-page applications where different URLs display different components without page refreshes.

**Key Benefits:**

- **Single Page Application (SPA)**: No page refreshes when navigating
- **Declarative Syntax**: Define routes using JSX components
- **URL Parameters**: Dynamic routes with params like `/user/:id`
- **Browser History**: Back/forward buttons work automatically
- **Hash-based URLs**: Uses `#/path` for maximum compatibility
- **Battle-tested**: Built on industry-standard routing technology

---

## Getting Started

Import routing components from `@jac-client/utils`:

```jac
cl import from "@jac-client/utils" {
    Router,
    Routes,
    Route,
    Link,
    Navigate,
    useNavigate,
    useLocation,
    useParams
}
```

**Core Components:**

- **`<Router>`**: Container that wraps your entire application
- **`<Routes>`**: Groups multiple routes together
- **`<Route>`**: Defines a single route with path and element
- **`<Link>`**: Navigation links that don't refresh the page
- **`<Navigate>`**: Component for conditional redirects

**Hooks:**

- **`useNavigate()`**: Get navigate function for programmatic navigation
- **`useLocation()`**: Access current location and pathname
- **`useParams()`**: Access URL parameters from dynamic routes

---

## Basic Routing Setup

### Simple Three-Page App

```jac
cl import from react { useEffect }
cl import from "@jac-client/utils" { Router, Routes, Route, Link }

# Note: useState is auto-injected when using `has` variables

cl {
    # Page Components
    def Home() -> any {
        return <div>
            <h1> Home Page</h1>
            <p>Welcome to the home page!</p>
        </div>;
    }

    def About() -> any {
        return <div>
            <h1>ℹ About Page</h1>
            <p>Learn more about our application.</p>
        </div>;
    }

    def Contact() -> any {
        return <div>
            <h1> Contact Page</h1>
            <p>Email: contact@example.com</p>
        </div>;
    }

    # Main App with React Router
    def app() -> any {
        return <Router>
            <div>
                <nav>
                    <Link to="/">Home</Link>
                    {" | "}
                    <Link to="/about">About</Link>
                    {" | "}
                    <Link to="/contact">Contact</Link>
                </nav>
                <Routes>
                    <Route path="/" element={<Home />} />
                    <Route path="/about" element={<About />} />
                    <Route path="/contact" element={<Contact />} />
                </Routes>
            </div>
        </Router>;
    }
}
```

**How It Works:**

1. **`<Router>`** wraps your entire app and manages routing state
2. **`<Routes>`** contains all your route definitions
3. **`<Route>`** maps a URL path to an element (note: `element={<Component />}`)
4. **`<Link>`** creates clickable navigation links
5. URLs will be hash-based: `#/`, `#/about`, `#/contact`

**Key Points:**

- Use `element={<Home />}` to render components
- No configuration needed - just wrap and go
- Hash-based URLs work everywhere

---

## Route Components

### Router Component

The `<Router>` component is the top-level container for your app:

```jac
<Router>
    {/* Your app content */}
</Router>
```

**Features:**

- Hash-based URLs (e.g., `#/about`, `#/contact`)
- No props needed - it just works!
- Manages routing state automatically
- Works in any environment

### Routes Component

The `<Routes>` component groups multiple routes:

```jac
<Routes>
    <Route path="/" element={<Home />} />
    <Route path="/about" element={<About />} />
    <Route path="/contact" element={<Contact />} />
</Routes>
```

### Route Component

Each `<Route>` defines a single route:

```jac
<Route path="/todos" element={<TodoList />} />
```

**Props:**

- **`path`**: The URL path (must start with `/`)
- **`element`**: The JSX element to render (note: call the component with `<>`)
- **`index`**: Boolean for index routes (optional)

**Important:** Use `element={<Component />}` not `component={Component}`

### Example: Index Routes

```jac
            <Routes>
    <Route index element={<Home />} />  {/* Matches parent route */}
    <Route path="/about" element={<About />} />
            </Routes>
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
cl import from "@jac-client/utils" { Router, Routes, Route, Link }

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

### Active Link Styling with useLocation

```jac
cl import from "@jac-client/utils" { Link, useLocation }

cl {
    def Navigation() -> any {
        location = useLocation();

        def linkStyle(path: str) -> dict {
            isActive = location.pathname == path;
            return {
                "padding": "0.5rem 1rem",
                    "textDecoration": "none",
                "color": "#0066cc" if isActive else "#333",
                "fontWeight": "bold" if isActive else "normal",
                "backgroundColor": "#e3f2fd" if isActive else "transparent",
                "borderRadius": "4px"
            };
        }

        return <nav style={{"display": "flex", "gap": "1rem", "padding": "1rem"}}>
            <Link to="/" style={linkStyle("/")}>Home</Link>
            <Link to="/about" style={linkStyle("/about")}>About</Link>
            <Link to="/contact" style={linkStyle("/contact")}>Contact</Link>
        </nav>;
    }
}
```

### Link Component Features

- **No Page Refresh**: Navigation happens without reloading the page
- **Client-Side Routing**: Fast transitions between pages
- **Browser History**: Works with browser back/forward buttons
- **Styling Support**: Can be styled like any other element
- **Battle-tested**: Reliable, production-ready navigation

---

## Programmatic Navigation with useNavigate

For programmatic navigation (e.g., after form submission), use the `useNavigate()` hook:

```jac
cl import from "@jac-client/utils" { useNavigate }

cl {
    def LoginForm() -> any {
        [username, setUsername] = useState("");
        [password, setPassword] = useState("");
        navigate = useNavigate();

    async def handleLogin(e: any) -> None {
        e.preventDefault();
        success = await jacLogin(username, password);
        if success {
            navigate("/dashboard");  # Navigate after successful login
        } else {
            alert("Login failed");
        }
    }

        return <form onSubmit={handleLogin}>
            <input
                type="text"
                value={username}
                onChange={lambda e: any -> None { setUsername(e.target.value); }}
                placeholder="Username"
            />
            <input
                type="password"
                value={password}
                onChange={lambda e: any -> None { setPassword(e.target.value); }}
                placeholder="Password"
            />
            <button type="submit">Login</button>
        </form>;
    }
}
```

**useNavigate() Features:**

- **Hook-based API**: Modern React pattern
- **Type-safe**: Works seamlessly with TypeScript/Jac types
- **Replace option**: Use `navigate("/path", { replace: true })` to replace history entry

**Common Use Cases:**

- After form submission
- After authentication
- Conditional navigation based on logic
- In button onClick handlers
- Redirects after API calls

---

## URL Parameters with useParams

Access dynamic URL parameters using the `useParams()` hook:

```jac
cl import from "@jac-client/utils" { useParams, Link }

cl {
    def UserProfile() -> any {
        params = useParams();
        userId = params.id;

        return <div>
            <h1>User Profile</h1>
            <p>Viewing profile for user ID: {userId}</p>
            <Link to="/">Back to Home</Link>
        </div>;
    }

    def app() -> any {
        return <Router>
            <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/user/:id" element={<UserProfile />} />
            </Routes>
        </Router>;
    }
}
```

**URL Pattern Examples:**

- `/user/:id` → Access via `params.id`
- `/posts/:postId/comments/:commentId` → Access via `params.postId` and `params.commentId`
- `/products/:category/:productId` → Multiple parameters

---

## Current Location with useLocation

Access the current location object using `useLocation()`:

```jac
cl import from "@jac-client/utils" { useLocation }

cl {
    def CurrentPath() -> any {
        location = useLocation();

        return <div>
            <p>Current pathname: {location.pathname}</p>
            <p>Current hash: {location.hash}</p>
            <p>Search params: {location.search}</p>
        </div>;
    }
}
```

**Location Object Properties:**

- **`pathname`**: Current path (e.g., `/about`)
- **`search`**: Query string (e.g., `?page=2`)
- **`hash`**: URL hash (e.g., `#section1`)
- **`state`**: Location state passed via navigate

---

## Protected Routes Pattern

Use the `<Navigate>` component to protect routes that require authentication:

```jac
cl import from "@jac-client/utils" { Navigate, useNavigate }

cl {
    def Dashboard() -> any {
        # Check if user is logged in
        if not jacIsLoggedIn() {
            return <Navigate to="/login" />;
        }

        return <div>
            <h1> Dashboard</h1>
            <p>Welcome! You are logged in.</p>
            <p>This is protected content only visible to authenticated users.</p>
        </div>;
    }

    def LoginPage() -> any {
        navigate = useNavigate();

        async def handleLogin(e: any) -> None {
            e.preventDefault();
            username = document.getElementById("username").value;
            password = document.getElementById("password").value;
            success = await jacLogin(username, password);
            if success {
                navigate("/dashboard");
            }
        }

        return <form onSubmit={handleLogin}>
            <h2>Login</h2>
            <input id="username" type="text" placeholder="Username" />
            <input id="password" type="password" placeholder="Password" />
            <button type="submit">Login</button>
        </form>;
    }

    def app() -> any {
        return <Router>
            <Routes>
                <Route path="/" element={<HomePage />} />
                <Route path="/login" element={<LoginPage />} />
                <Route path="/dashboard" element={<Dashboard />} />
            </Routes>
        </Router>;
    }
}
```

**Protected Route Pattern:**

1. Check authentication at the start of the component
2. Return `<Navigate to="/login" />` if not authenticated
3. Return protected content if authenticated
4. Use `useNavigate()` to redirect after successful login

---

## Complete Examples

### Example 1: Simple Multi-Page App

```jac
cl import from react { useEffect }
cl import from "@jac-client/utils" { Router, Routes, Route, Link, useLocation }

# Note: useState is auto-injected when using `has` variables

cl {
    def Navigation() -> any {
        location = useLocation();

        def linkStyle(path: str) -> dict {
            isActive = location.pathname == path;
            return {
                "padding": "0.5rem 1rem",
                "textDecoration": "none",
                "color": "#0066cc" if isActive else "#333",
                "fontWeight": "bold" if isActive else "normal"
            };
        }

        return <nav style={{"padding": "1rem", "backgroundColor": "#f0f0f0"}}>
            <Link to="/" style={linkStyle("/")}>Home</Link>
            {" | "}
            <Link to="/about" style={linkStyle("/about")}>About</Link>
            {" | "}
            <Link to="/contact" style={linkStyle("/contact")}>Contact</Link>
        </nav>;
    }

    def Home() -> any {
        return <div>
            <h1> Home Page</h1>
            <p>Welcome to the home page!</p>
        </div>;
    }

    def About() -> any {
        return <div>
            <h1>ℹ About Page</h1>
            <p>Learn more about our application.</p>
        </div>;
    }

    def Contact() -> any {
        return <div>
            <h1> Contact Page</h1>
            <p>Email: contact@example.com</p>
        </div>;
    }

    def app() -> any {
        return <Router>
            <div>
                <Navigation />
                <div style={{"padding": "2rem"}}>
                    <Routes>
                        <Route path="/" element={<Home />} />
                        <Route path="/about" element={<About />} />
                        <Route path="/contact" element={<Contact />} />
                    </Routes>
                </div>
            </div>
        </Router>;
    }
}
```

### Example 2: App with URL Parameters

```jac
cl import from "@jac-client/utils" { Router, Routes, Route, Link, useParams }

cl {
    def UserList() -> any {
        users = ["Alice", "Bob", "Charlie"];

        return <div>
            <h1> User List</h1>
            {users.map(lambda user: any -> any {
                return <div key={user}>
                    <Link to={"/user/" + user}>{user}</Link>
                </div>;
            })}
        </div>;
    }

    def UserProfile() -> any {
        params = useParams();
        username = params.id;

        return <div>
            <h1> Profile: {username}</h1>
            <p>Viewing profile for {username}</p>
            <Link to="/">← Back to User List</Link>
        </div>;
    }

    def app() -> any {
        return <Router>
            <Routes>
                <Route path="/" element={<UserList />} />
                <Route path="/user/:id" element={<UserProfile />} />
            </Routes>
        </Router>;
    }
}
```

---

## Best Practices

### 1. **Use Correct Route Syntax**

```jac
#  CORRECT - Use element prop with JSX
<Route path="/" element={<Home />} />

#  WRONG - Don't pass component without JSX
<Route path="/" component={Home} />
```

### 2. **Import All Needed Components**

```jac
cl import from "@jac-client/utils" {
    Router,
    Routes,
    Route,
    Link,
    Navigate,
    useNavigate,
    useLocation,
    useParams
}
```

### 3. **Use Hooks for Navigation**

```jac
#  CORRECT - Use useNavigate hook
def MyComponent() -> any {
    navigate = useNavigate();
    navigate("/dashboard");
}

#  OLD - Global navigate() function (still works for backward compatibility)
navigate("/dashboard");
```

### 4. **Protected Routes Pattern**

```jac
#  CORRECT - Check auth in component
def ProtectedPage() -> any {
    if not jacIsLoggedIn() {
        return <Navigate to="/login" />;
    }
    return <div>Protected content</div>;
}
```

### 5. **Use Link for Navigation**

```jac
#  CORRECT - Use Link component
<Link to="/about">About</Link>

#  WRONG - Regular anchor tags cause page reload
<a href="#/about">About</a>
```

### 6. **Dynamic Routes with Parameters**

```jac
# Define route with parameter
<Route path="/user/:id" element={<UserProfile />} />

# Access parameter in component
def UserProfile() -> any {
    params = useParams();
    userId = params.id;
    return <div>User: {userId}</div>;
}
```

### 7. **Active Link Styling**

```jac
def Navigation() -> any {
    location = useLocation();

    def isActive(path: str) -> bool {
        return location.pathname == path;
    }

    return <nav>
        <Link
            to="/"
            style={{"fontWeight": "bold" if isActive("/") else "normal"}}
        >
            Home
        </Link>
    </nav>;
}
```

---

## Summary

- **Simple & Declarative**: Use `<Router>`, `<Routes>`, `<Route>` components
- **Hash-based URLs**: Uses `#/path` for maximum compatibility
- **Modern Hooks**: `useNavigate()`, `useLocation()`, `useParams()`
- **Protected Routes**: Use `<Navigate>` component for redirects
- **URL Parameters**: Dynamic routes with `:param` syntax
- **No Configuration**: Just wrap your app in `<Router>` and start routing!
- **Production-ready**: Battle-tested routing for real applications

Routing in Jac is simple, powerful, and production-ready!
