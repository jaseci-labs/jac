---
name: jac-sv-auth
description: The server-side auth model - deciding which endpoints are public versus authenticated, and isolating data per user. Load when deciding which server functions need login or whose data they should see. Pair with `jac-sv-endpoints` (endpoint visibility), `jac-cl-auth` (client side of the auth loop).
---

Jac's server auth model is built on **per-user data isolation**. There's no explicit user id to check - the runtime handles login via `@jac/runtime` client helpers (`jacLogin`, etc.) and then routes each user's queries to their own subgraph. You pick the endpoint prefix; the runtime does the rest. (For data that *specific* users share, isolation has an escape hatch - see "Sharing data with specific users" below.)

- **`def:pub`** - anonymous. Anyone can call. `root` is the **shared global graph** - every caller sees the same data.
- **`def:priv`** - authenticated. Requires login. `root` is the **current user's isolated subgraph** - same code, different data per caller.
- **Client calls to `def:priv` without a session** throw `UNAUTHORIZED`; the client catches and redirects to `/login` (see `jac-cl-auth`).

```jac
node Todo {
    has title: str;
}


# PUBLIC - shared root, everyone sees the same data.
def:pub total_public_todos() -> int {
    return len([root -->][?:Todo]);
}


# PRIVATE - per-user root, each caller sees only their own data.
# Same query code, different subgraph per user.
def:priv my_todos() -> list[Todo] {
    return [root -->][?:Todo];
}

def:priv add_todo(title: str) -> Todo {
    return (root ++> Todo(title=title))[0];
}
```

For full CRUD shapes (update / toggle / delete + typed returns + async), see `jac-sv-endpoints`.

## Sharing data with specific users

`def:pub` (one shared global graph) and `def:priv` (per-user isolated graph) are
not the only two options. For data that some *specific* users share but the
public must not see - a shared document, a team workspace, a two-player game -
keep the endpoints `def:priv` and use the ambient permission builtins (no
import needed):

- `grant(node, level)` - give another user access to a specific node.
- `revoke(node)` - withdraw that access.
- `allroots()` - list every user's `root` (returns `list[Root]`), for admin or
  cross-user views.

This opens a chosen node to chosen users instead of dumping shared state into
the global `def:pub` graph. The jac-scale reference documents the full
cross-user permission model (access levels, granting against another user's
root) - consult it before building a multi-user-shared feature.

## Pitfalls

- `def:pub` and `def:priv` can live in the **same file** - visibility is per-function, not per-module.
- On the client side, a call to a `def:priv` endpoint without a valid session raises an error containing `"UNAUTHORIZED"`. Wrap in try/except and redirect to login - see `jac-cl-auth`.
- There is **no `current_user()` helper**. User identity is implicit in which `root` the endpoint sees. Store per-user metadata (preferences, roles) on nodes reachable from that user's `root` and read it inside `def:priv` endpoints.
- **`walker:pub`** is a third endpoint flavor for complex traversal-style queries. The client calls it and reads `result.reports`. Niche - prefer `def:pub` / `def:priv` first.
- **Shared `root` on `def:pub` = shared data - wrong visibility = silent data-leak.** Writing user-specific data (e.g. a user's notes) from a `def:pub` endpoint puts it in the global graph; *every other user calling the same endpoint reads it back*. NO compile error, NO runtime error - only surfaces when User B sees User A's data. If the endpoint writes user-specific data it **must** be `def:priv` (per-user-isolated root). Verify: log in as two different users; if reads from one show the other's data, the visibility is wrong.
