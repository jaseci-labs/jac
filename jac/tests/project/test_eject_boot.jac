"""Behavioral tests for `jac eject`: boots the generated FastAPI app and drives
it over HTTP. The text-assertion suite in test_eject.jac checks what eject
*writes*; this checks what the written app *does*.

Needs fastapi + httpx (starlette's TestClient), so CI installs those and runs
this file as its own step -- the same shape as test_inprocess_dispatch.jac."""

import json;
import pytest;
import sys;
import types;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.cli.commands { eject }

# The bulk runtime suite runs under a scratch HOME that hides globally-installed
# packages, so these skip there and are really exercised by the dedicated CI step
# that installs them. That step asserts they actually ran, so the skip cannot
# quietly become permanent.
glob _fastapi = pytest.importorskip("fastapi"),
     _httpx = pytest.importorskip("httpx");


"""Materialize a project whose ejected backend is exercised over HTTP: a :pub
walker, a token-gated walker, and a :pub function."""
def _write_bootable_project(src: Path) {
    src.mkdir(parents=True, exist_ok=True);
    (src / "jac.toml").write_text(
        f'[project]\nname = "bootapp"\nversion = "0.1.0"\nentry-point = "main.jac"\n'
    );
    (src / "main.jac").write_text('import from server { Greet }\n');
    (src / "lib").mkdir(exist_ok=True);
    (src / "lib" / "helpers.jac").write_text(
        'def:pub shout(word: str) -> str {\n' + '    return word.upper();\n' + '}\n'
    );
    (src / "server.sv.jac").write_text(
        'import from lib.helpers { shout }\n\n' + 'walker:pub Greet {\n' + '    has name: str,\n' + '        reports: list[str] = [];\n' + '    can g with Root entry {\n' + '        report f"Hello, {self.name}!";\n' + '    }\n' + '}\n\n' + 'walker:pub Loud {\n' + '    has name: str,\n' + '        reports: list[str] = [];\n' + '    can g with Root entry {\n' + '        report shout(self.name);\n' + '    }\n' + '}\n\n' + 'walker Secret {\n' + '    has reports: list[str] = [];\n' + '    can g with Root entry {\n' + '        report "secret";\n' + '    }\n' + '}\n\n' + 'def:pub ping(word: str) -> str {\n' + '    return f"pong:{word}";\n' + '}\n'
    );
}


"""Boot an ejected backend in-process and hand back a fastapi TestClient.

On exit the backend's modules are purged from sys.modules and its dir dropped
from sys.path, so the generic module names an ejected backend uses (`main`,
`server`) cannot leak into the next test.

Scope: the app binds to the live jaclang already in sys.modules, not to the
copy vendored into backend/. So this exercises the emitted app, not the
vendoring -- the clean-venv step in ci.yml covers that."""
obj _EjectedApp {
    has src: Path,
        backend: str = "",
        preexisting: set[str] = set();

    def __enter__ -> any {
        import importlib;
        import from fastapi.testclient { TestClient }
        self.backend = str((self.src / "ejected" / "backend").resolve());
        # import_module resolves sys.modules before sys.path, so a `main` or
        # `server` cached by an earlier test would shadow this backend and we
        # would silently drive the wrong app. Evict the colliding names first.
        # Never `jaclang`: it must stay bound to the live runtime rather than
        # rebinding to the copy vendored into backend/.
        for entry in Path(self.backend).iterdir() {
            if entry.suffix == ".py" {
                name = entry.stem;
            } elif entry.is_dir() {
                name = entry.name;
            } else {
                continue;
            }
            if name == "jaclang" {
                continue;
            }
            # sys.modules keys a package's children by their dotted name, so
            # dropping `lib` alone would leave a stale `lib.helpers` behind for
            # the freshly imported package to bind to.
            for cached in list(sys.modules.keys()) {
                if (cached == name) or cached.startswith(name + ".") {
                    sys.modules.pop(cached, None);
                }
            }
        }
        # Captured after the eviction, so an evicted name counts as new and gets
        # purged again on exit.
        self.preexisting = set(sys.modules.keys());
        sys.path.insert(0, self.backend);
        importlib.invalidate_caches();
        return TestClient(importlib.import_module("main").app);
    }

    def __exit__(_exc_type: any, _exc: any, _tb: any) -> bool {
        for mod_name in list(sys.modules.keys()) {
            if mod_name in self.preexisting {
                continue;
            }
            mod_file = sys.modules[mod_name]?.__file__;
            if mod_file and str(mod_file).startswith(self.backend) {
                del sys.modules[mod_name];
            }
        }
        if self.backend in sys.path {
            sys.path.remove(self.backend);
        }
        return False;
    }
}


