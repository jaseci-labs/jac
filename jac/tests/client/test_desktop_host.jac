"""The desktop host's boot: the real server on loopback, from a sealed image.

`host_boot.boot` is what the generated native host runs inside its embedded
interpreter. It materializes the app image the build shipped beside the
binary (or, in dev, loads the entry straight from the source tree), assembles
the served program with its colocated services, and serves it on 127.0.0.1
with the desktop broker registered as an extension and the built client
bundle as the served dist. The webview then simply navigates to that origin:
walker and function calls are ordinary HTTP like on the web, plugin calls go
to `/__jac/invoke`, and a remote backend only changes where the bundle's
calls are pointed.

These boot the same module the binary boots, in this interpreter, with the
image built by the same `build_jab` the desktop target uses. No webview, no
display, no native build.
"""

import json;
import os;
import shutil;
import tempfile;
import urllib.request;
import from pathlib { Path }
import from jaclang { JacRuntime as Jac }
import from jaclang.project.config { JacConfig, set_config }
import from jaclang.client.targets.desktop.native { host_boot }


glob _APP_SRC: str = (
         "walker:pub greet {\n"
         "    has name: str = \"world\";\n"
         "\n"
         "    can run with Root entry {\n"
         "        report {\"greeting\": f\"hello {self.name}\"};\n"
         "    }\n"
         "}\n"
         "\n"
         "def:pub add(a: int, b: int) -> int {\n"
         "    return a + b;\n"
         "}\n"
     );


def _project -> str {
    tmp = tempfile.mkdtemp(prefix="jac_desktop_host_");
    proj = os.path.join(tmp, "proj");
    os.makedirs(proj, exist_ok=True);
    (Path(proj) / "jac.toml").write_text(
        "[project]\nname = \"hostapp\"\nkind = \"desktop\"\n\n[desktop]\nname = \"hostapp\"\n"
    );
    (Path(proj) / "main.jac").write_text(_APP_SRC);
    return proj;
}


def _app_dir(tmp: str) -> str {
    app_dir = os.path.join(tmp, "app");
    os.makedirs(os.path.join(app_dir, "dist"), exist_ok=True);
    (Path(app_dir) / "dist" / "index.html").write_text(
        "<!doctype html><title>hostapp</title>shell"
    );
    return app_dir;
}


def _get(url: str) -> tuple[int, str] {
    try {
        with urllib.request.urlopen(url, timeout=15) as r {
            return (int(r.status), r.read().decode("utf-8"));
        }
    } except urllib.error.HTTPError as e {
        return (int(e.code), e.read().decode("utf-8"));
    }
}


def _post(url: str, body: dict) -> tuple[int, str] {
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        method="POST",
        headers={"Content-Type": "application/json"}
    );
    try {
        with urllib.request.urlopen(req, timeout=15) as r {
            return (int(r.status), r.read().decode("utf-8"));
        }
    } except urllib.error.HTTPError as e {
        return (int(e.code), e.read().decode("utf-8"));
    }
}


def _config(app_dir: str, program: dict, backend: str = "embedded") -> str {
    return json.dumps(
        {
            "app_name": "hostapp",
            "mode": "webview",
            "app_dir": app_dir,
            "program": program,
            "backend": backend,
            "dispatch": {"timeout_s": 30.0, "max_queue": 128, "debug": False},
            "plugins": {}
        }
    );
}


test "boot serves a sealed image on loopback with the broker and the built dist" {
    os.environ["JAC_SCALE_RUNTIME"] = "1";
    proj = _project();
    tmp = os.path.dirname(proj);
    ctx: any = None;
    try {
        import from jaclang.dist.seal { build_jab }
        app_dir = _app_dir(tmp);
        config = JacConfig.load(Path(proj) / "jac.toml");
        jab = build_jab(config, Path(app_dir) / "app.jab", bake_client=False);
        set_config(None);
        os.environ["JAC_DATA_PATH"] = os.path.join(tmp, "data");
        ctx = host_boot.boot(_config(app_dir, {"jab": str(jab)}));
        assert ctx.port > 0 , ctx.port;
        origin = f"http://127.0.0.1:{ctx.port}";

        (code, body) = _get(f"{origin}/__jac/health");
        assert code == 200 and json.loads(body)["ok"] == True , (code, body);
        (code, body) = _get(f"{origin}/");
        assert code == 200 and "hostapp" in body , (code, body);
        (code, body) = _get(f"{origin}/any/client/route");
        assert code == 200 and "hostapp" in body , (code, body);

        (code, body) = _post(f"{origin}/walker/greet", {"name": "Ada"});
        assert code == 200 , (code, body);
        assert json.loads(body)["data"]["reports"][0]["greeting"] == "hello Ada" , body;
        (code, body) = _post(f"{origin}/function/add", {"a": 2, "b": 3});
        assert code == 200 and json.loads(body)["data"]["result"] == 5 , (code, body);
    } finally {
        if ctx is not None {
            ctx.shutdown();
        }
        os.environ.pop("JAC_DATA_PATH", None);
        set_config(None);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "boot serves a source entry in dev and a remote backend serves no program" {
    os.environ["JAC_SCALE_RUNTIME"] = "1";
    proj = _project();
    tmp = os.path.dirname(proj);
    ctx: any = None;
    try {
        app_dir = _app_dir(tmp);
        os.environ["JAC_DATA_PATH"] = os.path.join(tmp, "data");
        ctx = host_boot.boot(
            _config(app_dir, {"entry": os.path.join(proj, "main.jac")})
        );
        origin = f"http://127.0.0.1:{ctx.port}";
        (code, body) = _post(f"{origin}/walker/greet", {"name": "dev"});
        assert code == 200 and "hello dev" in body , (code, body);
        ctx.shutdown();

        ctx = host_boot.boot(
            _config(
                app_dir,
                {"entry": os.path.join(proj, "main.jac")},
                backend="https://example.invalid"
            )
        );
        origin = f"http://127.0.0.1:{ctx.port}";
        (code, body) = _get(f"{origin}/__jac/health");
        assert code == 200 , (code, body);
        (code, body) = _get(f"{origin}/");
        assert code == 200 and "hostapp" in body , (code, body);
        (code, body) = _post(f"{origin}/walker/greet", {"name": "x"});
        assert code in (404, 405) , (
            f"a remote backend runs no program locally; the bundle calls the remote: {code} {body}"
        );
    } finally {
        if ctx is not None {
            ctx.shutdown();
        }
        os.environ.pop("JAC_DATA_PATH", None);
        set_config(None);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
