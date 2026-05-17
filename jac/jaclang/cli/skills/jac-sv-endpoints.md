---
name: jac-sv-endpoints
description: Writing server-side functions the client can call - endpoint visibility, typed responses, and the basic create/read/update/delete shape. Load before writing any backend function callable from the client. Pair with `jac-sv-persistence` (graph queries inside endpoint bodies), `jac-sv-auth` (def:pub vs def:priv).
---

Server endpoints are functions the client invokes as RPC. They live at the top of `main.jac` or in a `.sv.jac` module. How a function is declared controls whether - and how - the client can call it:

- **`def:pub`** - public endpoint. Anyone can call. Use for unauthenticated data (public feeds, listings).
- **`def:priv`** - private endpoint. Requires login; each user gets their own isolated `root`. Use for per-user data.
- **`def`** (no prefix) - **also a client-callable endpoint**, registered like `def:priv` (authenticated, per-user `root`). Jac has no "internal-only" modifier. To keep a function *off* the API, prefix its name with `_` (e.g. `def _helper(...)`) - underscore-prefixed functions are never registered.

Return types auto-serialize: node archetypes, primitives, `list[T]`, `dict`, `T | None`.

```jac
node Item {
    has title: str;
    has done: bool = False;
}


# Public - anyone can call.
def:pub list_items() -> list[Item] {
    return [root -->][?:Item];
}

def:pub add_item(title: str) -> Item {
    return (root ++> Item(title=title))[0];
}

def:pub toggle_item(id: str) -> Item | None {
    for i in [root -->][?:Item] {
        if jid(i) == id {
            i.done = not i.done;
            return i;
        }
    }
    return None;
}

def:pub delete_item(id: str) -> bool {
    for i in [root -->][?:Item] {
        if jid(i) == id {
            del i;
            return True;
        }
    }
    return False;
}


# Private - requires login; root is the current user's subgraph.
def:priv get_my_items() -> list[Item] {
    return [root -->][?:Item];
}


# Internal helper - the leading `_` keeps it OFF the API. (A plain `def` with no
# underscore would itself be registered as an authenticated endpoint.)
def _compute_age(item: Item) -> int {
    return len(item.title);
}
```

## Pitfalls

- `async def:pub` is required when the endpoint uses `await` (external API calls, LLM endpoints). Missing `async` on a body that awaits is a parse/type error.
- To delete a node: `del node;` - removes it and all its edges from the graph. Run it inside a loop that matches the id; don't try to pass nodes by reference from the client.
- Every client-callable endpoint needs an explicit return type. `def:pub add_item(title: str)` with no `-> T` is an error.
- **Return type IS the wire format.** Client gets dot access when you return typed nodes/objs (`list[Item]` → `items[0].title`). Returning raw `dict` or `list` loses typing on the client side.
- `def:pub` = public endpoint (anonymous), `def:priv` = authenticated endpoint (per-user). A plain `def` is **also registered** - as an authenticated endpoint, same as `def:priv`. Only a leading `_` (`def _helper(...)`) keeps a function off the API. See `jac-sv-auth` for the full auth-model semantics.
- **Use `jid(node)` for cross-RPC node identity; `id(node)` silently breaks lookups.** `id()` returns Python's in-memory address, which changes every server restart AND differs across worker processes - a lookup `for n in [root -->] { if id(n) == client_id { ... } }` returns no match every time, no error, just empty results. Use `jid(node)` (returns a stable persistent string) and compare with `if jid(n) == client_id`.
- **Creating a new `services/X.sv.jac` is always a 2-file change.** The new endpoint must ALSO be added to `main.jac`'s plain `import from services.X { fn, Types }` block at the top. Without that import, the dispatcher never sees it and client calls hit `404 Not Found`. Especially easy to miss when extending a client-only app - `main.jac` previously had no server import block at all. See `jac-fullstack-patterns` for the full registry rule.
