# Fullstack Jac Pitfalls — .cl.jac Frontend + Backend Integration

> These rules apply when building fullstack Jaseci apps with .cl.jac frontend components.
> Everything in core_jac.md ALSO applies. This file covers the additional fullstack gotchas.

---

## File Types

- `.jac` — Backend code (nodes, endpoints, walkers). Uses Python runtime.
- `.cl.jac` — Frontend code (React components). Compiles to JavaScript.

---

## BEFORE WRITING ANY CODE

**Read `jac.toml` FIRST.** Only use npm packages listed in `[dependencies.npm]`. Do NOT import unlisted libraries. NEVER assume any UI library is available. Use plain Tailwind CSS + inline SVG for styling and icons.

When creating a new fullstack project, ensure `jac.toml` has these Tailwind dependencies:

```toml
[dependencies.npm]
tailwind-merge = "^3.4.0"
clsx = "^2.1.1"

[dependencies.npm.dev]
"@jac-client/dev-deps" = "2.0.0"
"@tailwindcss/vite" = "^4.1.17"
tailwindcss = "^4.1.17"

[plugins.client.vite]
plugins = ["tailwindcss()"]
lib_imports = ["import tailwindcss from '@tailwindcss/vite'"]
```

---

## Backend Rules (.jac)

### 1. Backend logic in `.sv.jac` files, imported in `main.jac`

Define backend logic (nodes, endpoints, walkers) in separate `.sv.jac` files under a `services/` directory. Then import them in TWO places:

```jac
# services/products.sv.jac — define endpoints here
node Product {
    has id: str, name: str, price: float;
}

def:pub get_products() -> list {
    return [{"id": p.id, "name": p.name, "price": p.price}
            for p in [root()-->][?:Product]];
}

def:pub add_product(name: str, price: float) -> dict {
    p = (root() ++> Product(id=str(uuid4()), name=name, price=price))[0];
    return {"id": p.id, "name": p.name};
}
```

```jac
# main.jac — import to REGISTER endpoints with the server
import from services.products { get_products, add_product }
```

```jac
# hooks/useProducts.cl.jac — sv import to CALL endpoints from frontend
sv import from ..services.products { get_products, add_product }
```

**Both imports are required:**
- `main.jac` import → registers the endpoint so the server exposes it
- `sv import` in `.cl.jac` → generates HTTP stubs so frontend can call it

For small projects, you can keep everything in `main.jac` directly. For larger apps, split into `.sv.jac` files.

### 2. Endpoint types: `def:pub` vs `def:priv` vs `walker:pub`

```jac
# Public — anyone can call
def:pub get_items() -> list {
    return [{"id": str(i.id), "title": i.title} for i in [root()-->][?:Item]];
}

# Private — requires login, per-user isolated root
def:priv get_my_items() -> list {
    return [{"id": str(i.id), "title": i.title} for i in [root()-->][?:Item]];
}

# Walker — for complex graph traversal
walker:pub get_details {
    has item_id: str;
    can find with Root entry {
        for i in [-->][?:Item] {
            if str(i.id) == self.item_id { visit i; return; }
        }
        report {"error": "not found"};
    }
}
```

### 3. Return dicts/lists from endpoints — NOT nodes directly

```jac
# WRONG — returns node objects
def:pub get_items() -> list { return [root()-->][?:Item]; }

# RIGHT — serialize to dicts
def:pub get_items() -> list {
    return [{"id": str(i.id), "title": i.title} for i in [root()-->][?:Item]];
}
```

### 4. Node CRUD pattern

```jac
node Item {
    has title: str;
    has done: bool = False;
}

# Create + connect to root (auto-persists in SQLite)
root() ++> Item(title="Buy milk");

# Query
items = [root()-->][?:Item];
found = [root()-->][?:Item][?title == "Buy milk"][0];

# Delete
del found;
# or: root() del--> found;
```

### 5. Frontend entry point in main.jac

```jac
cl import from .components.Layout { Layout }
cl {
    def:pub app() -> JsxElement { return <Layout />; }
}
```

---

## Frontend Rules (.cl.jac)

### 6. Component props — ALWAYS use `props: dict`

```jac
# WRONG — individual params on JsxElement components
def:pub Header(title: str, theme: str) -> JsxElement { ... }

# RIGHT — always use props: dict, destructure inside
def:pub Header(props: dict) -> JsxElement {
    title = props.title or "";
    theme = props.theme or "light";
    return <header>{title}</header>;
}

# EXCEPTION: app(), layout(), page() take no props — that's fine
def:pub app() -> JsxElement { return <Layout />; }
```

Components returning `JsxElement` MUST accept `props: dict` as the single parameter (or no params). NEVER use individual typed params like `(title: str, count: int)`.

