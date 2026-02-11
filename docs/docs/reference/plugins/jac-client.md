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

---

## Client Blocks

Use `cl { }` to define client-side (React) code:

```jac
cl {
    def:pub app() -> any {
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
    def:pub app() -> any {  # :pub required
        return <App />;
    }
}
```

---

## Components

### Function Components

```jac
cl {
    def:pub Button(props: dict) -> any {
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
    def:pub Card(props: dict) -> any {
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
    def:pub app() -> any {
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
    def:pub Counter() -> any {
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
    def:pub Form() -> any {
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
    def:pub DataLoader() -> any {
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

    def:pub UserProfile(userId: str) -> any {
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

    def:pub DataLoader() -> any {
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

    def:pub AppProvider(props: dict) -> any {
        has theme: str = "light";

        return <AppContext.Provider value={{"theme": theme}}>
            {props.children}
        </AppContext.Provider>;
    }

    def:pub ThemedComponent() -> any {
        ctx = useContext(AppContext);
        return <div className={ctx.theme}>Content</div>;
    }
}
```

---

## Backend Integration

### useWalker Hook

Fetch data from walkers:

```jac
cl {
    import from jac_client { useWalker }

    def:pub TaskList() -> any {
        (data, loading, error, refetch) = useWalker("get_tasks");

        if loading {
            return <p>Loading...</p>;
        }

        return <ul>
            {[<li key={task["id"]}>{task["title"]}</li> for task in data]}
        </ul>;
    }
}
```

### useWalker Returns

| Value | Type | Description |
|-------|------|-------------|
| `data` | any | Walker's reported data |
| `loading` | bool | True while fetching |
| `error` | str \| None | Error message if failed |
| `refetch` | function | Re-fetch data |

### With Parameters

```jac
cl {
    def:pub SearchTasks() -> any {
        has search_term: str = "";
        (data, loading, error, refetch) = useWalker(
            "search_tasks",
            {"query": search_term, "limit": 10}
        );
        return <div>Results</div>;
    }
}
```

### callWalker

For mutations (create, update, delete):

```jac
cl {
    import from jac_client { callWalker }

    async def handle_submit() -> None {
        result = await callWalker("create_task", {"title": new_title});
        if result["success"] {
            refetch();
        }
    }
}
```

---

## Routing

### Basic Routes

```jac
cl {
    import from jac_client { Router, Route, Link }

    def:pub app() -> any {
        return <Router>
            <nav>
                <Link to="/">Home</Link>
                <Link to="/about">About</Link>
            </nav>

            <Route path="/" element={<Home />} />
            <Route path="/about" element={<About />} />
        </Router>;
    }
}
```

### URL Parameters

```jac
cl {
    import from jac_client { useParams }

    def:pub UserProfile() -> any {
        params = useParams();
        user_id = params["id"];

        return <div>User: {user_id}</div>;
    }

    # Route: /user/:id
}
```

### Programmatic Navigation

```jac
cl {
    import from jac_client { useNavigate }

    def:pub LoginForm() -> any {
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

### Nested Routes

```jac
cl {
    import from jac_client { Outlet }

    def:pub DashboardLayout() -> any {
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

### jacLogin / jacSignup

```jac
cl {
    import from jac_client { jacLogin, jacSignup }

    async def handle_login(email: str, password: str) -> None {
        result = await jacLogin(email, password);
        if result["success"] {
            # Store token, redirect
        }
    }

    async def handle_signup(email: str, password: str) -> None {
        result = await jacSignup(email, password);
        if result["success"] {
            # Auto-login or redirect to login
        }
    }
}
```

---

## Styling

### Inline Styles

```jac
cl {
    def:pub StyledComponent() -> any {
        return <div style={{"color": "blue", "padding": "10px"}}>
            Styled content
        </div>;
    }
}
```

### CSS Classes

```jac
cl {
    def:pub Card() -> any {
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

    def:pub app() -> any {
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
| `jac build` | Build for production (web) |
| `jac build --client desktop` | Build desktop app |
| `jac setup desktop` | One-time desktop target setup (Tauri) |
| `jac add --npm <pkg>` | Add npm package |
| `jac remove --npm <pkg>` | Remove npm package |

### jac build

Build a Jac application for a specific target.

```bash
jac build [filename] [--client TARGET] [-p PLATFORM]
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Path to .jac file | `main.jac` |
| `--client` | Build target (`web`, `desktop`) | `web` |
| `-p, --platform` | Desktop platform (`windows`, `macos`, `linux`, `all`) | Current platform |

**Examples:**

```bash
# Build web target (default)
jac build

# Build specific file
jac build main.jac

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
| `target` | Target to setup (e.g., `desktop`) |

**Examples:**

```bash
# Setup desktop target (installs Tauri prerequisites)
jac setup desktop
```

### Extended Core Commands

jac-client extends several core commands:

| Command | Added Option | Description |
|---------|-------------|-------------|
| `jac create` | `--use client` | Create full-stack project template |
| `jac create` | `--skip` | Skip npm package installation |
| `jac start` | `--client <target>` | Client build target for dev server |
| `jac add` | `--npm` | Add npm (client-side) dependency |
| `jac remove` | `--npm` | Remove npm (client-side) dependency |

---

## Multi-Target Architecture

jac-client supports building for multiple deployment targets from a single codebase.

### Web Target (Default)

Standard browser deployment using Vite:

```bash
jac build                    # Build for web
jac start --dev              # Dev server with HMR
```

### Desktop Target (Tauri)

Native desktop applications using Tauri:

```bash
jac setup desktop            # One-time setup
jac build --client desktop   # Build desktop app
jac start --client desktop   # Dev mode for desktop
```

Desktop builds produce native executables for Windows, macOS, and Linux.

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
    def:pub Form() -> any {
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
    def:pub ConditionalComponent() -> any {
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

## Related Resources

- [Fullstack Setup Tutorial](../../tutorials/fullstack/setup.md)
- [Components Tutorial](../../tutorials/fullstack/components.md)
- [State Management Tutorial](../../tutorials/fullstack/state.md)
- [Backend Integration Tutorial](../../tutorials/fullstack/backend.md)
- [Authentication Tutorial](../../tutorials/fullstack/auth.md)
- [Routing Tutorial](../../tutorials/fullstack/routing.md)
