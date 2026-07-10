# Full-Stack Project Setup

Jac's built-in client framework lets you build full-stack web applications where the frontend (React-style JSX components) and backend (walkers, functions, graph operations) live in the same codebase -- even the same file. The compiler separates client and server code automatically: client-side code -- a `.cl.jac` file or anything inside a `cl { }` block -- compiles to JavaScript and runs in the browser, while everything else compiles to Python and runs on the server.

This means no separate frontend repository, no REST API boilerplate, and no manual data serialization. When a client component calls a server function, the compiler generates the HTTP layer for you. Hot Module Replacement (HMR) is built in, so changes to both frontend and backend code reflect instantly during development.

In this tutorial, you'll set up a full-stack project, understand the file structure, and get the development server running.

> **Prerequisites**
>
> - Completed: [Installation](../../quick-guide/install.md)
> - Familiar with: HTML/CSS basics, React concepts helpful
> - Install: `curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash` (installs the self-contained `jac` binary -- no Python, pip, or uv required)
> - Time: ~15 minutes

---

## Create a Project

```bash
jac create --use web-static myapp
cd myapp
```

This creates:

```
myapp/
├── jac.toml              # Configuration
├── main.jac              # Entry point (frontend + backend)
├── README.md             # Project readme
├── AGENTS.md             # Agent guide for the project
├── components/           # Reusable UI components
│   └── Button.cl.jac     # Example button component
├── assets/               # Static assets (images, fonts)
├── .jac/                 # Build artifacts (gitignored)
└── .gitignore            # Git ignore rules
```

---

## Project Structure

### main.jac

```jac
# Backend code (nodes, walkers)
node Todo {
    has title: str;
    has done: bool = False;
}

walker:pub get_todos {
    can fetch with Root entry {
        for todo in [-->][?:Todo] {
            report todo;
        }
    }
}

# Frontend code (client section)
cl {
    def:pub app() -> JsxElement {
        has message: str = "Hello from Jac!";

        return <div>
            <h1>{message}</h1>
        </div>;
    }
}
```

### jac.toml

```toml
[project]
name = "myapp"
version = "1.0.0"
description = "Jac client application: myapp"
entry-point = "main.jac"

[dependencies.npm]
react = "^18.2.0"
react-dom = "^18.2.0"
react-router-dom = "^6.22.0"
react-error-boundary = "^5.0.0"
zod = "^4.3.6"

[dependencies.npm.dev]
vite = "^6.4.1"
"@vitejs/plugin-react" = "^4.2.1"
typescript = "^5.3.3"
"@types/react" = "^18.2.0"
"@types/react-dom" = "^18.2.0"

[dev-dependencies]
watchdog = ">=3.0.0"

[serve]
base_route_app = "app"

[client]
```

---

## Run the App

### Development Mode (with Hot Reload)

```bash
jac start --dev
```

This starts:

- **Vite dev server** on port 8000 (open in browser)
- **API server** on port 8001 (proxied via Vite)
- **File watcher** for `.jac` files

Open http://localhost:8000/cl/app

### Production Mode

```bash
jac start
```

Open http://localhost:8000/cl/app

---

## Understanding `cl { }`

A `cl { }` block marks frontend (client) code -- everything inside the braces compiles to JavaScript/React, while everything outside stays on the server:

```jac
# This is backend code (runs on server)
walker api_endpoint {
    can visit with Root entry { report {}; }
}

# This is frontend code (runs in browser)
cl {
    def:pub MyComponent() -> JsxElement {
        return <div>I run in the browser</div>;
    }
}
```

**Key rules:**

- Code inside a `cl { }` block (or in a `.cl.jac` file) compiles to JavaScript/React
- `def:pub` exports functions (like React components)
- `app()` is the required entry point

---

## File Organization Options

### Option 1: Single File (Small Apps)

```jac
# main.jac - everything in one file

# Backend
node User { has name: str = ""; }
walker get_user {
    can visit with Root entry { report {}; }
}

# Frontend
cl {
    def:pub app() -> JsxElement {
        return <div>App</div>;
    }
}
```

### Option 2: Separate Files (Larger Apps)

```
myapp/
├── main.jac           # Entry point
├── models.jac         # Backend nodes
├── api.jac            # Backend walkers
├── components/
│   ├── Header.cl.jac  # Frontend component
│   └── Footer.cl.jac  # Frontend component
└── pages/
    ├── Home.cl.jac    # Frontend page
    └── About.cl.jac   # Frontend page
```

**Note:** `.cl.jac` files are automatically client-side (no `cl { }` block needed).

---

## Import Between Files

### Backend Imports

```jac
# api.jac
import from models { User, Todo }

walker get_user {
    can visit with Root entry { report {}; }
}
```

### Frontend Imports

```jac
# main.jac
cl {
    import from "./components/Header.cl.jac" { Header }

    def:pub app() -> JsxElement {
        return <div>
            <Header />
            <main>Content</main>
        </div>;
    }
}
```

---

## Adding npm Packages

```bash
# Add a package
jac install --npm lodash

# Add dev dependency
jac install --npm --dev @types/react

# Install all dependencies
jac install --npm
```

Or in `jac.toml`:

```toml
[dependencies.npm]
lodash = "^4.17.21"
axios = "^1.6.0"
```

Then use in frontend:

!!! note "npm imports and `jac check`"
    npm packages bundle correctly at build time, but the static checker has no `.d.ts`-like stubs for them yet, so `jac check` reports their attributes as Unknown. The code below runs as written under `jac start`.

```jac
cl {
    import lodash;

    def:pub app() -> JsxElement {
        items = lodash.sortBy(["c", "a", "b"]);
        return <ul>{[<li>{i}</li> for i in items]}</ul>;
    }
}
```

---

## Configuration

### jac.toml Options

```toml
[project]
name = "myapp"
version = "0.1.0"
entry-point = "main.jac"

[client]
# Client-specific config

[client.configs.postcss]
plugins = ["tailwindcss", "autoprefixer"]

[dependencies]
# Python packages

[dependencies.npm]
# npm packages

[dev-dependencies]
watchdog = ">=3.0.0"
```

---

## Verify Setup

Create this minimal `main.jac`:

```jac
cl {
    def:pub app() -> JsxElement {
        has count: int = 0;

        return <div style={{"textAlign": "center", "marginTop": "50px"}}>
            <h1>Jac Full-Stack</h1>
            <p>Count: {count}</p>
            <button onClick={lambda -> None { count = count + 1; }}>
                Increment
            </button>
        </div>;
    }
}
```

Run `jac start --dev` and open http://localhost:8000/cl/app

Click the button - the count should increase!

---

## Next Steps

- [Components](components.md) - Build reusable UI components
- [State Management](state.md) - Reactive state with hooks
- [Backend Integration](backend.md) - Connect to walkers
- [Building a Desktop App](desktop.md) - Package the same app as a single `jac nacompile`d binary that embeds the OS webview - no Rust toolchain (ships with `jaclang` core; see [jac-desktop Reference](../../reference/plugins/jac-desktop.md))
- [Build an AI Day Planner](../first-app/build-ai-day-planner.md) - Complete full-stack example with AI
