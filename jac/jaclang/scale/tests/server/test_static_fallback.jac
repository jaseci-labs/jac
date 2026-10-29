import os;
import tempfile;


# A root service that answers everything with `marker`, to prove a request never reached it.
def _spawn_root_stub(marker: bytes) -> tuple[any, int] {
    app = ServingApp(title="root-stub");
    async def handler(request: Request, call_next: object) -> Response {
        return Response(content=marker, media_type="application/octet-stream");
    }
    app.add_middleware(handler);
    server = ServingServer(app=app, host="127.0.0.1", port=0);
    stop = server.serve_background();
    return (stop, server.bound_port);
}


def _get_request -> Request {
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
    resp = gw.handle_static(_get_request(), "/static/assets/logo.svg");

    assert resp is not None , "a /static/* project asset must still resolve when a static mount "
    "claims the 'static' prefix but lacks the file (#7020)";
    assert resp.status_code == 200;
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


test "gateway dispatch: public/ at the web root, and a mount-owned miss 404s without leaking" {
    import shutil;
    import from jaclang.testing.testkit { ServingTestClient as TestClient }
    project_root = tempfile.mkdtemp();
    dist = tempfile.mkdtemp();
    mount_dir = tempfile.mkdtemp();
    # A real root member, as `jac start --fleet` has, that knows nothing of the
    # gateway's mounts and would serve its own copy.
    (root_stop, root_port) = _spawn_root_stub(b"FROM_ROOT_SERVICE");
    try {
        for (rel, data) in [
            ("public/media/logo.png", b"FROM_PUBLIC"),
            ("public/brand/logo.png", b"PNG")
        ] {
            os.makedirs(
                os.path.dirname(os.path.join(project_root, rel)), exist_ok=True
            );
            with open(os.path.join(project_root, rel), "wb") as f {
                f.write(data);
            }
        }
        with open(os.path.join(dist, "index.html"), "w") as f {
            f.write("<html>SPA</html>");
        }

        def _gateway(reg: ServiceRegistry, mounts: list[dict[str, str]]) -> any {
            gw = MicroserviceGateway(
                registry=reg, client_dist_dir=dist, static_mounts=mounts
            );
            gw.base_path = project_root;
            gw.setup();
            return TestClient(gw.app);
        }

        fleet = ServiceRegistry();
        fleet.register(
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
        with_root = _gateway(fleet, [{"url_prefix": "media", "local_path": mount_dir}]);
        # no root member owns "/", so /docs takes the client-page branch
        client_pages = _gateway(
            ServiceRegistry(), [{"url_prefix": "docs", "local_path": mount_dir}]
        );
        plain = _gateway(ServiceRegistry(), []);
        png = {"accept": "image/png"};
        html = {"accept": "text/html"};
        # (client, method, path, headers, expected status, expected body or None)
        for (client, method, path, headers, status, body) in [
            (plain, "GET", "/brand/logo.png", png, 200, b"PNG"),
            (plain, "GET", "/docs", html, 200, b"<html>SPA</html>"),
            (with_root, "GET", "/media/logo.png", png, 404, None),
            (with_root, "HEAD", "/media/logo.png", png, 404, None),
            (client_pages, "GET", "/docs", html, 404, None),
            (client_pages, "GET", "/docs/", html, 404, None)
        ] {
            resp = client.get(path, headers=headers)
                if method == "GET"
                else client.head(path, headers=headers);
            assert resp.status_code == status , (method, path, resp.status_code);
            if body is not None {
                assert resp.content == body , (method, path);
            }
            for leaked in (b"FROM_PUBLIC", b"SPA", b"FROM_ROOT_SERVICE") {
                assert body is not None or leaked not in resp.content , (
                    method,
                    path,
                    leaked
                );
            }
        }
    } finally {
        root_stop();
        shutil.rmtree(project_root, ignore_errors=True);
        shutil.rmtree(dist, ignore_errors=True);
        shutil.rmtree(mount_dir, ignore_errors=True);
    }
}
