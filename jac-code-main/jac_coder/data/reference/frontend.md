# Frontend Components — .cl.jac

## Component Definition

Components are public functions returning `JsxElement`.

```jac
def:pub Header(props: dict) -> JsxElement {
    title = props.title or "";
    return (
        <header className="border-b px-6 py-4">
            <h1 className="text-xl font-bold">{title}</h1>
        </header>
    );
}
```

Components need `def:pub` to be importable by other files.

## State Management

`has` inside a component function auto-generates `useState`.

```jac
def:pub Counter() -> JsxElement {
    has count: int = 0;
    has name: str = "";
    has items: list = [];

    # Assignment triggers re-render (calls setter internally)
    count = count + 1;
    items = items + [newItem];    # new reference = re-render
}
```

- NEVER define `setX` yourself — it already exists from `has`
- NEVER use `.append()` — it mutates in place (no re-render)
- Always init with correct type, NEVER `None` or `any`

## Effects (Lifecycle)

```jac
can with entry { ... }                  # Mount (useEffect with [])
async can with entry { ... }            # Async mount
can with [dep1, dep2] entry { ... }     # Watch dependencies
can with (a, b) entry { ... }           # Also dependency watch
can with exit { ... }                   # Cleanup/unmount
```

NEVER use `useEffect(lambda...)` — that is OLD syntax.

## Event Handlers

ALL handlers must be named `def` functions defined BEFORE `return`. NEVER use lambda or inline def in JSX.

```jac
def:pub TodoList() -> JsxElement {
    has inputValue: str = "";

    # Define handler above return
    def handle_input(e: any) -> None {
        inputValue = e.target.value;
    }

    def handle_submit() -> None {
        if inputValue { add_item(inputValue); inputValue = ""; }
    }

    # Pass by name
    return <div>
        <input value={inputValue} onChange={handle_input} />
        <button onClick={handle_submit}>Add</button>
    </div>;
}
```

## List Rendering

Use list comprehension, NEVER `.map()`.

```jac
# Render list — pass data as PROPS to a child component
{[<TodoItem key={item["id"]} data={item} /> for item in items]}

# With filter
{[<Tag key={t} label={t} /> for t in tags if t != "hidden"]}

# Add to list (new reference)
items = items + [newItem];

# Remove from list
items = [item for item in items if item["id"] != targetId];
```

**WARNING:** Dynamic dict values as JSX text children render BLANK.
```jac
# WRONG — renders blank buttons
{[<Button>{k["label"]}</Button> for k in keys]}

# RIGHT — explicit elements with literal text for small fixed sets
<Button><span>7</span></Button>
<Button><span>8</span></Button>

# RIGHT — child component that renders via str(props.label)
{[<KeyBtn key={k["label"]} label={k["label"]} /> for k in keys]}
```

## Conditional Rendering

```jac
{showSidebar and (<Sidebar items={items} />)}
{isActive and (<ActiveView />) or (<InactiveView />)}
{(not loading) and (<Content />)}
```

## Custom Hooks

```jac
def:pub useCounter(initial: int = 0) -> dict {
    has count: int = initial;
    def increment() -> None { count = count + 1; }
    def decrement() -> None { count = count - 1; }
    return {"count": count, "increment": increment, "decrement": decrement};
}
```

## Data Hook Pattern (sv import + state)

```jac
# hooks/useTodos.cl.jac — point to the .sv.jac file, NOT main.jac
sv import from ..services.todoService { get_todos, add_todo, delete_todo }

def:pub useTodos() -> dict {
    has todos: list = [];
    has loading: bool = True;
    has error: str = "";

    async can with entry {
        try {
            result = await get_todos();
            todos = result or [];
        } except Exception as e {
            error = str(e);
        }
        loading = False;
    }

    async def handleAdd(title: str) -> None {
        if not title { return; }
        result = await add_todo(title);  # positional args only
        if result and not result.error {
            todos = todos + [result];
        }
    }

    async def handleDelete(id: str) -> None {
        result = await delete_todo(id);  # positional args only
        if result and not result.error {
            todos = [t for t in todos if t["id"] != id];
        }
    }

    return {
        "todos": todos, "loading": loading, "error": error,
        "handleAdd": handleAdd, "handleDelete": handleDelete
    };
}
```

## Frontend Import Rules

