---
name: jac-sv-persistence
description: Store and query durable graph data and evolve schemas. Use for root attachment, identity lookup, migrations, or failed persisted reads.
---

Use nodes and edges as the application data model. In a persistence-enabled context, attachment to persistent graph state promotes transient nodes into storage. Endpoint transactions manage successful writes; scripts and background work must follow the persistence lifecycle described by the runtime. Disconnecting an edge does not delete a previously persisted node: use explicit deletion when intended.

```jac
node User { has name: str; }

node Post {
    has title: str;
    has published: bool = False;
}

edge Wrote: User --> Post { has at: str = ""; }

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

# UPDATE - resolve a known jid with jobj() and mutate in place.
# Identity lookup does not replace access checks; a grant need not add a root edge.
def:pub publish(post_id: str) -> Post | None {
    target = jobj(post_id);
    if isinstance(target, Post) {
        target.published = True;
        return target;
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
todo = root ++> Todo(title=t);             # untyped edge; returns the connected node
user +>:Wrote(at="..."):+> existing_post;  # attach an existing node
```

**Ask the store, not the process.** A predicate, an ordering term and a bound inside the reference all compile into one SQL statement, so the query answers the question instead of the neighbourhood being loaded and filtered in Python:

```
[u ->:Wrote:-> [?:Post, published, -at]][:20]   # WHERE + ORDER BY + LIMIT, one query
len([u ->:Wrote:-> [?:Post]])                   # a COUNT; deserializes nothing
if [u ->:Wrote:-> [?:Post, published]] { ... }  # stops at the first row
```

The cost only lands in the query when the traversal is read on the spot. Bind it to a name first and it materialises there, because a reference holds the graph as of the line it was written on.

**Promote the fields you filter and order by.** Field predicates and orderings read a jsonb path, which is a scan unless the field has an index. Declare them and the compiler names the promoted column instead:

```toml
[database]
indexes = { Post = ["at", "published"], Msg = ["at", "seq"] }
```

