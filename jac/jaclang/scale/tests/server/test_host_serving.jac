"""A program hosted by the one server assembly, outside the CLI.

A desktop host, a test harness, an embedding process: each wants the same
server `jac run --serve` assembles, without the CLI around it. Three things the
assembly must offer for that, pinned here against a two-app workspace:

- `serve_background()` runs the transport on a background thread, binding
  127.0.0.1 with an ephemeral port and reporting the bound port, and the
  returned callable stops it;
- `client_dist` in the serve settings names the client bundle the server
  serves, so a host that built its own bundle serves it from wherever it put
  it, index and assets, with the SPA fallback;
- `prepare_inprocess_runtime` colocates the workspace's service apps the way
  the CLI serve flow does, so an in-process server answers `/api/<service>/...`.
"""

import json;
import os;
import shutil;
import sys;
import tempfile;
import urllib.request;
import from pathlib { Path }
import from jaclang { JacRuntime as Jac }
import from jaclang.project.config { set_config }
import from jaclang.server { sv_client }
import from jaclang.server.server { JacAPIServer }
import from jaclang.server.settings { ServeSettings }


glob _TOML: str = (
         "[project]\n"
         "name = \"hosted\"\n"
         "default-app = \"web\"\n"
         "\n"
         "[apps.web]\n"
         "kind = \"web-app\"\n"
         "path = \"web\"\n"
         "\n"
         "[apps.feed]\n"
         "kind = \"service\"\n"
         "entry-point = \"core/feed.jac\"\n"
     ),
     _WEB_SRC: str = (
         "walker:pub Hello {\n"
         "    has who: str = \"world\";\n"
         "\n"
         "    can run with Root entry {\n"
         "        report \"hello \" + self.who;\n"
         "    }\n"
         "}\n"
     ),
     _FEED_SRC: str = (
         "walker:pub Latest {\n"
         "    can run with Root entry {\n"
         "        report [\"a\", \"b\"];\n"
         "    }\n"
         "}\n"
     );


def _workspace -> str {
    tmp = tempfile.mkdtemp(prefix="jac_host_serving_");
    os.makedirs(os.path.join(tmp, "web"), exist_ok=True);
    os.makedirs(os.path.join(tmp, "core"), exist_ok=True);
    (Path(tmp) / "jac.toml").write_text(_TOML);
    (Path(tmp) / "web" / "main.jac").write_text(_WEB_SRC);
    (Path(tmp) / "core" / "feed.jac").write_text(_FEED_SRC);
    return tmp;
}


def _dist(tmp: str) -> str {
    dist = os.path.join(tmp, "bundle");
    os.makedirs(os.path.join(dist, "assets"), exist_ok=True);
    (Path(dist) / "index.html").write_text("<!doctype html><title>hosted</title>ok");
    (Path(dist) / "assets" / "app.js").write_text("console.log('hosted');");
    return dist;
}


def _get(url: str) -> tuple[int, str] {
    try {
        with urllib.request.urlopen(url, timeout=10) as r {
            return (int(r.status), r.read().decode("utf-8"));
        }
    } except urllib.error.HTTPError as e {
        return (int(e.code), e.read().decode("utf-8"));
    }
}


def _post(url: str, body: dict) -> tuple[int, str] {
    data = json.dumps(body).encode("utf-8");
    req = urllib.request.Request(
        url, data=data, method="POST", headers={"Content-Type": "application/json"}
    );
    try {
        with urllib.request.urlopen(req, timeout=10) as r {
            return (int(r.status), r.read().decode("utf-8"));
        }
    } except urllib.error.HTTPError as e {
        return (int(e.code), e.read().decode("utf-8"));
    }
}


def _load(tmp: str, mod: str, base: str) {
    if mod in Jac.loaded_modules {
        del Jac.loaded_modules[mod];
    }
    if mod in sys.modules {
        del sys.modules[mod];
    }
    Jac.jac_import(target=mod, base_path=base, lng="jac");
}


def _reset(tmp: str) {
    sv_client.set_consumer_app("");
    sv_client.clear_local_providers();
    set_config(None);
    Jac.set_full_target_path("");
    shutil.rmtree(tmp, ignore_errors=True);
}


test "serve_background binds loopback on an ephemeral port and serves a client_dist" {
    os.environ["JAC_SCALE_RUNTIME"] = "1";
    tmp = _workspace();
    Jac.set_base_path(tmp);
    Jac.set_context(Jac.create_j_context(user_root=None));
    stop: any = None;
    try {
        set_config(None);
        Jac.set_full_target_path(os.path.join(tmp, "web", "main.jac"));
        sv_client.set_consumer_app("web");
        base = os.path.join(tmp, "web");
        _load(tmp, "main", base);
        settings = ServeSettings.load(
            base, {"host": "127.0.0.1", "port": 0, "client_dist": _dist(tmp)}
        );
        assert settings.port == 0 , "an explicit port 0 means ephemeral, not the config port";
        srv = JacAPIServer(
            module_name="main", port=0, base_path=base, settings=settings, extensions=[]
        );
        seen: list[int] = [];
        stop = srv.serve_background(on_ready=lambda (p: int) { seen.append(p); });
        assert seen and seen[0] > 0 , seen;
        assert srv.port == seen[0] , (srv.port, seen);
        origin = f"http://127.0.0.1:{seen[0]}";

        (code, body) = _get(f"{origin}/healthz/live");
        assert code == 200 , (code, body);

        (code, body) = _get(f"{origin}/");
        assert code == 200 and "hosted" in body , (code, body);
        (code, body) = _get(f"{origin}/assets/app.js");
        assert code == 200 and "hosted" in body , (code, body);
        (code, body) = _get(f"{origin}/some/client/route");
        assert code == 200 and "hosted" in body , (
            f"the SPA fallback must serve the client_dist index: {code} {body}"
        );

        (code, body) = _post(f"{origin}/walker/Hello", {"who": "loopback"});
        assert code == 200 and "hello loopback" in body , (code, body);
        (code, body) = _post(f"{origin}/api/web/walker/Hello", {"who": "routed"});
        assert code == 200 and "hello routed" in body , (code, body);
    } finally {
        if stop is not None {
            stop();
        }
        _reset(tmp);
    }
}


test "prepare_inprocess_runtime colocates the workspace's service apps" {
    os.environ["JAC_SCALE_RUNTIME"] = "1";
    tmp = _workspace();
    Jac.set_base_path(tmp);
    Jac.set_context(Jac.create_j_context(user_root=None));
    runtime: any = None;
    try {
        set_config(None);
        Jac.set_full_target_path(os.path.join(tmp, "web", "main.jac"));
        import from jaclang.scale.server.inprocess { prepare_inprocess_runtime }
        runtime = prepare_inprocess_runtime(
            os.path.join(tmp, "web", "main.jac"),
            os.path.join(tmp, "data"),
            endpoint_profile="desktop",
            setup_background_services=False
        );
        client = runtime.client;
        listing = client.get("/api/feed/walkers");
        assert listing.status_code == 200 , (
            f"the colocated service must be mounted: {listing.status_code} {listing.text}"
        );
        assert "Latest" in listing.text , listing.text;
        spawned = client.post("/api/feed/walker/Latest", json={});
        assert spawned.status_code == 200 and "\"a\"" in spawned.text , spawned.text;
        mine = client.post("/api/web/walker/Hello", json={"who": "self"});
        assert mine.status_code == 200 and "hello self" in mine.text , mine.text;
    } finally {
        if runtime is not None {
            runtime.close();
        }
        _reset(tmp);
    }
}
