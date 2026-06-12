"""Headless tests for the loopback OAuth + session broker.

These need no webview, no display, and no real OAuth provider: they start a real
``TCPServer`` with the broker handler on an ephemeral loopback port, swap the
browser opener for a recorder, and drive the routes over HTTP. This verifies the
exact code path the native host runs at runtime (the host execs the same broker
module in its embedded CPython).
"""

import os;
import json;
import socketserver;
import threading;
import tempfile;
import from urllib.request { Request, urlopen }
import from urllib.error { HTTPError }
import from urllib.parse { parse_qs, unquote, urlparse }
import from jac_desktop.native.oauth_broker {
    SessionStore,
    build_sso_login_url,
    make_handler
}

"""Start a broker server in a temp dir. Returns (srv, port, store, opened, web_dir)."""
def _start_server -> tuple {
    root_dir = tempfile.mkdtemp();
    web_dir = os.path.join(root_dir, "web");
    os.makedirs(web_dir, exist_ok=True);
    # Store lives OUTSIDE the served dir so the token is never web-readable.
    store = SessionStore(os.path.join(root_dir, "data", "session.json"));
    opened: list = [];
    def fake_open(url: str) -> bool {
        opened.append(url);
        return True;
    }
    handler = make_handler(web_dir, store, fake_open);
    srv = socketserver.TCPServer(("127.0.0.1", 0), handler);
    port = srv.server_address[1];
    t = threading.Thread(target=srv.serve_forever, daemon=True);
    t.start();
    return (srv, port, store, opened, web_dir);
}

"""HTTP request helper that also returns the status on 4xx/5xx (no raise)."""
def _req(
    port: int,
    path: str,
    method: str = "GET",
    body: dict | None = None,
    extra_headers: dict | None = None
) -> tuple {
    url = f"http://127.0.0.1:{port}{path}";
    data = json.dumps(body).encode() if body is not None else None;
    headers = {"Content-Type": "application/json"} if data is not None else {};
    if extra_headers {
        headers.update(extra_headers);
    }
    req = Request(url, data=data, method=method, headers=headers);
    try {
        with urlopen(req) as r {
            return (r.status, r.read().decode());
        }
    } except HTTPError as e {
        return (e.code, e.read().decode());
    }
}

"""Run /oauth/start and return the broker callback path (carrying its nonce).

The single-use `state` nonce is broker-internal; tests recover it the same way
the real flow does -- from the `client_callback` the broker hands the browser.
"""
def _start_flow(port: int, opened: list, platform: str = "github") -> str {
    (s, _b) = _req(
        port, f"/__jac/oauth/start?platform={platform}&api_base=http://localhost:8000"
    );
    assert s == 200;
    cb_enc = parse_qs(urlparse(opened[-1]).query)["client_callback"][0];
    return urlparse(unquote(cb_enc)).path;
}

# ============================================================================
# Pure-function: SSO login URL construction
# ============================================================================
"""build_sso_login_url embeds the loopback callback and rejects bad platforms."""
test "broker builds sso login url with encoded callback" {
    cb = "http://127.0.0.1:5123/__jac/oauth/callback";
    url = build_sso_login_url("http://localhost:8000/", "google", cb);
    # Trailing slash trimmed; platform path correct; callback percent-encoded.
    assert url.startswith("http://localhost:8000/sso/google/login?client_callback=");
    assert "127.0.0.1%3A5123" in url , f"callback not encoded in {url}";
    assert " " not in url;

    raised = False;
    try {
        build_sso_login_url("http://localhost:8000", "evil", cb);
    } except ValueError {
        raised = True;
    }
    assert raised , "unknown platform must raise ValueError";
}

