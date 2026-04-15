# jac-client Reference

jac-client adds client-side compilation to Jac so you can write React-style UI components using `to cl:` section headers (or `.cl.jac` files). The compiler separates your code automatically -- server-side logic compiles to Python, while client-side components compile to JavaScript with React as the rendering engine.

You also get project scaffolding (`jac create --use client`), npm dependency management, a Vite-powered dev server with HMR, and automatic HTTP bridge generation so your client components can call server walkers without manual API wiring. This reference covers installation, project structure, the module system, component authoring, and build configuration.

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

Files ending in `.cl.jac` are automatically treated as client-side code -- no `to cl:` header needed:

```jac
# components/Header.cl.jac -- automatically client-side
def:pub Header() -> JsxElement {
    return <header>My App</header>;
}
```

This is equivalent to starting a regular `.jac` file with a `to cl:` section header.

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

### Server Sections

```jac
to sv:

# Server-only section
node User {
    has email: str;
}

# Single-statement form (no header, no braces)
sv import from .database { connect_db }
sv node SecretData { has value: str; }
```

> **Note on `sv import` between two server modules.** When both the importer and the importee are server-context modules running as separate microservices, `sv import` generates HTTP client stubs instead of pulling the provider into the consumer's process. The same source also works as a monolith. See [Microservice Interop (sv-to-sv)](jac-scale.md#microservice-interop-sv-to-sv) in the jac-scale reference for details.

### REST API with jac start

Public walkers automatically become REST endpoints:

```jac
walker:pub GetUsers {
    can get with Root entry {
        users = [-->][?:User];
        report users;
    }
}

# Endpoint: POST /walker/GetUsers
```

Start the server:

```bash
jac start main.jac --port 8000
```

### Typed Object Passing

Objects crossing the server/client boundary are automatically serialized and hydrated as typed instances. You can return typed objects directly from server functions and walkers instead of manually constructing dicts:

```jac
node Task {
    has title: str,
        done: bool = False;
}

# Server: return typed objects directly
def:pub get_tasks -> list[Task] {
    return [root()-->][?:Task];
}

def:pub create_task(title: str) -> Task {
    task = root() ++> Task(title=title);
    return task[0];
}

# Client: receives hydrated Task instances
to cl:

sv import from .main { get_tasks, create_task }

def:pub app -> JsxElement {
    has tasks: list = [];

    async can with entry {
        tasks = await get_tasks();  # list of Task objects
    }

    async def addTask(title: str) -> None {
        task = await create_task(title);  # a Task object
        tasks = tasks + [task];
    }

    return <div>
        {[<span key={t.title}>{t.title} - {t.done}</span> for t in tasks]}
    </div>;
}
```

The compiler generates JavaScript class stubs with `__from_wire`/`__to_wire` methods for each type that crosses the boundary. This works for:

- **`obj` types** -- fields are hydrated recursively (nested objects are also typed)
- **`node` types** -- same as obj, plus graph identity is preserved (access via `jid(node)`)
- **`enum` types** -- emitted as frozen JavaScript objects
- **`list[T]` returns** -- each element is individually hydrated
- **Bidirectional** -- typed objects sent as function arguments or walker `has` fields are serialized with `__type__` metadata and deserialized on the server

Walker reports also benefit from typed hydration:

```jac
walker:pub create_todo {
    has text: str;

    can create with Root entry {
        new_todo = here ++> Task(title=self.text);
        report new_todo;  # Client receives a typed Task, not a raw dict
    }
}
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

## Client Sections

Use the `to cl:` section header to tag every following module-level element as client-side (React) code:

```jac
to cl:

def:pub app() -> JsxElement {
    return <div>
        <h1>Hello, World!</h1>
    </div>;
}
```

A section header applies until the next `to X:` header or end of file. You can switch back with `to sv:`, `to na:`, or end the file.

### Single-Statement Forms

For one-off client-side declarations, use the single-statement `cl` prefix:

```jac
cl import from react { useState }
cl glob THEME: str = "dark";
```

This also works for component definitions -- the preferred shorthand for a single tagged declaration inside a mostly-server file:

```jac
cl def:pub app -> JsxElement {
    has count: int = 0;
    return <div>Count: {count}</div>;
}
```

### Braced Blocks (legacy / inner-scope)

The older `cl { ... }` braced block still works and is useful for **inner-scope overrides** inside a function or class, but at module scope it emits **W0064** pointing at the section-header form. In `.cl.jac` files or after a `to cl:` header, no wrapper is needed at all.

### Export Requirement

The entry `app()` function must be exported with `:pub`:

```jac
to cl:

