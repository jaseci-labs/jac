---
name: jac-cl-auth
description: Client-side authentication - signing up, logging in, logging out, AuthGuard for protected routes, and SSO login. Load when adding any auth UI or guarding pages from unauthenticated users. Pair with `jac-sv-auth` (server side of the auth loop), `jac-cl-routing` (post-login navigation).
---

Client auth uses four helpers from `@jac/runtime`. **Return types differ - get them wrong and the file fails `jac check` with E1001:**

| Helper | Async? | Returns | Pre-declare as |
|---|---|---|---|
| `jacSignup(email, password)` | yes | `dict` - `{"success": bool, ...}` | `result: dict \| None = None` |
| `jacLogin(email, password)` | yes | `bool` | `ok: bool = False` |
| `jacLogout()` | no | `None` | - (call it, no assign) |
| `jacIsLoggedIn()` | no | `bool` | - (use inline) |

These patterns apply in any client code - plain `.jac` components inferred client (the `@jac/runtime` import itself is a string-path npm import, which is client-only syntax; markers are optional overrides - see `jac-codespaces`).

The two return types behave differently for failure checks. `jacLogin` returns a plain `bool` - `if not ok { ... }` detects a failed login directly. `jacSignup` returns a **`dict`** shaped `{"success": bool, "user_id" | "error": ...}`, and it is *always* a non-empty (truthy) dict - so `if not signup_result` can **never** catch a failed signup. Check the `success` key instead: `if not signup_result["success"] { ... }`. (Typing a `jacSignup` result as `bool` also fails `jac check` with `E1001: Cannot assign dict to bool`.)

## ⚠ Read first - signup + first `def:priv` call must be 3 awaited steps