Also use `className`, NOT `class` for HTML attributes in JSX:
```jac
# WRONG
<div class="container">

# RIGHT
<div className="container">
```

### 7. Jac syntax, NOT JavaScript

```
WRONG (JS)                          →  RIGHT (Jac)
──────────────────────────────────────────────────
const x = 5;                        →  x = 5;
let items = [];                     →  has items: list = [];
x ? a : b                           →  a if x else b
() => { ... }                       →  def handler() -> None { ... }
`hello ${name}`                     →  f"hello {name}"
x === y                             →  x == y
console.log(x)                      →  print(x)
x.length                            →  len(x)
parseInt(x)                         →  int(x)
x.toString()                        →  str(x)
items.map(fn)                       →  {[<Item /> for item in items]}
items.filter(fn)                    →  [i for i in items if cond]
# PITFALL: dict values as JSX children render BLANK
# WRONG: {[<Btn>{k["label"]}</Btn> for k in keys]}
# RIGHT: explicit <Btn><span>7</span></Btn> or child component with str(props.label)
items.push(x)                       →  items = items + [x];
useEffect(() => {}, [])             →  can with entry { ... }
useState(0)                         →  has count: int = 0;
!condition                          →  not condition
new Date()                          →  Reflect.construct(Date, [])
window.open(url)                    →  globalThis.open(url, "_blank")
```

### 7. State — `has` auto-generates useState

```jac
has count: int = 0;        # auto-creates count + setCount
has name: str = "";
has items: list = [];

count = count + 1;         # calls setCount internally
items = items + [newItem]; # new reference = re-render
```

**NEVER define `setX` yourself. NEVER use `.append()` for state** — it mutates in place (no re-render). Always `items = items + [x]`.

### 8. Effects — `can with entry/exit`

```jac
can with entry { ... }                  # mount (useEffect(fn, []))
async can with entry { ... }            # async mount
can with [dep1, dep2] entry { ... }     # dependency watch
can with exit { ... }                   # cleanup/unmount
```

**NEVER use `useEffect(lambda...)` — that is OLD syntax.**

### 9. Event handlers — NEVER inline in JSX

```jac
# WRONG — lambda in JSX
<button onClick={lambda -> None { count = count + 1; }}>

# WRONG — inline def
<button onClick={def(e: any) -> None { count = count + 1; }}>

# RIGHT — named function ABOVE return, passed by name
def handle_click() -> None {
    count = count + 1;
}
return <button onClick={handle_click}>Click</button>;
```

ALL event handlers must be named `def` functions defined BEFORE `return`.

### 10. Functions MUST be defined BEFORE `return`

```jac
# WRONG — helper after return (unreachable)
return <div>{render_item(data)}</div>;
def render_item(d: dict) -> JsxElement { ... }

# RIGHT — define above
def render_item(d: dict) -> JsxElement { ... }
return <div>{render_item(data)}</div>;
```

### 11. No comments inside JSX

```jac
# WRONG — all of these crash
return <div>
    {# comment}
    <!-- HTML comment -->
    {/* JS comment */}
</div>;

# RIGHT — comments ABOVE JSX
# Render the list
return <div>...</div>;
```

### 12. `sv import` — calling server functions and walkers

`sv import` brings server-side functions and walkers into client code. The compiler generates HTTP stubs automatically — no manual fetch calls needed.

```jac
# Import syntax — NO quotes, dots for path, point to the .sv.jac file where endpoints are defined
sv import from ..services.items { get_items, add_item }
sv import from ..services.items {
    get_items,
    add_item,
    delete_item
}
```

**Two call patterns — NEVER mix them up:**

```jac
# def:pub / def:priv → await, returns value directly
items = await get_items() or [];

# walker:pub / walker:priv → root spawn, result is in .reports[0]
result = root spawn get_tasks();
if result.reports and len(result.reports) > 0 {
    tasks = result.reports[0] or [];
} else {
    tasks = [];
}
```

**Kwargs rule:**

```jac
# def:pub — POSITIONAL ONLY (kwargs compile to a single dict arg — wrong data)
# WRONG
resp = await calc(a=2, b=4, op="add");
# RIGHT
resp = await calc(2, 4, "add");

# root spawn — kwargs ARE fine (matched to walker has fields by name)
result = root spawn add_task(title="Buy milk");
result = root spawn toggle_task(task_id=task["id"]);
```

**Always wrap in try/except:**

```jac
async can with entry {
    try {
        items = await get_items() or [];
    } except Exception as e {
        error = str(e);
    }
    loading = False;
}
```

### 13. JS constructors need `Reflect.construct`

