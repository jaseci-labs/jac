"""The desktop broker as a server extension.

The desktop host runs the real Jac server on loopback, and everything a native
window needs beyond the app's own endpoints lives under `/__jac/` as one
`ServerExtension`: a health probe, the session token the SSO flow hands back,
the OAuth start and callback pair that walks the login through the system
browser, the event stream the plugin host pushes to, and plugin invocation.
These drive the extension through the same in-process client every other
server test uses, with the browser opener and the plugin host swapped for
recorders, so no webview or display is needed.
"""

import json;
import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from urllib.parse { parse_qs, unquote, urlparse }
import from jaclang { JacRuntime as Jac }
import from jaclang.server.server { JacAPIServer }
import from jaclang.testing.testkit { ServingTestClient as TestClient }
import from jaclang.client.targets.desktop.native.broker_extension {
    DesktopBrokerExtension
}
import from jaclang.client.targets.desktop.native.oauth_broker { SessionStore }


obj _FakeHost {
    has calls: list = [],
        subscribers: list = [];

    def dispatch(req_json: str) -> str {
        self.calls.append(req_json);
        return json.dumps({"ok": True, "data": {"echo": json.loads(req_json)}});
    }

    def subscribe -> any {
        import queue;
        q = queue.Queue();
        self.subscribers.append(q);
        return q;
    }

    def unsubscribe(q: any) {
        if q in self.subscribers {
            self.subscribers.remove(q);
        }
    }
}


glob _counter: list[int] = [0];


def _server(
    tmp: str, opened: list, host: _FakeHost
) -> tuple[TestClient, SessionStore] {
    _counter[0] += 1;
    mod = f"broker_app_{_counter[0]}";
    (Path(tmp) / f"{mod}.jac").write_text(
        "walker:pub Ping {\n    can run with Root entry {\n        report \"pong\";\n    }\n}\n"
    );
    Jac.jac_import(target=mod, base_path=tmp, lng="jac");
    store = SessionStore(os.path.join(tmp, "data", "session.json"));
    def fake_open(url: str) -> bool {
        opened.append(url);
        return True;
    }
    ext = DesktopBrokerExtension(store=store, host=host, opener=fake_open);
    srv = JacAPIServer(module_name=mod, port=0, base_path=tmp, extensions=[ext]);
    srv.load_module();
    srv._ensure_internal_users();
    app = srv.build_app();
    return (TestClient(app, raise_server_exceptions=False), store);
}


def _setup -> tuple[str, list, _FakeHost] {
    os.environ["JAC_SCALE_RUNTIME"] = "1";
    tmp = tempfile.mkdtemp(prefix="jac_broker_ext_");
    Jac.set_base_path(tmp);
    Jac.set_context(Jac.create_j_context(user_root=None));
    return (tmp, [], _FakeHost());
}


def _callback_path(opened: list) -> str {
    parsed = urlparse(opened[-1]);
    cb = parse_qs(parsed.query)["client_callback"][0];
    return urlparse(unquote(cb)).path;
}


glob LOOPBACK: dict[str, str] = {"Host": "127.0.0.1:1"};


