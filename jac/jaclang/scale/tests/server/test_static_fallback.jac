import os;
import tempfile;
import from jaclang.runtimelib.serving.datatypes { Request }
import from jaclang.scale.runtime.gateway.microservice_gateway { MicroserviceGateway }
import from jaclang.scale.runtime.gateway.service_registry { ServiceRegistry }
import from jaclang.scale.server.serve { JacAPIServerStatic }
import from jaclang.jac0core.runtime { JacRuntime as Jac }


def _static_server(project_root: str) -> JacAPIServerStatic {
    # serve_root_asset / serve_static_file derive base_path from the Jac context;
    # point it at a real tempdir tree so the resolver runs against it (no project
    # markers above /tmp, so find_project_root falls back to this dir).
    Jac.get_context().base_path_dir = project_root;
    return JacAPIServerStatic();
}


def _get_request -> Request {
    import from jaclang.runtimelib.serving.datatypes { URL }
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


test "a mount-owned asset miss 404s through full gateway dispatch (no leak, no SPA)" {
    import shutil;
    project_root = tempfile.mkdtemp();
    empty_dist = tempfile.mkdtemp();
    mount_dir = tempfile.mkdtemp();
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

        gw = MicroserviceGateway(
            registry=ServiceRegistry(),
            client_dist_dir=empty_dist,
            static_mounts=[{"url_prefix": "media", "local_path": mount_dir}]
        );
        gw.base_path = project_root;
        gw.setup();

        import from jaclang.runtimelib.serving.testing {
            ServingTestClient as TestClient
        }
        client = TestClient(gw.app);
        resp = client.get("/media/logo.png", headers={"accept": "image/png"});

        assert resp.status_code == 404 , (
            "the 'media' mount owns /media exclusively; a miss must 404 through "
            "the full dispatch -- not serve public/media/logo.png and not the SPA "
            f"shell; got {resp.status_code}"
        );
        assert b"FROM_PUBLIC" not in resp.content;
        assert b"SPA" not in resp.content;
    } finally {
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

        import from jaclang.runtimelib.serving.datatypes { URL }
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
    try {
        brand_dir = os.path.join(project_root, "public", "brand");
        os.makedirs(brand_dir, exist_ok=True);
        with open(os.path.join(brand_dir, "logo.png"), "wb") as f {
            f.write(b"PNG_DATA");
        }

        srv = _static_server(project_root);
        resp = srv.serve_root_asset("brand/logo.png");
        assert resp.status_code == 200 , "public/brand/logo.png must resolve at /brand/logo.png in the monolith";
    } finally {
        shutil.rmtree(project_root, ignore_errors=True);
    }
}


test "monolith: a bare project-root file is not exposed at the web root (#8125 security)" {
    import shutil;
    project_root = tempfile.mkdtemp();
    try {
        with open(os.path.join(project_root, "package.json"), "w") as f {
            f.write("{\"private\": true}");
        }

        srv = _static_server(project_root);
        resp = srv.serve_root_asset("package.json");
        assert resp.status_code == 404 , "a bare project-root file (package.json) must not be served at /package.json";
    } finally {
        shutil.rmtree(project_root, ignore_errors=True);
    }
}


test "monolith: project src/ is not exposed at the web root (#8125 security)" {
    import shutil;
    project_root = tempfile.mkdtemp();
    try {
        src_dir = os.path.join(project_root, "src");
        os.makedirs(src_dir, exist_ok=True);
        with open(os.path.join(src_dir, "app.js"), "w") as f {
            f.write("export const KEY = 1;");
        }

        srv = _static_server(project_root);
        resp = srv.serve_root_asset("src/app.js");
        assert resp.status_code == 404 , "project source under src/ must not be served at /src/app.js";
    } finally {
        shutil.rmtree(project_root, ignore_errors=True);
    }
}


test "monolith: no basename flattening at the web root (I5)" {
    import shutil;
    project_root = tempfile.mkdtemp();
    try {
        assets_dir = os.path.join(project_root, "assets");
        os.makedirs(assets_dir, exist_ok=True);
        with open(os.path.join(assets_dir, "logo.png"), "wb") as f {
            f.write(b"PNG");
        }

        srv = _static_server(project_root);
        resp = srv.serve_root_asset("sub/logo.png");
        assert resp.status_code == 404 , "assets/logo.png must not be reachable at /sub/logo.png via basename flattening";
    } finally {
        shutil.rmtree(project_root, ignore_errors=True);
    }
}


test "monolith: no basename flattening under /static (I5)" {
    import shutil;
    project_root = tempfile.mkdtemp();
    try {
        assets_dir = os.path.join(project_root, "assets");
        os.makedirs(assets_dir, exist_ok=True);
        with open(os.path.join(assets_dir, "logo.png"), "wb") as f {
            f.write(b"PNG");
        }

        srv = _static_server(project_root);
        resp = srv.serve_static_file("sub/logo.png");
        assert resp.status_code == 404 , "assets/logo.png must not be reachable at /static/sub/logo.png via basename flattening";
    } finally {
        shutil.rmtree(project_root, ignore_errors=True);
    }
}
