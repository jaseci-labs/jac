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
import from jaclang.client.targets.desktop.native.backend_choice { BackendChoice }
import from jaclang.client.targets.desktop.native.profile_store { ProfileStore }


obj _FakeHost {
    has calls: list[any] = [],
        subscribers: list[any] = [],
        closed: int = 0;

    def close_window {
        self.closed += 1;
    }

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


glob _counter: list[int] = [0],
     _servers: list[any] = [];


def _server(
    tmp: str,
    opened: list[any],
    host: _FakeHost,
    choice: (BackendChoice | None) = None,
    profiles: (ProfileStore | None) = None
) -> tuple[TestClient, SessionStore] {
    _counter[0] += 1;
    mod = f"broker_app_{_counter[0]}";
    (Path(tmp) / f"{mod}.jac").write_text(
        "walker:pub Ping {\n    can run with Root entry {\n        report \"pong\";\n    }\n}\n"
    );
    import from jaclang.compiler.driver.application { prepare_application }
    import from jaclang.runtime.prepared { initialize_application }
    initialize_application(
        prepare_application(str(Path(tmp) / f'{mod}.jac'), Jac.get_program(), tmp)
    );
    store = SessionStore(os.path.join(tmp, "data", "session.json"));
    def fake_open(url: str) -> bool {
        opened.append(url);
        return True;
    }
    ext = DesktopBrokerExtension(
        store=store,
        host=host,
        opener=fake_open,
        choice=choice,
        profiles=profiles,
        relaunch_delay_s=0.0
    );
    srv = JacAPIServer(module_name=mod, port=0, base_path=tmp, extensions=[ext]);
    _servers.append(srv);
    srv.load_module();
    srv._ensure_internal_users();
    app = srv.build_app();
    return (TestClient(app, raise_server_exceptions=False), store);
}


def _setup -> tuple[str, list[any], _FakeHost] {
    os.environ["JAC_SCALE_RUNTIME"] = "1";
    tmp = tempfile.mkdtemp(prefix="jac_broker_ext_");
    Jac.set_base_path(tmp);
    Jac.set_context(Jac.create_j_context(user_root=None));
    return (tmp, [], _FakeHost());
}


def _callback_path(opened: list[any]) -> str {
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


test "a backend choice is served as a script and switched through the broker" {
    import time;
    (tmp, opened, host) = _setup();
    try {
        path = os.path.join(tmp, "data", "backend.json");
        backends = {"local": "embedded", "web": "https://web.example"};
        choice = BackendChoice.load(backends, "ask", path);
        (client, _store) = _server(tmp, opened, host, choice);

        script = client.get("/__jac/backend.js", headers=LOOPBACK);
        assert script.status_code == 200 , script.text;
        assert "javascript" in script.headers["content-type"];
        assert script.headers["cache-control"] == "no-store";
        assert 'window.__JAC_BACKEND__={"active": ""' in script.text , script.text;
        assert "__JAC_API_BASE_URL__" not in script.text , script.text;
        info = client.get("/__jac/backend", headers=LOOPBACK).json();
        assert info["active"] == "" and info["default"] == "ask" , info;
        assert info["backends"]
            == [
                {"name": "local", "kind": "embedded", "url": ""},
                {"name": "web", "kind": "remote", "url": "https://web.example"}
            ] , info;

        bad = client.post("/__jac/backend", json={"name": "cloud"}, headers=LOOPBACK);
        assert bad.status_code == 400 and "unknown backend" in bad.text , bad.text;
        assert not os.path.exists(path);

        ok = client.post("/__jac/backend", json={"name": "web"}, headers=LOOPBACK);
        assert ok.json() == {"ok": True, "relaunch": True} , ok.text;
        deadline = time.time() + 5;
        while host.closed == 0 and time.time() < deadline {
            time.sleep(0.02);
        }
        assert host.closed == 1 , "a switch closes the window so the host relaunches";
        assert choice.relaunch;

        again = BackendChoice.load(backends, "ask", path);
        assert again.active == "web" and again.api_base() == "https://web.example";
        assert 'window.__JAC_API_BASE_URL__="https://web.example";' in again.script();
        assert BackendChoice.load(backends, "local", path).active == "web" , "a saved choice beats the default";
        assert BackendChoice.load(backends, "local", path + ".none").active == "local";
        assert BackendChoice.load(
            {"a": "embedded", "b": "https://b.example"}, "ask", path
        ).active
            == "" , "a saved name the build no longer has falls back to the default";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "a single-backend broker serves an empty script and refuses a switch" {
    (tmp, opened, host) = _setup();
    try {
        (client, _store) = _server(tmp, opened, host);
        script = client.get("/__jac/backend.js", headers=LOOPBACK);
        assert script.status_code == 200 and script.text == "" , script.text;
        assert client.get("/__jac/backend", headers=LOOPBACK).json()["backends"] == [];
        refused = client.post("/__jac/backend", json={"name": "web"}, headers=LOOPBACK);
        assert refused.status_code == 404 , refused.text;
        assert host.closed == 0;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


"""Run `/__jac/backend.js` for each pick in turn against one localStorage (under
the bundled JS runtime) and return what the page sees after each load."""
def _run_backend_scripts(
    scripts: list[str], seed: dict[str, str], session_token: str = ""
) -> list[dict[str, any]] {
    import subprocess;
    import from tests.support { js_runtime_or_none }
    bun = js_runtime_or_none();
    if bun is None {
        return [];
    }
    driver = (
        "var store="
        + json.dumps(seed)
        + ";"
        + "globalThis.window={localStorage:{"
        + "getItem:function(k){return k in store?store[k]:null;},"
        + "setItem:function(k,v){store[k]=String(v);},"
        + "removeItem:function(k){delete store[k];}}};"
        + "var calls=[];globalThis.XMLHttpRequest=function(){this.status=0;this.responseText='';};"
        + "XMLHttpRequest.prototype.open=function(m,u,a){calls.push([m,u,a]);};"
        + "XMLHttpRequest.prototype.send=function(){this.status=200;"
        + "this.responseText=JSON.stringify({token:"
        + json.dumps(session_token)
        + "});};"
        + "var seen=[];var scripts="
        + json.dumps(scripts)
        + ";"
        + "for(var i=0;i<scripts.length;i++){(0,eval)(scripts[i]);"
        + "seen.push({store:JSON.parse(JSON.stringify(store)),base:window.__JAC_API_BASE_URL__||'',calls:calls.slice(),profiles:window.__JAC_PROFILES__||null});"
        + "delete window.__JAC_API_BASE_URL__;}"
        + "console.log(JSON.stringify(seen));"
    );
    tmp = tempfile.mkdtemp(prefix="jac_backend_js_");
    try {
        path = os.path.join(tmp, "drive.js");
        Path(path).write_text(driver);
        out = subprocess.run([bun, path], capture_output=True, text=True, timeout=60);
        assert out.returncode == 0 , out.stderr;
        return json.loads(out.stdout.strip().splitlines()[-1]);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "the backend script keeps jac_token the active backend's own" {
    backends = {"local": "embedded", "web": "https://web.example"};
    def script_for(active: str) -> str {
        return BackendChoice(backends=backends, active=active).script();
    }
    def sign_in(token: str) -> str {
        return "window.localStorage.setItem('jac_token'," + json.dumps(token) + ");";
    }
    seen = _run_backend_scripts(
        [
            script_for("local"),
            sign_in("tok-local"),
            script_for("web"),
            sign_in("tok-web"),
            script_for("local"),
            script_for(""),
            script_for("local")
        ],
        {"jac_token": "tok-from-before-the-choice"}
    );
    if not seen {
        return;
    }
    assert seen[0]["store"] == {"jac_backend": "local"} , (
        "a token no backend can be named for is dropped, never sent on",
        seen[0]
    );
    assert seen[2]["store"] == {"jac_token@local": "tok-local", "jac_backend": "web"} , "the web backend never sees the local token";
    assert seen[2]["base"] == "https://web.example";
    assert seen[4]["store"]
        == {
            "jac_token": "tok-local",
            "jac_token@local": "tok-local",
            "jac_token@web": "tok-web",
            "jac_backend": "local"
        } , "switching back restores that backend's token";
    assert seen[5]["store"] == seen[4]["store"] , "before a choice the script touches nothing";
    assert seen[6]["store"] == seen[4]["store"] , "an unchanged pick leaves the token alone";
}


test "concurrent switches save one choice and relaunch once" {
    import threading;
    tmp = tempfile.mkdtemp(prefix="jac_backend_race_");
    try {
        path = os.path.join(tmp, "backend.json");
        choice = BackendChoice.load(
            {"a": "embedded", "b": "https://b.example"}, "ask", path
        );
        errors: list[any] = [];
        def pick {
            try {
                choice.choose("b");
            } except Exception as e {
                errors.append(e);
            }
        }
        threads = [threading.Thread(target=pick) for _ in range(16)];
        for t in threads {
            t.start();
        }
        for t in threads {
            t.join();
        }
        assert errors == [] , errors;
        assert BackendChoice.load(choice.backends, "ask", path).active == "b";
        assert not os.path.exists(path + ".tmp");
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "local profiles are created, picked and signed into through the broker" {
    (tmp, opened, host) = _setup();
    try {
        path = os.path.join(tmp, "data", "profiles.json");
        profiles = ProfileStore.load(path);
        (client, _store) = _server(tmp, opened, host, profiles=profiles);
        srv = _servers[-1];
        info = client.get("/__jac/profiles", headers=LOOPBACK).json();
        assert info == {"enabled": True, "active": "", "profiles": []} , info;
        none = client.post("/__jac/profiles/session", headers=LOOPBACK).json();
        assert none["token"] == "" , "no profile, no session";
        assert client.post(
            "/__jac/profiles", json={"name": "  "}, headers=LOOPBACK
        ).status_code
            == 400;

        work = client.post(
            "/__jac/profiles", json={"name": "Work"}, headers=LOOPBACK
        ).json();
        assert work["ok"] and work["profile"]["name"] == "Work" , work;
        play = client.post(
            "/__jac/profiles", json={"name": "Side project"}, headers=LOOPBACK
        ).json();
        info = client.get("/__jac/profiles", headers=LOOPBACK).json();
        assert info["active"] == play["profile"]["id"] , "creating a profile picks it";
        assert [p["name"] for p in info["profiles"]] == ["Work", "Side project"];
        assert "user_id" not in str(info) , "the page never sees the user behind a profile";

        play_token = client.post("/__jac/profiles/session", headers=LOOPBACK).json()[
            "token"
        ];
        picked = client.post(
            "/__jac/profiles/active",
            json={"id": work["profile"]["id"]},
            headers=LOOPBACK
        );
        assert picked.json()["active"] == work["profile"]["id"] , picked.text;
        work_token = client.post("/__jac/profiles/session", headers=LOOPBACK).json()[
            "token"
        ];
        play_user = srv.user_manager.validate_jwt_token(play_token);
        work_user = srv.user_manager.validate_jwt_token(work_token);
        assert play_user and work_user and play_user != work_user , "each profile is its own user";
        assert srv.user_manager.get_root_id(play_user)
            != srv.user_manager.get_root_id(work_user) , "and its own root";

        assert client.post(
            "/__jac/profiles/active", json={"id": "nope"}, headers=LOOPBACK
        ).status_code
            == 400;
        assert client.post(
            "/__jac/profiles/active", json={"id": ""}, headers=LOOPBACK
        ).json()["active"]
            == "";
        reloaded = ProfileStore.load(path);
        assert reloaded.active == "" and len(reloaded.profiles) == 2 , "profiles persist; leaving keeps them";
        script = client.get("/__jac/backend.js", headers=LOOPBACK).text;
        assert script.startswith("window.__JAC_PROFILES__=") , script;
        assert "/__jac/profiles/session" in script and "eyJ" not in script , "the token never rides in the script body";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "a broker without profiles refuses the profile routes" {
    (tmp, opened, host) = _setup();
    try {
        (client, _store) = _server(tmp, opened, host);
        assert client.get("/__jac/profiles", headers=LOOPBACK).json()["enabled"]
            == False;
        for route in [
            "/__jac/profiles",
            "/__jac/profiles/active",
            "/__jac/profiles/session"
        ] {
            assert client.post(route, json={}, headers=LOOPBACK).status_code
                == 404 , route;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "the profile script signs the page in as the active profile before the bundle runs" {
    store = ProfileStore(path="/unused", active="p1", profiles=[]);
    seen = _run_backend_scripts(
        [store.script()], {"jac_token": "stale"}, session_token="tok-p1"
    );
    if not seen {
        return;
    }
    assert seen[0]["calls"] == [["POST", "/__jac/profiles/session", False]] , "one synchronous, relative POST";
    assert seen[0]["store"]["jac_token"] == "tok-p1" , seen[0];
    assert seen[0]["profiles"] == {"active": "p1", "profiles": []};
    none = _run_backend_scripts(
        [store.script()], {"jac_token": "stale"}, session_token=""
    );
    assert "jac_token" not in none[0]["store"] , "no active profile leaves no session behind";
}


test "a damaged profile list still opens: bad entries are skipped or repaired" {
    tmp = tempfile.mkdtemp(prefix="jac_profiles_bad_");
    try {
        path = os.path.join(tmp, "profiles.json");
        Path(path).write_text(
            json.dumps(
                {
                    "active": "p2",
                    "profiles": [
                        {
                            "id": "p1",
                            "name": "Work",
                            "user_id": "u1",
                            "created": "unknown"
                        },
                        {"id": "p2", "name": "Play", "user_id": "u2", "created": 5},
                        {"id": "p3", "name": "No user"},
                        "not a profile",
                        {"id": "p4", "name": "Side", "user_id": "u4", "created": [1]}
                    ]
                }
            )
        );
        store = ProfileStore.load(path);
        assert [p.id for p in store.profiles] == ["p1", "p2", "p4"] , store.profiles;
        assert [p.created for p in store.profiles] == [0.0, 5.0, 0.0] , "a bad timestamp is repaired, not fatal";
        assert store.active == "p2";
        Path(path).write_text(json.dumps({"active": "p1", "profiles": "oops"}));
        broken = ProfileStore.load(path);
        assert broken.profiles == [] and broken.active == "";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
