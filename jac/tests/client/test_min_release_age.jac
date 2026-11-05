"""Client dependency installs skip versions newer than [client.npm] min_release_age,
checked against a local registry holding one old and one just-published version."""

import base64;
import hashlib;
import io;
import json;
import os;
import tarfile;
import tempfile;
import threading;
import from datetime { datetime, timezone }
import from http.server { BaseHTTPRequestHandler, ThreadingHTTPServer }
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.client.vite_bundler { ViteBundler, release_age_seconds }
import from jaclang.client.client_bundle { ClientBundleError }

glob PKG: str = "jac-age-probe",
     ROUTES: dict[str, bytes] = {};


class _Registry(BaseHTTPRequestHandler) {
    def do_GET(self: _Registry) {
        body: (bytes | None) = ROUTES.get(self.path.split("?")[0]);
        if body is None {
            self.send_response(404);
            self.send_header("Content-Length", "0");
            self.end_headers();
            return;
        }
        self.send_response(200);
        self.send_header("Content-Type", "application/json");
        self.send_header("Content-Length", str(len(body)));
        self.end_headers();
        self.wfile.write(body);
    }

    def log_message(self: _Registry, fmt: str, *args: any) -> None {
        return;
    }
}


def _tarball(version: str) -> bytes {
    manifest = json.dumps({"name": PKG, "version": version}).encode();
    buf = io.BytesIO();
    with tarfile.open(fileobj=buf, mode="w:gz") as tar {
        info = tarfile.TarInfo("package/package.json");
        info.size = len(manifest);
        tar.addfile(info, io.BytesIO(manifest));
    }
    return buf.getvalue();
}


def _start_registry -> tuple[any, str] {
    srv = ThreadingHTTPServer(("127.0.0.1", 0), _Registry);
    url = f"http://127.0.0.1:{srv.server_address[1]}";
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z");
    times = {
        "created": "2020-01-01T00:00:00.000Z",
        "modified": now,
        "1.0.0": "2020-01-01T00:00:00.000Z",
        "1.1.0": now
    };
    ROUTES.clear();
    versions: dict[str, any] = {};
    for version in ["1.0.0", "1.1.0"] {
        tgz = _tarball(version);
        path = f"/{PKG}/-/{PKG}-{version}.tgz";
        ROUTES[path] = tgz;
        digest = base64.b64encode(hashlib.sha512(tgz).digest()).decode();
        versions[version] = {
            "name": PKG,
            "version": version,
            "dist": {"tarball": url + path, "integrity": "sha512-" + digest}
        };
    }
    ROUTES[f"/{PKG}"] = json.dumps(
        {
            "name": PKG,
            "dist-tags": {"latest": "1.1.0"},
            "versions": versions,
            "time": times
        }
    ).encode();
    threading.Thread(target=srv.serve_forever, daemon=True).start();
    return (srv, url);
}


def _install(spec: str, npm_toml: str = "") -> str {
    (srv, url) = _start_registry();
    try {
        with tempfile.TemporaryDirectory() as tmp {
            base = Path(tmp);
            (base / "jac.toml").write_text(
                "[project]\nname = \"app\"\nversion = \"0.1.0\"\n\n"
                    + f"[client.npm]\n{npm_toml}\n"
            );
            build_dir = base / "client";
            (build_dir / "configs").mkdir(parents=True);
            (build_dir / "configs" / "package.json").write_text(
                json.dumps({"name": "app", "dependencies": {PKG: spec}})
            );
            (build_dir / "configs" / ".npmrc").write_text(f"registry={url}/\n");
            with patch.dict(
                os.environ, {"BUN_INSTALL_CACHE_DIR": str(base / "cache")}
            ) {
                ViteBundler(base).install_packages(
                    install_dir=build_dir, force=True, capture_output=True
                );
            }
            assert not (build_dir / "bunfig.toml").exists() , "bunfig.toml left behind";
            installed = build_dir / "node_modules" / PKG / "package.json";
            return json.loads(installed.read_text())["version"];
        }
    } finally {
        srv.shutdown();
    }
}


test "a version published today is skipped for the newest older one" {
    assert _install("^1.0.0") == "1.0.0";
}


test "min_release_age = 0 turns the limit off" {
    assert _install("^1.0.0", "min_release_age = 0") == "1.1.0";
}


test "an excluded package installs its newest version" {
    assert _install("^1.0.0", f"min_release_age_excludes = [\"{PKG}\"]") == "1.1.0";
}


test "pinning a version that is too new fails and names the setting" {
    message = "";
    try {
        _install("1.1.0");
    } except ClientBundleError as e {
        message = str(e);
    }
    assert "minimum-release-age" in message , message;
    assert "min_release_age_excludes" in message , message;
}


test "min_release_age takes seconds or a number with a unit" {
    assert release_age_seconds(90) == 90;
    assert release_age_seconds("90") == 90;
    assert release_age_seconds("12h") == 43200;
    assert release_age_seconds("3d") == 259200;
    message = "";
    try {
        release_age_seconds("soon");
    } except ClientBundleError as e {
        message = str(e);
    }
    assert "min_release_age" in message , message;
}