def:pub app() -> JsxElement {  # :pub required
    return <App />;
}
```

---

## Components

### Function Components

```jac
to cl:

def:pub Button(props: dict) -> JsxElement {
    return <button
        className={props.get("className", "")}
        onClick={props.get("onClick")}
    >
        {props.children}
    </button>;
}
```

### Using Props

```jac
to cl:

def:pub Card(props: dict) -> JsxElement {
    return <div className="card">
        <h2>{props["title"]}</h2>
        <p>{props["description"]}</p>
        {props.children}
    </div>;
}
```

### Composition

```jac
to cl:

def:pub app() -> JsxElement {
    return <div>
        <Card title="Welcome" description="Hello!">
            <Button onClick={lambda -> None { print("clicked"); }}>
                Click Me
            </Button>
        </Card>
    </div>;
}
```

---

## Reactive State

### The `has` Keyword

Inside client-tagged code (`to cl:` sections, `.cl.jac` files, or `cl { }` blocks), `has` creates reactive state:

```jac
to cl:

def:pub Counter() -> JsxElement {
    has count: int = 0;  # Compiles to useState(0)

    return <div>
        <p>Count: {count}</p>
        <button onClick={lambda -> None { count = count + 1; }}>
            Increment
        </button>
    </div>;
}
```

### How It Works

| Jac Syntax | React Equivalent |
|------------|------------------|
| `has count: int = 0` | `const [count, setCount] = useState(0)` |
| `count = count + 1` | `setCount(count + 1)` |

### Complex State

```jac
to cl:

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
to cl:

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
```

### useEffect (Manual)

You can also use `useEffect` manually by importing it from React:

```jac
to cl:

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
```

### useContext

```jac
to cl:

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
```

### Custom Hooks

Create reusable state logic by defining functions that use `has`:

```jac
to cl:

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
```

---

## Backend Integration

### Calling Walkers from Client

Use native Jac `spawn` syntax to call walkers from client code. First, import your walkers with `sv import`, then spawn them:

```jac
# Import walkers from backend
sv import from ...main { get_tasks, create_task }

to cl:

