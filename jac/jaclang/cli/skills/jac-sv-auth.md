---
name: jac-sv-auth
description: Configure server endpoint authentication and caller identity. Use when selecting visibility, handling tokens, or defining access requirements.
---

Jac's server auth is built on **per-user data isolation**: every registered user gets their own root, and authenticated endpoints run against the caller's root. There is no user-id parameter to check - identity is implicit in which `root` the endpoint sees.

## Endpoint auth semantics (canonical - verified against the live server)

- **`def:pub` / `walker:pub`** - no auth required. An **anonymous** caller runs on the shared guest graph (`root` is `root.shared`); a caller who *does* send a valid token runs on **their own root**. So `root` inside a `:pub` endpoint is not one fixed graph - it depends on the caller's token.
- **`def:protect` / `walker:protect`** - JWT required (`401 UNAUTHORIZED` without one); runs on the caller's own isolated root. This is the authenticated endpoint, and it bridges to clients and to other apps exactly like `:pub` does.
- **Plain `def` / `def:priv`** (and plain `walker` / `walker:priv`) - **private**: never registered as an endpoint, never importable by client code, never on another app's bridge surface. A plain def is a server-side helper; a plain walker is spawned in-process or on a schedule. Nothing is served unless its declaration says so.
- The declaration is the only source of truth: there is no `_`-prefix rule, no "name it in the entry import" rule, and no `[placement.pins]` trust-boundary form. `jac fix access` migrates code written for the old plain-means-authenticated rule.

```jac
node Todo {
    has title: str;
}


# PUBLIC - anonymous callers all share the guest graph.
def:pub public_feed_size() -> int {
    return len([root -->][?:Todo]);
}


# AUTHENTICATED (def:protect) - per-user root, each caller
# sees only their own data. Same query code, different subgraph per user.
def:protect my_todos() -> list[Todo] {
    return [root -->][?:Todo];
}

def:protect add_todo(title: str) -> Todo {
    return root ++> Todo(title=title);
}

# PRIVATE (plain def) - a helper the endpoints above may call; never served.
def open_count() -> int {
    return len([root -->][?:Todo]);
}
```

CRUD shapes, return types, walkers: `jac-sv-endpoints`.

## REST auth flow (any non-jac-client caller)

The jac client wraps this (`jacLogin` etc. - see `jac-cl-auth`); raw REST consumers drive it directly. **Register takes an identity array, NOT a flat `{username, password}` body** (that returns 422):

```bash
curl -X POST http://localhost:8000/user/register -H "Content-Type: application/json" -d '{
  "identities": [{"type": "username", "value": "alice"},
                 {"type": "email", "value": "a@example.com"}],
  "credential": {"type": "password", "password": "secret123"},
  "profile": {"firstname": "Alice"}}'              # profile optional; response includes a token

curl -X POST http://localhost:8000/user/login -H "Content-Type: application/json" -d '{
  "identity": {"type": "username", "value": "alice"},
  "credential": {"type": "password", "password": "secret123"}}'
# -> {"ok": true, "data": {"user_id": "...", "token": "eyJ...", "root_id": "...", "role": "user"}}

curl -X POST http://localhost:8000/function/my_todos \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{}'

curl http://localhost:8000/user/me -H "Authorization: Bearer $TOKEN"   # profile, identities, role
```

Identity types: `username`, `email` (max one of each; login works with either). Also available: `POST /user/refresh-token`, `PUT /user/password`, password-reset/verify endpoints via a configured emailer.

## Roles

Scale HAS a built-in role system: `admin` / `system` / `user`, stored on the user and carried in JWT claims (login and `/user/me` return it). New registrations are `user`; the bootstrap admin is created on first start. Set roles via the admin API or the admin portal at `/admin`:

```bash
curl -X PUT http://localhost:8000/admin/users/alice \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"role": "admin"}'
```

The built-in roles gate *platform* surfaces (admin portal, `/metrics`). For **app-domain** roles (moderator, team owner, ...), the in-Jac pattern is still a role field on a node hanging off the user's root, checked inside an authenticated endpoint - see `jac-sv-multi-user`.

## JWT production footgun

With no secret configured, a dev server mints one per project into `.jac/data/jwt_secret` (gitignored, mode 0600) and reuses it across restarts, so browser sessions survive a restart and no two projects share a signing key. A deployment must set its own secret, because a per-project file would be per-replica in a cluster - a cluster with none configured falls back to the shipped placeholder and warns at boot, and anyone who knows that placeholder can forge tokens for any user:

```toml
[serve.auth]
secret = "long-random-string"     # or env JAC_SERVE_AUTH_SECRET; algorithm HS256, token_ttl_days 7
```

No token revocation exists - tokens stay valid until expiry. SSO (Google/Apple/GitHub): configure `[scale.sso.<platform>]` and send users to `/sso/<platform>/login`.

## Sharing data with specific users

`grant(node, level)` opens a node to **every** logged-in user - it is NOT a per-user grant. Per-user sharing uses `allow_root` / `disallow_root`, and truly-public data belongs on `root.shared`. **Load `jac-sv-multi-user`** for all of it.

## Pitfalls

- **Wrong visibility = silent data leak.** Writing user-specific data from a `def:pub` endpoint puts anonymous users' data on the shared guest graph, and the same code does different things for token-holders. No compile or runtime error - it only surfaces when user B sees user A's data. User-specific data ⇒ authenticated endpoint (`def:protect`). Verify by logging in as two users and checking reads don't cross.
- Don't "fix" a 401 by making the endpoint `:pub` - that changes whose graph it runs on, not just who may call it.
- `:pub` and authenticated endpoints can live in the same file - visibility is per-declaration.
- Client calls to an authenticated endpoint without a session raise an error containing `"UNAUTHORIZED"` - catch and redirect to login (`jac-cl-auth`).
- `register` returns a token too (verified), but `login`'s response is the canonical source of `token` + `root_id` - keep `root_id` if you plan to use per-user grants (`jac-sv-multi-user`).

Deep dive bundled with the CLI: `jac guide reference/persistence` (auth + per-user roots in the full persistence reference).