"""operation selects the SSO path (login|register) and rejects anything else."""
test "broker builds sso url for register and rejects bad operation" {
    cb = "http://127.0.0.1:5123/__jac/oauth/callback";
    url = build_sso_login_url("http://localhost:8000", "google", cb, "register");
    assert url.startswith("http://localhost:8000/sso/google/register?client_callback=");

    # Default stays login, so existing callers that omit operation are unchanged.
    url2 = build_sso_login_url("http://localhost:8000", "google", cb);
    assert "/sso/google/login?" in url2;

    raised = False;
    try {
        build_sso_login_url("http://localhost:8000", "google", cb, "delete_account");
    } except ValueError {
        raised = True;
    }
    assert raised , "unknown operation must raise ValueError";
}

# ============================================================================
# Session store lifecycle over HTTP (the restart-persistence mechanism)
# ============================================================================
"""GET starts empty; POST persists; GET reads back; DELETE clears."""
test "broker session get post delete lifecycle" {
    (srv, port, store, _opened, _web) = _start_server();
    try {
        (s0, b0) = _req(port, "/__jac/session");
        assert s0 == 200;
        assert json.loads(b0)["token"] == "" , "session should start empty";

        (s1, _b1) = _req(port, "/__jac/session", "POST", {"token": "tok-abc"});
        assert s1 == 200;
        # Persisted to disk (survives a process/origin change == restart).
        assert store.read() == "tok-abc";

        (s2, b2) = _req(port, "/__jac/session");
        assert json.loads(b2)["token"] == "tok-abc";

        (s3, _b3) = _req(port, "/__jac/session", "DELETE");
        assert s3 == 200;
        (s4, b4) = _req(port, "/__jac/session");
        assert json.loads(b4)["token"] == "" , "session should be cleared";
    } finally {
        srv.shutdown();
        srv.server_close();
    }
}

# ============================================================================
# OAuth start -> opens system browser at a loopback-callback login URL
# ============================================================================
"""/oauth/start opens the browser with client_callback pointing back at us."""
test "broker oauth start opens browser with loopback callback" {
    (srv, port, _store, opened, _web) = _start_server();
    try {
        (s, b) = _req(
            port, "/__jac/oauth/start?platform=github&api_base=http://localhost:8000"
        );
        assert s == 200;
        assert json.loads(b)["ok"] == True;
        assert len(opened) == 1 , "exactly one browser open expected";
        url = opened[0];
        assert url.startswith(
            "http://localhost:8000/sso/github/login?client_callback="
        );
        # The callback must point back at THIS server's loopback port + broker route.
        expected_cb = f"127.0.0.1%3A{port}%2F__jac%2Foauth%2Fcallback";
        assert expected_cb in url , f"callback not pointing at us: {url}";
    } finally {
        srv.shutdown();
        srv.server_close();
    }
}

"""/oauth/start?operation=register opens the register URL; a bad op -> 400."""
test "broker oauth start honors operation register" {
    (srv, port, _store, opened, _web) = _start_server();
    try {
        (s, _b) = _req(
            port,
            "/__jac/oauth/start?platform=github&api_base=http://localhost:8000&operation=register"
        );
        assert s == 200;
        assert opened[0].startswith(
            "http://localhost:8000/sso/github/register?client_callback="
        );

        (s2, _b2) = _req(
            port,
            "/__jac/oauth/start?platform=github&api_base=http://localhost:8000&operation=evil"
        );
        assert s2 == 400;
        assert len(opened) == 1 , "a bad operation must not open a browser";
    } finally {
        srv.shutdown();
        srv.server_close();
    }
}

"""An unknown platform is rejected with 400 and never opens a browser."""
test "broker oauth start rejects unknown platform" {
    (srv, port, _store, opened, _web) = _start_server();
    try {
        (s, _b) = _req(
            port, "/__jac/oauth/start?platform=evil&api_base=http://localhost:8000"
        );
        assert s == 400;
        assert len(opened) == 0 , "no browser should open for a bad platform";
    } finally {
        srv.shutdown();
        srv.server_close();
    }
}

