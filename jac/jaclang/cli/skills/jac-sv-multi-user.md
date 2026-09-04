---
name: jac-sv-multi-user
description: Multi-user data sharing - cross-user permission grants (the ambient AccessLevel enum, everyone or one specific user), the shared root / public feed pattern (root.shared), archetype-wide access policy (__jac_access__), per-user grants with allow_root, roles, scanning every user's root (allroots). Load when logged-in users need to see or act on each other's data, or when tempted to fake "shared" data with a def:pub global graph. Pair with `jac-sv-auth`, `jac-node-edge-patterns`.
---

Authenticated endpoints give every user an isolated subgraph hung off *their* `root` (see `jac-sv-auth`). Cross-user features punch through that isolation three ways:

1. **`grant(node, level)`** - open ONE node to **every** logged-in user. `revoke(node)` undoes it. Ambient builtins, no import.
2. **`Jac.allow_root(node, root_id, level)`** - open one node to **one specific user**. `Jac.disallow_root(node, root_id)` undoes it. Needs an import (below).
3. **`root.shared`** - the deployment's public commons graph; write public data there directly.
4. **`def __jac_access__`** on a node/edge - open **every instance of the archetype** at a fixed level; for app-owned public structure (below).

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
    grant(t, level=AccessLevel.WRITE);   # likes/comments MUTATE tweet fields -> WRITE
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

`grant`/`allow_root` take a member of the ambient `AccessLevel` enum (no import). Higher includes lower: `AccessLevel.NO_ACCESS` (explicit deny) < `AccessLevel.READ` (read fields, traverse in) < `AccessLevel.CONNECT` (+ attach edges) < `AccessLevel.WRITE` (+ mutate fields). Omitted level defaults to `AccessLevel.READ`; pass it explicitly and pick the least that works.

**Pick the level by what the interaction does to the target.** Edge-attach interactions (follow a Profile, join a Channel) need only `AccessLevel.CONNECT`. Interactions that MUTATE FIELDS on the target need `AccessLevel.WRITE`: littleX stores likes/comments as fields ON the tweet (`here.likes`, `here.comments`), so Tweets get `AccessLevel.WRITE` while Profiles and Channels get `AccessLevel.CONNECT`.

The Scale reference's `perm_grant` / `perm_revoke` / `allow_root` / `disallow_root` take the same `AccessLevel` members. (The former ambient constants `NoPerm`/`ReadPerm`/`ConnectPerm`/`WritePerm` were removed - if you see them in older snippets, they map 1:1 onto the enum members.)

## Per-user grants: allow_root

