# Backend Development — Endpoints, Persistence, Auth

## Function Endpoints (def:pub / def:priv)

Simple CRUD — preferred for most use cases.

```jac
import from uuid { uuid4 }
import from datetime { datetime }

node Todo {
    has id: str = "";
    has title: str = "";
    has completed: bool = False;
    has created_at: str = "";
}

def:pub get_todos() -> list {
    return [{"id": t.id, "title": t.title, "completed": t.completed}
            for t in [root()-->][?:Todo]];
}

def:pub add_todo(title: str) -> dict {
    todo = (root() ++> Todo(
        id=str(uuid4()), title=title,
        created_at=str(datetime.now())
    ))[0];
    return {"id": todo.id, "title": todo.title, "completed": False};
}

def:pub toggle_todo(id: str) -> dict {
    for todo in [root()-->][?:Todo] {
        if todo.id == id {
            todo.completed = not todo.completed;
            return {"id": todo.id, "completed": todo.completed};
        }
    }
    return {"error": "not found"};
}

def:pub delete_todo(id: str) -> dict {
    for todo in [root()-->][?:Todo] {
        if todo.id == id {
            del todo;
            return {"deleted": id};
        }
    }
    return {"error": "not found"};
}
```

## Walker Endpoints

For graph traversal and multi-step operations:

```jac
walker :pub get_post_with_comments {
    has post_id: str = "";

    can find_post with Root entry {
        for p in [-->][?:Post] {
            if p.id == self.post_id { visit p; return; }
        }
        report {"error": "not found"};
    }

    can collect with Post entry {
        comments = [{"id": c.id, "text": c.text}
                    for c in [-->][?:Comment]];
        report {
            "post": {"id": here.id, "title": here.title},
            "comments": comments
        };
    }
}
```

## Data Persistence

- Nodes connected to `root()` **auto-persist** across requests (SQLite)
- No database setup needed — the language handles it
- `del node;` removes from graph and storage

```jac
# Create + persist
root() ++> Todo(id=str(uuid4()), title="Buy milk");

# Query all
todos = [root()-->][?:Todo];

# Query with filter
found = [root()-->][?:Todo](?title == "Buy milk");

# Delete
root() del--> todo;
# or: del todo;
```

## Per-User Data Isolation (def:priv)

`:priv` endpoints require authentication. Each user gets their own isolated `root()`.

```jac
# Public — shared root, anyone can call
def:pub get_shared_data() -> list {
    return [{"id": str(d.id)} for d in [root()-->][?:DataNode]];
}

# Private — per-user root, requires login
def:priv get_my_tasks() -> list {
    return [{"id": t.id, "title": t.title}
            for t in [root()-->][?:Task]];
}
```

## Authentication

Built-in — no manual login/signup logic needed. The runtime handles JWT tokens, storage, and session management.

```jac
import from "@jac/runtime" { jacLogin, jacSignup, jacLogout, jacIsLoggedIn }
```

| Function | Async? | Returns | Behavior |
|----------|--------|---------|----------|
| `jacLogin(username, password)` | yes | `bool` | POSTs `/user/login`, stores JWT in localStorage on success |
| `jacSignup(username, password)` | yes | `dict` `{"success": bool, "error"?: str}` | POSTs `/user/register`, auto-stores token on success (user is logged in) |
| `jacLogout()` | no | `void` | Clears token + all cache |
| `jacIsLoggedIn()` | no | `bool` | Checks if token exists in localStorage |

**Runtime behaviors:**

- Token stored as `jac_token` in localStorage, sent as `Authorization: Bearer {token}` on every `def:priv`/`walker:priv` call
- On 401 response: token auto-cleared, page reloads (user redirected to login)
- `jacSignup` success = user is already logged in (no separate login call needed)

**SSO (Google OAuth)** — configure in `jac.toml`, no code needed:

```toml
[plugins.scale.sso.google]
client_id = "your-google-client-id"
client_secret = "your-google-client-secret"
```

## File-Based Routing

```
pages/
├── layout.jac              # Root layout with <Outlet />
├── index.jac               # Route: /
├── about.jac               # Route: /about
├── users/
│   ├── index.jac           # Route: /users
│   └── [id].jac            # Route: /users/:id (dynamic)
├── (public)/               # Route group (no URL segment)
│   └── login.jac           # Route: /login
├── (auth)/                 # Protected group
│   ├── layout.jac          # AuthGuard layout
│   └── dashboard.jac       # Route: /dashboard
└── [...notFound].jac       # Catch-all 404
```

### Layout with Outlet

```jac
# pages/layout.jac
import from "@jac/runtime" { Outlet, Link }

cl {
    def:pub layout() -> JsxElement {
        return <>
            <nav>
                <Link to="/">Home</Link>
                <Link to="/about">About</Link>
            </nav>
            <main><Outlet /></main>
        </>;
    }
}
```

### Dynamic Routes

```jac
# pages/users/[id].jac
import from "@jac/runtime" { useParams }

cl {
    def:pub page() -> JsxElement {
        params = useParams();
        return <div>User: {params.id}</div>;
    }
}
```

### Protected Routes

```jac
# pages/(auth)/layout.jac
import from "@jac/runtime" { AuthGuard, Outlet }

cl {
    def:pub layout() -> JsxElement {
        return <AuthGuard redirect="/login"><Outlet /></AuthGuard>;
    }
}
```

### Navigation

```jac
import from "@jac/runtime" { useNavigate, Link }

navigate = useNavigate();
navigate("/path");                    # Push
navigate("/path", {"replace": True}); # Replace
navigate(-1);                          # Back

<Link to="/about">About</Link>
```

## Running a Fullstack App

```bash
jac start --dev main.jac   # Dev: Vite + API server (port from jac.toml config)
jac start main.jac         # Production: single server
```

Visit `http://localhost:<port>/docs` for Swagger UI (check terminal output for actual port).
