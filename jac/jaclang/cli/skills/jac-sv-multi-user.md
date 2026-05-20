---
name: jac-sv-multi-user
description: Multi-user data sharing - cross-user permission grants, per-user roles, scanning every user's root. Load when logged-in users need to see or act on each other's data, or when tempted to fake "shared" data with a def:pub global graph. Pair with `jac-sv-auth`, `jac-node-edge-patterns`.
---

`def:priv` gives every user their own isolated subgraph hung off *their* `root` (see `jac-sv-auth`). Cross-user features deliberately punch through that isolation with two ambient builtins:

1. **`grant(node, level)`** - open ONE node to every logged-in user at a chosen access level. `revoke(node)` undoes it.
2. **`allroots()`** - enumerate every user's `root` (`list[Root]`), to scan or fan out across the whole system. Callable from any `def:priv`/`def:pub` server function.

No imports - `grant`, `revoke`, and `allroots` are injected ambiently and type-check clean when passed a node. littleX is built entirely on these two, with no per-root grant API needed.

```jac
node Profile {
    has username: str;
}

node Tweet {
    has content: str;
}

edge Posted {}

# CREATE - each user owns its data under its own root; a socially
# reachable node must be granted so OTHER users can traverse into it.
def:priv post_tweet(content: str) -> str {
    prof = [root --> [?:Profile]][0];
    t = (prof +>:Posted:+> Tweet(content=content))[0];
    grant(t, level=ConnectPerm);          # others may now connect/read this tweet
    return t.content;
}


# CROSS-USER READ - allroots() surfaces every user's root even from a
# per-user def:priv endpoint; you still only see nodes that were granted.
def:priv global_feed() -> list[dict] {
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

`grant` takes a level - an ambient constant (no import) or its int. Higher includes lower:

| Level | Other users can… | Use for |
|---|---|---|
| `NoPerm` | nothing (explicit deny) | revoking a prior grant via level |
| `ReadPerm` | read fields, traverse into it | a published doc/profile others only view |
| `ConnectPerm` | the above + attach edges to it | socially-connectable nodes (follow, like, comment targets) - littleX's default |
| `WritePerm` | the above + mutate its fields | a genuinely shared, co-edited node |

`grant(node)` with no level defaults to **`ReadPerm`** (read-only - the safe default). Still pass the level explicitly for intent, and pick the least that works: only use `ConnectPerm` when other users must attach edges (follow/like/comment), only `WritePerm` for genuinely co-edited nodes.

## Roles

There is no `current_user()` and no built-in role system. A "role" is just per-user metadata you store on a node reachable from that user's `root` and read inside a `def:priv` endpoint:

```jac
node Account {
    has role: str = "member";
}

def:priv is_admin() -> bool {
    accts = [root --> [?:Account]];
    return len(accts) > 0 and accts[0].role == "admin";
}

def:priv admin_only_action() -> str {
    if not is_admin() { return "forbidden"; }
    # ... privileged work, e.g. an allroots() scan ...
    return "done";
}
```

Gate any `allroots()` / cross-user write behind such a check - `allroots()` itself does no authorization; it just enumerates roots.

## Pitfalls

- **A node is only reachable by other users if it was `grant`-ed.** Creating it under your root and connecting an edge is NOT enough - default isolation still hides it. Forgetting the `grant` is the #1 cause of "the other user's feed is empty" with no error.
- **`allroots()` must be called from server context (a `def:priv`/`def:pub` function running under the persistence tier), not a plain `jac run` script.** In a single-session `jac run` it returns only the one root; the real multi-tier behavior (surfacing every user's root across L1/L3) only exists under `jac start`/served execution. Validate cross-user features by running two real logged-in users, never by a single-root script.
- **`grant` is per-node, not per-subtree.** Granting a `Profile` does not grant the `Tweet`s hanging off it - each node another user must read needs its own grant. Grant at creation, in the same function that makes the node.
- **`def:pub` is a blunter, often wrong alternative.** Putting shared data on the `def:pub` global root exposes it to anonymous callers and mixes it into one graph. For user-owned-but-shared data keep endpoints `def:priv` and use `grant`; reserve `def:pub` for truly public, non-user data. See `jac-sv-auth`.