"Share with user B only" - `grant()` over-shares to all users. `allow_root` is the per-user form. It is NOT ambient (calling bare `allow_root(...)` passes `jac check` with a warning but **NameErrors at runtime** - the Scale docs' bare usage is misleading); import the runtime:

```jac
import from jaclang { JacRuntime as Jac }
import from uuid { UUID }

def share_with(tweet_id: str, target_root: str) {
    for t in [root -->][?:Tweet] {
        if jid(t) == tweet_id {
            Jac.allow_root(t, UUID(target_root), AccessLevel.READ);  # jac:ignore[E1053]
            # Jac.disallow_root(t, UUID(target_root));       # revoke that one user
        }
    }
}
```

`target_root` is the other user's root id - the `root_id` field of their `/user/login` response, or `jid(root)` captured server-side. Like `grant`, it's per-node, not per-subtree. The `jac:ignore[E1053]` is needed because the checker doesn't yet accept node types for the `archetype: Archetype` parameter (runtime is fine - verified live); alternatively cast `t as Archetype` with `import from jaclang.runtime.archetype { Archetype }`.

## Sharing with a group: `allow_group`

`allow_root(obj, root_id, level)` writes one entry per grantee into that
object's own permission map, so an audience of N costs N entries on every
object and joining or leaving rewrites all of them. Name a **group** instead:
the grant is one entry, and membership is an edge.

```jac
node Doc { has body: str; }
node Team { has name: str; }
edge MemberOf {}

import from jaclang { JacRuntime as Jac }
import from uuid { UUID }

def share_with_team(doc: Doc, team: Team) {
    Jac.allow_group(doc, UUID(jid(team)), AccessLevel.READ);  # jac:ignore[E1053]
}

def join_team(team: Team) {
    root +>:MemberOf:+> team;   # joining: one edge, zero content writes
}
```

- Membership is resolved through the edge at check time, so a join or a leave
  touches no content row at all - which is what makes it O(1) rather than
  proportional to the group's data.
- Group grants compose with the rest: an existing per-root grant still
  applies, and a group grant only ever raises the level.
- The permission test compiles into the query for the standard model (owner,
  granted-to-all, granted-to-you, granted-to-your-group), so a gated read
  costs the rows you may see. An archetype overriding `__jac_access__` or
  `__jac_access_for__` decides in Jac, which has no SQL form, and keeps the
  object-space filter.

## root.shared - the public commons

Every served deployment has one public graph besides the per-user roots: the guest root that anonymous requests run on. `root.shared` resolves to it from any request context - the right home for genuinely public data (feed, catalog, announcements):

```jac
def publish(text: str) {                     # authenticated author, public post
    fresh = root.shared ++> Tweet(content=text);
    grant(fresh, level=AccessLevel.READ);    # author still owns it; open it to readers
}

def:pub read_feed() -> list[str] {           # works anonymous or logged-in
    return [t.content for t in [root.shared -->][?:Tweet]];
}
```

- One traversal regardless of user count - the better public-feed pattern vs the O(N-users) `allroots()` scan above.
- **Floor: `AccessLevel.CONNECT`.** Every user (authenticated or anonymous) can read it and attach nodes without an arming grant. Nodes you hang there stay *owned by you* and closed until you `grant` them.
- **Container/leaf pairing** (the guestbook's shape, `root.shared → Day(date) → Visitor`): grant the *container* `AccessLevel.CONNECT` so strangers can attach under it, and each *leaf* `AccessLevel.READ` so everyone reads it but only the author's walkers mutate it.
- **Lockdown:** `grant(root.shared, level=AccessLevel.READ)` (from an anonymous/system context) makes the commons read-only; any explicit level except `AccessLevel.NO_ACCESS` is respected.
- Outside a server (`jac run`, scripts, tests) there are no separate users: `jid(root.shared) == jid(root)`.

## Archetype-wide policy: `__jac_access__`

When openness is an invariant of the TYPE - a machine-generated cache on `root.shared`, commons state any request may rebuild - a per-creation-site `grant()` is fragile (one missed call, and it only surfaces when a SECOND user hits that path). Declare the policy once on the archetype:

```jac
node PublicNode {
    def __jac_access__ -> AccessLevel {
        return AccessLevel.WRITE;    # every instance opens WRITE to every user
    }
}
edge PublicEdge {
    def __jac_access__ -> AccessLevel {
        return AccessLevel.WRITE;
    }
}

node DocPage(PublicNode) {}    # subtypes inherit the policy
edge Contains(PublicEdge) {}
```

- Consulted for every non-owner access, BEFORE stored grants: a returned level is final; return `None` (with return type `-> AccessLevel | None`) to fall through to grant checking, enabling conditional policies like `return AccessLevel.READ if self.published else None;`.
- Return `AccessLevel` members (ambient, no import). Strings (`"WRITE"`) and ints are accepted but a typo'd string is a runtime `KeyError` on the first cross-user request - never hand-write them.
- Owner and system root always have `WRITE`; the hook cannot lock the author out.
- Decision rule: user-owned contributions -> `grant` at creation (owner decides per instance); app-owned public structure -> `__jac_access__` (author decides per archetype).

## Per-caller policy: `__jac_access_for__`

`__jac_access__` answers "what does every non-owner get" - it cannot see who is
asking, and the owner fast-path pre-empts it, so a role like "viewer of this
team's doc" is not expressible with it. Declare `__jac_access_for__(caller)`
instead; it receives the calling root's UUID and runs BEFORE the owner
fast-path, so ownership admits but the role decides:

```jac
node TeamDoc {
    has editors: list[str] = [];   # root ids, maintained by the app

    def __jac_access_for__(caller: UUID) -> (AccessLevel | None) {
        if str(caller) in self.editors { return AccessLevel.WRITE; }
        return AccessLevel.READ;    # everyone else, the owner included
    }
}
```

- A returned level is final for that caller - even the owning root can be held
  to `READ`, which is what makes org-style roles expressible. Return `None` to
  fall through to the normal resolution (ownership, then stored grants).
- The system root always has `WRITE`; the hook cannot lock the platform out.
- When an archetype defines `__jac_access_for__`, its zero-arg
  `__jac_access__` is not consulted - one policy per archetype, and the
  caller-aware one wins. Archetypes that define neither, or only the zero-arg
  form, behave exactly as before.

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

## Invitation tokens: app_tokens

Never hand-roll invitation tokens with a `used: bool` flag on a node - a
read-then-write flag lets two concurrent accepts both win. The platform's token
store does this correctly (raw value shown once, only the sha256 persisted,
server-side expiry, atomic single-winner consume) and is exposed for app flows:

```jac
import from jaclang.scale.identity.app_tokens {
    token_create, token_peek, token_consume, token_revoke
}

def invite(role: str) -> dict {
    # subject groups tokens for revocation; payload rides along to the redeemer
    tok = token_create(
        "org-invite", subject=jid(root), ttl_seconds=86400,
        payload={"role": role}
    );
    return {"token": tok};   # shown once; never stored raw
}

def accept(token: str) -> dict {
    got = token_consume("org-invite", token);   # exactly one caller wins
    if got is None { return {"ok": False}; }    # invalid, expired, or lost race
    return {"ok": True, "role": got["payload"]["role"]};
}

def cancel_invites -> dict {
    return {"revoked": token_revoke("org-invite", jid(root))};
}
```

`token_peek` inspects without consuming. Purposes are namespaced internally
(`app:` prefix), so they cannot collide with the identity endpoints' own
`verify`/`reset` tokens, and two different purposes never redeem each other's
tokens.

## Pitfalls

- **A node is only reachable by other users if granted** (`grant`, `allow_root`, or living open on `root.shared`). Creating it under your root and connecting an edge is NOT enough - forgetting the grant is the #1 cause of "the other user's feed is empty" with no error. Grant at creation time, in the same function.
- **Grants are per-node, not per-subtree.** Granting a `Profile` does not grant the `Tweet`s hanging off it.
- **`allroots()` needs served context** (`jac run`). In a single-session `jac run` it returns only the one root - validate cross-user features with two real logged-in users, never a single-root script.
- **`allroots()` fan-outs can visit the same node twice** - a node reachable through more than one root (granted, shared) is surfaced once per path, so a bare per-visit tally double-counts. Dedupe with a `jid(here)`-keyed dict (littleX's trending walker keeps a `seen: dict[str, bool]`).
- **`def:pub` is the wrong tool for shared data.** Anonymous callers land on the guest graph, token-holders on their own root - so a `:pub` "global graph" isn't even one graph. Keep endpoints authenticated and use `grant`/`root.shared`. See `jac-sv-auth`.
- `jobj(id)` resolves any node by jid regardless of grants - don't treat a jid as a secret capability; enforce sharing decisions with grant levels and traversal, not id obscurity.
