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

### Mutations (Create, Update, Delete)

```jac
sv import from ...main { create_task, toggle_task, delete_task }

cl {
    def:pub TaskForm() -> JsxElement {
        has title: str = "";
        has tasks: list = [];

        async def handleSubmit() -> None {
            if not title.trim() {
                return;
            }
            result = root spawn create_task(title=title.trim());
            if result.reports {
                tasks = tasks.concat([result.reports[0]]);
            }
            title = "";
        }

        async def handleToggle(taskId: str) -> None {
            taskId spawn toggle_task();
            # Update local state
        }

        return <form onSubmit={lambda e: any -> None { e.preventDefault(); handleSubmit(); }}>
            <input value={title} onChange={lambda e: any -> None { title = e.target.value; }} />
            <button type="submit">Add Task</button>
        </form>;
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

Each page file exports a `page` function:

```jac
# pages/about.jac
cl {
    def:pub page() -> any {
        return <div>
            <h1>About Us</h1>
        </div>;
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

[plugins.client.configs.tailwind]
# Generates tailwind.config.js
content = ["./src/**/*.{jac,tsx,jsx}"]
```

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

## Development Server

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

## Related Resources

- [Fullstack Setup Tutorial](../../tutorials/fullstack/setup.md)
- [Components Tutorial](../../tutorials/fullstack/components.md)
- [State Management Tutorial](../../tutorials/fullstack/state.md)
- [Backend Integration Tutorial](../../tutorials/fullstack/backend.md)
- [Authentication Tutorial](../../tutorials/fullstack/auth.md)
- [Routing Tutorial](../../tutorials/fullstack/routing.md)
