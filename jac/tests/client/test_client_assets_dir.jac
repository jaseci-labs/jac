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
import from jaclang.server.serving.static_assets { asset_root_table, resolve_asset }


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
        table = asset_root_table(base, base / ".jac" / "client" / "dist");
        assert resolve_asset(table, "/static/assets/logo.svg") == shared / "logo.svg";
        assert resolve_asset(table, "/static/assets/media/diagram.png")
            == shared / "media" / "diagram.png";
        assert resolve_asset(table, "/logo.svg") == shared / "logo.svg";
        assert resolve_asset(table, "/static/assets/missing.svg") is None;
    }
}


def _served_project(tmp: str) -> Path {
    # A built project with a custom [build] dir, so its bundle is under
    # .custom-build/ and .jac/client/dist holds only a stale one. The signing
    # secret sits where the server keeps it, a project-root dist/ exists, and
    # outside.txt is a sibling of the project, above anything a request may reach.
    base = Path(tmp) / "site";
    base.mkdir();
    _project(base, "");
    with open(base / "jac.toml", "a") as f {
        f.write("\n[build]\ndir = \".custom-build\"\n");
    }
    (base / ".custom-build" / "client" / "dist").mkdir(parents=True);
    (base / ".custom-build" / "client" / "dist" / "bundle.js").write_text("bundle");
    (base / "dist").mkdir();
    (base / "dist" / "app.js").write_text("console.log('app')");
    (base / ".jac" / "data").mkdir(parents=True);
    (base / ".jac" / "data" / "jwt_secret").write_text("TOP-SECRET-SIGNING-KEY");
    (base / ".jac" / "client" / "dist").mkdir(parents=True);
    (base / ".jac" / "client" / "dist" / "bundle.js").write_text("stale");
    (Path(tmp) / "outside.txt").write_text("outside the project");
    return base;
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
            module=SimpleNamespace(__file__=str(base / "main.jac")),
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
            # handler were not serving this project's configured build, it
            # would fail first.
            (status, body) = _raw_get(server.bound_port, "/static/bundle.js");
            assert status == 200 and body == b"bundle" , (status, body);

            probes = [
                "/static/../jac.toml",
                "/static/..%2Fjac.toml",
                "/static/..%2f.jac%2fdata%2fjwt_secret",
                "/static/%2e%2e/jac.toml",
                "/static/%2e%2e%2f%2e%2e%2foutside.txt",
                # the bundle is three levels below the project root, so these
                # would land on real files if the handler did not contain them
                "/static/../../../jac.toml",
                "/static/..%2F..%2F..%2F.jac%2Fdata%2Fjwt_secret",
                "/static/%2e%2e%2f%2e%2e%2f%2e%2e%2f%2e%2e%2foutside.txt",
                # a project-root dist/ is not an asset root
                "/static/app.js"
            ];
            for target in probes {
                (status, body) = _raw_get(server.bound_port, target);
                assert status == 404 , (target, status);
                for leaked in (
                    b"TOP-SECRET",
                    b"[project]",
                    b"outside",
                    b"console.log"
                ) {
                    assert leaked not in body , (target, leaked);
                }
            }
        } finally {
            if stop is not None {
                stop();
            }
            ctx.base_path_dir = previous;
        }
    }
}