In .cl.jac, `ClassName()` without `new` returns wrong type or throws. Jac has no `new` keyword.

```jac
# WRONG
year = Date().getFullYear();          # CRASH: string has no method getFullYear
ws = WebSocket("ws://localhost");     # CRASH: must be called with new

# RIGHT
year = Reflect.construct(Date, []).getFullYear();
ws = Reflect.construct(WebSocket, ["ws://localhost"]);

# Safe statics (no Reflect needed):
Date.now();  JSON.parse();  Math.random();
```

Classes that ALWAYS need Reflect.construct: Date, WebSocket, TextDecoder, TextEncoder, URL, URLSearchParams, FormData, AbortController, RegExp, Error, Worker, Headers, Request, Response.

### 14. Browser global name conflicts

NEVER define functions named: `open`, `close`, `print`, `fetch`, `focus`, `blur`, `scroll`, `alert`, `confirm`, `prompt`, `stop`, `find`

Use `handleOpen`, `handleClose`, `handleFetch`, etc.

### 15. Display numbers/booleans with `str()`

```jac
# WRONG — may render nothing
<span>{count}</span>

# RIGHT
<span>{str(count)}</span>
```

### 16. ALWAYS guard everything defensively

Undefined access CRASHES the whole app in .cl.jac.

```jac
# State — always init with correct types, NEVER None
has items: list = [];
has user: dict = {};
has loading: bool = True;

# Dict access — use "key" in dict, not .get()
name = item["name"] if "name" in item else "";

# Async results — always wrap in try/except
async can with entry {
    try {
        result = await get_items();
        items = result or [];
    } except Exception as e {
        error = str(e);
    }
    loading = False;
}

# Props — always default
items = props.items or [];
title = props.title or "";
```

---

## Import Rules (CRITICAL — memorize the pattern)

### In .jac files (backend)

```jac
import from datetime { datetime }               # Python module
cl import from .components.Layout { Layout }     # Client component (NO quotes, cl prefix)
```

### In .cl.jac files (frontend)

In `.cl.jac` files, the `cl` prefix is NOT needed — everything is already client-side.

```jac
# Client-to-client — NO quotes, DOTS not slashes (NO cl prefix needed)
import from .Header { Header }                   # same directory
import from ..hooks.useTodos { useTodos }        # parent directory
import from ...lib.utils { cn }                  # 2 levels up

# Server calls — sv import, NO quotes
sv import from ..services.todoService { get_todos, add_todo }

# NPM packages — WITH quotes (NO cl prefix needed in .cl.jac)
import from "clsx" { cn }

# Runtime — WITH quotes (NO cl prefix needed in .cl.jac)
import from "@jac/runtime" { jacLogin, Outlet }

# CSS — WITH quotes
import "..styles.global.css";
```

### In .sv.jac files (backend services)

In `.sv.jac` files, the `sv` prefix is NOT needed — everything is already server-side.

```jac
# Python modules — no prefix needed
import from uuid { uuid4 }
import from datetime { datetime }
```

### Dot level cheat sheet

```
.   = same directory
..  = 1 level up (parent)
... = 2 levels up
```

### NEVER do

- `cl sv import` — never combine prefixes
- `"..main"` with quotes on sv import — sv import has NO quotes
- Slashes in LOCAL import paths — always dots for local files
- File extensions in imports — never `.cl`, `.jac`, `.cl.jac`
- `@jac.runtime` or `@mantine.core` — WRONG! npm `@`-scoped packages keep `/`: `"@jac/runtime"`, `"@mantine/core"`

---

## Project Structure

```
project-root/
├── jac.toml              # config + deps
├── main.jac              # Entry point: imports from services/ + cl { app() }
├── services/             # .sv.jac backend logic (nodes + endpoints)
│   ├── products.sv.jac   # Product node + CRUD endpoints
│   ├── cart.sv.jac       # Cart node + cart endpoints
│   └── auth.sv.jac       # Auth-related endpoints (if custom)
├── components/           # .cl.jac components (one per file)
│   ├── Layout.cl.jac     # Root layout — imports child components
│   ├── Header.cl.jac     # Nav/header
│   └── ItemList.cl.jac   # Data display (calls hook)
├── hooks/                # .cl.jac data hooks (sv import + state)
│   └── useItems.cl.jac   # sv import from ..services.items { get_items }
├── pages/                # .jac file-based routing (optional)
├── lib/                  # .cl.jac shared utilities
└── styles/               # CSS files
```

**Key rule:** Endpoints defined in `.sv.jac` files must be imported in BOTH `main.jac` (to register) AND `.cl.jac` hooks (to call via `sv import`).

Layout.cl.jac is the root layout. Data logic lives in hooks/, called by child components — NOT by Layout.
