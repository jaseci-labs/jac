# jac-client Reference

jac-client adds client-side compilation to Jac so you can write React-style UI components using `cl { }` blocks (or `.cl.jac` files). The compiler separates your code automatically -- server-side logic compiles to Python, while client-side components compile to JavaScript with React as the rendering engine.

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
├── README.md          # Project readme
├── AGENTS.md          # Agent guide for the project
├── components/        # Reusable components
│   └── Button.cl.jac  # Example component (.cl.jac = client-side)
└── assets/            # Static assets (images, fonts)
```

TypeScript/TSX and CSS files are also supported -- drop a `.tsx` component or
a `.css` file anywhere in the project and import it from your Jac code.

### The `.cl.jac` Convention

Files ending in `.cl.jac` are automatically treated as client-side code -- no `cl { }` block needed:

```jac
# components/Header.cl.jac -- automatically client-side
def:pub Header() -> JsxElement {
    return <header>My App</header>;
}
```

This is equivalent to wrapping a regular `.jac` file's contents in a `cl { }` block.

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

!!! note
    `main.jac` is the default entry point. All `jac start` commands below omit the filename. If your entry point differs (e.g., `app.jac`), pass it explicitly: `jac start app.jac`.

```bash
jac start --port 8000
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
    return [root-->][?:Task];
}

def:pub create_task(title: str) -> Task {
    task = root ++> Task(title=title);
    return task[0];
}

