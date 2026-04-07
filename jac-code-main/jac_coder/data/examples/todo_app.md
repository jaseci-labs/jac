# Todo App — Jac Fullstack Example

Authenticated todo app: graph-backed CRUD via `def:priv` endpoints, `sv import` for server calls, `AuthGuard` protected routes, and reactive `has` state with `async can with entry` on-mount fetch. Styled with Tailwind v4 utility classes — design tokens registered via `@theme` in `global.css`.

## Project Structure

```
todo/
├── jac.toml
├── main.jac                         # Entry: imports backend symbols + mounts client
├── service/
│   └── todoService.sv.jac           # Todo node + all def:priv CRUD functions
├── index.cl.jac                     # Client router: /, /login, /dashboard
├── pages/
│   └── login.cl.jac                 # Login/signup with jacLogin, jacSignup
├── components/
│   ├── TodoList.cl.jac              # Dashboard: header, progress bar, add form, list
│   ├── TodoItem.cl.jac              # Single todo row: checkbox + hover-reveal delete
│   └── EmptyState.cl.jac            # Empty list placeholder
├── hooks/
│   └── useTodos.cl.jac              # State + API: fetch on mount, auth error handling
└── styles/
    └── global.css                   # Tailwind v4 @theme tokens + base styles
```

---

## `jac.toml`

```toml
[project]
name = "todo"
version = "1.0.0"
description = "Jac Todo application"
entry-point = "main.jac"

[dependencies]
python-dotenv = ">=1.0.0"

[dependencies.npm]
jac-client-node = "1.0.7"
clsx = "^2.1.1"
tailwind-merge = "^3.4.0"

[dependencies.npm.dev]
"@jac-client/dev-deps" = "2.0.0"
"@tailwindcss/vite" = "^4.1.17"
tailwindcss = "^4.1.17"

[serve]
base_route_app = "app"

[plugins.client.vite]
plugins = ["tailwindcss()"]
lib_imports = ["import tailwindcss from '@tailwindcss/vite'"]

[plugins.client.app_meta_data]
title = "todo"
```

---

## `main.jac`

Entry point. Imports all backend symbols from the service so they are registered as `/function/` endpoints, then mounts the client via `cl import`.

```jac
import from service.todoService { Todo, get_todos, add_todo, toggle_todo, delete_todo }

cl import from .index { ClientApp }

cl {
    def:pub app() -> JsxElement {
        return <ClientApp/>;
    }
}
```

---

## `service/todoService.sv.jac`


```jac
import from uuid { uuid4 }
import from datetime { datetime }

node Todo {
    has id: str = "";
    has title: str = "";
    has completed: bool = False;
    has created_at: str = "";

    def postinit {
        if not self.id {
            self.id = str(uuid4());
        }
        if not self.created_at {
            self.created_at = datetime.now().isoformat();
        }
    }
}

def:priv get_todos() -> list {
    return [
        {"id": t.id, "title": t.title, "completed": t.completed}
        for t in [root()-->][?:Todo]
    ];
}

def:priv add_todo(title: str) -> dict {
    todo = (root() ++> Todo(title=title))[0];
    return {"id": todo.id, "title": todo.title, "completed": False};
}

def:priv toggle_todo(id: str) -> dict {
    for todo in [root()-->][?:Todo] {
        if todo.id == id {
            todo.completed = not todo.completed;
            return {"id": todo.id, "completed": todo.completed};
        }
    }
    return {"error": "not found"};
}

def:priv delete_todo(id: str) -> dict {
    for todo in [root()-->][?:Todo] {
        if todo.id == id {
            root() del --> todo;
            return {"deleted": id};
        }
    }
    return {"error": "not found"};
}
```

---

## `index.cl.jac`


```jac
import ".styles.global.css";
import from .pages.login { page as LoginPage }
import from .components.TodoList { TodoList }
import from "@jac/runtime" { AuthGuard, Router, Routes, Route, Navigate }

def:pub AuthGuardRoute() -> JsxElement {
    return <>{AuthGuard("/login")}</>;
}

def:pub ClientApp() -> JsxElement {
    return (
        <Router>
            <Routes>
                <Route path="/" element={<Navigate to="/login" replace={True} />} />
                <Route path="/login" element={<LoginPage />} />
                <Route element={<AuthGuardRoute />}>
                    <Route path="/dashboard" element={<TodoList />} />
                </Route>
            </Routes>
        </Router>
    );
}
```