```jac
# Same directory (.cl.jac to .cl.jac) — NO quotes, dots not slashes
import from .Header { Header }

# Parent directory — NO quotes
import from ..hooks.useTodos { useTodos }

# Two levels up — NO quotes
import from ...lib.utils { cn }

# Server calls — sv import, NO quotes, point to .sv.jac file
sv import from ..services.todoService { get_todos, add_todo }

# NPM packages — WITH quotes
import from "clsx" { cn }

# Runtime — WITH quotes (no cl prefix needed in .cl.jac files)
import from "@jac/runtime" { jacLogin, Outlet }

# CSS — WITH quotes
import "..styles.global.css";
```

**Dot levels:** `.` = same dir, `..` = parent, `...` = 2 up

## Calling Backend Walkers

```jac
sv import from ..services.postService { get_post_details }

async def loadDetails() -> None {
    result = root spawn get_post_details(post_id=postId);
    if result and result.reports and len(result.reports) > 0 {
        data = result.reports[0];
    }
}
```

## Primitive Idioms (Jac, NOT JavaScript)

| JS (WRONG) | Jac (RIGHT) |
|---|---|
| `console.log(x)` | `print(x)` |
| `String(x)` / `.toString()` | `str(x)` |
| `parseInt(x)` | `int(x)` |
| `x.length` | `len(x)` |
| `.toLowerCase()` | `.lower()` |
| `.toUpperCase()` | `.upper()` |
| `.trim()` | `.strip()` |
| `.indexOf(sub)` | `.find(sub)` |

## Inline Styles

```jac
<div style={{"display": "flex", "gap": "8px", "backgroundColor": "#f0f0f0"}} />
```

## Service Layer Pattern (for walker calls)

```jac
# services/apiService.cl.jac
sv import from .itemService { create_item, list_items }

async def:pub createItem(title: str) -> any {
    try {
        response = root spawn create_item(title=title);
        result = response.reports[len(response.reports) - 1]
            if response.reports and len(response.reports) > 0 else {};
        return {"success": True, "item": result};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}
```

## @jac/runtime — Available Symbols

In `.cl.jac` files, use `import from "@jac/runtime"` (WITH quotes, NO `cl` prefix needed — you're already in client context).
In `.jac` files (like main.jac), use `cl import from "@jac/runtime"` (WITH `cl` prefix to specify client context).

### Auth
```jac
import from "@jac/runtime" { jacLogin, jacSignup, jacLogout, jacIsLoggedIn }

# jacLogin / jacSignup are ASYNC — always await
success = await jacLogin(username, password);    # returns bool
result = await jacSignup(username, password);    # returns {"success": bool, "error"?: str}
jacLogout();                                      # sync — clears token + cache
is_auth = jacIsLoggedIn();                        # sync — returns bool

# Signup auto-logs in on success — no separate jacLogin call needed
if result["success"] { navigate("/dashboard"); }
else { error = result["error"] or "Signup failed"; }
```

### Routing
```jac
import from "@jac/runtime" {
    Link, Navigate, useNavigate, useLocation, useParams, Outlet, AuthGuard
}

# Link — declarative navigation
<Link to="/dashboard">Go to Dashboard</Link>

# Navigate — redirect component
if not jacIsLoggedIn() { return <Navigate to="/login" />; }

# useNavigate — programmatic navigation
navigate = useNavigate();
navigate("/path");                     # push
navigate("/path", {"replace": True});  # replace
navigate(-1);                          # back

# useLocation — current URL info
location = useLocation();
# location.pathname, location.search, location.hash

# useParams — dynamic route params (from [id].jac)
params = useParams();
# params.id

# Outlet — renders child routes in layouts
return <div><Outlet /></div>;

# AuthGuard — protects routes, redirects if not logged in
return <AuthGuard redirect="/login"><Outlet /></AuthGuard>;
```

### IMPORTANT
- In `.cl.jac` files: NO `cl` prefix needed — just `import from "@jac/runtime"`
- In `.jac` files (main.jac): USE `cl import from "@jac/runtime"` (need `cl` prefix for client context)
- ALWAYS use quotes: `"@jac/runtime"` (it's an npm-style path)
- NEVER use dots: `@jac.runtime` ← WRONG
- Auth functions use POSITIONAL args (kwargs broken in .cl.jac)
