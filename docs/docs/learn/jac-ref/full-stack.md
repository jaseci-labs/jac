# Part IV: Full-Stack Development

Jac enables true full-stack development: backend APIs, frontend UI, and AI logic in a single language. The `jac-client` plugin compiles Jac to JavaScript/React for the browser, while `jac-scale` handles server deployment. This part covers modules, server/client separation, and the JSX-like syntax for building UIs.

## 19. Module System

Jac's module system bridges Python and JavaScript ecosystems. You can import from PyPI packages on the server and npm packages on the client using familiar syntax. The `include` statement (like C's `#include`) merges code directly, which is useful for splitting large files.

### 19.1 Import Statements

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
```

### 19.2 Include Statements

Include merges code directly (like C's `#include`):

```jac
include utils;  # Merges utils.jac into current scope
```

### 19.3 CSS and Asset Imports

```jac
import "./styles.css";
import "./global.css";
```

### 19.4 Export and Visibility

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

## 20. Server-Side Development

### 20.1 Server Code Blocks

```jac
sv {
    # Server-only code
    node User {
        has id: str;
        has email: str;
    }

    walker:pub CreateUser {
        has email: str;

        can create with `root entry {
            user = User(id=uuid4(), email=self.email);
            root ++> user;
            report user;
        }
    }
}
```

### 20.2 REST API with jac start

Public walkers automatically become REST endpoints:

```jac
walker:pub GetUsers {
    can get with `root entry {
        users = [-->(`?User)];
        report users;
    }
}

# Endpoint: POST /GetUsers
```

Start the server:

```bash
jac start main.jac --port 8000
```

### 20.3 Module Introspection

```jac
# List all walkers in module
walkers = get_module_walkers();

# List all functions
functions = get_module_functions();
```

### 20.4 Transport Layer

The transport layer handles HTTP request/response:

```jac
# Custom transport handling
import from jaclang.transport { BaseTransport, HTTPTransport }
```

---

## 21. Client-Side Development (JSX)

### 21.1 Client Code Blocks

```jac
cl {
    import from react { useState, useEffect }

    def:pub App -> any {
        has count: int = 0;

        return (
            <div>
                <h1>Counter: {count}</h1>
                <button onclick={lambda: self.count += 1}>
                    Increment
                </button>
            </div>
        );
    }
}
```

### 21.2 State Management with `has`

In client components, `has` creates reactive state:

```jac
def:pub TodoApp -> any {
    has todos: list = [];
    has input_text: str = "";

    def add_todo -> None {
        if self.input_text {
            self.todos.append({"text": self.input_text, "done": False});
            self.input_text = "";
        }
    }

    return (
        <div>
            <input
                value={self.input_text}
                oninput={lambda e: self.input_text = e.target.value}
            />
            <button onclick={self.add_todo}>Add</button>
            <ul>
                {[<li>{todo["text"]}</li> for todo in self.todos]}
            </ul>
        </div>
    );
}
```

### 21.3 Effects and Lifecycle

```jac
def:pub DataLoader -> any {
    has data: list = [];
    has loading: bool = True;

    useEffect(lambda: {
        fetch_data();
    }, []);

    async def fetch_data -> None {
        response = await fetch("/api/data");
        self.data = await response.json();
        self.loading = False;
    }

    if self.loading {
        return <div>Loading...</div>;
    }

    return <div>{[<p>{item}</p> for item in self.data]}</div>;
}
```

### 21.4 JSX Syntax

```jac
# Elements
<div>content</div>
<Component prop="value" />

# Attributes
<input type="text" value={variable} />
<button onclick={handler}>Click</button>

# Conditionals
{condition && <div>Shown if true</div>}
{condition ? <Yes /> : <No />}

# Lists
{[<Item key={i} data={item} /> for (i, item) in enumerate(items)]}

# Fragments
<>
    <Child1 />
    <Child2 />
</>
```

### 21.5 Styling Patterns

```jac
import from "@jac-client/utils" { cn }

# Inline styles
<div style={{"color": "red", "fontSize": "16px"}}>Styled</div>

# Tailwind classes
<div className="p-4 bg-blue-500 text-white">Tailwind</div>