---

## `pages/login.cl.jac`


```jac
import from "@jac/runtime" { useNavigate, jacLogin, jacSignup }

def:pub page() -> JsxElement {
    has is_login_mode: bool = True;
    has email: str = "";
    has password: str = "";
    has error: str = "";
    has loading: bool = False;
    navigate = useNavigate();

    async def handle_submit(e: any) -> None {
        e.preventDefault();
        loading = True;
        error = "";
        try {
            if is_login_mode {
                login_res = await jacLogin(email, password);
                if login_res {
                    navigate("/dashboard");
                } else {
                    error = "Invalid credentials";
                }
            } else {
                signup_res = await jacSignup(email, password);
                if signup_res {
                    login_after_signup = await jacLogin(email, password);
                    if login_after_signup {
                        navigate("/dashboard");
                    } else {
                        error = "Login after signup failed. Please try logging in.";
                    }
                } else {
                    error = "Signup failed. Email might be in use.";
                }
            }
        } except Exception as e {
            error = "An error occurred during authentication.";
        }
        loading = False;
    }

    def handle_email(e: any) -> None {
        email = e.target.value;
    }
    def handle_password(e: any) -> None {
        password = e.target.value;
    }

    def toggle_mode() -> None {
        is_login_mode = not is_login_mode;
        error = "";
    }

    return (
        <div className="min-h-screen w-full bg-background flex items-center justify-center p-4">
            <div className="w-full max-w-[28rem]">
                <div className="text-center mb-10">
                    <h1 className="text-5xl text-foreground tracking-[0.05em] leading-none">
                        {"Welcome" if is_login_mode else "Create Account"}
                    </h1>
                    <p className="mt-3 text-sm text-muted-foreground">
                        {"Sign in to manage your tasks"
                            if is_login_mode
                            else "Sign up to get started"}
                    </p>
                </div>
                <div className="bg-card rounded-2xl border border-border shadow-card p-8">
                    {error and (<div className="bg-red-500/8 border border-red-500/25 rounded-xl px-4 py-3 text-sm text-red-700 mb-5">{error}</div>)}
                    <form onSubmit={handle_submit} className="flex flex-col gap-5">
                        <div>
                            <label className="block text-xs font-medium uppercase tracking-[0.05em] text-muted-foreground mb-2">Email</label>
                            <div className="relative">
                                <svg
                                    className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground pointer-events-none"
                                    viewBox="0 0 24 24"
                                    fill="none"
                                    xmlns="http://www.w3.org/2000/svg"
                                >
                                    <path
                                        d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"
                                        stroke="currentColor"
                                        strokeWidth="2"
                                        strokeLinecap="round"
                                        strokeLinejoin="round"
                                    />
                                    <polyline
                                        points="22,6 12,13 2,6"
                                        stroke="currentColor"
                                        strokeWidth="2"
                                        strokeLinecap="round"
                                        strokeLinejoin="round"
                                    />
                                </svg>
                                <input
                                    className="w-full rounded-xl border border-border bg-background text-foreground pl-10 pr-4 py-3 text-sm outline-none transition-[border-color,box-shadow] duration-150 placeholder:text-muted-foreground focus:border-primary focus:ring-[3px] focus:ring-primary/12"
                                    type="text"
                                    value={email}
                                    onChange={handle_email}
                                    placeholder="Enter your email"
                                    required={True}
                                    autoComplete="username"
                                />
                            </div>
                        </div>
                        <div>
                            <label className="block text-xs font-medium uppercase tracking-[0.05em] text-muted-foreground mb-2">Password</label>
                            <div className="relative">
                                <svg
                                    className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground pointer-events-none"
                                    viewBox="0 0 24 24"
                                    fill="none"
                                    xmlns="http://www.w3.org/2000/svg"
                                >
                                    <path
                                        d="M7 11V7a5 5 0 0 1 10 0v4"
                                        stroke="currentColor"
                                        strokeWidth="2"
                                        strokeLinecap="round"
                                    />
                                    <rect
                                        x="3"
                                        y="11"
                                        width="18"
                                        height="11"
                                        rx="2"
                                        ry="2"
                                        stroke="currentColor"
                                        strokeWidth="2"
                                    />
                                </svg>
                                <input
                                    className="w-full rounded-xl border border-border bg-background text-foreground pl-10 pr-4 py-3 text-sm outline-none transition-[border-color,box-shadow] duration-150 placeholder:text-muted-foreground focus:border-primary focus:ring-[3px] focus:ring-primary/12"
                                    type="password"
                                    value={password}
                                    onChange={handle_password}
                                    placeholder="••••••••"
                                    required={True}
                                    autoComplete="current-password"
                                />
                            </div>
                        </div>
                        <button
                            className="w-full h-12 inline-flex items-center justify-center gap-1.5 rounded-xl text-sm font-medium cursor-pointer transition-opacity duration-150 bg-primary text-primary-foreground border border-primary hover:opacity-90"
                            type="submit"
                            disabled={loading}
                        >
                            {loading
                            and (
                                "Signing in..." if is_login_mode else "Signing up..."
                            )
                            or (
                                <span className="flex items-center justify-center gap-2">
                                    {"Sign in" if is_login_mode else "Sign up"}
                                    <svg
                                        width="16"
                                        height="16"
                                        viewBox="0 0 24 24"
                                        fill="none"
                                        xmlns="http://www.w3.org/2000/svg"
                                    >
                                        <path
                                            d="M5 12h14M12 5l7 7-7 7"
                                            stroke="currentColor"
                                            strokeWidth="2"
                                            strokeLinecap="round"
                                            strokeLinejoin="round"
                                        />
                                    </svg>
                                </span>
                            )}
                        </button>
                    </form>
                    <div className="mt-6 text-center text-sm text-muted-foreground">
                        {"Don't have an account? "
                            if is_login_mode
                            else "Already have an account? "}
                        <button
                            type="button"
                            onClick={toggle_mode}
                            className="bg-transparent border-0 text-primary font-medium cursor-pointer underline p-0"
                        >
                            {"Sign up" if is_login_mode else "Sign in"}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
}
```

