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
def _req(port: int, path: str, method: str = "GET", body: dict | None = None) -> tuple {
    url = f"http://127.0.0.1:{port}{path}";
    data = json.dumps(body).encode() if body is not None else None;
    headers = {"Content-Type": "application/json"} if data is not None else {};
    req = Request(url, data=data, method=method, headers=headers);
    try {
        with urlopen(req) as r {
            return (r.status, r.read().decode());
        }
    } except HTTPError as e {
        return (e.code, e.read().decode());
    }
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
"""/oauth/callback?token=... stores the token; the UI then reads it via /session."""
test "broker oauth callback stores token" {
    (srv, port, store, _opened, _web) = _start_server();
    try {
        (s, b) = _req(port, "/__jac/oauth/callback?token=tok-xyz");
        assert s == 200;
        assert "Signed in" in b;
        assert store.read() == "tok-xyz";

        (se, be) = _req(port, "/__jac/oauth/callback?error=access_denied");
        assert se == 400;
        assert "access_denied" in be;
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