# ============================================================================
# OAuth callback -> stores the token the provider round-tripped back
# ============================================================================
"""A callback carrying a valid state nonce stores the token; replay is rejected."""
test "broker oauth callback stores token for a valid state nonce" {
    (srv, port, store, opened, _web) = _start_server();
    try {
        cb_path = _start_flow(port, opened);
        (s, b) = _req(port, f"{cb_path}?token=tok-xyz");
        assert s == 200;
        assert "Signed in" in b;
        assert store.read() == "tok-xyz";

        # The nonce is single-use: replaying the same callback URL is rejected
        # and cannot overwrite the stored token.
        store.clear();
        (s2, _b2) = _req(port, f"{cb_path}?token=tok-replay");
        assert s2 == 400;
        assert store.read() == "" , "a replayed nonce must not store a token";
    } finally {
        srv.shutdown();
        srv.server_close();
    }
}

"""A callback with no/unknown state nonce cannot inject a token (#6485 review)."""
test "broker oauth callback rejects an unknown or missing state nonce" {
    (srv, port, store, _opened, _web) = _start_server();
    try {
        # No flow started -> no nonce is valid; an attacker-supplied token is
        # dropped on the floor.
        (s, _b) = _req(port, "/__jac/oauth/callback/deadbeef?token=tok-evil");
        assert s == 400;
        assert store.read() == "";

        # The bare callback (no nonce segment) is rejected the same way.
        (s2, _b2) = _req(port, "/__jac/oauth/callback?token=tok-evil");
        assert s2 == 400;
        assert store.read() == "";
    } finally {
        srv.shutdown();
        srv.server_close();
    }
}

"""A provider error on a valid nonce surfaces the error and stores nothing."""
test "broker oauth callback surfaces provider error for a valid nonce" {
    (srv, port, store, opened, _web) = _start_server();
    try {
        cb_path = _start_flow(port, opened);
        (se, be) = _req(port, f"{cb_path}?error=access_denied");
        assert se == 400;
        assert "access_denied" in be;
        assert store.read() == "";
    } finally {
        srv.shutdown();
        srv.server_close();
    }
}

# ============================================================================
# Freshness + Host pinning (#6485 review)
# ============================================================================
"""Starting a new flow drops any stale token so the poller can't read it."""
test "broker oauth start clears any stale session token" {
    (srv, port, store, opened, _web) = _start_server();
    try {
        store.write("stale-token");
        assert store.read() == "stale-token";
        _start_flow(port, opened);
        assert store.read() == "" , "oauth/start must clear a stale token";
    } finally {
        srv.shutdown();
        srv.server_close();
    }
}

"""A non-loopback Host header is rejected (DNS-rebinding defense)."""
test "broker rejects requests with a non-loopback Host header" {
    (srv, port, store, _opened, _web) = _start_server();
    try {
        store.write("secret-token");
        # A DNS-rebinding page reaches us with its own hostname in `Host`; pinning
        # to loopback rejects it before it can read the token.
        (s, _b) = _req(
            port, "/__jac/session", "GET", None, {"Host": "evil.example.com"}
        );
        assert s == 403 , "a non-loopback Host must be rejected";

        # A normal loopback Host still works.
        (s2, b2) = _req(
            port, "/__jac/session", "GET", None, {"Host": f"127.0.0.1:{port}"}
        );
        assert s2 == 200;
        assert json.loads(b2)["token"] == "secret-token";
    } finally {
        srv.shutdown();
        srv.server_close();
    }
}

# ============================================================================
# Static passthrough: non-broker paths still serve the app bundle
# ============================================================================
"""Paths outside the broker prefix serve files from the dist directory."""
test "broker serves static files for non broker paths" {
    (srv, port, _store, _opened, web) = _start_server();
    try {
        with open(os.path.join(web, "index.html"), "w") as f {
            f.write("<h1>hello-desktop</h1>");
        }
        (s, b) = _req(port, "/index.html");
        assert s == 200;
        assert "hello-desktop" in b;
    } finally {
        srv.shutdown();
        srv.server_close();
    }
}