---

## `hooks/useTodos.cl.jac`

```jac
sv import from ..service.todoService { get_todos, add_todo, toggle_todo, delete_todo }
import from "@jac/runtime" { jacLogout, useNavigate }

def:pub useTodos() -> dict {
    has todos: list = [];
    has loading: bool = True;
    has error: str = "";

    navigate = useNavigate();

    def handleAuthError() -> None {
        jacLogout();
        navigate("/login");
    }

    async def fetch_initial() -> None {
        try {
            result = await get_todos();
            todos = result or [];
        } except Exception as e {
            msg = str(e);
            if "UNAUTHORIZED" in msg {
                handleAuthError();
                return;
            } else {
                error = "Failed to load: " + msg;
            }
        }
        loading = False;
    }

    async can with entry {
        await fetch_initial();
    }

    async def handleAdd(title: str) -> None {
        if not title {
            return;
        }
        try {
            result = await add_todo(title);
            if result and ("error" not in result) {
                todos = todos + [result];
            }
        } except Exception as e {
            msg = str(e);
            if "UNAUTHORIZED" in msg {
                handleAuthError();
            } else {
                error = msg;
            }
        }
    }

    async def handleToggle(id: str) -> None {
        try {
            result = await toggle_todo(id);
            if result and ("error" not in result) {
                todos = [
                    (
                        {
                            "id": t["id"],
                            "title": t["title"],
                            "completed": result["completed"]
                        }
                            if t["id"] == id
                            else t
                    ) for t in todos
                ];
            }
        } except Exception as e {
            msg = str(e);
            if "UNAUTHORIZED" in msg {
                handleAuthError();
            } else {
                error = msg;
            }
        }
    }

    async def handleDelete(id: str) -> None {
        try {
            result = await delete_todo(id);
            if result and ("error" not in result) {
                todos = [
                    t
                    for t in todos
                    if t["id"] != id
                ];
            }
        } except Exception as e {
            msg = str(e);
            if "UNAUTHORIZED" in msg {
                handleAuthError();
            } else {
                error = msg;
            }
        }
    }

    return {
        "todos": todos,
        "loading": loading,
        "error": error,
        "handleAdd": handleAdd,
        "handleToggle": handleToggle,
        "handleDelete": handleDelete
    };
}
```

