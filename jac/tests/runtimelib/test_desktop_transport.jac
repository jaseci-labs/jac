"""Client-runtime transport inside the desktop shell (run under bun via the cl
test runner).

The desktop host serves the app on a loopback origin, so a desktop bundle
talks to its server exactly like a web bundle does: walker and function calls
are HTTP `fetch`es to `{api base}{bridge route}/walker/{name}` and
`.../function/{name}`. There is no second transport for the native window; the
desktop globals (`__JAC_DESKTOP__`, `__JAC_BROKER__`) only tell the SSO flow
that a broker is there. These pin that with `fetch` mocked, so no host is
needed.
"""

import from "@jac/runtime" { __jacCallFunction, __setLocalStorage }

"""A minimal mock `fetch` Response carrying `body` from `.json()`."""
def _resp(body: dict, status: int = 200) -> dict {
    return {
        "ok": status < 300,
        "status": status,
        "json": lambda -> any { return Promise.resolve(body); },
        "text": lambda -> any { return Promise.resolve(JSON.stringify(body)); }
    };
}

"""Pretend we're inside the desktop shell and record every fetch."""
def _install_desktop -> list {
    seen = [];
    globalThis.window = globalThis.window or {};
    globalThis.__JAC_DESKTOP__ = True;
    globalThis.__JAC_BROKER__ = "/__jac";
    globalThis.__JAC_NATIVE__ = undefined;
    globalThis.__jac_invoke = undefined;
    globalThis.fetch = lambda (url: any, init: any) -> any {
        seen.append({"url": url, "init": init});
        if "/function/" in str(url) {
            return Promise.resolve(_resp({"ok": True, "data": {"result": 42}}));
        }
        return Promise.resolve(_resp({"ok": True, "data": {"reports": ["hi"]}}));
    };
    return seen;
}

def _clear_desktop {
    globalThis.__JAC_DESKTOP__ = False;
    globalThis.__JAC_BROKER__ = "";
}

test "a walker spawn in the desktop shell is an HTTP fetch to its route" {
    __setLocalStorage("jac_token", "tok-d");
    seen = _install_desktop();
    out = await __jacSpawn(
        "login", "", {"email": "ada@x.io"}, {"app": "web", "route": "/api/web"}
    );
    assert out["reports"][0] == "hi";
    assert len(seen) == 1 , seen;
    assert str(seen[0]["url"]).endswith("/api/web/walker/login") , seen[0]["url"];
    assert seen[0]["init"]["headers"]["Authorization"] == "Bearer tok-d";
    _clear_desktop();
}

test "a function call in the desktop shell is an HTTP fetch to its route" {
    __setLocalStorage("jac_token", "tok-f");
    seen = _install_desktop();
    out = await __jacCallFunction(
        "add", {"a": 1, "b": 2}, {"app": "web", "route": "/api/web"}
    );
    assert out == 42;
    assert str(seen[0]["url"]).endswith("/api/web/function/add") , seen[0]["url"];
    _clear_desktop();
}