"""Register + log in a user against a booted ejected app, returning an auth header."""
def _auth_header(client: any, username: str = "u@example.com") -> dict {
    client.post("/user/register", json={"username": username, "password": "pw123456"});
    res = client.post(
        "/user/login", json={"username": username, "password": "pw123456"}
    );
    assert res.status_code == 200 , f"login failed: {res.status_code} {res.text}";
    token = res.json()["data"]["token"];
    return {"Authorization": f"Bearer {token}"};
}

test "ejected app boots and serves the routes it declares" {
    with TemporaryDirectory() as td {
        src = Path(str(td)) / "bootapp";
        _write_bootable_project(src);
        assert eject.eject(source=str(src), output="", force=False) == 0;
        with _EjectedApp(src=src) as client {
            paths = {route.path for route in client.app.routes};
            assert "/walker/Greet" in paths;
            assert "/walker/Secret" in paths;
            assert "/function/ping" in paths;
            assert "/user/register" in paths;
            assert "/user/login" in paths;
            assert client.get("/__health").status_code == 200;
        }
    }
}


test "ejected app registers and authenticates a user" {
    with TemporaryDirectory() as td {
        src = Path(str(td)) / "bootapp";
        _write_bootable_project(src);
        assert eject.eject(source=str(src), output="", force=False) == 0;
        with _EjectedApp(src=src) as client {
            res = client.post(
                "/user/register", json={"username": "a@b.co", "password": "pw123456"}
            );
            assert res.status_code == 200 , res.text;
            res = client.post(
                "/user/login", json={"username": "a@b.co", "password": "pw123456"}
            );
            assert res.status_code == 200 , res.text;
            assert res.json()["data"]["token"];
            # Wrong password must not mint a token.
            res = client.post(
                "/user/login", json={"username": "a@b.co", "password": "wrong"}
            );
            assert res.status_code == 401;
        }
    }
}


test "ejected :pub walker runs unauthenticated and reports its result" {
    with TemporaryDirectory() as td {
        src = Path(str(td)) / "bootapp";
        _write_bootable_project(src);
        assert eject.eject(source=str(src), output="", force=False) == 0;
        with _EjectedApp(src=src) as client {
            res = client.post("/walker/Greet", json={"name": "Ada"});
            assert res.status_code == 200 , res.text;
            assert "Hello, Ada!" in json.dumps(res.json());
        }
    }
}


test "ejected token-gated walker rejects an anonymous caller and runs for a user" {
    with TemporaryDirectory() as td {
        src = Path(str(td)) / "bootapp";
        _write_bootable_project(src);
        assert eject.eject(source=str(src), output="", force=False) == 0;
        with _EjectedApp(src=src) as client {
            assert client.post("/walker/Secret", json={}).status_code == 401;
            res = client.post("/walker/Secret", json={}, headers=_auth_header(client));
            assert res.status_code == 200 , res.text;
            assert "secret" in json.dumps(res.json());
        }
    }
}


test "ejected :pub function runs and returns its value" {
    with TemporaryDirectory() as td {
        src = Path(str(td)) / "bootapp";
        _write_bootable_project(src);
        assert eject.eject(source=str(src), output="", force=False) == 0;
        with _EjectedApp(src=src) as client {
            res = client.post("/function/ping", json={"word": "hi"});
            assert res.status_code == 200 , res.text;
            assert "pong:hi" in json.dumps(res.json());
        }
    }
}


test "booting one ejected app does not leak its modules into the next" {
    with TemporaryDirectory() as td {
        src = Path(str(td)) / "bootapp";
        _write_bootable_project(src);
        assert eject.eject(source=str(src), output="", force=False) == 0;
        with _EjectedApp(src=src) as client {
            assert client.post(
                "/walker/Greet", json={"name": "one"}
            ).status_code == 200;
        }
        # An ejected backend uses generic module names; a leaked `main`/`server`
        # would silently serve the previous test's app.
        assert "main" not in sys.modules;
        assert "server" not in sys.modules;
        assert str((src / "ejected" / "backend").resolve()) not in sys.path;
    }
}


test "harness observes the ejected app even when a stale `main` is cached" {
    with TemporaryDirectory() as td {
        src = Path(str(td)) / "bootapp";
        _write_bootable_project(src);
        assert eject.eject(source=str(src), output="", force=False) == 0;
        # importlib resolves sys.modules before sys.path, so a `main` left behind
        # by an earlier test would shadow the freshly ejected backend and we would
        # silently drive the wrong app.
        decoy = types.ModuleType("main");
        decoy.app = "not-a-fastapi-app";
        sys.modules["main"] = decoy;
        try {
            with _EjectedApp(src=src) as client {
                res = client.post("/walker/Greet", json={"name": "Ada"});
                assert res.status_code == 200 , res.text;
                assert "Hello, Ada!" in json.dumps(res.json());
            }
        } finally {
            sys.modules.pop("main", None);
        }
    }
}


