# jac-client Reference

Complete reference for jac-client, the full-stack web development plugin for Jac.

---

## Installation

```bash
pip install jac-client
```

---

## Project Setup

### Create New Project

```bash
jac create myapp --use client
cd myapp
```

### Project Structure

```
myapp/
├── jac.toml           # Project configuration
├── main.jac           # Entry point with app() function
├── components/        # Reusable components
│   └── Button.tsx     # TypeScript components supported
└── styles/            # CSS files
    └── main.css
```

### The `.cl.jac` Convention

Files ending in `.cl.jac` are automatically treated as client-side code -- no `cl { }` wrapper needed:

```jac
# components/Header.cl.jac -- automatically client-side
def:pub Header() -> JsxElement {
    return <header>My App</header>;
}
```

This is equivalent to wrapping the contents in `cl { }` in a regular `.jac` file.

---

## Module System

Jac's module system bridges Python and JavaScript ecosystems. You can import from PyPI packages on the server and npm packages on the client using familiar syntax. The `include` statement (like C's `#include`) merges code directly, which is useful for splitting large files.

### Import Statements

```jac
# Simple import
import math;
import sys, json;

# Aliased import
import datetime as dt;

# From import
import from typing { List, Dict, Optional }
import from math { sqrt, pi, log as logarithm }

# Relative imports
import from . { sibling_module }
import from .. { parent_module }
import from .utils { helper_function }

# npm package imports (client-side)
import from react { useState, useEffect }
import from "@mui/material" { Button, TextField }

# CSS and asset imports
import "./styles.css";
import "./global.css";
```

### Include Statements

