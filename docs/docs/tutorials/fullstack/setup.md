# Full-Stack Project Setup

Create a Jac project with frontend and backend in one codebase.

> **Prerequisites**
>
> - Completed: [Hello World](../../quick-guide/hello-world.md)
> - Familiar with: HTML/CSS basics, React concepts helpful
> - Install: `pip install jaseci`
> - Time: ~15 minutes

---

## Create a Project

```bash
jac create --use client myapp
cd myapp
```

This creates:

```
myapp/
├── jac.toml              # Configuration
├── main.jac              # Entry point (frontend + backend)
├── README.md             # Project readme
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
        for todo in [-->](?:Todo) {
            report todo;
        }
    }
}

# Frontend code (inside cl block)
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
description = "Jac client application"
entry-point = "main.jac"

[dependencies]

[dependencies.npm]
jac-client-node = "1.0.4"

[dependencies.npm.dev]
"@jac-client/dev-deps" = "1.0.0"

[dev-dependencies]
watchdog = ">=3.0.0"

[serve]
base_route_app = "app"

[plugins.client]
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

The `cl { }` block marks frontend (client) code:

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

- `cl { }` code compiles to JavaScript/React
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

**Note:** `.cl.jac` files are automatically client-side (no `cl { }` needed).

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
jac add --npm lodash

# Add dev dependency
jac add --npm --dev @types/react

# Install all dependencies
jac add --npm
```

Or in `jac.toml`:

```toml
[dependencies.npm]
lodash = "^4.17.21"
axios = "^1.6.0"
```

Then use in frontend:

```jac
cl {
    import lodash;

    def:pub app() -> JsxElement {
        items = lodash.sortBy(["c", "a", "b"]);
        return <ul>{items.map(lambda i: any -> any { return <li>{i}</li>; })}</ul>;
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

[plugins.client]
# Client-specific config

[plugins.client.configs.postcss]
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
- [Build a Todo App](todo-app.md) - Complete full-stack example with AI
