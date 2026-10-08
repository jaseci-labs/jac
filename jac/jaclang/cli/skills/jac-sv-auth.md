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
  "credential": {"type": "password", "password": "correct horse battery"},
  "profile": {"firstname": "Alice"}}'              # profile optional; response includes a token

curl -X POST http://localhost:8000/user/login -H "Content-Type: application/json" -d '{
  "identity": {"type": "username", "value": "alice"},
  "credential": {"type": "password", "password": "correct horse battery"}}'
# -> {"ok": true, "data": {"user_id": "...", "token": "eyJ...", "root_id": "...", "role": "user"}}

curl -X POST http://localhost:8000/function/my_todos \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{}'

curl http://localhost:8000/user/me -H "Authorization: Bearer $TOKEN"   # profile, identities, role
```

Identity types: `username`, `email` (max one of each; login works with either unless `login_with` narrows it). Which ones an account needs, and how strong the password must be, is the project's **auth policy** (below); a value that breaks it gets `400 POLICY_VIOLATION` with every broken rule in `error.details.violations`. Also available: `POST /user/refresh-token`, `PUT /user/password`, password-reset/verify endpoints via a configured emailer.

## Media and downloads: the session cookie

A browser cannot attach `Authorization` to `<img src>`, `<video src>`, `<audio src>` or an `<a href download>` navigation. Opt in with `[serve.auth] session_cookie = true` in `jac.toml` (env `JAC_SERVE_AUTH_SESSION_COOKIE` overrides it either way) and `/user/register`, `/user/login`, `/user/refresh-token`, `PUT /user/username`, and the second-factor `POST /user/mfa/verify` and `/user/mfa/login` also set `jac_session` (`HttpOnly`, `SameSite=Strict`, `Path=/`, `Secure` on HTTPS), which carries the same JWT:

- It is read for `GET` and `HEAD` only, and only when the request has no `Authorization` header. A write never authenticates by cookie, so keep `GET` endpoints read-only.
- A bad, expired or duplicated cookie is anonymous (401 on a protected endpoint), exactly like a bad header. The token is never read from the query string.
- `POST /user/logout` clears it (so do a password change and a password reset), and `jacLogout()` calls it. The cookie is invisible to script, so a hand-rolled client that only drops its stored token stays signed in for media until the token expires.
- A session that began elsewhere (SSO, a token minted before the switch) gets its cookie from `POST /user/refresh-token`.
- Cookie-authorized responses get `Vary: Cookie` and, unless the endpoint set its own, `Cache-Control: private`.
- The cookie is host-only: pages and API must share an origin. `Secure` follows the request scheme, so behind a TLS-terminating proxy list it in `[serve.proxy] trusted`. In a fleet, the gateway and every service must agree, which `jac.toml` gives you for free; if you use the variable instead, set it everywhere. Admin, `/metrics`, WebSockets and service-to-service calls stay header-only.

## Roles

Scale HAS a built-in role system: `admin` / `system` / `user`, stored on the user and carried in JWT claims (login and `/user/me` return it). New registrations are `user`; the bootstrap admin is created on first start. Set roles via the admin API or the admin portal at `/admin`:

```bash
curl -X PUT http://localhost:8000/admin/users/alice \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"role": "admin"}'
```

The built-in roles gate *platform* surfaces (admin portal, `/metrics`). For **app-domain** roles (moderator, team owner, ...), the in-Jac pattern is still a role field on a node hanging off the user's root, checked inside an authenticated endpoint - see `jac-sv-multi-user`.

## Second factor (TOTP)

Opt-in per user; an account with no verified factor signs in exactly as above. All bodies are JSON, all but the last need `Authorization: Bearer $TOKEN`.

| Call | Body | Answers |
|---|---|---|
| `POST /user/mfa/enroll` | `password` (+ `code` or `recovery_code` if a verified factor already exists) | `factor_id`, `secret`, `otpauth_uri` - shown once, factor is `unverified` |
| `POST /user/mfa/verify` | `factor_id`, `code` | activates the factor; a new `token` at `aal2`; `recovery_codes` (10, single-use) the first time |
| `GET /user/mfa/factors` | - | `factors` (id, status, created_at; never the secret), `current_level`, `next_level` |
| `POST /user/mfa/unenroll` | `factor_id`, `code` or `recovery_code` | removes the factor (the password alone cannot) |
| `POST /user/mfa/login` | `challenge_token`, `code` or `recovery_code` | the session `token`, at `aal2` |

Once a factor is verified, `POST /user/login` stops answering a `token`: it answers `{"mfa_required": true, "challenge_token": "...", "expires_in": 300}`. The challenge is not a session (every other endpoint answers 401 for it); exchange it at `/user/mfa/login`. Codes are RFC 6238 (SHA-1, 6 digits, 30 s, one step of clock skew), single-use, and five failures lock the account's second step for 15 minutes (`JAC_SERVE_AUTH_SECOND_FACTOR_ATTEMPTS`, `..._LOCKOUT_SECONDS`, `..._CHALLENGE_TTL_SECONDS`, `..._ISSUER`).

A session that proved a second factor carries `"aal": "aal2"` (plus `amr`, `auth_time`); a password-only or SSO session has no `aal` claim and reads as `aal1`. Use `/user/mfa/verify` on a verified factor to step an `aal1` session up. Require the level inside an endpoint:

```jac
import from jaclang.server.identity.assurance { caller_assurance_level }