It is the top-level `[database]` table, not `[scale.database]` (which holds the deploy's connection settings): under `[scale.database]` the key is reported as unknown and ignored.

Without this a `[?:Post, -at]` still returns the right rows -- correctness never depends on the declaration -- it just sorts the whole set to do it.

**Owning content as a group.** A group is a root nobody logs in as. Declare it as a `Root` subtype so it can hold fields, and `save` it: saving a new group makes the caller its `ADMIN`. Content attached under it belongs to it, and `set_access` adds members:

```jac
node Workspace(Root) { has name: str; }
node Item { has label: str; }

def make_org_item(member_root_id: str) -> Item {
    org = Workspace(name="Acme");
    save(org);                                   # required: nothing points to it yet
    item = org ++> Item(label="x");              # owned by the org, not by the caller
    set_access(org, member_root_id, AccessLevel.READ);   # the member reads all the org owns
    return item;
}
```

Why own it by the org rather than by its creator: the owning root always has `ADMIN`. A record a member created under their own root stays theirs after they leave the org. A record owned by the org follows its membership, so `clear_access(org, member_id)` ends the member's access to all of it at once. `save(obj, owner=g)` still works for content created away from the group: it requires `WRITE` on `g` and raises `ValueError` when `g` is not a root or a group, or the object is already saved under another owner. `Jac.owner_of(obj)` reads the owner.

**Sharing: name a group, not every grantee.** Membership is a `Member` edge from the member to the group, so a join or a leave touches no content row. `set_access(doc, team, AccessLevel.READ)` makes the team itself a member of the doc, and every member of the team reaches it, capped by their own level in the team. Levels only ever rise across grants and memberships; a `NO_ACCESS` setting is a block. The permission test compiles into the query for the standard model (owner, granted-to-all, the groups you act as, per-root entries), so a gated read costs the rows you may see rather than every candidate. An archetype that overrides `__jac_access__` decides access with arbitrary Jac, which has no SQL form: those keep the object-space filter, correctly but at full cost.

Edge-type filter / creation / deletion syntax, and the ordering-term rules: see `jac-node-edge-patterns`.

## View models: report views, not raw nodes

Give each node a `to_view()` returning an `obj` view model with `id=jid(self)` plus viewer-relative computed fields. Inside a node method running under a served request, `root` is the **calling user's** root - so `is_mine` computes per caller. Endpoints report the views (sorted with a typed lambda), never raw nodes:

```jac
node User { has name: str; }

obj PostView {
    has id: str, title: str, created_at: str, is_mine: bool;
}

node Post {
    has title: str = "", author: str = "", created_at: str = "";

    def to_view -> PostView {
        mine = [root-->[?:User]];    # `root` here = whoever is calling
        return PostView(
            id=jid(self), title=self.title, created_at=self.created_at,
            is_mine=(len(mine) > 0 and self.author == mine[0].name)
        );
    }
}

def:pub feed() -> list[PostView] {
    posts = [p.to_view() for p in [root-->[?:Post]]];
    posts.sort(key=lambda (p: PostView) { p.created_at; }, reverse=True);
    return posts;
}
```

## Schema changes survive

Persisted data lives in the project's Postgres database - an embedded server provisioned automatically, or an external one via `JAC_DB_URL` (env) / `[scale.database] url`. Same model either way. Edits to archetypes **never delete data**:

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

def fix_tags(doc: dict[str, any]) -> None {  # migration callback for the rule below
    doc["tags"] = str(doc.get("tags", "")).split(",");
}

impl Person.__jac_schema__ -> None {
    schema_alias("name", stored="username"); # field rename: old value flows into new field
    schema_drop("legacy_bio");               # deleted field: preserve remains in the attic
    schema_upgrade(fix_tags, when=(lambda (doc: dict[str, any]) { isinstance(doc.get("tags"), str); }));
}
```

`schema_was`, `schema_alias`, `schema_drop`, `schema_upgrade` are ambient builtins, only callable inside `__jac_schema__`. Rules are shape-matched (no version numbers), idempotent, validated at startup, and run identically against the embedded Postgres locally and a managed Postgres at scale. `JAC_SCHEMA_REPAIR=repair|detect|off` is the kill switch (default `repair`).

Operator workflow when rows do quarantine:

```bash
jac db inspect --app app.jac            # state of the world
jac db quarantine list --app app.jac    # what's quarantined and why
jac db alias add "__main__.OldName" "__main__.NewName" --app app.jac   # rescue without redeploy
jac db recover-all --app app.jac        # re-attempt every quarantined row
```

## Pitfalls

- **Invalid anchors after a change:** check the reference, selected app/store, and schema migration state. Follow `jac-debugging` and `jac-sv-persistence`; do not infer that an anchor error requires deleting project data.
- A node is not persisted until it's reachable from `root`. `Post(title="x")` alone is a dangling node; `root ++> Post(...)` (or a typed edge from a reachable node) is what commits it.
- **Find-by-id keys on `jid()`, two patterns**: the in-root loop (`for p in [root-->][?:Post] { if jid(p) == id ... }`) and `jobj(id)` + `isinstance` - O(1), and REQUIRED when the target lives under another user's root (granted foreign nodes are unreachable from `[root-->]`). NEVER Python `id()`: an in-memory address that changes every restart and differs across workers, so lookups silently return empty.
- **`jobj` resolves regardless of grants** - it never authorizes. Police the subsequent read/mutation with grant levels (`jac-sv-multi-user`); don't treat a jid as a secret capability.
- `def:priv` endpoints run against a per-user `root` - the same query code gives each user only their own data (see `jac-sv-auth`).
- Renaming a field without `schema_alias` doesn't error - old values silently land in the attic and the field reads as its default. If users "lost" data after a rename, it's in the attic; declare the alias and the value flows back on next load.
