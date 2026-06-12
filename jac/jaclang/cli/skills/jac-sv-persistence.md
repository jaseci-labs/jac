---
name: jac-sv-persistence
description: Modeling relationships and querying the graph from server endpoints - connecting entities, multi-step reads, filtering, find-by-id - plus schema changes, field renames, migration, quarantine, and database backends. Load when server code stores or queries relational data, or when a schema edit breaks reads. Pair with `jac-sv-endpoints` (persistence runs inside endpoint bodies).
---

The server's graph IS the database. Create entities by attaching nodes to `root` (or to each other via typed edges); read them with list-comprehension traversals; filter and aggregate with bracket predicates and `len()`. Writes persist automatically - no save/commit call needed inside endpoints (`commit()` exists for scripts that exit abruptly).

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


# UPDATE - find by jid, mutate in place; changes persist when the endpoint returns
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

## Query patterns

```
[root -->][?:Post]                         # all posts
[root -->][?:Post][?published]             # bool field - no `== True` (W2075)
[root -->][?:Post][?author == "alice"]     # filter by any has-field (brackets, not parens - W0061)
len([root -->][?:Post])                    # aggregate - no count() form
todo = (root ++> Todo(title=t))[0];        # untyped edge; [0] unwraps the result list
user +>:Wrote(at="..."):+> existing_post;  # attach an existing node
```

Edge-type filter / creation / deletion syntax: see `jac-node-edge-patterns`.

## Schema changes survive

Persisted data lives in `.jac/data/` (SQLite) by default; set `MONGODB_URI` (env or `[plugins.scale.database] mongodb_uri`) to flip to MongoDB (+ Redis L2 cache). Same model on both. Edits to archetypes **never delete data**:

- **Added field with a default** → old rows load, field takes the default. **Type change** → coerced (str↔int/float/bool, ISO str→datetime, value→Enum, ...); failed coercion keeps the raw value and logs.
- **Removed field** → the stored value moves to the **attic** (`__jac_attic__` sub-document riding with the row), recoverable, never dropped.
- **Unloadable rows** (renamed class with no alias, corrupt data) → moved to a quarantine sidecar, never deleted. Inspect/rescue with `jac db`.

**Renames need declaring** - otherwise a field rename looks like remove+add (old values land in the attic, new field gets the default) and a class rename quarantines every row:

```jac
@archetype_alias("__main__.LegacyPerson")    # class rename (ambient builtin decorator)
node Person {
    has name: str = "";

    static def __jac_schema__ -> None;       # field-level history hook
}

impl Person.__jac_schema__ -> None {
    schema_alias("name", stored="username"); # field rename: old value flows into new field
    schema_drop("legacy_bio");               # deleted field: preserve remains in the attic
    schema_upgrade(fix_tags, when=(lambda doc: dict : isinstance(doc.get("tags"), str)));
}
```

`schema_was`, `schema_alias`, `schema_drop`, `schema_upgrade` are ambient builtins, only callable inside `__jac_schema__`. Rules are shape-matched (no version numbers), idempotent, validated at startup, and run identically on SQLite and Mongo. `JAC_SCHEMA_REPAIR=repair|detect|off` is the kill switch (default `repair`).

Operator workflow when rows do quarantine:

```bash
jac db inspect --app app.jac            # state of the world
jac db quarantine list --app app.jac    # what's quarantined and why
jac db alias add "__main__.OldName" "__main__.NewName" --app app.jac   # rescue without redeploy
jac db recover-all --app app.jac        # re-attempt every quarantined row
```

## Pitfalls

- **THE dev-loop landmine: `{"detail": "Invalid anchor id ..."}` 500s** on previously-working endpoints = stale anchors persisted by a previous run under a different schema. Stop the server, `rm -rf .jac/data/`, restart. Fine in dev (it deletes local data); in production use the alias/quarantine machinery above instead.
- A node is not persisted until it's reachable from `root`. `Post(title="x")` alone is a dangling node; `root ++> Post(...)` (or a typed edge from a reachable node) is what commits it.
- **Find-by-id ALWAYS uses `jid()`** - loop, compare, mutate-or-return. NOT Python `id()`: that returns an in-memory address that changes every restart and differs across workers, so lookups silently return empty. `jid(node)` is the only identity that survives the RPC round-trip.
- `def:priv` endpoints run against a per-user `root` - the same query code gives each user only their own data (see `jac-sv-auth`).
- Renaming a field without `schema_alias` doesn't error - old values silently land in the attic and the field reads as its default. If users "lost" data after a rename, it's in the attic; declare the alias and the value flows back on next load.