---

## `components/EmptyState.cl.jac`

```jac
def:pub EmptyState(props: dict) -> JsxElement {
    return (
        <div className="text-center py-16">
            <div className="inline-flex items-center justify-center rounded-2xl mb-4 w-16 h-16 bg-muted">
                <svg
                    className="text-muted-foreground"
                    width="28"
                    height="28"
                    viewBox="0 0 24 24"
                    fill="none"
                    xmlns="http://www.w3.org/2000/svg"
                >
                    <path
                        d="M22 11.08V12a10 10 0 1 1-5.93-9.14"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                    />
                    <polyline
                        points="22 4 12 14.01 9 11.01"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                    />
                </svg>
            </div>
            <p className="text-sm text-muted-foreground">Your task list is empty</p>
        </div>
    );
}
```

---

## `components/TodoItem.cl.jac`


```jac
def:pub TodoItem(props: dict) -> JsxElement {
    todo = props["todo"] or {};
    onToggle = props["onToggle"] or None;
    onDelete = props["onDelete"] or None;

    tid: str = "";
    title: str = "";
    completed: bool = False;
    if "id" in todo { tid = str(todo["id"]); }
    if "title" in todo { title = str(todo["title"]); }
    if "completed" in todo { completed = bool(todo["completed"]); }

    def handleToggle() -> None {
        if onToggle { onToggle(tid); }
    }

    def handleDelete() -> None {
        if onDelete { onDelete(tid); }
    }

    return (
        <div className="group flex items-center gap-3 px-4 py-3.5 rounded-xl bg-card border border-border shadow-soft hover:shadow-card transition-shadow duration-200">
            <button
                className={"shrink-0 w-5 h-5 rounded-full border-2 flex items-center justify-center cursor-pointer transition-[background-color,border-color] duration-200 p-0 " + ("bg-primary border-primary" if completed else "border-muted-foreground/30 bg-transparent hover:border-primary")}
                onClick={handleToggle}
                aria-label={"Mark complete" if not completed else "Mark incomplete"}
            >
                {completed
                and (
                    <svg
                        width="10"
                        height="10"
                        viewBox="0 0 24 24"
                        fill="none"
                        xmlns="http://www.w3.org/2000/svg"
                    >
                        <path
                            d="M20 6L9 17l-5-5"
                            stroke="white"
                            strokeWidth="3"
                            strokeLinecap="round"
                            strokeLinejoin="round"
                        />
                    </svg>
                )}
            </button>
            <span className={"flex-1 text-sm transition-colors duration-200 " + ("line-through text-muted-foreground" if completed else "text-foreground")}>
                {title}
            </span>
            <button
                className="opacity-0 group-hover:opacity-100 p-1 rounded-md bg-transparent text-muted-foreground cursor-pointer transition-[opacity,color] duration-200 hover:text-destructive"
                onClick={handleDelete}
                aria-label="Delete task"
            >
                <svg
                    width="16"
                    height="16"
                    viewBox="0 0 24 24"
                    fill="none"
                    xmlns="http://www.w3.org/2000/svg"
                >
                    <polyline
                        points="3 6 5 6 21 6"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                    />
                    <path
                        d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                    />
                    <path
                        d="M10 11v6M14 11v6"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                    />
                    <path
                        d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                    />
                </svg>
            </button>
        </div>
    );
}
```

---

## `components/TodoList.cl.jac`

