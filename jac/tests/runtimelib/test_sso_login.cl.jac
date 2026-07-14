"""Client-runtime SSO login tests (run under bun via the cl test runner).

These exercise the real compiled `@jac/runtime` `jacSsoLogin` with `fetch` and
the desktop-shell `window` flags mocked, so no webview, OAuth provider, or
backend is needed. They lock in the two branches:

  * desktop shell -> hands off to the loopback broker (`/__jac/oauth/start`) and
    polls `/__jac/session` for the token, then stores it under `jac_token`;
  * plain web -> navigates the document to the server's `/sso/<p>/<op>` endpoint.
"""

import from "@jac/runtime" {
    jacSsoLogin,
    jacSetToken,
    jacLogout,
    jacIsLoggedIn,
    __getLocalStorage,
    __setLocalStorage
}

"""A minimal mock `fetch` Response carrying `body` from `.json()`."""
def _resp(body: dict) -> dict {
    return {
        "ok": True,
        "status": 200,
        "json": lambda -> any { return Promise.resolve(body); }
    };
}

test "desktop SSO hands off to the broker, polls the session, stores jac_token" {
    # Pretend we're inside the Jac-native desktop shell.
    window.__JAC_DESKTOP__ = True;
    window.__JAC_BROKER__ = "/__jac";
    __setLocalStorage("jac_token", "");

    calls = [];
    globalThis.fetch = lambda (url: any) -> any {
        calls.append(url);
        if url.includes("oauth/start") {
            return Promise.resolve(_resp({"ok": True}));
        }
        # /__jac/session: hand back the token the broker would have stored.
        return Promise.resolve(_resp({"token": "tok-123"}));
    };

    ok = await jacSsoLogin("google");

    assert ok == True;
    # Token landed under the canonical key the rest of the runtime reads.
    assert __getLocalStorage("jac_token") == "tok-123";
    # The broker open was requested with the right platform + operation...
    assert any(
        c.includes("oauth/start")
        and c.includes("platform=google")
        and c.includes("operation=login") for c in calls
    );
    # ...and the session store was polled on the broker prefix.
    assert any(c.includes("/__jac/session") for c in calls);

    # Teardown so later tests see a clean web environment.
    window.__JAC_DESKTOP__ = False;
    window.__JAC_BROKER__ = "";
    globalThis.fetch = undefined;
}

test "web SSO navigates to the server's sso endpoint (no broker)" {
    window.__JAC_DESKTOP__ = False;
    window.__JAC_BROKER__ = "";
    window.location.href = "http://localhost/";

    ok = await jacSsoLogin("github", "https://api.example.com", "register");

    assert ok == True;
    assert window.location.href == "https://api.example.com/sso/github/register";
}

test "jacSetToken stores under jac_token and drives jacIsLoggedIn" {
    __setLocalStorage("jac_token", "");
    assert jacIsLoggedIn() == False;

    jacSetToken("a.b.c");
    assert __getLocalStorage("jac_token") == "a.b.c";
    assert jacIsLoggedIn() == True;

    jacLogout();
    assert jacIsLoggedIn() == False;
}

test "desktop jacLogout drops the broker session too (DELETE /__jac/session)" {
    # Inside the desktop shell, logout must also clear the broker's on-disk
    # session so a later login can't poll up the old token.
    window.__JAC_DESKTOP__ = True;
    window.__JAC_BROKER__ = "/__jac";
    __setLocalStorage("jac_token", "tok-xyz");

    urls = [];
    methods = [];
    globalThis.fetch = lambda (url: any, opts: any) -> any {
        urls.append(url);
        methods.append(opts["method"] if opts else "GET");
        return Promise.resolve(_resp({"ok": True}));
    };

    jacLogout();

    # Local session is cleared synchronously...
    assert jacIsLoggedIn() == False;
    # ...and a DELETE was issued against the broker session endpoint.
    assert len(urls) == 1 , "logout should issue exactly one broker request";
    assert urls[0].includes("/__jac/session");
    assert methods[0] == "DELETE";

    window.__JAC_DESKTOP__ = False;
    window.__JAC_BROKER__ = "";
    globalThis.fetch = undefined;
}