Include merges code directly (like C's `#include`):

```jac
include utils;  # Merges utils.jac into current scope
```

### Export and Visibility

```jac
# Public by default
def helper -> int { return 42; }

# Explicitly public
def:pub api_function -> None { }

# Private to module
def:priv internal_helper -> None { }

# Public walker (becomes API endpoint with jac start)
walker:pub GetUsers { }

# Private walker
walker:priv InternalProcess { }
```

---

## Server-Side Development

### Server Code Blocks

```jac
sv {
    # Server-only block
    node User {
        has id: str;
        has email: str;
    }
}

# Single-statement form (no braces)
sv import from .database { connect_db }
sv node SecretData { has value: str; }
```

### REST API with jac start

Public walkers automatically become REST endpoints:

```jac
walker:pub GetUsers {
    can get with Root entry {
        users = [-->](?:User);
        report users;
    }
}

# Endpoint: POST /GetUsers
```

Start the server:

```bash
jac start main.jac --port 8000
```

### Module Introspection

```jac
with entry {
    # List all walkers in module
    walkers = get_module_walkers();

    # List all functions
    functions = get_module_functions();
}
```

---

## Client Blocks

Use `cl { }` to define client-side (React) code:

```jac
cl {
    def:pub app() -> JsxElement {
        return <div>
            <h1>Hello, World!</h1>
        </div>;
    }
}
```

### Single-Statement Forms

For one-off client-side declarations, use the single-statement `cl` prefix:

```jac
cl import from react { useState }
cl glob THEME: str = "dark";
```

### Export Requirement

The entry `app()` function must be exported with `:pub`:

```jac
cl {
    def:pub app() -> JsxElement {  # :pub required
        return <App />;
    }
}
```

---

## Components

### Function Components

```jac
cl {
    def:pub Button(props: dict) -> JsxElement {
        return <button
            className={props.get("className", "")}
            onClick={props.get("onClick")}
        >
            {props.children}
        </button>;
    }
}
```

### Using Props

```jac
cl {
    def:pub Card(props: dict) -> JsxElement {
        return <div className="card">
            <h2>{props["title"]}</h2>
            <p>{props["description"]}</p>
            {props.children}
        </div>;
    }
}
```

### Composition

```jac
cl {
    def:pub app() -> JsxElement {
        return <div>
            <Card title="Welcome" description="Hello!">
                <Button onClick={lambda -> None { print("clicked"); }}>
                    Click Me
                </Button>
            </Card>
        </div>;
    }
}
```

---

## Reactive State

### The `has` Keyword

Inside `cl { }` blocks, `has` creates reactive state:

```jac
cl {
    def:pub Counter() -> JsxElement {
        has count: int = 0;  # Compiles to useState(0)

        return <div>
            <p>Count: {count}</p>
            <button onClick={lambda -> None { count = count + 1; }}>
                Increment
            </button>
        </div>;
    }
}
```

### How It Works

| Jac Syntax | React Equivalent |
|------------|------------------|
| `has count: int = 0` | `const [count, setCount] = useState(0)` |
| `count = count + 1` | `setCount(count + 1)` |

### Complex State

```jac
cl {
    def:pub Form() -> JsxElement {
        has name: str = "";
        has items: list = [];
        has data: dict = {"key": "value"};

        # Create new references for lists/objects
        def add_item(item: str) -> None {
            items = items + [item];  # Concatenate to new list
        }

        return <div>Form</div>;
    }
}
```

!!! warning "Immutable Updates for Lists and Objects"
    State updates must produce new references to trigger re-renders. Mutating in place will not work.

    ```jac
    # Correct - creates new list
    todos = todos + [new_item];
    todos = [t for t in todos if t["id"] != target_id];

    # Wrong - mutates in place (no re-render)
    todos.append(new_item);
    ```

---

## React Hooks

### useEffect (Automatic)

Similar to how `has` variables automatically generate `useState`, the `can with entry` and `can with exit` syntax automatically generates `useEffect` hooks:

| Jac Syntax | React Equivalent |
|------------|------------------|
| `can with entry { ... }` | `useEffect(() => { ... }, [])` |
| `async can with entry { ... }` | `useEffect(() => { (async () => { ... })(); }, [])` |
| `can with exit { ... }` | `useEffect(() => { return () => { ... }; }, [])` |
| `can with [dep] entry { ... }` | `useEffect(() => { ... }, [dep])` |
| `can with (a, b) entry { ... }` | `useEffect(() => { ... }, [a, b])` |

```jac
cl {
    def:pub DataLoader() -> JsxElement {
        has data: list = [];
        has loading: bool = True;

        # Run once on mount (async with IIFE wrapping)
        async can with entry {
            data = await fetch_data();
            loading = False;
        }

        # Cleanup on unmount
        can with exit {
            cleanup_subscriptions();
        }

        return <div>...</div>;
    }

    def:pub UserProfile(userId: str) -> JsxElement {
        has user: dict = {};

        # Re-run when userId changes (dependency array)
        async can with [userId] entry {
            user = await fetch_user(userId);
        }

        # Multiple dependencies using tuple syntax
        async can with (userId, refresh) entry {
            user = await fetch_user(userId);
        }

        return <div>{user.name}</div>;
    }
}
```

### useEffect (Manual)

You can also use `useEffect` manually by importing it from React:

```jac
cl {
    import from react { useEffect }

    def:pub DataLoader() -> JsxElement {
        has data: list = [];
        has loading: bool = True;

        # Run once on mount
        useEffect(lambda -> None {
            fetch_data();
        }, []);

        # Run when dependency changes
        useEffect(lambda -> None {
            refresh_data();
        }, [some_dep]);

        return <div>...</div>;
    }
}
```

### useContext

```jac
cl {
    import from react { createContext, useContext }

    glob AppContext = createContext(None);

    def:pub AppProvider(props: dict) -> JsxElement {
        has theme: str = "light";

        return <AppContext.Provider value={{"theme": theme}}>
            {props.children}
        </AppContext.Provider>;
    }

    def:pub ThemedComponent() -> JsxElement {
        ctx = useContext(AppContext);
        return <div className={ctx.theme}>Content</div>;
    }
}
```

### Custom Hooks

Create reusable state logic by defining functions that use `has`:

```jac
cl {
    import from react { useEffect }

    def use_local_storage(key: str, initial_value: any) -> tuple {
        has value: any = initial_value;

        useEffect(lambda -> None {
            stored = localStorage.getItem(key);
            if stored {
                value = JSON.parse(stored);
            }
        }, []);

        useEffect(lambda -> None {
            localStorage.setItem(key, JSON.stringify(value));
        }, [value]);

        return (value, lambda v: any -> None { value = v; });
    }

    def:pub Settings() -> JsxElement {
        (theme, set_theme) = use_local_storage("theme", "light");
        return <div>
            <p>Current: {theme}</p>
            <button onClick={lambda -> None { set_theme("dark"); }}>Dark</button>
        </div>;
    }
}
```

---

## Backend Integration

### Calling Walkers from Client

Use native Jac `spawn` syntax to call walkers from client code. First, import your walkers with `sv import`, then spawn them:

```jac
# Import walkers from backend
sv import from ...main { get_tasks, create_task }

cl {
    def:pub TaskList() -> JsxElement {
        has tasks: list = [];
        has loading: bool = True;

        # Fetch data on component mount
        async can with entry {
            result = root spawn get_tasks();
            if result.reports and result.reports.length > 0 {
                tasks = result.reports[0];
            }
            loading = False;
        }

        if loading {
            return <p>Loading...</p>;
        }

        return <ul>
            {[<li key={task["id"]}>{task["title"]}</li> for task in tasks]}
        </ul>;
    }
}
```

### Walker Response

The `spawn` call returns a result object:

| Property | Type | Description |
|----------|------|-------------|
| `result.reports` | list | Data reported by walker via `report` |
| `result.status` | int | HTTP status code |

### Spawn Syntax

| Syntax | Description |
|--------|-------------|
| `root spawn WalkerName()` | Spawn walker from root node |
| `root spawn WalkerName(arg=value)` | Spawn with parameters |
| `node_id spawn WalkerName()` | Spawn from specific node |

The spawn call returns a result object with:

- `result.reports` - Data reported by the walker
- `result.status` - HTTP status code

### Mutations (Create, Update, Delete)

```jac
sv import from ...main { add_task, toggle_task, delete_task }

cl {
    def:pub TaskManager() -> JsxElement {
        has tasks: list = [];

        # Create
        async def handle_add(title: str) -> None {
            result = root spawn add_task(title=title);
            if result.reports and result.reports.length > 0 {
                tasks = tasks + [result.reports[0]];
            }
        }

        # Update
        async def handle_toggle(task_id: str) -> None {
            result = root spawn toggle_task(task_id=task_id);
            if result.reports and result.reports[0]["success"] {
                tasks = tasks.map(lambda t: any -> any {
                    if t["id"] == task_id {
                        return {**t, "completed": not t["completed"]};
                    }
                    return t;
                });
            }
        }

        # Delete
        async def handle_delete(task_id: str) -> None {
            result = root spawn delete_task(task_id=task_id);
            if result.reports and result.reports[0]["success"] {
                tasks = tasks.filter(lambda t: any -> bool {
                    return t["id"] != task_id;
                });
            }
        }

        return <div>...</div>;
    }
}
```

### Error Handling Pattern

Wrap spawn calls in try/catch and track loading/error state:

```jac
cl {
    def:pub SafeDataView() -> JsxElement {
        has data: any = None;
        has loading: bool = True;
        has error: str = "";

        async can with entry {
            loading = True;
            try {
                result = root spawn get_data();
                if result.reports and result.reports.length > 0 {
                    data = result.reports[0];
                }
            } except e {
                error = f"Failed to load: {e}";
            }
            loading = False;
        }

        if loading { return <p>Loading...</p>; }
        if error {
            return <div>
                <p>{error}</p>
                <button onClick={lambda -> None { location.reload(); }}>Retry</button>
            </div>;
        }
        return <div>{JSON.stringify(data)}</div>;
    }
}
```

### Polling for Real-Time Updates

Use `setInterval` with effect cleanup for periodic data refresh:

```jac
cl {
    import from react { useEffect }

    def:pub LiveData() -> JsxElement {
        has data: any = None;

        async def fetch_data() -> None {
            result = root spawn get_live_data();
            if result.reports and result.reports.length > 0 {
                data = result.reports[0];
            }
        }

        async can with entry { await fetch_data(); }

        useEffect(lambda -> None {
            interval = setInterval(lambda -> None { fetch_data(); }, 5000);
            return lambda -> None { clearInterval(interval); };
        }, []);

        return <div>{data and <p>Last updated: {data["timestamp"]}</p>}</div>;
    }
}
```

---

## Routing

### File-Based Routing (Recommended)

jac-client supports file-based routing using a `pages/` directory:

```

myapp/
├── main.jac
└── pages/
    ├── index.jac          # /
    ├── about.jac          # /about
    ├── users/
    │   ├── index.jac      # /users
    │   └── [id].jac       # /users/:id (dynamic route)
    └── (auth)/            # Route group (parentheses)
        ├── layout.jac     # Shared layout for auth routes
        ├── login.jac      # /login
        └── signup.jac     # /signup

```

**Route mapping:**

| File | Route | Description |
|------|-------|-------------|
| `pages/index.jac` | `/` | Home page |
| `pages/about.jac` | `/about` | Static page |
| `pages/users/index.jac` | `/users` | Users list |
| `pages/users/[id].jac` | `/users/:id` | Dynamic parameter |
| `pages/[...notFound].jac` | `*` | Catch-all (404) |
| `pages/(auth)/dashboard.jac` | `/dashboard` | Route group (no URL segment) |
| `pages/layout.jac` | -- | Wraps child routes with `<Outlet />` |

Each page file exports a `page` function:

```jac
# pages/users/[id].jac
cl import from "@jac/runtime" { useParams, Link }

cl {
    def:pub page() -> JsxElement {
        params = useParams();
        return <div>
            <Link to="/users">Back</Link>
            <h1>User {params.id}</h1>
        </div>;
    }
}
```

**Route groups** organize pages without affecting the URL. A layout file can wrap them with authentication:

```jac
# pages/(auth)/layout.jac -- protects all pages in this group
cl import from "@jac/runtime" { AuthGuard, Outlet }

cl {
    def:pub layout() -> JsxElement {
        return <AuthGuard redirect="/login">
            <Outlet />
        </AuthGuard>;
    }
}
```

### Manual Routes

For manual routing, import components from `@jac/runtime`:

```jac
cl import from "@jac/runtime" { Router, Routes, Route, Link }

cl {
    def:pub app() -> JsxElement {
        return <Router>
            <nav>
                <Link to="/">Home</Link>
                <Link to="/about">About</Link>
            </nav>

            <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/about" element={<About />} />
            </Routes>
        </Router>;
    }
}
```

### URL Parameters

```jac
cl import from "@jac/runtime" { useParams }

cl {
    def:pub UserProfile() -> JsxElement {
        params = useParams();
        user_id = params["id"];

        return <div>User: {user_id}</div>;
    }

    # Route: /user/:id
}
```

### Programmatic Navigation

```jac
cl import from "@jac/runtime" { useNavigate }

cl {
    def:pub LoginForm() -> JsxElement {
        navigate = useNavigate();

        async def handle_login() -> None {
            success = await do_login();
            if success {
                navigate("/dashboard");
            }
        }

        return <button onClick={lambda -> None { handle_login(); }}>
            Login
        </button>;
    }
}
```

### Nested Routes with Outlet

```jac
cl import from "@jac/runtime" { Outlet }

# pages/layout.jac -- root layout wrapping all pages
cl {
    def:pub layout() -> JsxElement {
        return <>
            <nav>...</nav>
            <main><Outlet /></main>
            <footer>...</footer>
        </>;
    }
}

# pages/dashboard/layout.jac -- nested dashboard layout
cl {
    def:pub DashboardLayout() -> JsxElement {
        # Child routes render where Outlet is placed
        return <div>
            <Sidebar />
            <main>
                <Outlet />
            </main>
        </div>;
    }
}
```

### Routing Hooks Reference

Import from `@jac/runtime`:

| Hook | Returns | Usage |
|------|---------|-------|
| `useParams()` | dict | Access URL parameters: `params.id` |
| `useNavigate()` | function | Navigate programmatically: `navigate("/path")`, `navigate(-1)` |
| `useLocation()` | object | Current location: `location.pathname`, `location.search` |
| `Link` | component | Navigation: `<Link to="/path">Text</Link>` |
| `Outlet` | component | Render child routes in layouts |
| `AuthGuard` | component | Protect routes: `<AuthGuard redirect="/login">` |

---

## Authentication

jac-client provides built-in authentication functions via `@jac/runtime`.

### Available Functions

| Function | Returns | Description |
|----------|---------|-------------|
| `jacLogin(username, password)` | `bool` | Login user, returns True on success |
| `jacSignup(username, password)` | `dict` | Register user, returns `{success: bool, error?: str}` |
| `jacLogout()` | `void` | Clear auth token |
| `jacIsLoggedIn()` | `bool` | Check if user is authenticated |

**Additional user management operations** (available via API endpoints when using jac-scale):

| Operation | Description |
|-----------|-------------|
| Update Username | Change username via API endpoint |
| Update Password | Change password via API endpoint |
| Guest Access | Anonymous user support via `__guest__` account |

### jacLogin

```jac
cl import from "@jac/runtime" { jacLogin, useNavigate }

cl {
    def:pub LoginForm() -> any {
        has username: str = "";
        has password: str = "";
        has error: str = "";

        navigate = useNavigate();

        async def handleLogin(e: any) -> None {
            e.preventDefault();
            # jacLogin returns bool (True = success, False = failure)
            success = await jacLogin(username, password);
            if success {
                navigate("/dashboard");
            } else {
                error = "Invalid credentials";
            }
        }

        return <form onSubmit={handleLogin}>...</form>;
    }
}
```

### jacSignup

```jac
cl import from "@jac/runtime" { jacSignup }

cl {
    async def handleSignup() -> None {
        # jacSignup returns dict with success key
        result = await jacSignup(username, password);
        if result["success"] {
            # User registered and logged in
            navigate("/dashboard");
        } else {
            error = result["error"] or "Signup failed";
        }
    }
}
```

### jacLogout / jacIsLoggedIn

```jac
cl import from "@jac/runtime" { jacLogout, jacIsLoggedIn }

cl {
    def:pub NavBar() -> any {
        isLoggedIn = jacIsLoggedIn();

        def handleLogout() -> None {
            jacLogout();
            # Redirect to login
        }

        return <nav>
            {isLoggedIn and (
                <button onClick={lambda -> None { handleLogout(); }}>Logout</button>
            ) or (
                <a href="/login">Login</a>
            )}
        </nav>;
    }
}
```

### Per-User Graph Isolation

Each authenticated user gets an isolated root node:

```jac
walker:pub GetMyData {
    can get with Root entry {
        # 'root' is user-specific
        my_data = [-->](?:MyData);
        report my_data;
    }
}
```

### Single Sign-On (SSO)

Configure in `jac.toml`:

```toml
[plugins.scale.sso.google]
client_id = "your-google-client-id"
client_secret = "your-google-client-secret"
```

**SSO Endpoints:**

| Endpoint | Description |
|----------|-------------|
| `/sso/{platform}/login` | Initiate SSO login |
| `/sso/{platform}/register` | Initiate SSO registration |
| `/sso/{platform}/login/callback` | OAuth callback |

### AuthGuard for Protected Routes

Use `AuthGuard` to protect routes in file-based routing:

```jac
cl import from "@jac/runtime" { AuthGuard, Outlet }

# pages/(auth)/layout.jac
cl {
    def:pub layout() -> any {
        return <AuthGuard redirect="/login">
            <Outlet />
        </AuthGuard>;
    }
}
```

---

## Styling

### Inline Styles

```jac
cl {
    def:pub StyledComponent() -> JsxElement {
        return <div style={{"color": "blue", "padding": "10px"}}>
            Styled content
        </div>;
    }
}
```

### CSS Classes

```jac
cl {
    def:pub Card() -> JsxElement {
        return <div className="card card-primary">
            Content
        </div>;
    }
}
```

### CSS Files

```css
/* styles/main.css */
.card {
    padding: 1rem;
    border-radius: 8px;
}
```

```jac
cl {
    import "./styles/main.css";
}
```

### cn() Utility (Tailwind/shadcn)

```jac
cl {
    # cn() from local lib/utils.ts (shadcn/ui pattern)
    import from "../lib/utils" { cn }

    def:pub StylingExamples() -> JsxElement {
        has condition: bool = True;
        has hasError: bool = False;
        has isSuccess: bool = True;

        className = cn(
            "base-class",
            condition and "active",
            {"error": hasError, "success": isSuccess}
        );

        return <div>
            <div className="p-4 bg-blue-500 text-white">Tailwind</div>
            <div className={className}>Dynamic</div>
        </div>;
    }
}
```

> **Note:** The `cn()` utility is a local file you create in your project (shadcn/ui pattern):
>
> ```typescript
> // lib/utils.ts
> import { type ClassValue, clsx } from "clsx"
> import { twMerge } from "tailwind-merge"
> export function cn(...inputs: ClassValue[]) { return twMerge(clsx(inputs)) }
> ```

### JSX Syntax Reference

```jac
cl {
    def:pub JsxExamples() -> JsxElement {
        has variable: str = "text";
        has condition: bool = True;
        has items: list = [];
        has props: dict = {};

        return <div>
            <input type="text" value={variable} />

            {condition and <div>Shown if true</div>}

            {items}

            <button {...props}>Click</button>
        </div>;
    }
}
```

---

## TypeScript Integration

TypeScript/TSX files are automatically supported:

```tsx
// components/Button.tsx
import React from 'react';

interface ButtonProps {
    label: string;
    onClick: () => void;
}

export const Button: React.FC<ButtonProps> = ({ label, onClick }) => {
    return <button onClick={onClick}>{label}</button>;
};
```

```jac
cl {
    import from "./components/Button" { Button }

    def:pub app() -> JsxElement {
        return <Button label="Click" onClick={lambda -> None { }} />;
    }
}
```

---

## Configuration

### jac.toml

```toml
[project]
name = "myapp"
version = "0.1.0"

[serve]
base_route_app = "app"        # Serve at /
cl_route_prefix = "/cl"       # Client route prefix

[plugins.client]
enabled = true

# Import path aliases
[plugins.client.paths]
"@components/*" = "./components/*"
"@utils/*" = "./utils/*"

[plugins.client.configs.tailwind]
# Generates tailwind.config.js
content = ["./src/**/*.{jac,tsx,jsx}"]

# Private/scoped npm registries
[plugins.client.npm.scoped_registries]
"@mycompany" = "https://npm.pkg.github.com"

[plugins.client.npm.auth."//npm.pkg.github.com/"]
_authToken = "${NODE_AUTH_TOKEN}"

# Global npm settings
[plugins.client.npm.settings]
always-auth = true
```

### NPM Registry Configuration

The `[plugins.client.npm]` section configures custom npm registries and authentication for private or scoped packages. This generates an `.npmrc` file automatically during dependency installation, eliminating the need to manage `.npmrc` files manually.

| Key | Type | Description |
|-----|------|-------------|
| `settings` | `dict` | Global `.npmrc` key-value settings (registry, always-auth, strict-ssl, proxy, etc.) |
| `scoped_registries` | `dict` | Maps npm scopes to registry URLs |
| `auth` | `dict` | Registry authentication tokens |

**Global settings** emit arbitrary `.npmrc` key-value pairs:

```toml
[plugins.client.npm.settings]
registry = "https://registry.internal.example.com"
always-auth = true
strict-ssl = false
proxy = "http://proxy.company.com:8080"
```

**Scoped registries** map `@scope` prefixes to custom registry URLs:

```toml
[plugins.client.npm.scoped_registries]
"@mycompany" = "https://npm.pkg.github.com"
"@internal" = "https://registry.internal.example.com"
```

**Auth tokens** configure authentication for each registry. Use environment variables to avoid committing secrets:

```toml
[plugins.client.npm.auth."//npm.pkg.github.com/"]
_authToken = "${NODE_AUTH_TOKEN}"
```

The `${NODE_AUTH_TOKEN}` syntax is resolved via the existing jac.toml environment variable interpolation. If the variable is not set at config load time, it passes through as a literal `${NODE_AUTH_TOKEN}` in the generated `.npmrc`, which npm and bun also resolve natively.

The generated `.npmrc` is placed in `.jac/client/configs/` and is automatically applied when Jac installs dependencies (e.g., via `jac add --npm`, `jac start`, or `jac build`).

### Import Path Aliases

The `[plugins.client.paths]` section lets you define custom import path aliases. Aliases are automatically applied to the generated Vite `resolve.alias` and TypeScript `compilerOptions.paths`, so both bundling and IDE autocompletion work out of the box.

```toml
[plugins.client.paths]
"@components/*" = "./components/*"
"@utils/*" = "./utils/*"
"@shared" = "./shared/index"
```

With the above config, you can use aliases in your `.cl.jac` or `cl {}` code:

```jac
cl {
    import from "@components/Button" { Button }
    import from "@utils/format" { formatDate }
    import from "@shared" { constants }
}
```

| Feature | How It's Applied |
|---------|-----------------|
| **Vite** | Added to `resolve.alias` in `vite.config.js` - resolves `@components/Button` to `./components/Button` at build time |
| **TypeScript** | Added to `compilerOptions.paths` in `tsconfig.json` with `baseUrl: "."` - enables IDE autocompletion and type checking |
| **Module resolver** | The Jac compiler resolves aliases during compilation, so `import from "@components/Button"` finds the correct file |

**Wildcard patterns** (`@alias/*` -> `./path/*`) match any sub-path under the prefix. **Exact patterns** (`@alias` -> `./path`) match only the alias itself.

---

## CLI Commands

### Quick Reference

| Command | Description |
|---------|-------------|
| `jac create myapp --use client` | Create new full-stack project |
| `jac start` | Start dev server |
| `jac start --dev` | Dev server with HMR |
| `jac start --client pwa` | Start PWA (builds then serves) |
| `jac start --client desktop` | Start desktop app in dev mode |
| `jac build` | Build for production (web) |
| `jac build --client desktop` | Build desktop app |
| `jac build --client pwa` | Build PWA with offline support |
| `jac setup desktop` | One-time desktop target setup (Tauri) |
| `jac setup pwa` | One-time PWA setup (icons directory) |
| `jac add --npm <pkg>` | Add npm package |
| `jac add --npm --dev <pkg>` | Add npm dev dependency |
| `jac add --npm` | Install all npm dependencies from jac.toml |
| `jac remove --npm <pkg>` | Remove npm package |

npm dependencies can also be declared in `jac.toml`:

```toml
[dependencies.npm]
lodash = "^4.17.21"
axios = "^1.6.0"
```

For private packages from custom registries, see [NPM Registry Configuration](#npm-registry-configuration) above.

### jac build

Build a Jac application for a specific target.

```bash
jac build [filename] [--client TARGET] [-p PLATFORM]
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Path to .jac file | `main.jac` |
| `--client` | Build target (`web`, `desktop`, `pwa`) | `web` |
| `-p, --platform` | Desktop platform (`windows`, `macos`, `linux`, `all`) | Current platform |

**Examples:**

```bash
# Build web target (default)
jac build

# Build specific file
jac build main.jac

# Build PWA with offline support
jac build --client pwa

# Build desktop app for current platform
jac build --client desktop

# Build for a specific platform
jac build --client desktop --platform windows

# Build for all platforms
jac build --client desktop --platform all
```

### jac setup

One-time initialization for a build target.

```bash
jac setup <target>
```

| Option | Description |
|--------|-------------|
| `target` | Target to setup (`desktop`, `pwa`) |

**Examples:**

```bash
# Setup desktop target (creates src-tauri/ directory)
jac setup desktop

# Setup PWA target (creates pwa_icons/ directory)
jac setup pwa
```

### Extended Core Commands

jac-client extends several core commands:

| Command | Added Option | Description |
|---------|-------------|-------------|
| `jac create` | `--use client` | Create full-stack project template |
| `jac create` | `--skip` | Skip npm package installation |
| `jac start` | `--client <target>` | Client build target for dev server |
| `jac add` | `--npm` | Add npm (client-side) dependency |
| `jac add` | `--npm --dev` | Add npm dev dependency |
| `jac remove` | `--npm` | Remove npm (client-side) dependency |

---

## Multi-Target Architecture

jac-client supports building for multiple deployment targets from a single codebase.

| Target | Command | Output | Setup Required |
|--------|---------|--------|----------------|
| **Web** (default) | `jac build` | `.jac/client/dist/` | No |
| **Desktop** (Tauri) | `jac build --client desktop` | Native installers | Yes |
| **PWA** | `jac build --client pwa` | Installable web app | No |

### Web Target (Default)

Standard browser deployment using Vite:

```bash
jac build                    # Build for web
jac start --dev              # Dev server with HMR
```

**Output:** `.jac/client/dist/` with `index.html`, bundled JS, and CSS.

### Desktop Target (Tauri)

Native desktop applications using Tauri. Creates installers for Windows, macOS, and Linux.

**Prerequisites:**

- Rust/Cargo: [rustup.rs](https://rustup.rs)
- Build tools (platform-specific)

**Setup & Build:**

```bash
# 1. One-time setup (creates src-tauri/ directory)
jac setup desktop

# 2. Development with hot reload
jac start main.jac --client desktop --dev

# 3. Build installer for current platform
jac build --client desktop

# 4. Build for specific platform
jac build --client desktop --platform windows
jac build --client desktop --platform macos
jac build --client desktop --platform linux
```

**Output:** Installers in `src-tauri/target/release/bundle/`:

- Windows: `.exe` installer
- macOS: `.dmg` or `.app` bundle
- Linux: `.AppImage`, `.deb`, or `.rpm`

**Configuration:** Edit `src-tauri/tauri.conf.json` to customize window size, title, and app metadata.

### PWA Target

Progressive Web App with offline support, installability, and native-like experience.

**Features:**

- Offline support via Service Worker
- Installable on devices
- Auto-generated `manifest.json`
- Automatic icon generation (with Pillow)

**Setup & Build:**

```bash
# Optional: One-time setup (creates pwa_icons/ directory)
jac setup pwa

# Build PWA (includes manifest + service worker)
jac build --client pwa

# Development (service worker disabled for better DX)
jac start --client pwa --dev

# Production (builds PWA then serves)
jac start --client pwa
```

**Output:** Web bundle + `manifest.json` + `sw.js` (service worker)

**Configuration in jac.toml:**

```toml
[plugins.client.pwa]
theme_color = "#000000"
background_color = "#ffffff"
cache_name = "my-app-cache-v1"

[plugins.client.pwa.manifest]
name = "My App"
short_name = "App"
description = "My awesome Jac app"
```

**Custom Icons:** Add `pwa-192x192.png` and `pwa-512x512.png` to `pwa_icons/` directory.

---

## Automatic Endpoint Caching

The client runtime automatically caches responses from reader endpoints and invalidates caches when writer endpoints are called. This uses compiler-provided `endpoint_effects` metadata -- no manual cache annotations or `jacInvalidate()` calls needed.

**How it works:**

1. The compiler classifies each walker/function endpoint as a **reader** (no side effects) or **writer** (modifies state)
2. Reader responses are stored in an LRU cache (500 entries, 60-second TTL)
3. Concurrent identical requests are deduplicated (only one network call)
4. When a writer endpoint is called, all cached reader responses are automatically invalidated
5. Auth state changes (login/logout) clear the entire cache

This means spawning the same walker twice in quick succession only makes one API call, and creating/updating data automatically refreshes any cached reads.

---

## BrowserRouter (Clean URLs)

jac-client uses `BrowserRouter` for client-side routing, producing clean URLs like `/about` and `/users/123` instead of hash-based URLs like `#/about`.

For this to work in production, your server must return the SPA HTML for all non-API routes. When using `jac start`, this is handled automatically -- the server's catch-all route serves the SPA HTML for extensionless paths, excluding API prefixes (`cl/`, `walker/`, `function/`, `user/`, `static/`).

The Vite dev server is configured with `appType: 'spa'` for history API fallback during development.

---

## Build Error Diagnostics

When client builds fail, jac-client displays structured error diagnostics instead of raw Vite/Rollup output. Errors include:

- **Error codes** (`JAC_CLIENT_001`, `JAC_CLIENT_003`, etc.)
- **Source snippets** pointing to the original `.jac` file location
- **Actionable hints** and quick fix commands

| Code | Issue | Example Fix |
|------|-------|-------------|
| `JAC_CLIENT_001` | Missing npm dependency | `jac add --npm <package>` |
| `JAC_CLIENT_003` | Syntax error in client code | Check source snippet |
| `JAC_CLIENT_004` | Unresolved import | Verify import path |

To see raw error output alongside formatted diagnostics, set `debug = true` under `[plugins.client]` in `jac.toml` or set the `JAC_DEBUG=1` environment variable.

> **Note:** Debug mode is enabled by default for a better development experience. For production deployments, set `debug = false` in `jac.toml`.

---

## Build-Time Constants

Define global variables that are replaced at compile time using the `[plugins.client.vite.define]` section in `jac.toml`:

```toml
[plugins.client.vite.define]
"globalThis.API_URL" = "\"https://api.example.com\""
"globalThis.FEATURE_ENABLED" = true
"globalThis.BUILD_VERSION" = "\"1.2.3\""
```

These values are inlined by Vite during bundling. String values must be double-quoted (JSON-encoded). Access them in client code:

```jac
cl {
    def:pub Footer() -> JsxElement {
        return <p>Version: {globalThis.BUILD_VERSION}</p>;
    }
}
```

---

## Development Server

### Prerequisites

jac-client uses [Bun](https://bun.sh/) for package management and JavaScript bundling. If Bun is not installed, the CLI prompts you to install it automatically.

### Start Server

```bash
# Basic
jac start main.jac

# With hot module replacement
jac start main.jac --dev

# HMR without client bundling (API only)
jac start main.jac --dev --no-client

# Dev server for desktop target
jac start main.jac --client desktop
```

### API Proxy

In dev mode, API routes are automatically proxied:

- `/walker/*` → Backend
- `/function/*` → Backend
- `/user/*` → Backend

---

## Event Handlers

```jac
cl {
    def:pub Form() -> JsxElement {
        has value: str = "";

        return <div>
            <input
                value={value}
                onChange={lambda e: any -> None { value = e.target.value; }}
                onKeyPress={lambda e: any -> None {
                    if e.key == "Enter" { submit(); }
                }}
            />
            <button onClick={lambda -> None { submit(); }}>
                Submit
            </button>
        </div>;
    }
}
```

---

## Conditional Rendering

```jac
cl {
    def:pub ConditionalComponent() -> JsxElement {
        has show: bool = False;
        has items: list = [];

        if show {
            content = <p>Visible</p>;
        } else {
            content = <p>Hidden</p>;
        }
        return <div>
            {content}

            {show and <p>Only when true</p>}

            {[<li key={item["id"]}>{item["name"]}</li> for item in items]}
        </div>;
    }
}
```

---

## Error Handling

### JacClientErrorBoundary

`JacClientErrorBoundary` is a specialized error boundary component that catches rendering errors in your component tree, logs them, and displays a fallback UI, preventing the entire app from crashing when a descendant component fails.

### Quick Start

Import and wrap `JacClientErrorBoundary` around any subtree where you want to catch render-time errors:

```jac
cl import from "@jac/runtime" { JacClientErrorBoundary }

cl {
    def:pub app() -> any {
        return <JacClientErrorBoundary fallback={<div>Oops! Something went wrong.</div>}>
            <MainAppComponents />
        </JacClientErrorBoundary>;
    }
}
```

### Built-in Wrapping

By default, jac-client internally wraps your entire application with `JacClientErrorBoundary`. This means:

- You don't need to manually wrap your root app component
- Errors in any component are caught and handled gracefully
- The app continues to run and displays a fallback UI instead of crashing

### Props

| Prop               | Type              | Description                          |
|--------------------|-------------------|--------------------------------------|
| `fallback`         | JsxElement        | Custom fallback UI to show on error  |
| `FallbackComponent`| Component         | Show default fallback UI with error  |
| `children`         | JsxElement        | Components to protect                |

### Example with Custom Fallback

```jac
cl {
    def:pub App() -> any {
        return <JacClientErrorBoundary fallback={<div className="error">Component failed to load</div>}>
            <ExpensiveWidget />
        </JacClientErrorBoundary>;
    }
}
```

### Nested Boundaries

You can nest multiple error boundaries for fine-grained error isolation:

```jac
cl {
    def:pub App() -> any {
        return <JacClientErrorBoundary fallback={<div>App error</div>}>
            <Header />
            <JacClientErrorBoundary fallback={<div>Content error</div>}>
                <MainContent />
            </JacClientErrorBoundary>
            <Footer />
        </JacClientErrorBoundary>;
    }
}
```

If `MainContent` throws an error, only that boundary's fallback is shown, while `Header` and `Footer` continue rendering normally.

### Use Cases

1. **Isolate Failure-Prone Widgets**: Protect sections that fetch data, embed third-party code, or are unstable
2. **Per-Page Protection**: Wrap top-level pages/routes to prevent one error from failing the whole app
3. **Micro-Frontend Boundaries**: Nest boundaries around embeddables for fault isolation

---

## Memory & Persistence

### Memory Hierarchy

| Tier | Type | Implementation |
|------|------|----------------|
| L1 | Volatile | VolatileMemory (in-process) |
| L2 | Cache | LocalCacheMemory (TTL-based) |
| L3 | Persistent | SqliteMemory (default) |

### TieredMemory

Automatic read-through caching and write-through persistence:

```jac
# Objects are automatically persisted
node User {
    has name: str;
}

with entry {
    user_node = User(name="Alice");
    # Manual save
    save(user_node);
    commit();
}
```

### ExecutionContext

Manages runtime context:

- `system_root` -- System-level root node
- `user_root` -- User-specific root node
- `entry_node` -- Current entry point
- `Memory` -- Storage backend

### Anchor Management

Anchors provide persistent object references across sessions, allowing nodes and edges to be retrieved by stable identifiers after server restarts or session changes.

---

## Development Tools

### Hot Module Replacement (HMR)

```bash
# Enable with --dev flag
jac start main.jac --dev
```

Changes to `.jac` files automatically reload without restart.

### Debug Mode

```bash
jac debug main.jac
```

Provides:

- Step-through execution
- Variable inspection
- Breakpoints
- Graph visualization

---

## Related Resources

- [Fullstack Setup Tutorial](../../tutorials/fullstack/setup.md)
- [Components Tutorial](../../tutorials/fullstack/components.md)
- [State Management Tutorial](../../tutorials/fullstack/state.md)
- [Backend Integration Tutorial](../../tutorials/fullstack/backend.md)
- [Authentication Tutorial](../../tutorials/fullstack/auth.md)
- [Routing Tutorial](../../tutorials/fullstack/routing.md)
