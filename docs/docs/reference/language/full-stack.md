# Part IV: Full-Stack Development

**In this part:**

- [Module System](#module-system) - Imports, includes, exports
- [Server-Side Development](#server-side-development) - Server blocks, REST APIs
- [Client-Side Development (JSX)](#client-side-development-jsx) - Client blocks, JSX syntax, state
- [Server-Client Communication](#server-client-communication) - Calling walkers from client
- [Authentication & Users](#23-authentication-users) - Login, SSO, user management
- [Memory & Persistence](#24-memory-persistence) - Storage tiers, anchors
- [Development Tools](#development-tools) - HMR, debugging

---

Jac enables true full-stack development: backend APIs, frontend UI, and AI logic in a single language. The `jac-client` plugin compiles Jac to JavaScript/React for the browser, while `jac-scale` handles server deployment. This part covers modules, server/client separation, and the JSX-like syntax for building UIs.

## Project Setup

Create a full-stack project with the `jac create` command:

```bash
jac create --use client myapp
cd myapp
```

This scaffolds the project structure:

```
myapp/
├── jac.toml              # Configuration
├── main.jac              # Entry point (frontend + backend)
├── components/           # Reusable UI components
│   └── Button.cl.jac     # Example button component
├── assets/               # Static assets (images, fonts)
└── .jac/                 # Build artifacts (gitignored)
```

Run in development mode (starts Vite dev server + API server + file watcher):

```bash
jac start --dev
```

### `.cl.jac` File Convention

Files named with the `.cl.jac` extension are automatically treated as client-side code. No `cl { }` wrapper is needed:

```jac
# components/Header.cl.jac -- automatically client-side
def:pub Header() -> JsxElement {
    return <header><h1>My App</h1></header>;
}
```

### Managing npm Packages

```bash
jac add --npm lodash          # Add a package
jac add --npm --dev @types/react  # Add dev dependency
jac add --npm                 # Install all dependencies
```

Or declare in `jac.toml`:

```toml
[dependencies.npm]
lodash = "^4.17.21"
axios = "^1.6.0"
```

---

## Module System

Jac's module system bridges Python and JavaScript ecosystems. You can import from PyPI packages on the server and npm packages on the client using familiar syntax. The `include` statement (like C's `#include`) merges code directly, which is useful for splitting large files.

### 1 Import Statements

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

# Scoped package imports (@jac/ for runtime modules)
import from "@jac/runtime" { renderJsxTree, jacLogin }
```

### 2 Include Statements

Include merges code directly (like C's `#include`):

```jac
include utils;  # Merges utils.jac into current scope
```

### 3 CSS and Asset Imports

```jac
import "./styles.css";
import "./global.css";
```

### 4 Export and Visibility

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

### 1 Server Code Blocks

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

### 2 REST API with jac start

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

### 3 Module Introspection

```jac
with entry {
    # List all walkers in module
    walkers = get_module_walkers();

    # List all functions
    functions = get_module_functions();
}
```

### 4 Transport Layer

The transport layer handles HTTP request/response:

```jac
# Custom transport handling
import from jaclang.transport { BaseTransport, HTTPTransport }
```

---

## Client-Side Development (JSX)

### 1 Client Code Blocks

```jac
cl {
    import from react { useState, useEffect }

    def:pub App -> JsxElement {
        has count: int = 0;
        return <div><h1>Counter: {count}</h1></div>;
    }
}

# Single-statement form
cl import from react { useState }
cl glob THEME: str = "dark";
```

### 2 State Management with `has`

In client components, `has` creates reactive state. The compiler transforms `has` declarations into React `useState` hooks:

| Jac Syntax | Compiled React Equivalent |
|------------|--------------------------|
| `has count: int = 0` | `const [count, setCount] = useState(0)` |
| `count = count + 1` | `setCount(count + 1)` |
| `has name: str = ""` | `const [name, setName] = useState("")` |
| `name = e.target.value` | `setName(e.target.value)` |

The component re-renders automatically when any `has` variable is assigned a new value.

```jac
cl {
    def:pub Counter() -> JsxElement {
        has count: int = 0;

        return <div>
            <p>Count: {count}</p>
            <button onClick={lambda -> None { count = count + 1; }}>
                Increment
            </button>
        </div>;
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

### 3 Effects and Lifecycle

Use `can with entry` for mount effects and `can with exit` for cleanup:

| Syntax | Behavior | React Equivalent |
|--------|----------|------------------|
| `can with entry { }` | Run on mount | `useEffect(() => { }, [])` |
| `async can with entry { }` | Async mount | `useEffect(() => { (async () => { })(); }, [])` |
| `can with exit { }` | Run on unmount | `useEffect(() => { return () => { }; }, [])` |
| `can with [dep] entry { }` | Run when dep changes | `useEffect(() => { }, [dep])` |
| `can with (a, b) entry { }` | Multiple deps | `useEffect(() => { }, [a, b])` |

```jac
cl {
    def:pub DataLoader() -> JsxElement {
        has data: list = [];
        has loading: bool = True;

        # Fetch data on mount (async automatically wrapped in IIFE)
        async can with entry {
            response = await fetch("/api/data");
            data = await response.json();
            loading = False;
        }

        if loading {
            return <div>Loading...</div>;
        }

        return <div>{data}</div>;
    }

    def:pub UserProfile(userId: str) -> JsxElement {
        has user: dict = {};

        # Re-fetch when userId changes
        async can with [userId] entry {
            user = await fetch_user(userId);
        }

        # Cleanup subscriptions on unmount
        can with exit {
            unsubscribe();
        }

        return <div>{user.name}</div>;
    }
}
```

### Global State with useContext

For state shared across components, use React's `createContext` and `useContext`:

```jac
cl {
    import from react { createContext, useContext }

    glob AppContext = createContext(None);

    def:pub AppProvider(props: dict) -> JsxElement {
        has user: any = None;
        has theme: str = "light";

        value = {
            "user": user,
            "theme": theme,
            "setUser": lambda u: any -> None { user = u; },
            "setTheme": lambda t: str -> None { theme = t; }
        };

        return <AppContext.Provider value={value}>
            {props.children}
        </AppContext.Provider>;
    }

    def:pub UserDisplay() -> JsxElement {
        ctx = useContext(AppContext);
        if ctx.user {
            return <p>Welcome, {ctx.user.name}!</p>;
        }
        return <p>Not logged in</p>;
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

### 4 JSX Syntax

```jac
cl {
    def:pub JsxExamples() -> JsxElement {
        has variable: str = "text";
        has condition: bool = True;
        has items: list = [];
        has props: dict = {};

        return <div>
            <input type="text" value={variable} />
            <button>Click</button>

            {condition and <div>Shown if true</div>}

            {items}

            <button {...props}>Click</button>
        </div>;
    }
}
```

### 5 Styling Patterns

```jac
cl {
    # cn() utility from local lib/utils.ts (shadcn/ui pattern)
    # Uses clsx + tailwind-merge for conditional class names
    import from "../lib/utils" { cn }   # Relative import
    # Or with path alias: import from "@/lib/utils" { cn }

    def:pub StylingExamples() -> JsxElement {
        has condition: bool = True;
        has hasError: bool = False;
        has isSuccess: bool = True;

        # Conditional classes with cn()
        className = cn(
            "base-class",
            condition and "active",
            {"error": hasError, "success": isSuccess}
        );

        return <div>
            <div style={{"color": "red", "fontSize": "16px"}}>Styled</div>
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
>
> To use `@/` path alias, configure it in your `tsconfig.json` or Vite config.

### 6 Routing

Jac supports two routing approaches: **file-based** (recommended) and **manual** (React Router-style).

#### File-Based Routing (Recommended)

Create a `pages/` directory with `.jac` files. The file structure maps directly to URL routes:

| File | Route | Description |
|------|-------|-------------|
| `pages/index.jac` | `/` | Home page |
| `pages/about.jac` | `/about` | Static page |
| `pages/users/index.jac` | `/users` | Users list |
| `pages/users/[id].jac` | `/users/:id` | Dynamic parameter |
| `pages/posts/[slug].jac` | `/posts/:slug` | Named parameter |
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
            <Link to="/users">← Back</Link>
            <h1>User {params.id}</h1>
        </div>;
    }
}
```

**Route groups** organize pages without affecting the URL. The `(auth)` group can automatically wrap pages with authentication via a layout file:

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

**Layout files** use `<Outlet />` to render child routes:

```jac
# pages/layout.jac -- root layout wrapping all pages
cl import from "@jac/runtime" { Outlet }

cl {
    def:pub layout() -> JsxElement {
        return <>
            <nav>...</nav>
            <main><Outlet /></main>
            <footer>...</footer>
        </>;
    }
}
```

#### Manual Routing

```jac
cl import from "@jac/runtime" { Router, Routes, Route, Link }

cl {
    def:pub App() -> JsxElement {
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

#### Routing Hooks

Import from `@jac/runtime`:

| Hook | Returns | Usage |
|------|---------|-------|
| `useParams()` | dict | Access URL parameters: `params.id` |
| `useNavigate()` | function | Navigate programmatically: `navigate("/path")`, `navigate(-1)` |
| `useLocation()` | object | Current location: `location.pathname`, `location.search` |
| `Link` | component | Navigation: `<Link to="/path">Text</Link>` |
| `Outlet` | component | Render child routes in layouts |
| `AuthGuard` | component | Protect routes: `<AuthGuard redirect="/login">` |

### 7 Client Bundle System

The client is bundled using Vite:

```toml
# jac.toml
[plugins.client]
port = 5173
typescript = false
```

---

## Server-Client Communication

### 1 Calling Server Walkers

From client code, use `sv import` to import walkers and `spawn` syntax to call them:

```jac
# Import walkers from server
sv import from ...main { AddTodo, GetTodos }

cl {
    def:pub TodoApp() -> any {
        has todos: list = [];

        # Fetch data on mount
        async can with entry {
            result = root spawn GetTodos();
            if result.reports {
                todos = result.reports[0];
            }
        }

        # Create new todo
        async def addTodo(text: str) -> None {
            result = root spawn AddTodo(title=text);
            if result.reports {
                todos = todos.concat([result.reports[0]]);
            }
        }

        return <div>...</div>;
    }
}
```

### 2 Spawn Syntax

| Syntax | Description |
|--------|-------------|
| `root spawn WalkerName()` | Spawn walker from root node |
| `root spawn WalkerName(arg=value)` | Spawn with parameters |
| `node_id spawn WalkerName()` | Spawn from specific node |

The spawn call returns a result object with:

- `result.reports` - Data reported by the walker
- `result.status` - HTTP status code

### 3 CRUD Mutation Patterns

For create/update/delete operations, spawn walkers and update local state with the result:

```jac
sv import from ...main { add_task, toggle_task, delete_task }

cl {
    def:pub TaskManager() -> JsxElement {
        has tasks: list = [];

        # Create
        async def handle_add(title: str) -> None {
            result = root spawn add_task(title=title);
            if result.reports and result.reports.length > 0 {
                tasks = tasks.concat([result.reports[0]]);
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

### 4 Error Handling Pattern

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

### 5 Polling for Real-Time Updates

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

### 6 Starting Full-Stack Server

```bash
# Development with hot reload
jac start main.jac --port 8000 --dev

# Production
jac start main.jac --port 8000
```

---

## Authentication & Users {#23-authentication-users}

### 1 Built-in Auth Functions

```jac
cl import from "@jac/runtime" {
    jacLogin,
    jacSignup,
    jacLogout,
    jacIsLoggedIn
}

cl {
    def:pub AuthExample() -> any {
        has isLoggedIn: bool = False;
        has email: str = "";
        has password: str = "";

        async def handleLogin() -> None {
            # jacLogin returns bool (True = success, False = failure)
            success = await jacLogin(email, password);
            if success {
                isLoggedIn = True;
            }
        }

        async def handleSignup() -> None {
            # jacSignup returns dict with success key
            result = await jacSignup(email, password);
            if result["success"] {
                await handleLogin();
            }
        }

        def handleLogout() -> None {
            jacLogout();
            isLoggedIn = False;
        }

        return <div>...</div>;
    }
}
```

### 2 User Management

| Operation | Function/Endpoint | Description |
|-----------|-------------------|-------------|
| Register | `jacSignup()` | Create new user account |
| Login | `jacLogin()` | Authenticate and get JWT |
| Logout | `jacLogout()` | Clear client token |
| Update Username | API endpoint | Change username |
| Update Password | API endpoint | Change password |
| Guest Access | `__guest__` account | Anonymous user support |

### 3 Per-User Graph Isolation

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

### 4 Single Sign-On (SSO)

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

### 5 AuthGuard Component

For file-based routing, protect route groups with the built-in `AuthGuard` component:

```jac
# pages/(auth)/layout.jac
cl import from "@jac/runtime" { AuthGuard, Outlet }

cl {
    def:pub layout() -> any {
        return <AuthGuard redirect="/login">
            <Outlet />
        </AuthGuard>;
    }
}
```

`AuthGuard` checks `jacIsLoggedIn()` and either renders child routes or redirects to the specified path. All pages in the `(auth)` route group are automatically protected.

### 6 Auth Function Reference

| Function | Returns | Description |
|----------|---------|-------------|
| `jacLogin(user, pass)` | `bool` | Authenticate user, stores JWT. `True` on success |
| `jacSignup(user, pass)` | `dict` | Register user. Returns `{"success": bool, ...}` |
| `jacLogout()` | `void` | Clear stored auth token |
| `jacIsLoggedIn()` | `bool` | Check current auth status |

All functions are imported from `@jac/runtime`. JWT token management is handled automatically by the runtime.

---

## Memory & Persistence {#24-memory-persistence}

### 1 Memory Hierarchy

| Tier | Type | Implementation |
|------|------|----------------|
| L1 | Volatile | VolatileMemory (in-process) |
| L2 | Cache | LocalCacheMemory (TTL-based) |
| L3 | Persistent | SqliteMemory (default) |

### 2 TieredMemory

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

### 3 ExecutionContext

Manages runtime context:

- `system_root` -- System-level root node
- `user_root` -- User-specific root node
- `entry_node` -- Current entry point
- `Memory` -- Storage backend

### 4 Anchor Management

Anchors provide persistent object references across sessions.

---

## Development Tools

### 1 Hot Module Replacement (HMR)

```bash
# Enable with --dev flag
jac start main.jac --dev
```

Changes to `.jac` files automatically reload without restart.

### 2 File System Watcher

The JacFileWatcher monitors for changes with debouncing to prevent rapid reloads.

### 3 Debug Mode

```bash
jac debug main.jac
```

Provides:

- Step-through execution
- Variable inspection
- Breakpoints
- Graph visualization

---

## Learn More

**Tutorials:**

- [Full-Stack Project Setup](../../tutorials/fullstack/setup.md) - Create your first full-stack project
- [React-Style Components](../../tutorials/fullstack/components.md) - Build UI components
- [Backend Integration](../../tutorials/fullstack/backend.md) - Connect frontend to walkers
- [Build an AI Day Planner](../../tutorials/first-app/build-ai-day-planner.md) - Complete example

**Related Reference:**

- [jac-client Reference](../plugins/jac-client.md) - Complete API documentation
