"""Auth context for the google-auth example.

Wraps the app, derives the current user from the stored `jac_token` JWT, and
exposes SSO login / register / logout. Login and register delegate to the
runtime's `jacSsoLogin`, which opens the *system browser* via the desktop broker
when running inside the Jac-native desktop shell (so users authenticate in their
real browser, reusing existing sessions) and falls back to a normal redirect on
the web.
"""

import from react { createContext }
import from "@jac/runtime" { jacSsoLogin, jacLogout, __getLocalStorage, useNavigate }

glob:pub AuthContext = createContext(None);

"""Decode the `jac_token` JWT payload into a `{name, email}` user, or None."""
def decodeUser(token: str) -> any {
    if not token {
        return None;
    }
    try {
        payload = JSON.parse(atob(token.split('.')[1]));
        name = payload.username or payload.name or payload.email or "user";
        return {"name": name, "email": payload.email or ""};
    } except e {
        console.warn("[auth] could not decode token:", e);
        return None;
    }
}

def:pub AuthProvider(children: any) -> JsxElement {
    # Hydrate from any token already in storage (e.g. after a web OAuth redirect
    # reloaded the page, or a desktop session restored from disk).
    has user: any = decodeUser(__getLocalStorage("jac_token") or "");
    navigate = useNavigate();

    # After a successful SSO round-trip, pull the freshly stored token and show
    # the user. On the web this code doesn't run (the page has already
    # redirected to the provider); in the desktop shell jacSsoLogin resolves here
    # once the broker has the token, so this is what completes the login.
    async def _finishIfLoggedIn {
        u = decodeUser(__getLocalStorage("jac_token") or "");
        if u {
            user = u;
            navigate("/dashboard");
        }
    }

    async def handleLogin(platform: str) {
        if await jacSsoLogin(platform) {
            await _finishIfLoggedIn();
        }
    }

    async def handleRegister(platform: str) {
        if await jacSsoLogin(platform, "", "register") {
            await _finishIfLoggedIn();
        }
    }

    def handleLogout {
        jacLogout();
        user = None;
        navigate("/login");
    }

    value = {
        "user": user,
        "handleLogin": handleLogin,
        "handleRegister": handleRegister,
        "handleLogout": handleLogout
    };
    return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
