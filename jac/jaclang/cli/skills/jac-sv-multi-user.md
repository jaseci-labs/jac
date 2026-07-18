---
name: jac-sv-multi-user
description: Multi-user data sharing - cross-user permission grants (ReadPerm/ConnectPerm/WritePerm, everyone or one specific user), the shared root / public feed pattern (root.shared), per-user grants with allow_root, roles, scanning every user's root (allroots). Load when logged-in users need to see or act on each other's data, or when tempted to fake "shared" data with a def:pub global graph. Pair with `jac-sv-auth`, `jac-node-edge-patterns`.
---

Authenticated endpoints give every user an isolated subgraph hung off *their* `root` (see `jac-sv-auth`). Cross-user features punch through that isolation three ways:

1. **`grant(node, level)`** - open ONE node to **every** logged-in user. `revoke(node)` undoes it. Ambient builtins, no import.
2. **`Jac.allow_root(node, root_id, level)`** - open one node to **one specific user**. `Jac.disallow_root(node, root_id)` undoes it. Needs an import (below).
3. **`root.shared`** - the deployment's public commons graph; write public data there directly.

Plus **`allroots()`** (ambient) - enumerate every user's `root` (`list[Root]`) for admin/fan-out scans.

```jac
node Profile { has username: str; }
node Tweet { has content: str; }
edge Posted {}

# CREATE - data lives under the author's root; grant() is what makes it
# reachable by OTHER users. littleX is built on exactly this.
def post_tweet(content: str) -> str {
    prof = [root --> [?:Profile]][0];
    t = prof +>:Posted:+> Tweet(content=content);
    grant(t, level=WritePerm);   # likes/comments MUTATE tweet fields -> WritePerm
    return t.content;
}


# CROSS-USER READ - allroots() surfaces every root even from a per-user
# endpoint; you still only see nodes that were granted. NOTE: this scan is
# O(number of users) per request - for a public feed prefer root.shared below.
def global_feed() -> list[dict] {
    feed: list[dict] = [];
    for r in allroots() {
        for prof in [r --> [?:Profile]] {
            for tw in [prof ->:Posted:-> [?:Tweet]] {
                feed.append({"by": prof.username, "text": tw.content});
            }
        }
    }
    return feed;
}
```

## Access levels

`grant`/`allow_root` take an ambient level constant (or its int). Higher includes lower: `NoPerm` (explicit deny) < `ReadPerm` (read fields, traverse in) < `ConnectPerm` (+ attach edges) < `WritePerm` (+ mutate fields). Omitted level defaults to `ReadPerm`; pass it explicitly and pick the least that works.

**Pick the level by what the interaction does to the target.** Edge-attach interactions (follow a Profile, join a Channel) need only `ConnectPerm`. Interactions that MUTATE FIELDS on the target need `WritePerm`: littleX stores likes/comments as fields ON the tweet (`here.likes`, `here.comments`), so Tweets get `WritePerm` while Profiles and Channels get `ConnectPerm`.

**Vocabulary mapping:** the Scale reference spells these `perm_grant` / `perm_revoke` / `allow_root` / `disallow_root` with levels `NO_ACCESS` / `READ` / `CONNECT` / `WRITE` - same machinery as the ambient `grant` / `revoke` + `NoPerm`..`WritePerm` names used here.

## Per-user grants: allow_root

