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

In client components, `has` creates reactive state:

```jac
cl {
    def:pub TodoApp() -> JsxElement {
        has todos: list = [];
        has input_text: str = "";

        def add_todo() -> None {
            if input_text {
                todos = todos + [{"text": input_text, "done": False}];
                input_text = "";
            }
        }

        return <div>
            <input value={input_text} />
            <button>Add</button>
            <ul>{todos}</ul>
        </div>;
    }
}
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

**File-Based Routing (Recommended):**

Create a `pages/` directory with `.jac` files that export a `page` function:

```
myapp/
└── pages/
    ├── index.jac          # /
    ├── about.jac          # /about
    └── users/
        └── [id].jac       # /users/:id (dynamic route)
```

**Manual Routing:**

```jac
cl import from "@jac/runtime" { Router, Routes, Route, Link }

cl {
    def:pub App() -> JsxElement {
        return (
            <Router>
                <nav>
                    <Link to="/">Home</Link>
                    <Link to="/about">About</Link>
                </nav>
                <Routes>
                    <Route path="/" element={<Home />} />
                    <Route path="/about" element={<About />} />
                </Routes>
            </Router>
        );
    }
}
```

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

### 3 Starting Full-Stack Server

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
- [Build a Todo App](../../tutorials/fullstack/todo-app.md) - Complete example

**Related Reference:**

- [jac-client Reference](../plugins/jac-client.md) - Complete API documentation
