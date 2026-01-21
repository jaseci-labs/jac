# Full-Stack Development with Jac Client

Build complete web applications using Jac for both frontend and backend. Jac Client provides React-style components with JSX syntax, state management, and seamless backend integration.

## Why Jac Client?

| Traditional Stack | Jac Full-Stack |
|-------------------|----------------|
| Separate frontend/backend languages | Single language for everything |
| HTTP boilerplate (fetch, axios) | Direct walker calls via `spawn` |
| Manual API integration | Seamless frontend-backend bridge |
| Separate type systems | Type safety across boundaries |

---

## Quick Start

```bash
# Create a new full-stack project
jac create --use client myapp
cd myapp
jac start
```

Visit `http://localhost:8000/cl/app` to see your app.

---

## Project Structure

```
myapp/
├── jac.toml              # Configuration
├── main.jac              # Main entry point (frontend + backend)
├── components/           # Reusable components (TypeScript/JSX)
│   └── Button.cl.jac        # Example component
├── assets/               # Static files (images, fonts)
└── .jac/                 # Build artifacts (gitignored)
```

---

## Basic Component

```jac
cl {
    def:pub app() -> any {
        has count: int = 0;

        return <div>
            <h1>Count: {count}</h1>
            <button onClick={lambda -> None { count = count + 1; }}>
                Increment
            </button>
        </div>;
    }
}
```

**Key Points:**

- `cl { }` block marks frontend code
- `def:pub app()` is the required entry point
- `has` variables in client functions are automatically reactive (generates React useState)

---

## State Management

### Reactive State with `has`

Inside a `cl { }` block or `.cl.jac` file, `has` variables automatically become React state. The compiler generates `useState` calls, auto-injects the `useState` import from `@jac-client/utils`, and transforms assignments to setter calls.

```jac
cl {
    def:pub Counter() -> any {
        has count: int = 0;
        has name: str = "World";

        return <div>
            <h1>Hello, {name}! Count: {count}</h1>
            <input
                value={name}
                onChange={lambda e: any -> None { name = e.target.value; }}
            />
            <button onClick={lambda -> None { count = count + 1; }}>+1</button>
        </div>;
    }
}
```

**Generated JavaScript:**

```javascript
const [count, setCount] = useState(0);
const [name, setName] = useState("World");
// Assignments like `count = count + 1` become `setCount(count + 1)`
```

### useEffect

```jac
cl {
    import from react { useEffect }

    def:pub DataLoader() -> any {
        has data: list = [];

        # Run once on mount
        useEffect(lambda -> None {
            async def load() -> None {
                result = root spawn get_items();
                data = result.reports;
            }
            load();
        }, []);

        return <ul>
            {data.map(lambda item: any -> any {
                return <li key={item._jac_id}>{item.name}</li>;
            })}
        </ul>;
    }
}
```

### useContext (Global State)

```jac
cl {
    import from react { createContext, useContext }

    AppContext = createContext(None);

    def:pub AppProvider(props: dict) -> any {
        has user: any = None;

        return <AppContext.Provider value={{ "user": user, "setUser": lambda v: any -> None { user = v; } }}>
            {props.children}
        </AppContext.Provider>;
    }

    def:pub UserDisplay() -> any {
        ctx = useContext(AppContext);
        return <div>User: {ctx.user or "Not logged in"}</div>;
    }
}
```

---

## Backend Integration

### Define Backend Walker

```jac
# Backend code (outside cl block)
node Todo {
    has text: str;
    has done: bool = False;
}

walker create_todo {
    has text: str;

    can create with `root entry {
        new_todo = here ++> Todo(text=self.text);
        report new_todo;
    }
}