```jac
import from "@jac/runtime" { jacLogout, useNavigate }
import from .TodoItem { TodoItem }
import from .EmptyState { EmptyState }
import from ..hooks.useTodos { useTodos }

def:pub TodoList() -> JsxElement {
    data = useTodos();

    todos = data["todos"] or [];
    loading = data["loading"];
    error = data["error"] or "";

    navigate = useNavigate();

    total = len(todos);
    completed_count = len(
        [t for t in todos if ("completed" in t) and t["completed"]]
    );
    progress_pct = ((completed_count * 100) / total) if total > 0 else 0;

    subtitle = (
        "Nothing here yet. Add your first task!"
            if total == 0
            else (str(completed_count) + " of " + str(total) + " completed")
    );

    has new_title: str = "";

    def handle_input(e: any) -> None { new_title = e.target.value; }

    async def handle_add(e: any) -> None {
        e.preventDefault();
        if not new_title { return; }
        await data["handleAdd"](new_title);
        new_title = "";
    }

    def handle_toggle(todo_id: str) -> None { data["handleToggle"](todo_id); }
    def handle_delete(todo_id: str) -> None { data["handleDelete"](todo_id); }

    def handle_logout() -> None {
        jacLogout();
        navigate("/login");
    }

    return (
        <div className="min-h-screen w-full bg-background">
            <div className="max-w-[36rem] mx-auto px-4 py-12">
                <div className="flex items-start justify-between mb-10">
                    <div>
                        <h1 className="text-4xl leading-10 text-foreground tracking-[0.06em]">
                            Your tasks
                        </h1>
                        <p className="text-sm text-muted-foreground">{subtitle}</p>
                    </div>
                    <button
                        className="inline-flex items-center justify-center gap-1.5 rounded-xl px-5 py-2.5 text-sm font-medium cursor-pointer transition-[background-color,color,border-color] duration-150 border border-transparent bg-transparent text-muted-foreground hover:bg-muted hover:text-foreground"
                        onClick={handle_logout}
                    >
                        <svg
                            width="16"
                            height="16"
                            viewBox="0 0 24 24"
                            fill="none"
                            xmlns="http://www.w3.org/2000/svg"
                        >
                            <path
                                d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"
                                stroke="currentColor"
                                strokeWidth="2"
                                strokeLinecap="round"
                                strokeLinejoin="round"
                            />
                            <polyline
                                points="16 17 21 12 16 7"
                                stroke="currentColor"
                                strokeWidth="2"
                                strokeLinecap="round"
                                strokeLinejoin="round"
                            />
                            <line
                                x1="21"
                                y1="12"
                                x2="9"
                                y2="12"
                                stroke="currentColor"
                                strokeWidth="2"
                                strokeLinecap="round"
                            />
                        </svg>
                        Sign out
                    </button>
                </div>
                {(total > 0)
                and (
                    <div className="h-1.5 bg-muted rounded-full overflow-hidden mb-8">
                        <div
                            className="h-full bg-primary rounded-full transition-[width] duration-500 ease-in-out"
                            style={{"width": str(progress_pct) + "%"}}
                        />
                    </div>
                )}
                <form onSubmit={handle_add} className="flex gap-2 mb-8">
                    <input
                        className="w-full h-12 flex-1 rounded-xl border border-border bg-background text-foreground px-4 text-sm outline-none transition-[border-color,box-shadow] duration-150 placeholder:text-muted-foreground focus:border-primary focus:ring-[3px] focus:ring-primary/12"
                        value={new_title}
                        onChange={handle_input}
                        placeholder="What needs to be done?"
                        disabled={loading}
                    />
                    <button
                        className="h-12 px-5 shrink-0 rounded-lg inline-flex items-center justify-center text-sm font-medium cursor-pointer transition-opacity duration-150 bg-primary text-primary-foreground border border-primary hover:opacity-90"
                        type="submit"
                        disabled={loading}
                    >
                        <span className="text-xl">+</span>
                    </button>
                </form>
                {error and (<div className="bg-red-500/8 border border-red-500/25 rounded-xl px-4 py-3 text-sm text-red-700 mb-5">{error}</div>)}
                {loading
                and (
                    <div className="flex justify-center py-12">
                        <svg
                            className="h-5 w-5 text-muted-foreground"
                            viewBox="0 0 24 24"
                            fill="none"
                            xmlns="http://www.w3.org/2000/svg"
                        >
                            <circle
                                cx="12"
                                cy="12"
                                r="10"
                                stroke="currentColor"
                                strokeWidth="4"
                                opacity="0.25"
                            />
                            <path
                                d="M4 12a8 8 0 018-8"
                                stroke="currentColor"
                                strokeWidth="4"
                                strokeLinecap="round"
                                opacity="0.75"
                            />
                        </svg>
                    </div>
                )}
                {(not loading)
                and (total > 0)
                and (
                    <div className="flex flex-col gap-2">
                        {[
                            <TodoItem
                                key={t["id"]}
                                todo={t}
                                onToggle={handle_toggle}
                                onDelete={handle_delete}
                            /> for t in todos
                        ]}
                    </div>
                )}
                {(not loading) and (total == 0) and (<EmptyState/>)}
            </div>
        </div>
    );
}
```

