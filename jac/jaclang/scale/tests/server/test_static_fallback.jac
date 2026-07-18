import os;
import tempfile;
import from starlette.requests { Request }
import from jaclang.scale.runtime.gateway.microservice_gateway { MicroserviceGateway }
import from jaclang.scale.runtime.gateway.service_registry { ServiceRegistry }


def _get_request -> Request {
    return Request({"type": "http", "method": "GET", "headers": []});
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