def:protect rotate_keys -> dict[str, any] {
    if caller_assurance_level() != "aal2" {
        return {"ok": False, "error": "second factor required"};
    }
    return {"ok": True};
}
```

`caller_assurance_level()` is `"aal2"`, `"aal1"`, or `""` when there is no signed-in HTTP caller (anonymous, scheduled, or a WebSocket call - gate those closed).

## Auth policy (`[serve.auth]`)

The policy is declared in `jac.toml` and enforced at every write (register, password change/reset, add-identity, rename, admin create). Existing accounts are never locked out by a change; rules apply to new values.

```toml
[serve.auth.identifiers]
username = "optional"       # "required" | "optional" | "off"; an account needs at least one identifier
email = "optional"          # username "off" + email "required" = the email is the login
login_with = []             # kinds that may log in; [] = both. "off" stops NEW identifiers only

[serve.auth.email]
verification = "none"       # "optional": mail a link, do not block. "required": no session until it is used (needs [scale.emailer])
allowed_domains = []

[serve.auth.password]
min_length = 8              # default
require = []                # any of "lower", "upper", "digit", "symbol"
reject_common = true        # default: bundled common-password list
history = 0                 # last N passwords may not be reused
max_age_days = 0

[serve.auth.registration]
enabled = true              # false: 403 REGISTRATION_CLOSED, accounts come from an admin

[serve.auth.lockout]
max_attempts = 10           # failed logins per source address + identity per window_seconds (900); 429 RATE_LIMITED
```

- A new username may not contain `@`. Register an email as `{"type": "email", ...}`, not as a username.
- `GET /user/auth-policy` (public) returns the rules a form needs; `jacSignup` reads it to type a bare string as a username or an email (`jacLogin` types by shape: `@` means email).
- With `verification = "required"`, `/user/register` returns `verification_required: true` and no token, and `/user/login` answers `403 EMAIL_NOT_VERIFIED` (re-sending the link) until `POST /user/verify-identity` succeeds.
- Every key takes an env override named `JAC_SERVE_AUTH_<TABLE>_<KEY>` (`JAC_SERVE_AUTH_PASSWORD_MIN_LENGTH`). An unknown key under `[serve.auth]` stops the server at startup.
- The bootstrap admin has no default password: a dev server mints one and logs it once; a cluster needs `[scale.admin] default_password` or `JAC_SCALE_ADMIN_PASSWORD` (`jac scale deploy` mints one into the app Secret).

## JWT production footgun

With no secret configured, a dev server mints one per project into `.jac/data/jwt_secret` (gitignored, mode 0600) and reuses it across restarts, so browser sessions survive a restart and no two projects share a signing key. A deployment must set its own secret, because a per-project file would be per-replica in a cluster - a cluster with none configured falls back to the shipped placeholder and warns at boot, and anyone who knows that placeholder can forge tokens for any user:

```toml
[serve.auth]
secret = "long-random-string"     # or env JAC_SERVE_AUTH_SECRET; algorithm HS256, token_ttl_days 7
session_cookie = false            # true: also set the media cookie above; env JAC_SERVE_AUTH_SESSION_COOKIE
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
