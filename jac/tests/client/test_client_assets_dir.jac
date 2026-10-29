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
        table = asset_root_table(base, base / ".jac" / "client" / "dist", []);
        static_hit = resolve_asset(table, "/static/assets/logo.svg");
        assert static_hit is not None and static_hit[0] == shared / "logo.svg";
        nested_hit = resolve_asset(table, "/static/assets/media/diagram.png");
        assert (
            nested_hit is not None and nested_hit[0] == shared / "media" / "diagram.png"
        );
        root_hit = resolve_asset(table, "/logo.svg");
        assert root_hit is not None and root_hit[0] == shared / "logo.svg";
        assert resolve_asset(table, "/static/assets/missing.svg") is None;
    }
}


def _served_project(tmp: str) -> Path {
    # A built project: the client bundle sits in .jac/client/dist, the signing
    # secret sits where the server keeps it, and a project-root dist/ exists so
    # a request can try to climb out of it. outside.txt is a sibling of the
    # project, one level above anything a request may reach.
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


# Serves `base` through the real transport, router and page handler, with the
# Jac context pointed at it the way `jac start` points it at the project.
def _serve_project(base: Path, module_file: str) -> tuple[int, any] {
    app = ServingApp();
    stub: any = SimpleNamespace(
        add_endpoint=app.add_endpoint,
        resolved_settings=_static_only_settings,
        module=SimpleNamespace(__file__=module_file),
        base_path=str(base),
        introspector=None
    );
    ctx = Jac.get_context();
    previous = ctx.base_path_dir;
    ctx.base_path_dir = str(base);
    server = ServingServer(app=app, host="127.0.0.1", port=0);
    try {
        register_page_endpoints(stub);
        stop = server.serve_background();
    } except Exception as e {
        ctx.base_path_dir = previous;
        raise e;
    }
    def _stop {
        stop();
        ctx.base_path_dir = previous;
    }
    return (server.bound_port, _stop);
}


test "GET /static/ with dot segments, literal or percent-encoded, cannot read the project tree" {
    # The path reaches the handler decoded and unnormalized, so this goes
    # through the real transport, router and handler rather than the finder.
    with TemporaryDirectory() as tmp {
        base = _served_project(tmp);
        (port, stop) = _serve_project(base, "");
        try {
            # The control is what makes the refusals mean something: if the
            # handler were not serving this project, it would fail first.
            (status, body) = _raw_get(port, "/static/bundle.js");
            assert status == 200 and body == b"bundle" , (status, body);

            # The bundle is served from .jac/client/dist, three levels below
            # the project root, so the deeper probes are the ones that would
            # land on a real file if the handler did not contain them.
            probes = [
                "/static/../jac.toml",
                "/static/..%2Fjac.toml",
                "/static/..%2f.jac%2fdata%2fjwt_secret",
                "/static/%2e%2e/jac.toml",
                "/static/%2e%2e%2f%2e%2e%2foutside.txt",
                "/static/../../../jac.toml",
                "/static/..%2F..%2Fdata%2Fjwt_secret",
                "/static/%2e%2e%2f%2e%2e%2f%2e%2e%2f%2e%2e%2foutside.txt",
                "/static/app.js"
            ];
            for target in probes {
                (status, body) = _raw_get(port, target);
                assert status == 404 , (target, status);
                for leaked in (
                    b"TOP-SECRET",
                    b"[project]",
                    b"outside the project",
                    b"console.log"
                ) {
                    assert leaked not in body , (target, leaked);
                }
            }
        } finally {
            stop();
        }
        # A project with a custom [build] dir builds its client bundle there,
        # not under .jac; the handler must serve that bundle, not a stale one.
        custom = Path(tmp) / "custom";
        custom.mkdir();
        _project(custom, "");
        with open(custom / "jac.toml", "a") as f {
            f.write("\n[build]\ndir = \".custom-build\"\n");
        }
        (custom / ".custom-build" / "client" / "dist").mkdir(parents=True);
        (custom / ".custom-build" / "client" / "dist" / "bundle.js").write_text(
            "custom-bundle"
        );
        (custom / ".jac" / "client" / "dist").mkdir(parents=True);
        (custom / ".jac" / "client" / "dist" / "bundle.js").write_text("stale");
        (port, stop) = _serve_project(custom, str(custom / "main.jac"));
        try {
            (status, body) = _raw_get(port, "/static/bundle.js");
            assert status == 200 and body == b"custom-bundle" , (status, body);
        } finally {
            stop();
        }
    }
}
