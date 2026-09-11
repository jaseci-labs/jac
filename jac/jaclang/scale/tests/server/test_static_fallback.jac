import os;
import tempfile;
import from pathlib { Path }
import from jaclang.server.serving.datatypes { Request, Response }
import from jaclang.server.serving.app { ServingApp }
import from jaclang.server.serving.server { ServingServer }
import from jaclang.scale.runtime.gateway.microservice_gateway { MicroserviceGateway }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceEntry,
    ServiceRegistry,
    ServiceStatus
}
import from jaclang.server.serving.static_assets { asset_root_table, resolve_asset }


"""A root stub that answers every request with a fixed marker body, so a test
can prove a request never reached it (rather than merely that its own file
didn't win) by asserting the marker is absent from the response."""
def _spawn_root_stub(marker: bytes) -> tuple[any, int] {
    app = ServingApp(title="root-stub");
    async def handler(request: Request, call_next: object) -> Response {
        return Response(content=marker, media_type="application/octet-stream");
    }
    app.add_middleware(handler);
    server = ServingServer(app=app, host="127.0.0.1", port=0);
    stop = server.serve_background();
    assert server.bound_port , "root stub did not bind a port";
    return (stop, server.bound_port);
}


"""The monolith (pages.jac's static_file/root_asset) builds its asset table
the same way: asset_root_table(project_root, client_dist, []) -- no static
mounts there, those are a gateway-only concept. Exercise the same primitive
directly rather than booting a real server."""
def _resolve(project_root: str, empty_dist: str, url_path: str) -> any {
    table = asset_root_table(Path(project_root), Path(empty_dist), []);
    return resolve_asset(table, url_path);
}


def _get_request -> Request {
    import from jaclang.server.serving.datatypes { URL }
    return Request(method="GET", url=URL(path="/static/assets/logo.svg"));
}


def _make_gateway(
    project_root: str, shadow_mount: str, dist: str
) -> MicroserviceGateway {
    gw = MicroserviceGateway(registry=ServiceRegistry());
    gw.base_path = project_root;
    gw.client_dist_dir = dist;
    gw.static_mounts = [{"url_prefix": "static", "local_path": shadow_mount}];
    return gw;
}


test "project /static asset resolves even when a static mount claims the prefix" {
    project_root = tempfile.mkdtemp();
    os.makedirs(os.path.join(project_root, "assets"), exist_ok=True);
    with open(os.path.join(project_root, "assets", "logo.svg"), "w") as f {
        f.write("<svg></svg>");
    }

    shadow_mount = tempfile.mkdtemp();
    empty_dist = tempfile.mkdtemp();

    gw = _make_gateway(project_root, shadow_mount, empty_dist);
    # project assets/ is served under /static/assets/ (the #6872 URL space):
    # assets/logo.svg resolves at /static/assets/logo.svg. A static mount claiming
    # the 'static' prefix must not shadow that real project asset (#7020) -- the
    # static/assets->assets root still serves it past the mount miss.
    resp = gw.handle_static(_get_request(), "/static/assets/logo.svg");

    assert resp is not None , "a /static/* project asset must still resolve when a static mount "
    "claims the 'static' prefix but lacks the file (#7020)";
    assert resp.status_code == 200;
}


test "a mount-owned asset miss 404s through full gateway dispatch (no leak, no SPA, no root fallthrough)" {
    import shutil;
    project_root = tempfile.mkdtemp();
    empty_dist = tempfile.mkdtemp();
    mount_dir = tempfile.mkdtemp();
    # A real root member, like `jac start --fleet` always has: the one this
    # PR's fix must stop dispatch from ever reaching for a mount-owned miss.
    # Without that fix, forward_to_root would forward the request to this
    # stub, which (like the monolith's own asset table) knows nothing about
    # the gateway's static_mounts and would serve its own public/media hit.
    (root_stop, root_port) = _spawn_root_stub(b"FROM_ROOT_SERVICE");
    try {
        # a project public/ file at the exact path the mount claims: must NOT leak
        media = os.path.join(project_root, "public", "media");
        os.makedirs(media, exist_ok=True);
        with open(os.path.join(media, "logo.png"), "wb") as f {
            f.write(b"FROM_PUBLIC");
        }
        # an index.html so the SPA fallback is available -- to prove it is NOT used
        with open(os.path.join(empty_dist, "index.html"), "w") as f {
            f.write("<html>SPA</html>");
        }

        reg = ServiceRegistry();
        reg.register(
            ServiceEntry(
                name="app",
                file="main.jac",
                prefix="/",
                port=root_port,
                url=f"http://127.0.0.1:{root_port}",
                status=ServiceStatus.HEALTHY,
                is_root=True,
                serves_client=True
            )
        );
        gw = MicroserviceGateway(
            registry=reg,
            client_dist_dir=empty_dist,
            static_mounts=[{"url_prefix": "media", "local_path": mount_dir}]
        );
        gw.base_path = project_root;
        gw.setup();

        import from jaclang.testing.testkit { ServingTestClient as TestClient }
        client = TestClient(gw.app);
        resp = client.get("/media/logo.png", headers={"accept": "image/png"});

        assert resp.status_code == 404 , (
            "the 'media' mount owns /media exclusively; a miss must 404 through "
            "the full dispatch -- not serve public/media/logo.png, not the SPA "
            f"shell, and not the root service; got {resp.status_code}"
        );
        assert b"FROM_PUBLIC" not in resp.content;
        assert b"SPA" not in resp.content;
        assert b"FROM_ROOT_SERVICE" not in resp.content , (
            "a mount-owned miss must 404 in handle_static itself, before dispatch "
            "ever reaches forward_to_root"
        );
    } finally {
        root_stop();
        shutil.rmtree(project_root, ignore_errors=True);
        shutil.rmtree(empty_dist, ignore_errors=True);
        shutil.rmtree(mount_dir, ignore_errors=True);
    }
}