test "harness observes the ejected app even when a stale submodule is cached" {
    with TemporaryDirectory() as td {
        src = Path(str(td)) / "bootapp";
        _write_bootable_project(src);
        assert eject.eject(source=str(src), output="", force=False) == 0;
        # sys.modules keys a package's children by their dotted name, so evicting
        # only the top-level `lib` would leave a stale `lib.helpers` for the fresh
        # package to bind to.
        decoy = types.ModuleType("lib.helpers");
        decoy.shout = lambda (word: str) -> str { return "STALE"; };
        sys.modules["lib.helpers"] = decoy;
        try {
            with _EjectedApp(src=src) as client {
                res = client.post("/walker/Loud", json={"name": "ada"});
                assert res.status_code == 200 , res.text;
                body = json.dumps(res.json());
                assert "STALE" not in body , f"bound to the stale submodule: {body}";
                assert "ADA" in body , body;
            }
        } finally {
            sys.modules.pop("lib.helpers", None);
        }
    }
}


"""Materialize a project mixing plain HTTP targets with a webhook walker, a
websocket walker, a scheduled walker, and a scheduled function. Only the plain
HTTP targets should reach the ejected app, matching `jac serve`."""
def _write_protocol_project(src: Path) {
    src.mkdir(parents=True, exist_ok=True);
    (src / "jac.toml").write_text(
        f'[project]\nname = "protoapp"\nversion = "0.1.0"\nentry-point = "main.jac"\n'
    );
    (src / "main.jac").write_text('import from server { Greet }\n');
    (src / "server.sv.jac").write_text(
        'import from jaclang.runtimelib.builtin { restspec, schedule, APIProtocol }\n\n' + 'walker:pub Greet {\n' + '    has name: str,\n' + '        reports: list[str] = [];\n' + '    can g with Root entry {\n' + '        report f"Hello, {self.name}!";\n' + '    }\n' + '}\n\n' + '@restspec(protocol=APIProtocol.WEBHOOK)\n' + 'walker:pub Hooky {\n' + '    has reports: list[str] = [];\n' + '    can g with Root entry {\n' + '        report "hooked";\n' + '    }\n' + '}\n\n' + '@restspec(protocol=APIProtocol.WEBSOCKET)\n' + 'walker:pub Socky {\n' + '    has reports: list[str] = [];\n' + '    can g with Root entry {\n' + '        report "socked";\n' + '    }\n' + '}\n\n' + '@schedule(interval=1)\n' + 'walker:pub Cronny {\n' + '    has reports: list[str] = [];\n' + '    can g with Root entry {\n' + '        report "cronned";\n' + '    }\n' + '}\n\n' + 'def:pub ping(word: str) -> str {\n' + '    return f"pong:{word}";\n' + '}\n\n' + '@schedule(interval=1)\n' + 'def:pub tick() -> str {\n' + '    return "tock";\n' + '}\n'
    );
}


test "ejected app mounts only the targets jac serve would, filtering protocol/schedule" {
    with TemporaryDirectory() as td {
        src = Path(str(td)) / "protoapp";
        _write_protocol_project(src);
        assert eject.eject(source=str(src), output="", force=False) == 0;
        with _EjectedApp(src=src) as client {
            paths = {route.path for route in client.app.routes};
            assert "/walker/Greet" in paths;
            assert "/function/ping" in paths;
            assert "/walker/Hooky" not in paths;
            assert "/walker/Socky" not in paths;
            assert "/walker/Cronny" not in paths;
            assert "/function/tick" not in paths;
        }
    }
}


test "ejected app rejects a filtered walker at runtime and still runs the plain one" {
    with TemporaryDirectory() as td {
        src = Path(str(td)) / "protoapp";
        _write_protocol_project(src);
        assert eject.eject(source=str(src), output="", force=False) == 0;
        with _EjectedApp(src=src) as client {
            res = client.post("/walker/Greet", json={"name": "Ada"});
            assert res.status_code == 200 , res.text;
            assert "Hello, Ada!" in json.dumps(res.json());
            assert client.post("/walker/Hooky", json={}).status_code == 404;
            assert client.post("/walker/Cronny", json={}).status_code == 404;
        }
    }
}


test "ejected /__health lists only the HTTP-exposed targets" {
    with TemporaryDirectory() as td {
        src = Path(str(td)) / "protoapp";
        _write_protocol_project(src);
        assert eject.eject(source=str(src), output="", force=False) == 0;
        with _EjectedApp(src=src) as client {
            meta = client.get("/__health").json();
            assert meta["walkers"] == ["Greet"] , meta;
            assert meta["functions"] == ["ping"] , meta;
        }
    }
}