---

## `styles/global.css`

Tailwind v4 via `@import "tailwindcss"`. Design tokens are registered in `@theme` so they become Tailwind utility classes (`bg-primary`, `text-foreground`, `shadow-card`, `font-display`, etc.). Google Fonts: Playfair Display (headings via `h1–h4` global rule) + Inter (body via `--font-sans`). No custom component CSS classes — all styling is done with Tailwind utilities directly in JSX.

```css
@import url('https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Inter:wght@300;400;500;600;700&family=Playfair+Display:wght@400;500;600;700&display=swap');

@import "tailwindcss";

@theme {
    --font-sans: 'Inter', ui-sans-serif, system-ui, sans-serif;
    --font-display: 'Playfair Display', Georgia, serif;

    --color-background: #faf9f7;
    --color-foreground: #1c1a17;
    --color-card: #f5f3f0;
    --color-primary: #f97316;
    --color-primary-foreground: #ffffff;
    --color-muted: #ede9e4;
    --color-muted-foreground: #7a7068;
    --color-border: #e5e0d9;
    --color-destructive: #ef4444;

    --shadow-soft: 0 1px 3px 0 rgba(28, 26, 23, 0.04), 0 1px 2px -1px rgba(28, 26, 23, 0.04);
    --shadow-card: 0 4px 16px -2px rgba(28, 26, 23, 0.06), 0 2px 4px -2px rgba(28, 26, 23, 0.04);
}

/* html/body/#root sizing, body background + antialiasing, h1–h4 display font */
```

> **Note:** The `@theme` at-rule is a Tailwind v4 feature. CSS language servers may flag it as an unknown rule — this is a false positive and does not affect the build.

---

## Running

```bash
jac start --dev
```

- App: `http://localhost:8000`
- API: `http://localhost:8001`
- Verify endpoints: `GET http://localhost:8001/introspect/functions`

---

## Key Patterns

| Pattern | Code |
|---|---|
| Register server function | `def:priv fn(arg: str) -> dict { ... }` in a `.jac` file |
| Import server fn to client | `sv import from ..service.todoService { fn }` — must point at the defining module |
| Call server fn | `result = await fn(arg)` |
| Reactive state | `has count: int = 0;` |
| On-mount effect | `async can with entry { await load(); }` |
| Create node + attach | `(root() ++> Todo(title=title))[0]` |
| All nodes of type | `[root()-->][?:Todo]` |
| Detach node | `root() del --> todo` |
| Auth guard route | `<Route element={<AuthGuardRoute />}>` wrapping protected routes |
| AuthGuard call | `return <>{AuthGuard("/login")}</>;` — called as function, not JSX |
| Conditional JSX | `{condition and (<Element />)}` |
| List JSX | `{[<El key={t["id"]} /> for t in items]}` |
| Login | `login_res = await jacLogin(email, password)` |
| Signup | `signup_res = await jacSignup(email, password)` |
| Logout | `jacLogout(); navigate("/login");` |
| Hover-reveal child | `group` on parent + `group-hover:opacity-100` on child |
| Tailwind custom token | `@theme { --color-primary: #f97316; }` → use as `bg-primary`, `text-primary`, `border-primary` |


### Type checker false positives

The JAC type checker emits spurious errors on common patterns — none prevent runtime:

- **E1032** — node attribute access via `[root()-->][?:Todo]` traversal (e.g. `t.id`, `t.title`)
- **E1031** — accessing `.target.value` on `e: any` event parameters
- **W2003** — assigning `has` state variables inside nested functions (`todos = ...`, `loading = ...`)
