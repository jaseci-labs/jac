---
name: jac-sv-persistence
description: Modeling relationships and querying the graph from server endpoints - connecting entities, multi-step reads, filtering, counting, and find-by-id patterns. Load when server code needs to store or query relational data. Pair with `jac-sv-endpoints` (persistence runs inside endpoint bodies).
---

The server's graph IS the database. Create entities by attaching nodes to `root` (or to each other via typed edges); read them with list-comprehension traversals; filter and aggregate with bracket predicates and `len()`. Every endpoint has access to the same graph - writes persist across calls automatically.

```jac
node User {
    has name: str;
}

node Post {
    has title: str;
    has published: bool = False;
}

edge Wrote {
    has at: str = "";
}


# CREATE - typed edge from user to the new post
def:pub write_post(user_id: str, title: str) -> Post | None {
    for u in [root -->][?:User] {
        if jid(u) == user_id {
            post = Post(title=title);
            u +>:Wrote(at="2026-04-21"):+> post;
            return post;
        }
    }
    return None;
}


# READ - posts written by a specific user (multi-hop through Wrote edges)
def:pub posts_by(user_id: str) -> list[Post] {
    for u in [root -->][?:User] {
        if jid(u) == user_id {
            return [u ->:Wrote:->][?:Post];   # [?:Post] recovers the node type
        }
    }
    return [];
}


# FILTER - posts matching a field predicate
def:pub published_posts() -> list[Post] {
    return [root -->][?:Post][?published];
}


# AGGREGATE - counts via len() on a list comprehension
def:pub count_posts() -> int {
    return len([root -->][?:Post]);
}


# UPDATE - find by jid, mutate in place
def:pub publish(post_id: str) -> Post | None {
    for p in [root -->][?:Post] {
        if jid(p) == post_id {
            p.published = True;
            return p;
        }
    }
    return None;
}
```

## Common patterns

**List-then-predicate vs filter-in-one-step:**

```
[root -->][?:Post]                         # all posts
[root -->][?:Post][?published]             # only published (bool field - no `== True`)
[root -->][?:Post][?author == "alice"]     # filter by any has-field
```

**Creating with an untyped edge (no relationship metadata):**

```
todo = (root ++> Todo(title=title))[0];    # [0] unwraps the edge-creation result
```

**Attach an existing node to another:**

```
user +>:Wrote(at="2026-04-21"):+> existing_post;
```

**Count without materializing:**

```
total = len([root -->][?:Post]);
published = len([root -->][?:Post][?published]);
```

## Pitfalls

- Mutate nodes in place - `p.published = True;` inside the loop. Changes persist once the endpoint returns; no explicit save/commit call.
- Aggregates use `len(...)` on a list expression - no dedicated `count()` query form. `len([root -->][?:Item])` is the idiom.
- Field-filter syntax is `[?field == value]` with brackets. `(?field == value)` is the **deprecated** parenthesized form (W0061) - always use brackets.
- For a **boolean** has-field, filter on the field directly: `[?published]` / `[?not published]`. Writing `[?published == True]` triggers W2075 (redundant boolean comparison).
- `def:priv` endpoints automatically run against a per-user `root` - the same query code gives each user only their own data. Use `def:priv` whenever the data should be user-scoped.
- A node is not persisted until it's reachable from `root`. `Post(title="x")` alone creates a dangling node; `root ++> Post(title="x")` or attaching via a typed edge from a reachable node is what commits it to the graph.
- Edge-type filter / creation / deletion syntax (`+>:E:+>`, `[src ->:E:->]`, `[edge a ->:E:-> b]`): see `jac-node-edge-patterns`.
- **Find-by-id ALWAYS uses `jid()`** - loop, compare, mutate-or-return. NOT Python `id()`. The `jid(node)` string is the only node identity that survives the RPC round-trip.