walker get_todos {
    can fetch with `root entry {
        for todo in [-->(`?Todo)] {
            report todo;
        }
    }
}
```

### Call from Frontend

```jac
cl {
    import from react { useEffect }

    def:pub TodoApp() -> any {
        has todos: list = [];
        has text: str = "";

        # Load todos on mount
        useEffect(lambda -> None {
            async def load() -> None {
                result = root spawn get_todos();
                todos = result.reports;
            }
            load();
        }, []);

        # Add todo handler
        def add_todo() -> None {
            async def create() -> None {
                result = root spawn create_todo(text=text);
                todos = [...todos, result.reports[0]];
                text = "";
            }
            create();
        }

        return <div>
            <input value={text} onChange={lambda e: any -> None { text = e.target.value; }} />
            <button onClick={lambda -> None { add_todo(); }}>Add</button>
            <ul>
                {todos.map(lambda t: any -> any {
                    return <li key={t._jac_id}>{t.text}</li>;
                })}
            </ul>
        </div>;
    }
}
```

---

## Routing

```jac
cl {
    import from "@jac-client/utils" { Router, Routes, Route, Link, useParams, useNavigate }

    def:pub Home() -> any {
        return <div>
            <h1>Home</h1>
            <Link to="/about">About</Link>
            <Link to="/user/123">User 123</Link>
        </div>;
    }

    def:pub About() -> any {
        return <h1>About Page</h1>;
    }

    def:pub UserProfile() -> any {
        params = useParams();
        return <h1>User: {params.id}</h1>;
    }

    def:pub app() -> any {
        return <Router>
            <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/about" element={<About />} />
                <Route path="/user/:id" element={<UserProfile />} />
            </Routes>
        </Router>;
    }
}
```

**Available Hooks:**

- `useNavigate()`: Programmatic navigation
- `useLocation()`: Current pathname, search, hash
- `useParams()`: URL parameters (`:id`)

---

## Authentication

```jac
cl {
    import from "@jac-client/utils" {
        jacLogin, jacSignup, jacLogout, jacIsLoggedIn
    }

    def:pub LoginForm() -> any {
        has username: str = "";
        has password: str = "";
        has error: str = "";

        def handle_login() -> None {
            async def login() -> None {
                success = await jacLogin(username, password);
                if success {
                    # Redirect or update state
                    print("Logged in!");
                } else {
                    error = "Login failed";
                }
            }
            login();
        }

        def handle_signup() -> None {
            async def signup() -> None {
                result = await jacSignup(username, password);
                if result.success {
                    print("Account created!");
                }
            }
            signup();
        }

        return <div>
            <input placeholder="Username" value={username}
                   onChange={lambda e: any -> None { username = e.target.value; }} />
            <input type="password" placeholder="Password" value={password}
                   onChange={lambda e: any -> None { password = e.target.value; }} />
            <button onClick={lambda -> None { handle_login(); }}>Login</button>
            <button onClick={lambda -> None { handle_signup(); }}>Sign Up</button>
            {error and <p style={{"color": "red"}}>{error}</p>}
        </div>;
    }

    def:pub ProtectedRoute(props: dict) -> any {
        if not jacIsLoggedIn() {
            return <Navigate to="/login" />;
        }
        return props.children;
    }
}
```

---

## Styling Options

### Inline Styles

```jac
cl {
    def:pub StyledButton() -> any {
        return <button style={{
            "backgroundColor": "blue",
            "color": "white",
            "padding": "10px 20px",
            "borderRadius": "5px"
        }}>
            Click Me
        </button>;
    }
}
```

### CSS Files

```jac
cl {
    import ".styles.css"

    def:pub MyComponent() -> any {
        return <div className="container">
            <h1 className="title">Hello</h1>
        </div>;
    }
}
```

### Tailwind CSS

Configure in `jac.toml` using `[plugins.client.configs]`:

```toml
[plugins.client.configs.postcss]
plugins = ["tailwindcss", "autoprefixer"]

[plugins.client.configs.tailwind]
content = ["./**/*.jac", "./**/*.cl.jac", "./.jac/client/**/*.{js,jsx,ts,tsx}"]
plugins = []
```

Then import your CSS file with Tailwind directives:

```jac
cl {
    import ".styles.css"  # Contains @tailwind directives

    def:pub TailwindComponent() -> any {
        return <div className="bg-blue-500 text-white p-4 rounded-lg">
            Tailwind Styled
        </div>;
    }
}
```

---

## TypeScript Integration

```jac
cl {
    # Import TypeScript components
    import from ".Button.tsx" { Button }

    def:pub app() -> any {
        return <div>
            <Button label="Click me" onClick={lambda -> None { print("Clicked!"); }} />
        </div>;
    }
}
```

---

## Package Management

```bash
# Add npm packages
jac add --npm lodash
jac add --npm --dev @types/react

# Remove packages
jac remove --npm lodash

# Install all dependencies
jac add --npm
```

Or in `jac.toml`:

```toml
[dependencies.npm]
lodash = "^4.17.21"
axios = "^1.6.0"