# Client: receives hydrated Task instances
cl {
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

Wrap client-side (React) code in a `cl { ... }` block -- the braces bracket exactly the tagged region, which is the clearest way to mix client and server code in one file:

```jac
cl {
    def:pub app() -> JsxElement {
        return <div>
            <h1>Hello, World!</h1>
        </div>;
    }
}
```

A `cl { ... }` block also works inside a function or class body to locally override the active codespace. In `.cl.jac` files, the whole file is already client-side, so no wrapper is needed.

### Section Headers

As an alternative to a block, the `to cl:` section header tags **every following module-level element** as client-side, until the next `to X:` header or end of file. This is convenient for a file that is mostly client code, since it avoids a wrapping block:

```jac
to cl:

def:pub app() -> JsxElement {
    return <div>
        <h1>Hello, World!</h1>
    </div>;
}
```

You can switch back with `to sv:`, `to na:`, or end the file.

### Single-Statement Forms

For one-off client-side declarations, use the single-statement `cl` prefix:

```jac
cl import from react { useState }
cl glob THEME: str = "dark";
```

This also works for component definitions -- a handy shorthand for a single tagged declaration inside a mostly-server file:

```jac
cl def:pub app -> JsxElement {
    has count: int = 0;
    return <div>Count: {count}</div>;
}
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

Declare each prop as a named, typed parameter -- the type-checker validates
every JSX call site per attribute. `children` is the special prop that holds
the JSX nested between a component's tags:

```jac
cl {
    def:pub Button(
        className: str = "",
        onClick: MouseEventHandler = None,
        children: any = None
    ) -> JsxElement {
        return <button className={className} onClick={onClick}>
            {children}
        </button>;
    }
}
```

### Using Props

```jac
cl {
    def:pub Card(title: str, description: str = "", children: any = None) -> JsxElement {
        return <div className="card">
            <h2>{title}</h2>
            <p>{description}</p>
            {children}
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

Inside client-tagged code (a `cl { }` block, a `.cl.jac` file, or a `to cl:` section), `has` creates reactive state:

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

    def:pub AppProvider(children: any = None) -> JsxElement {
        has theme: str = "light";

        return <AppContext.Provider value={{"theme": theme}}>
            {children}
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
                tasks = [
                    {**t, "completed": not t["completed"]} if t["id"] == task_id else t
                    for t in tasks
                ];
            }
        }

        # Delete
        async def handle_delete(task_id: str) -> None {
            result = root spawn delete_task(task_id=task_id);
            if result.reports and result.reports[0]["success"] {
                tasks = [t for t in tasks if t["id"] != task_id];
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

        # The outer lambda must NOT be annotated `-> None` -- a cleanup effect
        # returns a function, so `-> None` would be a type error.
        useEffect(lambda {
            interval = setInterval(lambda { fetch_data(); }, 5000);
            return lambda { clearInterval(interval); };
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
            <h1>User {params["id"]}</h1>
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

cl {
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
}
```

### Routing Hooks Reference

Import from `@jac/runtime`:

| Hook | Returns | Usage |
|------|---------|-------|
| `useParams()` | dict | Access URL parameters: `params["id"]` |
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

cl {
    # pages/(auth)/layout.jac
    def:pub layout() -> JsxElement {
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

### Scoped CSS (`.style.css` annexes)

A `.style.css` file that **shares a base name** with a `.cl.jac` module is
treated as a scoped-style annex -- the two files form one logical module. The
compiler hashes every class selector the annex declares with a per-module
digest, rewrites the CSS rule selectors, and rewrites JSX `className`/`class`
literals in the module that reference a declared class to the same hashed
form. Class names are scoped to the component automatically, so two modules
can both declare `.card` without colliding.

Given `Card.style.css` beside `Card.cl.jac`:

```css
/* Card.style.css */
.card {
    padding: 1rem;
    border: 1px solid #ccc;
}
.card-title { font-weight: 600; }

/* :global(...) opts out of scoping -- the inner selector is kept verbatim. */
:global(html) { box-sizing: border-box; }
```

```jac
# Card.cl.jac
def:pub Card(title: str, body: str) -> JsxElement {
    return <article className="card">
        <h2 className="card-title">{title}</h2>
        <p>{body}</p>
    </article>;
}
```

the compiler hashes the selectors and rewrites the matching `className`
literals to agree (hashes are stable per module):

```js
import "./Card.css";
function Card(props) {
  const {title, body} = props;
  return __jacJsx("article", {"className": "card-1419142b"},
    [__jacJsx("h2", {"className": "card-title-769bf254"}, [title]),
     __jacJsx("p", {}, [body])]);
}
```

```css
/* emitted sidecar Card.css */
.card-1419142b { padding: 1rem; border: 1px solid #ccc; }
.card-title-769bf254 { font-weight: 600; }
html { box-sizing: border-box; }   /* :global(...) unwrapped */
```

Key points:

- **No import needed.** The annex is paired by base name; the compiler injects
  the side-effect `import "./<base>.css";` for you.
- **Only declared classes are rewritten.** A `className` token with no matching
  selector in the annex is left untouched, so you can mix scoped and global
  (e.g. Tailwind) classes in the same `className`.
- **`:global(...)` is the escape hatch** for selectors that must stay
  unscoped (resets, third-party class targets, element selectors).
- Scoped styles are per-module; for app-wide styles (themes, resets, Tailwind)
  use a plain shared `import "./global.css";` instead.

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

> **Note:** In jac-shadcn projects `jac add --shadcn` / `jac create --use jac-shadcn` generate `lib/utils.cl.jac` for you. You can also write `cn()` by hand -- entirely in Jac (no TypeScript needed) with a variadic parameter:
>
> ```jac
> # lib/utils.cl.jac
> cl import from "clsx" { clsx }
> cl import from "tailwind-merge" { twMerge }
>
> def:pub cn(*inputs: any) -> str {
>     return twMerge(clsx(inputs));
> }
> ```
>
> Requires `clsx` and `tailwind-merge` in `[dependencies.npm]`.

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

            <button {**props} {variable}>Click</button>
        </div>;
    }
}
```

Two brace forms appear in attribute position. `{**props}` is a **spread** -- it forwards every key of `props` as an attribute. The JS-idiomatic `{...props}` spread is also accepted but emits `W0063` ("prefer `{**expr}`"), so `{**props}` is the canonical Jac form. `{variable}` is the **`{name}` shorthand** -- when an attribute's value is a variable of the same name it expands to `variable={variable}`, so `<Box {title} {count} {onClick}/>` is sugar for `<Box title={title} count={count} onClick={onClick}/>`. The shorthand is still validated per-attribute against the component signature.

### Suspense Fallbacks: `try` with `awaiting`

A `try` slot whose body needs to wait on async work can name its loading state with an `awaiting` clause. The cl lowering wraps the slot in `<JacAwaiting fallback={...}>{...}</JacAwaiting>` from `@jac/runtime` -- a `React.Suspense` shim -- so the `awaiting` body renders during the dispatched-but-not-joined window and the `try` body takes over once it settles. On `sv` and `na` targets the `awaiting` body is dropped with a `W2020` warning until the streaming-SSR and native-thread lowerings land.

```jac
cl {
    def:pub Profile(user_id: int) -> JsxElement {
        return <article>
            {try {
                <ResolvedProfile id={user_id}/>
            } awaiting {
                <p>Loading profile…</p>
            }}
        </article>;
    }
}
```

Add an `except` arm to name the error state. On the cl target the slot then lowers to a `<JacClientErrorBoundary fallback={...}>` (auto-imported from `@jac/runtime`, where it re-exports [`react-error-boundary`'s `ErrorBoundary`](#jacclienterrorboundary)) **wrapping** the `<JacAwaiting>` node, so a throw in the resolved `try` body -- including from data the suspense shim awaited -- is caught and the `except` body renders in its place:

```jac
cl {
    def:pub Profile(user_id: int) -> JsxElement {
        return <article>
            {try {
                <ResolvedProfile id={user_id}/>
            } awaiting {
                <p>Loading profile…</p>
            } except Exception {
                <p>Could not load profile.</p>
            }}
        </article>;
    }
}
```

Because a JS error boundary catches every error regardless of declared type, per-type dispatch and the optional `except ... as <name>` binding are not modeled -- the except bodies are concatenated in source order into the boundary's fallback. See the [components tutorial](../../tutorials/fullstack/components.md#try-with-awaiting-suspense-shaped-fallback) for the full model -- semantics, the `flow`/`wait` integration story, and the v1 caveats (`finally` rejected via `E2022`).

### Comments inside JSX

Use Jac's block-comment syntax wrapped in a JSX expression slot -- `{#* ... *#}` -- to leave a note inside a JSX tree. The comment renders nothing and is preserved verbatim by `jac format`:

```jac
cl {
    def:pub App() -> JsxElement {
        return <div>
            <h1>Hello</h1>
            {#* TODO: replace with a custom Button component *#}
            <button>Click me</button>
        </div>;
    }
}
```

A few rules to keep in mind:

- **Line comments don't work in JSX text.** A `#` outside an expression slot is treated as literal text -- HTML allows `#` in content, so the lexer can't reinterpret it. Wrap the note in `{#* ... *#}` instead.
- **The standard React form `{/* ... */}` is not supported.** Inside an expression slot, `/` and `*` parse as Jac operators, so a JSX comment must use Jac-native `{#* ... *#}`.
- **`{#* ... *#}` is the only no-op JSX slot.** An empty `{}` is still a parse error -- the slot must contain either a real expression or a block comment.

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
cl {
    import "./assets/main.css";  # contains: @import "tailwindcss";

    def:pub app() -> JsxElement {
        return <div className="min-h-screen bg-gray-100 p-8">
            <h1 className="text-3xl font-bold">Hello</h1>
        </div>;
    }
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

The `[jac-shadcn]` section configures the shadcn/ui component system, provided by the [`jac-super`](https://pypi.org/project/jac-super/) plugin. It controls the visual style, color theme, font, and border radius used by shadcn components in your project. Everything is resolved **offline** from data bundled with `jac-super`:

- `jac create --use jac-shadcn [--style … --theme … --font … --radius … --baseColor … --menuAccent …]` scaffolds a themed starter and writes these fields here.
- `jac retheme [--theme … --font … --style …]` regenerates `global.css` from this section (and re-resolves installed components when `style` changes).
- `jac add --shadcn <name>` reads `style` to choose which style's Tailwind classes to emit.

```toml
[jac-shadcn]
style = "nova"            # Component style variant (read by `jac add`)
baseColor = "neutral"     # Base color palette
theme = "amber"           # Accent color theme
font = "inter"            # Font family
radius = "default"        # Border radius preset
menuAccent = "subtle"     # Menu accent style
menuColor = "default"     # Menu color scheme
```

| Key | Description | Examples |
|-----|-------------|---------|
| `style` | Component style variant -- read by `jac add` to resolve bundled components | `"nova"`, `"vega"`, `"maia"`, `"lyra"`, `"mira"` |
| `baseColor` | Base neutral color palette | `"neutral"`, `"stone"`, `"zinc"`, `"gray"` |
| `theme` | Accent/primary color | `"amber"`, `"blue"`, `"green"`, `"red"` |
| `font` | Typography font family | `"figtree"` (default), `"inter"`, `"geist"`, `"outfit"` |
| `radius` | Border radius preset | `"default"`, `"none"`, `"small"`, `"medium"`, `"large"` |

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

### Base Path

Control the base path for asset resolution (JS/CSS) in the generated `index.html`. Useful for deploying the app on a subpath (e.g., `https://example.com/myapp/`).

```toml
[plugins.client]
base_path = "/myapp/"
```

Defaults to `"/"`. Can also be set to `"./"` for relative path resolution if needed.

---

## CLI Commands

### Quick Reference

| Command | Description |
|---------|-------------|
| `jac create myapp --use client` | Create new full-stack project |
| `jac start` | Start dev server |
| `jac start --dev` | Dev server with HMR |
| `jac start --client pwa` | Start PWA (builds then serves) |
| `jac start --client desktop` | Start desktop app (requires [jac-desktop](jac-desktop.md)) |
| `jac start --client mobile` | Start mobile app on device/simulator |
| `jac build` | Build for production (web) |
| `jac build --client desktop` | Build desktop app (requires [jac-desktop](jac-desktop.md)) |
| `jac build --client mobile` | Build mobile app (Android/iOS) |
| `jac build --client pwa` | Build PWA with offline support |
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
| `--client` | Build target (`web`, `desktop`, `pwa`, `mobile`) | `web` |
| `-p, --platform` | Platform for **mobile** (`android`, `ios`) or **desktop sidecar naming** (`windows` selects `.exe`; no cross-compilation yet) | Current platform |

For desktop builds, see the [jac-desktop Reference](jac-desktop.md): the desktop target compiles your `cl` UI into a single native binary that embeds the OS webview. In all desktop builds the build environment sets `JAC_BUILD=1` so import-time server starts stay inert.

**Examples:**

```bash
# Build web target (default)
jac build

# Build specific file
jac build main.jac

# Build PWA with offline support
jac build --client pwa

# Build desktop app (sidecar for current OS; use --platform windows for .exe name)
jac build --client desktop

# Name sidecar jac-sidecar.exe (build on Windows for a Windows binary)
jac build --client desktop --platform windows

# Build mobile app for Android
jac build --client mobile --platform android

# Build mobile app for iOS
jac build --client mobile --platform ios
```

### jac setup

One-time initialization for a build target.

```bash
jac setup <target> [-p PLATFORM]
```

| Option | Description |
|--------|-------------|
| `target` | Target to setup (`desktop`, `mobile`, `pwa`) |
| `-p, --platform` | Mobile setup platform (`android`, `ios`, `all`) |

**Examples:**

```bash
# Setup PWA target (creates pwa_icons/ directory)
jac setup pwa

# Setup mobile target for one platform only
jac setup mobile --platform ios

# Setup both mobile platforms (macOS only)
jac setup mobile --platform all
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
| **Desktop** (native webview) | `jac build --client desktop` | Single binary under `.jac/client/desktop/` | No (`jac-desktop`) |
| **Mobile** (Capacitor) | `jac build --client mobile --platform android` | Android APK / iOS build products | Yes |
| **PWA** | `jac build --client pwa` | Installable web app | No |

### Web Target (Default)

Standard browser deployment using Vite:

```bash
jac build                    # Build for web
jac start --dev              # Dev server with HMR
```

**Output:** `.jac/client/dist/` with `index.html`, bundled JS, and CSS.

### Desktop Target (native webview)

The desktop target is provided by the optional **[jac-desktop](jac-desktop.md)** plugin. It reuses jac-client's Vite frontend pipeline and compiles a native host (`jac nacompile`) that embeds the OS webview to render your `cl` UI - one self-contained binary, no Rust toolchain, no PyInstaller, no setup step.

```bash
pip install jac-client jac-desktop
jac build --client desktop
jac start --client desktop
```

See the **[jac-desktop Reference](jac-desktop.md)** for architecture and `[plugins.desktop]` configuration.

Tutorial: [Building a Desktop App](../../tutorials/fullstack/desktop.md).

### Mobile Target (Capacitor)

Native mobile applications for Android and iOS using [Capacitor](https://capacitorjs.com/). The same web bundle the web target produces is wrapped in a native shell, producing an Android APK or an iOS app.

**Prerequisites:**

- Node.js (or Bun)
- **Android**: Java/JDK 21+, Android SDK ([Android Studio](https://developer.android.com/studio))
- **iOS** (macOS only): Xcode, Xcode Command Line Tools, [CocoaPods](https://cocoapods.org/)

**Setup & Build:**

```bash
# 1. One-time setup (defaults from config / host)
jac setup mobile

# Optional explicit setup platform
jac setup mobile --platform android
jac setup mobile --platform ios     # macOS only
jac setup mobile --platform all     # both on macOS

# 2. Development: build and launch on device/simulator
jac start main.jac --client mobile                    # Android (default)
jac start main.jac --client mobile --platform ios

# 3. Build for Android
jac build --client mobile --platform android

# 4. Build for iOS
jac build --client mobile --platform ios
```

**Output:**

- Android: APK in `android/app/build/outputs/apk/`
- iOS: Xcode build products in `ios/App/build/`

**Configuration** via `[plugins.client.mobile]` in `jac.toml`:

```toml
[plugins.client.mobile]
app_name = "My App"
app_id = "com.example.myapp"
release = false          # true for release builds
bundle = false           # true to produce AAB instead of APK (Android)
default_platform = "android"  # default for jac start --client mobile
ios_sdk = "iphonesimulator"   # or "iphoneos" for device builds
ios_destination = "platform=iOS Simulator,name=iPhone 16,OS=latest"
```

**Notes:**

- `jac setup mobile` uses `--platform` when provided, otherwise `[plugins.client.mobile].default_platform`, otherwise host default (`ios` on macOS, `android` elsewhere).
- Mobile dev networking is auto-resolved by default; use `--host <ip>` only when you need to force a specific host.
- Android mobile dev auto-attempts `adb reverse` for Vite/API ports before launching Capacitor.
- iOS device builds and App Store archives require Xcode provisioning profiles. Use `npx cap open ios` to open the project in Xcode for signing configuration.
- Android release builds and signing require a keystore configured in `android/app/build.gradle`.
- Native Capacitor plugins (camera, geolocation, etc.) can be added via `jac add --npm @capacitor/<plugin>` followed by `npx cap sync`.

For a step-by-step tutorial, see [Building a Mobile App](../../tutorials/fullstack/mobile.md).

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

cl {
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
jac start

# With hot module replacement
jac start --dev

# HMR without client bundling (API only)
jac start --dev --no-client

# Dev server for desktop target
jac start --client desktop
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
cl {
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
cl {
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
    def:pub app() -> JsxElement {
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
    def:pub App() -> JsxElement {
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
    def:pub App() -> JsxElement {
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

## JavaScript Interop

### Constructing Browser Objects

Jac does not have a JavaScript-style `new` keyword. Use the `new(...)` ambient builtin to instantiate browser built-in constructors; the compiler lowers it to `Reflect.construct(Cls, [args])` in the emitted JavaScript:

<!-- jac-skip -->
```jac
cl {
    # WebSocket
    ws = new(WebSocket, url);

    # URL
    url = new(URL, String(baseUrl));

    # Date
    now = new(Date);

    # Promise
    p = new(Promise, lambda(resolve: any, reject: any) {
        resolve.call(None, "done");
    });

    # CustomEvent
    evt = new(CustomEvent, "my-event", {"detail": data});
}
```

`new(Cls, ...args)` is portable: it works in any codespace. On the server it is a thin wrapper for `Cls(*args)`; in `cl` blocks the compiler rewrites the call into `Reflect.construct(Cls, [args])` so it can drive JS class constructors that require `new`.

### Callback Invocations

When passing callbacks to be invoked later, use `.call(None, ...)`:

<!-- jac-skip -->
```jac
cl {
    handler = myCallback;
    ws.onmessage = lambda(e: any) {
        handler.call(None, JSON.parse(e.data));
    };
}
```

### Module-Level State

Use `glob` for state shared across a module:

```jac
cl {
    glob initialized: bool = False;
    glob cache: any = None;
}
```

For more patterns, see the [Advanced Patterns & JS Interop tutorial](../../tutorials/fullstack/advanced-patterns.md).

---

## Development Tools

### Hot Module Replacement (HMR)

```bash
# Enable with --dev flag
jac start --dev
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
- [Building a Desktop App](../../tutorials/fullstack/desktop.md)
- [jac-desktop Reference](jac-desktop.md)