When the same form that signs a user up also calls a `def:priv` endpoint (saving the new user's profile, preferences, default workspace), the call order is **fixed and each step MUST be awaited**:

1. `await jacSignup(email, password)` - creates the account; **no session yet**
2. `await jacLogin(email, password)` - establishes the session cookie
3. `await save_profile(...)` - only NOW does the `def:priv` call have an authenticated session

```
# `save_profile` here is YOUR server function (def:priv) - imported from a .sv.jac module.
async def handle_register(name: str, email: str, password: str) -> str {
    # Pre-declare every var that holds an `await` result. `let` scoping in the
    # generated JS can otherwise leave them undefined at the if-check.
    # Note the per-helper types: jacSignup -> dict, jacLogin -> bool.
    signup_result: dict | None = None;
    login_ok: bool = False;
    profile_result: any = None;

    signup_result = await jacSignup(email, password);
    if not signup_result["success"] { return "registration failed"; }

    login_ok = await jacLogin(email, password);
    if not login_ok { return "login after signup failed"; }

    profile_result = await save_profile(name, email);
    if profile_result is None { return "save failed"; }
    if not profile_result.success { return profile_result.message; }

    return "success";
}
```

**Why every `await` matters:** all three are async (return Promises). Skipping any `await` fires that call as a background Promise and lets the next line execute immediately. If `save_profile` fires before `jacLogin` completes, the session cookie isn't set yet → server gets the request without auth → `401 Unauthorized`. **Silent at compile time - only surfaces at runtime on first registration.**

**Why pre-declare:** in client Jac, `var = await fn()` can compile to a JS `let var = ...` that is scoped tighter than the surrounding function (especially around `try`/`except` and certain async patterns), so `if not var { ... }` on the next line throws `ReferenceError: var is not defined`. Declaring `var: T = default;` at the top forces a function-scope `let` that the if-check can see.

---

```jac
import from "@jac/runtime" { jacLogin, jacSignup, jacLogout, jacIsLoggedIn, Navigate }

# Login attempt - call from a submit handler or effect. Returns a status string.
# Pre-declare `ok` at the top - see "Why pre-declare" above.
async def try_login(email: str, password: str) -> str {
    ok: bool = False;
    try {
        ok = await jacLogin(email, password);
        if ok {
            return "success";
        }
        return "invalid credentials";
    } except Exception as e {
        return "error";
    }
}

# Signup is usually followed by a login to establish the session.
async def try_signup(email: str, password: str) -> str {
    signup_result: dict | None = None;       # jacSignup returns dict
    login_ok: bool = False;                  # jacLogin returns bool
    try {
        signup_result = await jacSignup(email, password);
        if not signup_result["success"] {
            return "signup failed (email may be in use)";
        }
        login_ok = await jacLogin(email, password);
        if login_ok {
            return "success";
        }
        return "login after signup failed";
    } except Exception as e {
        return "error";
    }
}

# Logout is synchronous - no await.
def perform_logout() {
    jacLogout();
}

# Typical protected page - inline guard at the top.
def:pub Dashboard() -> JsxElement {
    if not jacIsLoggedIn() {
        return <Navigate to="/login" replace={True} />;
    }
    return <div className="p-4">Welcome to the dashboard</div>;
}
```

## Protecting routes with `AuthGuard` (preferred over inline guards)

`AuthGuard` from `@jac/runtime` wraps children and redirects unauthenticated users - no per-page guard code, no rules-of-hooks ordering trap. With file-based routing, one layout protects a whole route group:

```jac
# pages/(auth)/layout.jac - every page in (auth)/ now requires login
import from "@jac/runtime" { AuthGuard, Outlet }

def:pub layout() -> JsxElement {
    return <AuthGuard redirect="/login"><Outlet /></AuthGuard>;
}
```

In manual routing, wrap the protected subtree the same way: `<AuthGuard redirect="/login"><Dashboard /></AuthGuard>`. Reserve the inline `jacIsLoggedIn()` guard for one-off cases.

## SSO login

Server side: configure a provider in `jac.toml` (handled by the built-in scale subsystem - see `jac-sv-auth`):

```toml
[scale.sso.google]
client_id = "..."
client_secret = "..."
```

The server then exposes `/sso/{platform}/login`, `/sso/{platform}/register`, and the OAuth callback. Client side, `await jacSsoLogin("google")` (async, returns `bool`) hands off to the provider and resolves once the token lands; `jacSetToken(token)` stores a token directly (used by SSO callback pages).

## Auth-relevant `@jac/runtime` exports

`jacLogin`, `jacSignup`, `jacLogout`, `jacIsLoggedIn`, `jacSsoLogin`, `jacSetToken`, `AuthGuard`, plus `Navigate` / `useNavigate` for post-auth redirects. For the full client export list, see `jac-cl-components`.

## Pitfalls

- Import auth helpers from `@jac/runtime` - see `jac-core-cheatsheet` for import form rules.
- Post-logout pattern: `jacLogout(); nav("/login");` - synchronous call, then navigate.
- Post-login navigation uses `useNavigate()` from `jac-cl-routing` - `nav = useNavigate(); ... nav("/dashboard");` after a successful login.
- **`jacSignup` does NOT establish a session.** ALWAYS follow with a `jacLogin` call using the same credentials - signup alone leaves the user unauthenticated.
- **`jacLogin`, `jacSignup`, `jacSsoLogin` are `async` - always `await`. `jacLogout` and `jacIsLoggedIn` are sync - NEVER `await` them.** `await jacLogout()` type-errors; missing `await` on `jacLogin` silently returns a coroutine instead of the result.
- **Pre-declare any var that holds an `await` result before the assignment.** In client Jac, `var = await fn()` can compile to a JS `let var = ...` whose scope is tighter than the surrounding function, so a later `if not var { ... }` throws `ReferenceError: var is not defined` at runtime. Compile passes; the page just blanks. Fix: declare the var with a default at the top, then assign.

```
# FRAGILE - runtime ReferenceError on the if-check
async def handle_login(email: str, password: str) -> str {
    ok = await jacLogin(email, password);
    if not ok { return "failed"; }      # ReferenceError: ok is not defined
    return "success";
}

# CORRECT - function-scope let, visible to the if-check
async def handle_login(email: str, password: str) -> str {
    ok: bool = False;
    ok = await jacLogin(email, password);
    if not ok { return "failed"; }
    return "success";
}
```

- For sharing the current user across components (an auth context with `user`/`setUser`), use the `createContext`/`useContext` pattern in `jac-cl-organization` - a `useAuth()` hook alone does NOT share state between consumers.

For jac-shadcn projects, apply auth handlers inside your `LoginPage.jac` component. The auth card layout pattern (viewport-centered, `max-w-sm`, `min-h-svh`) is in `jac-shadcn-blocks`.