test "a genuinely missing /static asset still 404s (no false-positive serving)" {
    project_root = tempfile.mkdtemp();
    os.makedirs(os.path.join(project_root, "assets"), exist_ok=True);
    shadow_mount = tempfile.mkdtemp();
    empty_dist = tempfile.mkdtemp();

    gw = _make_gateway(project_root, shadow_mount, empty_dist);
    resp = gw.handle_static(_get_request(), "/static/assets/does-not-exist.svg");

    assert resp is None , "a missing asset must not be served by the fallback path";
}


test "public/ asset is served at the web root like vite and next serve it (#8124)" {
    import shutil;
    project_root = tempfile.mkdtemp();
    empty_dist = tempfile.mkdtemp();
    try {
        brand_dir = os.path.join(project_root, "public", "brand");
        os.makedirs(brand_dir, exist_ok=True);
        with open(os.path.join(brand_dir, "logo.png"), "wb") as f {
            f.write(b"PNG_DATA");
        }

        gw = MicroserviceGateway(registry=ServiceRegistry());
        gw.base_path = project_root;
        gw.client_dist_dir = empty_dist;

        import from jaclang.server.serving.datatypes { URL }
        req = Request(method="GET", url=URL(path="/brand/logo.png"));
        resp = gw.handle_static(req, "/brand/logo.png");

        assert resp is not None , "public/brand/logo.png must be reachable at /brand/logo.png (the amplify bug #6876)";
        assert resp.status_code == 200;
        assert resp.body_bytes() == b"PNG_DATA";
    } finally {
        shutil.rmtree(project_root, ignore_errors=True);
        shutil.rmtree(empty_dist, ignore_errors=True);
    }
}


# --- Monolith serve_root_asset / serve_static_file (Step 4/5) ---

test "monolith: a public/ asset resolves at the web root (wiring)" {
    import shutil;
    project_root = tempfile.mkdtemp();
    empty_dist = tempfile.mkdtemp();
    try {
        brand_dir = os.path.join(project_root, "public", "brand");
        os.makedirs(brand_dir, exist_ok=True);
        with open(os.path.join(brand_dir, "logo.png"), "wb") as f {
            f.write(b"PNG_DATA");
        }

        hit = _resolve(project_root, empty_dist, "/brand/logo.png");
        assert hit is not None , "public/brand/logo.png must resolve at /brand/logo.png in the monolith";
    } finally {
        shutil.rmtree(project_root, ignore_errors=True);
        shutil.rmtree(empty_dist, ignore_errors=True);
    }
}


test "monolith: a bare project-root file is not exposed at the web root (#8125 security)" {
    import shutil;
    project_root = tempfile.mkdtemp();
    empty_dist = tempfile.mkdtemp();
    try {
        with open(os.path.join(project_root, "package.json"), "w") as f {
            f.write("{\"private\": true}");
        }

        hit = _resolve(project_root, empty_dist, "/package.json");
        assert hit is None , "a bare project-root file (package.json) must not be served at /package.json";
    } finally {
        shutil.rmtree(project_root, ignore_errors=True);
        shutil.rmtree(empty_dist, ignore_errors=True);
    }
}


test "monolith: project src/ is not exposed at the web root (#8125 security)" {
    import shutil;
    project_root = tempfile.mkdtemp();
    empty_dist = tempfile.mkdtemp();
    try {
        src_dir = os.path.join(project_root, "src");
        os.makedirs(src_dir, exist_ok=True);
        with open(os.path.join(src_dir, "app.js"), "w") as f {
            f.write("export const KEY = 1;");
        }

        hit = _resolve(project_root, empty_dist, "/src/app.js");
        assert hit is None , "project source under src/ must not be served at /src/app.js";
    } finally {
        shutil.rmtree(project_root, ignore_errors=True);
        shutil.rmtree(empty_dist, ignore_errors=True);
    }
}


test "monolith: no basename flattening at the web root (I5)" {
    import shutil;
    project_root = tempfile.mkdtemp();
    empty_dist = tempfile.mkdtemp();
    try {
        assets_dir = os.path.join(project_root, "assets");
        os.makedirs(assets_dir, exist_ok=True);
        with open(os.path.join(assets_dir, "logo.png"), "wb") as f {
            f.write(b"PNG");
        }

        hit = _resolve(project_root, empty_dist, "/sub/logo.png");
        assert hit is None , "assets/logo.png must not be reachable at /sub/logo.png via basename flattening";
    } finally {
        shutil.rmtree(project_root, ignore_errors=True);
        shutil.rmtree(empty_dist, ignore_errors=True);
    }
}


test "monolith: no basename flattening under /static (I5)" {
    import shutil;
    project_root = tempfile.mkdtemp();
    empty_dist = tempfile.mkdtemp();
    try {
        assets_dir = os.path.join(project_root, "assets");
        os.makedirs(assets_dir, exist_ok=True);
        with open(os.path.join(assets_dir, "logo.png"), "wb") as f {
            f.write(b"PNG");
        }

        hit = _resolve(project_root, empty_dist, "/static/sub/logo.png");
        assert hit is None , "assets/logo.png must not be reachable at /static/sub/logo.png via basename flattening";
    } finally {
        shutil.rmtree(project_root, ignore_errors=True);
        shutil.rmtree(empty_dist, ignore_errors=True);
    }
}