test "health and session lifecycle" {
    (tmp, opened, host) = _setup();
    try {
        (client, store) = _server(tmp, opened, host);
        assert client.get("/__jac/health", headers=LOOPBACK).json() == {"ok": True};
        assert client.get("/__jac/session", headers=LOOPBACK).json()["token"] == "";
        posted = client.post(
            "/__jac/session", json={"token": "tok-1"}, headers=LOOPBACK
        );
        assert posted.status_code == 200 , posted.text;
        assert store.read() == "tok-1";
        assert client.get("/__jac/session", headers=LOOPBACK).json()["token"]
            == "tok-1";
        assert client.request("DELETE", "/__jac/session", headers=LOOPBACK).status_code
            == 200;
        assert store.read() == "";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "oauth start opens the browser with a loopback callback and the callback stores the token" {
    (tmp, opened, host) = _setup();
    try {
        (client, store) = _server(tmp, opened, host);
        store.write("stale");
        started = client.get(
            "/__jac/oauth/start?platform=github&api_base=http://localhost:8000",
            headers=LOOPBACK
        );
        assert started.status_code == 200 , started.text;
        assert store.read() == "" , "a fresh flow clears any stale session";
        assert len(opened) == 1 , opened;
        assert opened[0].startswith("http://localhost:8000/sso/github/login?") , opened[
            0
        ];
        cb = _callback_path(opened);
        assert cb.startswith("/__jac/oauth/callback/") , cb;

        done = client.get(cb + "?token=tok-9", headers=LOOPBACK);
        assert done.status_code == 200 and "Signed in" in done.text , done.text;
        assert store.read() == "tok-9";

        replay = client.get(cb + "?token=tok-10", headers=LOOPBACK);
        assert replay.status_code == 400 , "a state nonce is single-use";
        assert store.read() == "tok-9";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "oauth start honors register and rejects an unknown platform" {
    (tmp, opened, host) = _setup();
    try {
        (client, _store) = _server(tmp, opened, host);
        ok = client.get(
            "/__jac/oauth/start?platform=google&operation=register&api_base=http://h",
            headers=LOOPBACK
        );
        assert ok.status_code == 200 , ok.text;
        assert "/sso/google/register?" in opened[-1] , opened[-1];
        bad = client.get(
            "/__jac/oauth/start?platform=myspace&api_base=http://h", headers=LOOPBACK
        );
        assert bad.status_code == 400 , bad.text;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "oauth callback surfaces a provider error and rejects an unknown nonce" {
    (tmp, opened, host) = _setup();
    try {
        (client, store) = _server(tmp, opened, host);
        client.get(
            "/__jac/oauth/start?platform=github&api_base=http://h", headers=LOOPBACK
        );
        cb = _callback_path(opened);
        failed = client.get(cb + "?error=access_denied", headers=LOOPBACK);
        assert failed.status_code == 400 and "access_denied" in failed.text , failed.text;
        assert store.read() == "";
        unknown = client.get(
            "/__jac/oauth/callback/not-a-nonce?token=x", headers=LOOPBACK
        );
        assert unknown.status_code == 400 , unknown.text;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "invoke reaches the plugin host and events stream what it pushes" {
    (tmp, opened, host) = _setup();
    try {
        (client, _store) = _server(tmp, opened, host);
        called = client.post(
            "/__jac/invoke",
            json=["jac.fs", "read_file", {"path": "/x"}],
            headers=LOOPBACK
        );
        assert called.status_code == 200 , called.text;
        assert called.json()["data"]["echo"] == ["jac.fs", "read_file", {"path": "/x"}];
        assert len(host.calls) == 1;

        import from jaclang.client.targets.desktop.native.broker_extension {
            event_stream
        }
        q = host.subscribe();
        q.put(json.dumps({"event": "ping", "payload": {"n": 1}}));
        q.put(None);
        lines = list(event_stream(host, q, keepalive_s=0.1));
        assert lines[0].startswith(b": connected") , lines;
        assert any(b"data: " in ln and b"\"ping\"" in ln for ln in lines) , lines;
        assert q not in host.subscribers , "the stream unsubscribes when it ends";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "the broker refuses a foreign host and a cross-site caller" {
    (tmp, opened, host) = _setup();
    try {
        (client, store) = _server(tmp, opened, host);
        foreign = client.get("/__jac/health", headers={"Host": "evil.example:80"});
        assert foreign.status_code == 403 , foreign.text;
        injected = client.post(
            "/__jac/session",
            json={"token": "stolen"},
            headers={"Host": "127.0.0.1:1", "Origin": "https://evil.example"}
        );
        assert injected.status_code == 403 , injected.text;
        assert store.read() == "";
        fetched = client.post(
            "/__jac/session",
            json={"token": "x"},
            headers={"Host": "127.0.0.1:1", "Sec-Fetch-Site": "cross-site"}
        );
        assert fetched.status_code == 403 , fetched.text;
        # The callback is the one route a foreign origin may land on: the
        # browser arrives there from the identity provider.
        client.get(
            "/__jac/oauth/start?platform=github&api_base=http://h", headers=LOOPBACK
        );
        cb = _callback_path(opened);
        landed = client.get(
            cb + "?token=tok-cb",
            headers={"Host": "127.0.0.1:1", "Sec-Fetch-Site": "cross-site"}
        );
        assert landed.status_code == 200 , landed.text;
        # The app's own endpoints are untouched by the broker's guards.
        pong = client.post(
            "/walker/Ping", json={}, headers={"Host": "evil.example:80"}
        );
        assert pong.status_code == 200 , pong.text;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
