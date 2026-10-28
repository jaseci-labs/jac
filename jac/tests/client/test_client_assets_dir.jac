"""The client assets directory: the app's own assets/ by default, or one
shared directory named by [client.assets] dir, served under /static/assets
and resolved from source with nested paths intact."""

import os;
import socket;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from types { SimpleNamespace }
import from jaclang.client.config_loader { JacClientConfig }
import from jaclang.runtime.runtime { JacRuntime as Jac }
import from jaclang.server.endpoints.pages { register_page_endpoints }
import from jaclang.server.serving.app { ServingApp }
import from jaclang.server.serving.server { ServingServer }
import from jaclang.server.static_files { find_root_asset, find_static_candidate }


def _project(base: Path, assets_dir: str) {
    (base / "main.jac").write_text("def app -> str { return \"hi\"; }\n");
    section = f"[client.assets]\ndir = \"{assets_dir}\"\n" if assets_dir else "";
    (base / "jac.toml").write_text(
        "[project]\nname = \"assets-probe\"\nversion = \"0.0.1\"\nentry-point = \"main\"\n\n"
            + section
    );
}


test "the assets directory defaults to the app base's assets" {
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        _project(base, "");
        assert JacClientConfig(base).get_assets_dir() == base / "assets";
    }
}


test "a configured assets directory resolves against the project base" {
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        _project(base, "core/site/assets");
        assert JacClientConfig(base).get_assets_dir()
            == base / "core" / "site" / "assets";
    }
}


test "static requests find shared assets from source, nested paths intact" {
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        _project(base, "core/site/assets");
        shared = base / "core" / "site" / "assets";
        (shared / "media").mkdir(parents=True);
        (shared / "logo.svg").write_text("<svg/>");
        (shared / "media" / "diagram.png").write_bytes(b"png");
        assert find_static_candidate(str(base), "assets/logo.svg")
            == shared / "logo.svg";
        assert (
            find_static_candidate(str(base), "assets/media/diagram.png")
            == shared / "media" / "diagram.png"
        );
        assert find_root_asset(str(base), "logo.svg") == shared / "logo.svg";
        assert find_static_candidate(str(base), "assets/missing.svg") is None;
    }
}


def _served_project(tmp: str) -> Path {
    # A built project: dist/ exists, which is what lets `dist/..` resolve, and
    # the signing secret sits where the server keeps it. outside.txt is a
    # sibling of the project, one level above anything a request may reach.
    base = Path(tmp) / "site";
    base.mkdir();
    _project(base, "");
    (base / "dist").mkdir();
    (base / "dist" / "app.js").write_text("console.log('app')");
    (base / ".jac" / "data").mkdir(parents=True);
    (base / ".jac" / "data" / "jwt_secret").write_text("TOP-SECRET-SIGNING-KEY");
    (base / ".jac" / "client" / "dist").mkdir(parents=True);
    (base / ".jac" / "client" / "dist" / "bundle.js").write_text("bundle");
    (Path(tmp) / "outside.txt").write_text("outside the project");
    return base;
}


test "a static request cannot climb out of the directory it is joined onto" {
    with TemporaryDirectory() as tmp {
        base = _served_project(tmp);
        climbing = [
            "../jac.toml",
            "../.jac/data/jwt_secret",
            "../main.jac",
            "assets/../../jac.toml",
            "a/b/../../../jac.toml",
            "../../outside.txt",
            ".."
        ];
        for rel in climbing {
            assert find_static_candidate(str(base), rel) is None , rel;
            assert find_root_asset(str(base), rel) is None , rel;
        }
        # The same files are found when asked for from where they live.
        assert find_static_candidate(str(base), "app.js") == base / "dist" / "app.js";
        assert find_static_candidate(str(base), "bundle.js")
            == base / ".jac" / "client" / "dist" / "bundle.js";
        # A link inside dist/ that points above it resolves outside dist/, so it
        # has to be refused by where the file is, not by how the path was
        # spelled. Containment is checked against dist/, not the project root.
        try {
            (base / "dist" / "leak.txt").symlink_to(base / "jac.toml");
        } except OSError {
            return;
        }
        assert find_static_candidate(str(base), "leak.txt") is None;
    }
}


def _static_only_settings -> any {
    return SimpleNamespace(client_dist="", static_only=True);
}


def _raw_get(port: int, target: str) -> tuple[int, bytes] {
    sock = socket.create_connection(("127.0.0.1", port), timeout=5);
    data = b"";
    try {
        sock.sendall(
            f"GET {target} HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n".encode()
        );
        while True {
            chunk = sock.recv(65536);
            if not chunk {
                break;
            }
            data += chunk;
        }
    } finally {
        sock.close();
    }
    (head, _, body) = data.partition(b"\r\n\r\n");
    return (int(head.split(b" ", 2)[1]), body);
}


test "GET /static/ with dot segments, literal or percent-encoded, cannot read the project tree" {
    # The path reaches the handler decoded and unnormalized, so this goes
    # through the real transport, router and handler rather than the finder.
    with TemporaryDirectory() as tmp {
        base = _served_project(tmp);
        app = ServingApp();
        stub: any = SimpleNamespace(
            add_endpoint=app.add_endpoint,
            resolved_settings=_static_only_settings,
            module=SimpleNamespace(__file__=""),
            base_path=str(base),
            introspector=None
        );
        ctx = Jac.get_context();
        previous = ctx.base_path_dir;
        ctx.base_path_dir = str(base);
        server = ServingServer(app=app, host="127.0.0.1", port=0);
        stop = None;
        try {
            register_page_endpoints(stub);
            stop = server.serve_background();
            # The control is what makes the refusals mean something: if the
            # handler were not serving this project, it would fail first.
            (status, body) = _raw_get(server.bound_port, "/static/app.js");
            assert status == 200 and b"console.log" in body , (status, body);

            probes = [
                "/static/../jac.toml",
                "/static/..%2Fjac.toml",
                "/static/..%2f.jac%2fdata%2fjwt_secret",
                "/static/%2e%2e/jac.toml",
                "/static/%2e%2e%2f%2e%2e%2foutside.txt"
            ];
            for target in probes {
                (status, body) = _raw_get(server.bound_port, target);
                assert status == 404 , (target, status);
                assert b"TOP-SECRET" not in body and b"[project]" not in body , target;
            }
        } finally {
            if stop is not None {
                stop();
            }
            ctx.base_path_dir = previous;
        }
    }
}
