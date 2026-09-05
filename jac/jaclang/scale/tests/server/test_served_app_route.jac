"""The served app answers at its own route.

Every app's bridge surface lives at its route (`[apps.<name>] route`, default
`/api/<name>`): a client compiled against another app spawns that app's
walkers at `{base}{route}/walker/{name}`. Colocated service apps were mounted
that way, but the app the server itself serves only answered at the root, so a
client bundle built for a sibling app -- a desktop shell pointed at the site's
server, a mobile app against a web-app's walkers -- had nowhere to go. The
served app is now mounted under its route too, alongside the root endpoints
it always had. A project without apps has no route to speak of and stays as
it was."""

import os;
import shutil;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang { JacRuntime as Jac }
import from jaclang.project.config { set_config }
import from jaclang.server { sv_client }
import from jaclang.server.server { JacAPIServer }
import from jaclang.testing.testkit { ServingTestClient as TestClient }


glob _WEB_SRC: str = (
         "walker:pub Hello {\n"
         "    has who: str = \"world\";\n"
         "\n"
         "    can run with Root entry {\n"
         "        report \"hello \" + self.who;\n"
         "    }\n"
         "}\n"
         "\n"
         "def:pub shout(text: str) -> str {\n"
         "    return text.upper();\n"
         "}\n"
     ),
     _TOML: str = (
         "[project]\n"
         "name = \"routed\"\n"
         "default-app = \"web\"\n"
         "\n"
         "[apps.web]\n"
         "kind = \"web-app\"\n"
         "path = \"web\"\n"
         "\n"
         "[apps.shell]\n"
         "kind = \"desktop\"\n"
         "path = \"shell\"\n"
     );


def _serve(tmp: str, mod: str, base: str) -> tuple[TestClient, JacAPIServer] {
    if mod in Jac.loaded_modules {
        del Jac.loaded_modules[mod];
    }
    if mod in sys.modules {
        del sys.modules[mod];
    }
    Jac.jac_import(target=mod, base_path=base, lng="jac");
    srv = JacAPIServer(module_name=mod, port=0, base_path=base, extensions=[]);
    srv.load_module();
    srv._ensure_internal_users();
    app = srv.build_app();
    return (TestClient(app, raise_server_exceptions=False), srv);
}


def _workspace -> str {
    tmp = tempfile.mkdtemp(prefix="jac_self_route_");
    os.makedirs(os.path.join(tmp, "web"), exist_ok=True);
    os.makedirs(os.path.join(tmp, "shell"), exist_ok=True);
    (Path(tmp) / "jac.toml").write_text(_TOML);
    (Path(tmp) / "web" / "main.jac").write_text(_WEB_SRC);
    (Path(tmp) / "shell" / "main.jac").write_text(
        "def:pub app -> JsxElement {\n    return <div>shell</div>;\n}\n"
    );
    return tmp;
}


def _reset(tmp: str) {
    sv_client.set_consumer_app("");
    sv_client.clear_local_providers();
    set_config(None);
    Jac.set_full_target_path("");
    shutil.rmtree(tmp, ignore_errors=True);
}


test "the served workspace app is mounted under its own route" {
    os.environ["JAC_SCALE_RUNTIME"] = "1";
    tmp = _workspace();
    Jac.set_base_path(tmp);
    Jac.set_context(Jac.create_j_context(user_root=None));
    try {
        set_config(None);
        Jac.set_full_target_path(os.path.join(tmp, "web", "main.jac"));
        sv_client.set_consumer_app("web");
        (client, _srv) = _serve(tmp, "main", os.path.join(tmp, "web"));

        root_listing = client.get("/walkers");
        assert root_listing.status_code == 200 , root_listing.text;

        listing = client.get("/api/web/walkers");
        assert listing.status_code == 200 , (
            f"the served app must answer at its route: {listing.status_code} {listing.text}"
        );
        assert "Hello" in listing.text , listing.text;

        spawned = client.post("/api/web/walker/Hello", json={"who": "route"});
        assert spawned.status_code == 200 , spawned.text;
        assert "hello route" in spawned.text , spawned.text;

        called = client.post("/api/web/function/shout", json={"text": "hi"});
        assert called.status_code == 200 , called.text;
        assert "HI" in called.text , called.text;
    } finally {
        _reset(tmp);
    }
}


test "a project without apps has no route of its own" {
    os.environ["JAC_SCALE_RUNTIME"] = "1";
    tmp = tempfile.mkdtemp(prefix="jac_self_route_bare_");
    Jac.set_base_path(tmp);
    Jac.set_context(Jac.create_j_context(user_root=None));
    try {
        (Path(tmp) / "bare.jac").write_text(_WEB_SRC);
        set_config(None);
        sv_client.set_consumer_app("");
        (client, _srv) = _serve(tmp, "bare", tmp);
        assert client.get("/walkers").status_code == 200;
        assert client.get("/api/bare/walkers").status_code == 404;
    } finally {
        _reset(tmp);
    }
}