# Conditional classes with cn()
className = cn(
    "base-class",
    condition && "active",
    {"error": hasError, "success": isSuccess}
);
<div className={className}>Dynamic</div>
```

### 21.6 Routing

```jac
import from react-router-dom { BrowserRouter, Routes, Route, Link }

def:pub App -> any {
    return (
        <BrowserRouter>
            <nav>
                <Link to="/">Home</Link>
                <Link to="/about">About</Link>
            </nav>
            <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/about" element={<About />} />
            </Routes>
        </BrowserRouter>
    );
}
```

### 21.7 Client Bundle System

The client is bundled using Vite:

```toml
# jac.toml
[plugins.client]
port = 5173
typescript = false
```

---

## 22. Server-Client Communication

### 22.1 Calling Server Walkers

From client code, call server walkers:

```jac
cl {
    async def add_todo(text: str) -> None {
        result = root spawn AddTodo(title=text);
        new_todo = result.reports[0];
        self.todos.append(new_todo);
    }
}
```

### 22.2 jacSpawn() Function

Client-side walker invocation:

```jac
cl {
    import from "@jac-client/utils" { jacSpawn }

    async def fetch_users -> None {
        result = await jacSpawn("GetUsers", {});
        self.users = result.reports;
    }
}
```

### 22.3 Starting Full-Stack Server

```bash
# Development with hot reload
jac start main.jac --port 8000 --watch

# Production
jac start main.jac --port 8000
```

---

## 23. Authentication & Users {#23-authentication-users}

### 23.1 Built-in Auth Functions

```jac
import from "@jac-client/utils" {
    jacLogin,
    jacSignup,
    jacLogout,
    jacIsLoggedIn
}

cl {
    async def handle_login -> None {
        success = await jacLogin(self.email, self.password);
        if success {
            self.logged_in = True;
        }
    }

    async def handle_signup -> None {
        success = await jacSignup(self.email, self.password);
        if success {
            await self.handle_login();
        }
    }

    def handle_logout -> None {
        jacLogout();
        self.logged_in = False;
    }
}
```

### 23.2 User Management

| Operation | Function/Endpoint | Description |
|-----------|-------------------|-------------|
| Register | `jacSignup()` | Create new user account |
| Login | `jacLogin()` | Authenticate and get JWT |
| Logout | `jacLogout()` | Clear client token |
| Update Username | API endpoint | Change username |
| Update Password | API endpoint | Change password |
| Guest Access | `__guest__` account | Anonymous user support |

### 23.3 Per-User Graph Isolation

Each authenticated user gets an isolated root node:

```jac
walker:pub GetMyData {
    can get with `root entry {
        # 'root' is user-specific
        my_data = [-->(`?MyData)];
        report my_data;
    }
}
```

### 23.4 Single Sign-On (SSO)

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

## 24. Memory & Persistence {#24-memory-persistence}

### 24.1 Memory Hierarchy

| Tier | Type | Implementation |
|------|------|----------------|
| L1 | Volatile | VolatileMemory (in-process) |
| L2 | Cache | LocalCacheMemory (TTL-based) |
| L3 | Persistent | SqliteMemory (default) |

### 24.2 TieredMemory

Automatic read-through caching and write-through persistence:

```jac
# Objects are automatically persisted
node User {
    has name: str;
}

# Manual save
save(user_node);
commit();
```

### 24.3 ExecutionContext

Manages runtime context:

- `system_root` -- System-level root node
- `user_root` -- User-specific root node
- `entry_node` -- Current entry point
- `Memory` -- Storage backend

### 24.4 Anchor Management

Anchors provide persistent object references across sessions.

---

## 25. Development Tools

### 25.1 Hot Module Replacement (HMR)

```bash
# Enable with --watch flag
jac start main.jac --watch
```

Changes to `.jac` files automatically reload without restart.

### 25.2 File System Watcher

The JacFileWatcher monitors for changes with debouncing to prevent rapid reloads.

### 25.3 Debug Mode

```bash
jac debug main.jac
```

Provides:

- Step-through execution
- Variable inspection
- Breakpoints
- Graph visualization

---