"Share with user B only" - `grant()` over-shares to all users. `allow_root` is the per-user form. It is NOT ambient (calling bare `allow_root(...)` passes `jac check` with a warning but **NameErrors at runtime** - the Scale docs' bare usage is misleading); import the runtime:

```jac
import from jaclang { JacRuntime as Jac }
import from uuid { UUID }

def share_with(tweet_id: str, target_root: str) {
    for t in [root -->][?:Tweet] {
        if jid(t) == tweet_id {
            Jac.allow_root(t, UUID(target_root), ReadPerm);  # jac:ignore[E1053]
            # Jac.disallow_root(t, UUID(target_root));       # revoke that one user
        }
    }
}
```

`target_root` is the other user's root id - the `root_id` field of their `/user/login` response, or `jid(root)` captured server-side. Like `grant`, it's per-node, not per-subtree. The `jac:ignore[E1053]` is needed because the checker doesn't yet accept node types for the `archetype: Archetype` parameter (runtime is fine - verified live); alternatively cast `t as Archetype` with `import from jaclang.jac0core.archetype { Archetype }`.

## root.shared - the public commons

Every served deployment has one public graph besides the per-user roots: the guest root that anonymous requests run on. `root.shared` resolves to it from any request context - the right home for genuinely public data (feed, catalog, announcements):

```jac
def publish(text: str) {                     # authenticated author, public post
    fresh = root.shared ++> Tweet(content=text);
    grant(fresh, level=ReadPerm);            # author still owns it; open it to readers
}

def:pub read_feed() -> list[str] {           # works anonymous or logged-in
    return [t.content for t in [root.shared -->][?:Tweet]];
}
```

- One traversal regardless of user count - the better public-feed pattern vs the O(N-users) `allroots()` scan above.
- **Floor: `ConnectPerm`.** Every user (authenticated or anonymous) can read it and attach nodes without an arming grant. Nodes you hang there stay *owned by you* and closed until you `grant` them.
- **Container/leaf pairing** (the guestbook's shape, `root.shared → Day(date) → Visitor`): grant the *container* `ConnectPerm` so strangers can attach under it, and each *leaf* `ReadPerm` so everyone reads it but only the author's walkers mutate it.
- **Lockdown:** `grant(root.shared, level=ReadPerm)` (from an anonymous/system context) makes the commons read-only; any explicit level except `NoPerm` is respected.
- Outside a server (`jac run`, scripts, tests) there are no separate users: `jid(root.shared) == jid(root)`.

## Roles

Platform roles (`admin`/`system`/`user`) are built in - JWT claims, `/user/me`, `PUT /admin/users/{username}` - see `jac-sv-auth`. App-domain roles are per-user metadata on the user's own graph:

```jac
node Account { has role: str = "member"; }

def admin_only_action() -> str {
    accts = [root --> [?:Account]];
    if not (len(accts) > 0 and accts[0].role == "admin") { return "forbidden"; }
    # ... privileged work, e.g. an allroots() scan ...
    return "done";
}
```

Read-only `allroots()` fan-outs don't need gating - grants already filter what each caller can see (public trending/explore feeds are ungated reads in practice). Gate cross-user WRITES behind a check like this - `allroots()` itself does no authorization.

## Pitfalls

- **A node is only reachable by other users if granted** (`grant`, `allow_root`, or living open on `root.shared`). Creating it under your root and connecting an edge is NOT enough - forgetting the grant is the #1 cause of "the other user's feed is empty" with no error. Grant at creation time, in the same function.
- **Grants are per-node, not per-subtree.** Granting a `Profile` does not grant the `Tweet`s hanging off it.
- **`allroots()` needs served context** (`jac start`). In a single-session `jac run` it returns only the one root - validate cross-user features with two real logged-in users, never a single-root script.
- **`allroots()` fan-outs can visit the same node twice** - a node reachable through more than one root (granted, shared) is surfaced once per path, so a bare per-visit tally double-counts. Dedupe with a `jid(here)`-keyed dict (littleX's trending walker keeps a `seen: dict[str, bool]`).
- **`def:pub` is the wrong tool for shared data.** Anonymous callers land on the guest graph, token-holders on their own root - so a `:pub` "global graph" isn't even one graph. Keep endpoints authenticated and use `grant`/`root.shared`. See `jac-sv-auth`.
- `jobj(id)` resolves any node by jid regardless of grants - don't treat a jid as a secret capability; enforce sharing decisions with grant levels and traversal, not id obscurity.