def:pub TaskList() -> JsxElement {
    has tasks: list = [];
    has loading: bool = True;

    # Fetch data on component mount
    async can with entry {
        result = root() spawn get_tasks();
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
| `root() spawn WalkerName()` | Spawn walker from root node |
| `root() spawn WalkerName(arg=value)` | Spawn with parameters |
| `node_id spawn WalkerName()` | Spawn from specific node |

The spawn call returns a result object with:

- `result.reports` - Data reported by the walker
- `result.status` - HTTP status code

### Mutations (Create, Update, Delete)

```jac
sv import from ...main { add_task, toggle_task, delete_task }

to cl:

def:pub TaskManager() -> JsxElement {
    has tasks: list = [];

    # Create
    async def handle_add(title: str) -> None {
        result = root() spawn add_task(title=title);
        if result.reports and result.reports.length > 0 {
            tasks = tasks + [result.reports[0]];
        }
    }

    # Update
    async def handle_toggle(task_id: str) -> None {
        result = root() spawn toggle_task(task_id=task_id);
        if result.reports and result.reports[0]["success"] {
            tasks = [
                {**t, "completed": not t["completed"]} if t["id"] == task_id else t
                for t in tasks
            ];
        }
    }

    # Delete
    async def handle_delete(task_id: str) -> None {
        result = root() spawn delete_task(task_id=task_id);
        if result.reports and result.reports[0]["success"] {
            tasks = [t for t in tasks if t["id"] != task_id];
        }
    }

    return <div>...</div>;
}
```

### Error Handling Pattern

Wrap spawn calls in try/catch and track loading/error state:

```jac
to cl:

def:pub SafeDataView() -> JsxElement {
    has data: any = None;
    has loading: bool = True;
    has error: str = "";

    async can with entry {
        loading = True;
        try {
            result = root() spawn get_data();
            if result.reports and result.reports.length > 0 {
                data = result.reports[0];
            }
        } except Exception as e {
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
```

### Polling for Real-Time Updates

Use `setInterval` with effect cleanup for periodic data refresh:

```jac
to cl:

import from react { useEffect }

def:pub LiveData() -> JsxElement {
    has data: any = None;

    async def fetch_data() -> None {
        result = root() spawn get_live_data();
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

to cl:

def:pub page() -> JsxElement {
    params = useParams();
    return <div>
        <Link to="/users">Back</Link>
        <h1>User {params.id}</h1>
    </div>;
}
```

**Route groups** organize pages without affecting the URL. A layout file can wrap them with authentication:

```jac
# pages/(auth)/layout.jac -- protects all pages in this group
cl import from "@jac/runtime" { AuthGuard, Outlet }

to cl:

def:pub layout() -> JsxElement {
    return <AuthGuard redirect="/login">
        <Outlet />
    </AuthGuard>;
}
```

### Manual Routes

For manual routing, import components from `@jac/runtime`:

```jac
cl import from "@jac/runtime" { Router, Routes, Route, Link }

to cl:

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
```

### URL Parameters

```jac
cl import from "@jac/runtime" { useParams }

to cl:

def:pub UserProfile() -> JsxElement {
    params = useParams();
    user_id = params["id"];

    return <div>User: {user_id}</div>;
}

# Route: /user/:id
```

### Programmatic Navigation

```jac
cl import from "@jac/runtime" { useNavigate }

to cl:

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
```

### Nested Routes with Outlet

```jac
cl import from "@jac/runtime" { Outlet }

to cl:

# pages/layout.jac -- root layout wrapping all pages
def:pub layout() -> JsxElement {
    return <>
        <nav>...</nav>
        <main><Outlet /></main>
        <footer>...</footer>
    </>;
}

# pages/dashboard/layout.jac -- nested dashboard layout
def:pub DashboardLayout() -> JsxElement {
    # Child routes render where Outlet is placed
    return <div>
        <Sidebar />
        <main>
            <Outlet />
        </main>
    </div>;
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

to cl:

def:pub LoginForm() -> JsxElement {
    has username: str = "";
    has password: str = "";
    has error: str = "";

    navigate = useNavigate();

    async def handleLogin(e: FormEvent) -> None {
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
```

### jacSignup

```jac
cl import from "@jac/runtime" { jacSignup }

to cl:

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
```

### jacLogout / jacIsLoggedIn

```jac
cl import from "@jac/runtime" { jacLogout, jacIsLoggedIn }

to cl:

def:pub NavBar() -> JsxElement {
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
```

### Per-User Graph Isolation

Each authenticated user gets an isolated root node:

```jac
walker:pub GetMyData {
    can get with Root entry {
        # 'here' is the user-specific root node
        my_data = [-->][?:MyData];
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

to cl:

# pages/(auth)/layout.jac
def:pub layout() -> JsxElement {
    return <AuthGuard redirect="/login">
        <Outlet />
    </AuthGuard>;
}
```

---

## Styling

### Inline Styles

```jac
to cl:

def:pub StyledComponent() -> JsxElement {
    return <div style={{"color": "blue", "padding": "10px"}}>
        Styled content
    </div>;
}
```

### CSS Classes

```jac
to cl:

def:pub Card() -> JsxElement {
    return <div className="card card-primary">
        Content
    </div>;
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
to cl:

import "./styles/main.css";
```

### cn() Utility (Tailwind/shadcn)

```jac
to cl:

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
```

> **Note:** The `cn()` utility is a local file you create in your project. You can write it entirely in Jac (no TypeScript needed):
>
> ```jac
> # lib/utils.cl.jac
> import from "clsx" { clsx }
> import from "tailwind-merge" { twMerge }
>
> def:pub cn(inputs: Any) -> str {
>     args = [].slice.call(arguments);
>     return twMerge(clsx(args));
> }
> ```
>
> Requires `clsx` and `tailwind-merge` in `[dependencies.npm]`.

### JSX Syntax Reference

```jac
to cl:

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
to cl:

import from "./components/Button" { Button }

def:pub app() -> JsxElement {
    return <Button label="Click" onClick={lambda -> None { }} />;
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
to cl:

import from "@components/Button" { Button }
import from "@utils/format" { formatDate }
import from "@shared" { constants }
```

| Feature | How It's Applied |
|---------|-----------------|
| **Vite** | Added to `resolve.alias` in `vite.config.js` - resolves `@components/Button` to `./components/Button` at build time |
| **TypeScript** | Added to `compilerOptions.paths` in `tsconfig.json` with `baseUrl: "."` - enables IDE autocompletion and type checking |
| **Module resolver** | The Jac compiler resolves aliases during compilation, so `import from "@components/Button"` finds the correct file |

**Wildcard patterns** (`@alias/*` -> `./path/*`) match any sub-path under the prefix. **Exact patterns** (`@alias` -> `./path`) match only the alias itself.

### Vite Plugin Integration

The `[plugins.client.vite]` section lets you extend the Vite build with any npm-based Vite plugin. All external tool integration follows the same two-step pattern:

1. Declare the npm package in `[dependencies.npm]`
2. Wire the plugin in `[plugins.client.vite]`

| Key | Type | Description |
|-----|------|-------------|
| `plugins` | list of strings | Vite plugin function calls, written as JS expressions |
| `lib_imports` | list of strings | ES import statements for each plugin |

These are written directly into the generated `vite.config.js` - `lib_imports` become top-level imports and `plugins` populate the `plugins: []` array.

**Example: Tailwind CSS v4**

```bash
jac add --npm --dev tailwindcss @tailwindcss/vite
```

```toml
[plugins.client.vite]
plugins = ["tailwindcss()"]
lib_imports = ["import tailwindcss from '@tailwindcss/vite'"]

[dependencies.npm.dev]
tailwindcss = "^4.0.0"
"@tailwindcss/vite" = "^4.0.0"
```

Then import Tailwind in your entry CSS and use `className=` in components:

```jac
to cl:

import "./assets/main.css";  # contains: @import "tailwindcss";

def:pub app() -> JsxElement {
    return <div className="min-h-screen bg-gray-100 p-8">
        <h1 className="text-3xl font-bold">Hello</h1>
    </div>;
}
```

**Example: Multiple plugins**

```toml
[plugins.client.vite]
plugins = ["tailwindcss()", "myPlugin({ option: 'value' })"]
lib_imports = [
    "import tailwindcss from '@tailwindcss/vite'",
    "import myPlugin from 'my-vite-plugin'"
]
```

#### Build Options

Override Vite build options via `[plugins.client.vite.build]`:

```toml
[plugins.client.vite.build]
sourcemap = true
minify = "esbuild"
outDir = "dist"
```

#### Dev Server Options

Configure the Vite dev server via `[plugins.client.vite.server]`:

```toml
[plugins.client.vite.server]
port = 3000
open = true
host = "0.0.0.0"
cors = true
```

### Generic Config File Generation

`[plugins.client.configs]` generates `<name>.config.js` files in `.jac/client/configs/` from TOML. Use this for tools that expect a `*.config.js` file - PostCSS, Tailwind v3, ESLint, Prettier, etc. No standalone config files needed in your project root.

**Example: Tailwind CSS v3 + PostCSS**

```bash
jac add --npm --dev tailwindcss autoprefixer postcss
```

```toml
[plugins.client.configs.postcss]
plugins = ["tailwindcss", "autoprefixer"]

[plugins.client.configs.tailwind]
content = ["./**/*.jac", "./**/*.cl.jac", "./.jac/client/**/*.{js,jsx,ts,tsx}"]
plugins = []

[plugins.client.configs.tailwind.theme.extend.colors]
primary = "#3490dc"

[dependencies.npm.dev]
tailwindcss = "^3.4.0"
autoprefixer = "^10.4.0"
postcss = "^8.4.0"
```

This generates `.jac/client/configs/postcss.config.js` and `.jac/client/configs/tailwind.config.js` automatically.

| Use case | Config section |
|---|---|
| Vite plugins (Tailwind v4, custom plugins) | `[plugins.client.vite]` |
| PostCSS / Tailwind v3 / ESLint / Prettier | `[plugins.client.configs]` |

### shadcn/ui Configuration

The `[jac-shadcn]` section configures the shadcn/ui component system. This controls the visual style, color theme, font, and border radius used by shadcn components in your project.

```toml
[jac-shadcn]
style = "nova"            # Component style variant
baseColor = "neutral"     # Base color palette
theme = "amber"           # Accent color theme
font = "inter"            # Font family
radius = "default"        # Border radius preset
menuAccent = "subtle"     # Menu accent style
menuColor = "default"     # Menu color scheme
registry = "https://jac-shadcn.jaseci.org"  # Component registry URL
```

| Key | Description | Examples |
|-----|-------------|---------|
| `style` | Component style variant | `"nova"`, `"default"` |
| `baseColor` | Base neutral color palette | `"neutral"`, `"slate"`, `"zinc"`, `"gray"` |
| `theme` | Accent/primary color | `"amber"`, `"blue"`, `"green"`, `"red"` |
| `font` | Typography font family | `"inter"`, `"geist"`, `"system"` |
| `radius` | Border radius preset | `"default"`, `"sm"`, `"md"`, `"lg"`, `"none"` |
| `registry` | shadcn component registry URL | Custom registry for Jac-compatible components |

shadcn components use semantic color tokens (`bg-primary`, `text-foreground`, `border-border`) that automatically adapt to the configured theme. See the [NPM Packages & UI Libraries tutorial](../../tutorials/fullstack/npm-and-libraries.md) for component authoring patterns.

### TypeScript Configuration

Override the generated `tsconfig.json` via `[plugins.client.ts]`:

```toml
[plugins.client.ts.compilerOptions]
strict = false
target = "ES2022"
noUnusedLocals = false
noUnusedParameters = false

[plugins.client.ts]
include = ["components/**/*", "lib/**/*", "types/**/*"]
```

`compilerOptions` values override defaults. `include` and `exclude` replace defaults entirely when provided.

### App Metadata

Set HTML `<head>` tags for the client app via `[plugins.client.app_meta_data]`:

```toml
[plugins.client.app_meta_data]
title = "My App"
description = "App description"
keywords = "jac, fullstack"
author = "Your Name"
theme_color = "#3490dc"
robots = "index, follow"
og_title = "My App"
og_description = "App description"
og_image = "/assets/og-image.png"
```

### API Base URL

Set the backend API base URL used by client-side requests:

```toml
[plugins.client.api]
base_url = "https://api.example.com"
```

Useful for production deployments where the API lives on a different domain than the frontend.

### Minification

Control minification in production builds:

```toml
[plugins.client]
minify = true
```

Defaults to `true` for `jac build` and `false` for `jac start --dev`.

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

**Core Dependencies**: The `jac-client-node` and `@jac-client/dev-deps` packages are required for all jac-client projects. If missing or outdated in `jac.toml`, they are automatically added or updated when the config is loaded (e.g., during `jac start`).

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

For desktop builds, the **client-only** variant (web bundle inside a Tauri shell, no bundled sidecar) is enabled by setting `client_only = true` under `[desktop]` in `jac.toml` rather than via a CLI flag -- see [Desktop Target → Client-Only Mode](#client-only-mode). In all desktop builds the build environment sets `JAC_BUILD=1` so import-time server starts stay inert.

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

Native desktop applications using Tauri. The full-stack Jac app -- frontend bundle, Jac runtime, and your backend walkers/functions -- ships as a single installer for Windows, macOS, and Linux. End users do not need Python or Node installed.

**Architecture:**

A desktop build produces a Tauri shell that hosts a webview pointed at a bundled **sidecar** -- a PyInstaller-frozen executable containing Python, jaclang, jac-client, your `.jac` sources, and any configured plugins. On launch, Tauri spawns the sidecar on a free local port, reads `JAC_SIDECAR_PORT=<port>` from its stdout, and injects the resulting URL into the webview before any page JavaScript runs. The webview is the same client bundle the web target produces; the sidecar is the same backend `jac start` would run, just frozen.

**Prerequisites:**

- Rust/Cargo: [rustup.rs](https://rustup.rs)
- Platform build tools (Visual Studio Build Tools on Windows, Xcode Command Line Tools on macOS, `webkit2gtk` + `libssl` + `librsvg` on Linux)

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

- Windows: `.exe` installer (NSIS) or `.msi`
- macOS: `.dmg` or `.app` bundle
- Linux: `.AppImage`, `.deb`, or `.rpm`

**Configuration:** Window size, title, identifier, and other Tauri metadata are configured under `[desktop]` in `jac.toml` (the build regenerates `src-tauri/tauri.conf.json` from it on every build):

```toml
[desktop]
name = "MyApp"
identifier = "com.example.myapp"
version = "1.0.0"

[desktop.window]
title = "MyApp"
width = 1200
height = 800
min_width = 800
min_height = 600

[desktop.platforms]
windows = true
macos = true
linux = true
```

**Python Dependencies:**

Desktop builds automatically install and bundle Python dependencies from `jac.toml`:

```toml
[dependencies]
websockets = ">=12.0"
httpx = ">=0.27.0"
```

These are auto-installed into the bundling environment before PyInstaller runs -- no manual `pip install` needed. During the build, `JAC_BUILD=1` is set in the environment so any Jac code that auto-starts a server at import time stays inert (preventing port conflicts and unnecessary work).

**Plugin Bundling:**

Desktop builds bundle Jac plugins into the sidecar executable using PyInstaller's `collect_all()` plus `importlib.metadata.requires()` for transitive dependency discovery. Configure which plugins to include via `[desktop.plugins]` in `jac.toml`:

```toml
[desktop.plugins]
jac_scale = true   # jac-scale: FastAPI server, auth, persistence (default: true)
byllm = true       # byllm/litellm for LLM support (default: true)
jac_coder = true   # jac-coder: AI coding features (default: true)
jac_mcp = true     # jac-mcp: MCP server integration (default: true)
```

**Notes:**

- Plugins must be installed (`pip install jac-scale byllm jac-coder jac-mcp`) before building -- the build collects them from your current Python environment.
- `jac_client` itself is **always** bundled as a core package regardless of this config, because the sidecar entry point imports it directly. Setting `jac_client = false` is ignored.
- The build excludes build-artifact directories (`src-tauri/`, `node_modules/`, `dist/`, `.jac/client/`) when collecting `.jac` files, so rebuilds do not recursively nest previous sidecar bundles.

**Bundled Jac Sources:**

All `.jac` files, `jac.toml`, and the `assets/` directory are copied into `src-tauri/jac/` and shipped as Tauri bundle resources. At runtime, the sidecar looks up `main.jac` in this bundled location first, falling back to parent directories. This is what makes desktop installs fully self-contained.

#### Data Persistence on Installed Builds

Installed desktop apps live in **read-only** locations -- `/usr/lib/`, `/opt/`, `C:\Program Files\`, or an AppImage's `/tmp/.mount_AppXXX/` squashfs. The Jac runtime and jac-scale write to disk relative to the working directory by default (the SQLite database `database.db`, the `.jac/data/` directory, session files), and those writes will fail or crash on a read-only mount.

The sidecar resolves this at startup, **before** importing any Jac module, by setting the `JAC_DATA_PATH` environment variable to a writable location and `chdir`-ing into it. The Jac runtime's `get_db_path()` and jac-scale's config loader both honor this variable.

**Default fallback chain** (the sidecar picks the first one that exists or can be created and passes a touch/unlink probe):

| Platform | Default | First fallback | Second fallback |
|----------|---------|----------------|-----------------|
| Linux / macOS | `~/.local/share/jac-app` | `~/.jac-app` | `/tmp/jac-app-{uid}` |
| Windows | `%LOCALAPPDATA%\jac-app` | `~/AppData/Local/jac-app` | `%TEMP%\jac-app` |

**Override the default** by passing `--data-path` to the sidecar (useful when running the bundled sidecar binary by hand for debugging, or when wiring it into a launcher you control):

```bash
./src-tauri/binaries/jac-sidecar --data-path /var/lib/myapp
```

You can also export `JAC_DATA_PATH` before launching the app to point at a custom location for that run. The path you choose must be writable by the user running the app -- the sidecar will probe it and fail loudly if it cannot.

**AppImage-specific environment cleanup:** AppImage runtimes inject `PYTHONHOME`, `PYTHONPATH`, and `PYTHONDONTWRITEBYTECODE` into the environment, which break the bundled Python interpreter inside the sidecar. The generated Tauri `main.rs` strips these variables before spawning the sidecar process.

#### Client-Only Mode

For setups where the desktop app is just a thin native shell around a remote backend (e.g., a hosted jac-scale deployment), set `client_only = true` under `[desktop]` in `jac.toml`:

```toml
[desktop]
client_only = true

[plugins.client.api]
base_url = "https://api.example.com"
```

In this mode the build:

- **Skips sidecar bundling entirely** -- no PyInstaller step, no Python bundle, smaller installer.
- **Requires** `[plugins.client.api] base_url` to be set; the build raises a `RuntimeError` if it is missing, since the webview has no local backend to talk to.
- **Still produces a full Tauri installer** -- only the backend half is omitted.

It is also useful in CI, where you may want to verify the web bundle compiles inside a desktop build without paying for the PyInstaller round-trip.

#### Runtime API URL Injection (Debugging)

Desktop builds do **not** embed the API base URL at compile time. Tauri allocates the sidecar port dynamically, then injects `window.__JAC_API_BASE_URL__` into the webview via an `initialization_script` before any page JavaScript executes. A `get_api_url` Tauri command is also exposed as a fallback for code that needs to query the URL after page load.

If you are debugging an "API not reachable" issue inside an installed desktop app:

1. Run the sidecar binary directly from `src-tauri/binaries/` -- it logs to stderr and prints `JAC_SIDECAR_PORT=<port>` to stdout on startup.
2. Use the **Debug** page in the `all-in-one` example app (under `examples/all-in-one/pages/debug.jac`), which shows the resolved API base URL, Tauri runtime detection, `get_api_url` invoke results, and interactive walker/HTTP probes.
3. Check the data path the sidecar settled on -- it logs `[sidecar] Cannot use data path …` lines for any candidate it had to skip.

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

### PWA Install Banner

After running `jac setup pwa`, your app automatically shows a native-style install prompt to users. No manual code changes required.

**Features:**

- **Automatic display** -- Glassmorphic dark banner with slide-up animation appears after configurable delay
- **Chrome/Edge integration** -- Uses `beforeinstallprompt` for native install flow
- **iOS Safari support** -- Detects iOS and shows step-by-step "Add to Home Screen" instructions
- **Smart re-prompting** -- Exponential backoff after dismiss (7 → 14 → 28 days), max 3 prompts total

**Banner Configuration in jac.toml:**

```toml
[plugins.client.pwa]
theme_color = "#000000"
background_color = "#ffffff"

# Install banner settings
install_banner = true                    # Enable/disable (default: true)
install_banner_delay = 3000              # Delay before showing in ms (default: 3000)
install_banner_position = "bottom"       # "bottom" or "top" (default: bottom)
install_button_text = "Install"          # Custom install button text
install_dismiss_text = "Not Now"         # Custom dismiss button text
```

**Programmatic Control (Optional):**

For advanced use cases, import the PWA runtime module:

```jac
cl import from "@jac/pwa" { usePwaInstall, PwaInstallButton }

to cl:

def:pub CustomInstallUI() -> JsxElement {
    (canInstall, triggerInstall) = usePwaInstall();

    return <div>
        {canInstall and (
            <button onClick={lambda -> None { triggerInstall(); }}>
                Get the App
            </button>
        )}
    </div>;
}
```

| Export | Type | Description |
|--------|------|-------------|
| `usePwaInstall()` | hook | Returns `(canInstall: bool, triggerInstall: () -> void)` |
| `PwaInstallButton` | component | Pre-styled install button component |

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
to cl:

def:pub Footer() -> JsxElement {
    return <p>Version: {globalThis.BUILD_VERSION}</p>;
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

Jac provides ambient DOM types (`ChangeEvent`, `KeyboardEvent`, `MouseEvent`, `FormEvent`, etc.) that are available without import. Use these for type-safe event handling:

```jac
to cl:

def:pub Form() -> JsxElement {
    has value: str = "";

    return <div>
        <input
            value={value}
            onChange={lambda e: ChangeEvent { value = e.target.value; }}
            onKeyPress={lambda e: KeyboardEvent {
                if e.key == "Enter" { submit(); }
            }}
        />
        <button onClick={lambda -> None { submit(); }}>
            Submit
        </button>
    </div>;
}
```

### Ambient DOM Types

The following event and element types are available in all Jac modules without any import statement. Use them for type-safe event handlers in JSX:

**Event Types:**

| Type | Fires On | Key Properties |
|------|----------|----------------|
| `Event` | Base event | `target`, `type`, `preventDefault()` |
| `ChangeEvent` | `onChange` | `target.value`, `target.checked` |
| `InputEvent` | `onInput` | `data`, `inputType` |
| `KeyboardEvent` | `onKeyDown`, `onKeyUp`, `onKeyPress` | `key`, `code`, `ctrlKey`, `shiftKey` |
| `MouseEvent` | `onClick`, `onMouseDown`, etc. | `clientX`, `clientY`, `button` |
| `PointerEvent` | `onPointerDown`, `onPointerUp` | `pointerId`, `pointerType`, `pressure` |
| `FocusEvent` | `onFocus`, `onBlur` | `relatedTarget` |
| `DragEvent` | `onDrag`, `onDrop` | `dataTransfer` |
| `TouchEvent` | `onTouchStart`, `onTouchEnd` | `touches`, `changedTouches` |
| `ClipboardEvent` | `onCopy`, `onCut`, `onPaste` | `clipboardData` |
| `FormEvent` | `onSubmit`, `onReset` | `target` (HTMLFormElement) |
| `WheelEvent` | `onWheel` | `deltaX`, `deltaY` |
| `AnimationEvent` | `onAnimationStart`, `onAnimationEnd` | `animationName`, `elapsedTime` |
| `TransitionEvent` | `onTransitionEnd` | `propertyName`, `elapsedTime` |
| `ScrollEvent` | `onScroll` | Inherits from UIEvent |

**Element Types:**

| Type | For Element |
|------|-------------|
| `HTMLElement` | Base (any element) |
| `HTMLInputElement` | `<input>` -- adds `value`, `checked`, `files`, `type` |
| `HTMLTextAreaElement` | `<textarea>` -- adds `value`, `rows`, `cols` |
| `HTMLSelectElement` | `<select>` -- adds `value`, `selectedIndex`, `options` |
| `HTMLFormElement` | `<form>` -- adds `submit()`, `reset()`, `elements` |
| `HTMLButtonElement` | `<button>` -- adds `disabled`, `type` |
| `HTMLAnchorElement` | `<a>` -- adds `href`, `target`, `pathname` |
| `HTMLImageElement` | `<img>` -- adds `src`, `alt`, `naturalWidth` |
| `HTMLCanvasElement` | `<canvas>` -- adds `getContext()`, `toDataURL()` |
| `HTMLVideoElement` | `<video>` -- adds `play()`, `pause()`, `currentTime` |
| `HTMLAudioElement` | `<audio>` -- adds `play()`, `pause()`, `volume` |

**Usage examples:**

```jac
to cl:

def:pub TypedForm() -> JsxElement {
    has text: str = "";
    has checked: bool = False;

    return <div>
        <input
            value={text}
            onChange={lambda e: ChangeEvent { text = e.target.value; }}
            onKeyDown={lambda e: KeyboardEvent {
                if e.key == "Enter" and not e.shiftKey { submit(); }
            }}
        />
        <input
            type="checkbox"
            checked={checked}
            onChange={lambda e: ChangeEvent { checked = e.target.checked; }}
        />
        <form onSubmit={lambda e: FormEvent {
            e.preventDefault();
            handleSubmit();
        }}>
            <button type="submit">Submit</button>
        </form>
    </div>;
}
```

!!! tip "Migrating from `any`"
    If you have existing event handlers using `e: any`, you can update them to use ambient types for better type safety and IDE support:

    ```jac
    # Before
    onChange={lambda e: any -> None { value = e.target.value; }}

    # After (no import needed)
    onChange={lambda e: ChangeEvent { value = e.target.value; }}
    ```

---

## Conditional Rendering

```jac
to cl:

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
```

---

## Error Handling

### JacClientErrorBoundary

`JacClientErrorBoundary` is a specialized error boundary component that catches rendering errors in your component tree, logs them, and displays a fallback UI, preventing the entire app from crashing when a descendant component fails.

### Quick Start

Import and wrap `JacClientErrorBoundary` around any subtree where you want to catch render-time errors:

```jac
cl import from "@jac/runtime" { JacClientErrorBoundary }

to cl:

def:pub app() -> JsxElement {
    return <JacClientErrorBoundary fallback={<div>Oops! Something went wrong.</div>}>
        <MainAppComponents />
    </JacClientErrorBoundary>;
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
to cl:

def:pub App() -> JsxElement {
    return <JacClientErrorBoundary fallback={<div className="error">Component failed to load</div>}>
        <ExpensiveWidget />
    </JacClientErrorBoundary>;
}
```

### Nested Boundaries

You can nest multiple error boundaries for fine-grained error isolation:

```jac
to cl:

def:pub App() -> JsxElement {
    return <JacClientErrorBoundary fallback={<div>App error</div>}>
        <Header />
        <JacClientErrorBoundary fallback={<div>Content error</div>}>
            <MainContent />
        </JacClientErrorBoundary>
        <Footer />
    </JacClientErrorBoundary>;
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

## JavaScript Interop

### Constructing Browser Objects

Jac does not have a `new` keyword. Use `Reflect.construct()` to instantiate browser built-in constructors:

<!-- jac-skip -->
```jac
to cl:

# WebSocket
ws = Reflect.construct(WebSocket, [url]);

# URL
url = Reflect.construct(URL, [String(baseUrl)]);

# Date
now = Reflect.construct(Date, []);

# Promise
p = Reflect.construct(Promise, [lambda(resolve: Any, reject: Any) {
    resolve.call(None, "done");
}]);

# CustomEvent
evt = Reflect.construct(CustomEvent, ["my-event", {"detail": data}]);
```

### Callback Invocations

When passing callbacks to be invoked later, use `.call(None, ...)`:

<!-- jac-skip -->
```jac
to cl:

handler = myCallback;
ws.onmessage = lambda(e: Any) {
    handler.call(None, JSON.parse(e.data));
};
```

### Module-Level State

Use `glob` for state shared across a module:

```jac
to cl:

glob initialized: bool = False;
glob cache: Any = None;
```

For more patterns, see the [Advanced Patterns & JS Interop tutorial](../../tutorials/fullstack/advanced-patterns.md).

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
- [NPM Packages & UI Libraries](../../tutorials/fullstack/npm-and-libraries.md)
- [Advanced Patterns & JS Interop](../../tutorials/fullstack/advanced-patterns.md)
- [Backend Integration Tutorial](../../tutorials/fullstack/backend.md)
- [Authentication Tutorial](../../tutorials/fullstack/auth.md)
- [Routing Tutorial](../../tutorials/fullstack/routing.md)