[dependencies.npm.dev]
sass = "^1.77.8"
```

---

## Exports (`:pub` keyword)

For jac-client >= 0.2.4, use `:pub` to export:

```jac
cl {
    # Exported function
    def:pub MyComponent() -> any { ... }

    # Exported variable
    glob:pub API_URL: str = "https://api.example.com";

    # Not exported (internal use only)
    def helper() -> any { ... }
}
```

---

## File Organization

### Separate Files

```
src/
├── app.jac           # Backend (nodes, walkers)
├── app.cl.jac        # Frontend (no cl block needed)
├── components/
│   ├── Button.jac
│   └── Modal.jac
└── pages/
    ├── Home.jac
    └── About.jac
```

### Mixed in Single File

```jac
# Backend code
node Todo { has text: str; }
walker get_todos { ... }

# Frontend code
cl {
    def:pub app() -> any {
        # Uses backend walkers directly
        result = root spawn get_todos();
        ...
    }
}
```

---

## Build Commands

```bash
# Development server (uses main.jac by default)
# If main.jac doesn't exist, specify your entry file: jac start app.jac
jac start

# Start with specific file (if your entry point is not main.jac)
jac start app.jac

# Production build
jac build main.jac

# Using jac.toml entry-point
jac start  # Uses [project].entry-point
```

> **Note**:
>
> - If your project uses a different entry file (e.g., `app.jac`, `server.jac`), specify it explicitly: `jac start app.jac`
>
---

## Hot Module Replacement (HMR)

For faster development, use `--dev` mode to enable Hot Module Replacement. Changes to `.jac` files are automatically detected and reloaded without restarting the server.

### Setup

HMR requires the `watchdog` package. New projects include it in `[dev-dependencies]` by default:

```toml
[dev-dependencies]
watchdog = ">=3.0.0"
```

Install dev dependencies:

```bash
jac install --dev
```

### Development Workflow

```bash
# Start with HMR enabled (uses main.jac by default)
jac start --dev
```

This starts:

- **Vite dev server** on port 8000 (open this in browser)
- **API server** on port 8001 (proxied via Vite)
- **File watcher** monitoring `*.jac` files for changes

When you edit a `.jac` file:

1. File watcher detects the change
2. Backend code is recompiled automatically
3. Frontend hot-reloads via Vite
4. Browser updates without full page refresh

### HMR Options

| Option | Description |
|--------|-------------|
| `--dev, -d` | Enable HMR mode |
| `--api-port PORT` | Custom API port (default: main port + 1) |
| `--no-client` | API-only mode (skip Vite/frontend) |

**Examples:**

```bash
# Full-stack HMR (frontend + backend, uses main.jac by default)
jac start --dev

# API-only HMR (no frontend bundling)
jac start --dev --no-client

# Custom ports
jac start --dev -p 3000 --api-port 3001
```

### Troubleshooting

If you see an error about watchdog not being installed:

```
Error: --dev requires 'watchdog' package to be installed.

Install it by running:
    jac install --dev
```

---

## Learn More

| Topic | Resource |
|-------|----------|
| Getting Started | [README](../jac-client/README.md) |
| Components | [Step 2: Components](../jac-client/guide-example/step-02-components.md) |
| Lifecycle Hooks | [Hooks Guide](../jac-client/lifecycle-hooks.md) |
| Advanced State | [State Patterns](../jac-client/advanced-state.md) |
| Styling Guide | [6 Styling Methods](../jac-client/styling/intro.md) |
| Routing | [Client-side Routing](../jac-client/routing.md) |
| Backend Integration | [Walkers as APIs](../jac-client/guide-example/step-08-walkers.md) |
| Authentication | [Auth Flows](../jac-client/guide-example/step-09-authentication.md) |
| TypeScript | [TS Integration](../jac-client/working-with-ts.md) |
| Configuration | [Advanced Config](../jac-client/advance/intro.md) |

## Tutorial Path

1. [Project Setup](../jac-client/guide-example/step-01-setup.md)
2. [First Component](../jac-client/guide-example/step-02-components.md)
3. [Styling](../jac-client/guide-example/step-03-styling.md)
4. [State Management](../jac-client/guide-example/step-05-local-state.md)
5. [Backend Integration](../jac-client/guide-example/step-08-walkers.md)
6. [Authentication](../jac-client/guide-example/step-09-authentication.md)
7. [Routing](../jac-client/guide-example/step-10-routing.md)
