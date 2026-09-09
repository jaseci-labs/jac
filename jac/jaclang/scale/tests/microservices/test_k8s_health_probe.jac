"""Tests for honest gateway health in Kubernetes (gateway-only) mode.

The gateway used to assert every declared route healthy without contacting
anything, so /healthz reported the contents of jac.toml rather than the state
of the cluster. These tests drive the real probe against real HTTP listeners
(a live http.server for the healthy arm, a closed port for the ghost arm) and
the real `jac scale gateway` subprocess for the end-to-end arm.
"""

import contextlib;
import json;
import os;
import subprocess;
import sys;
import time;
import uuid;
import requests;
import from pathlib { Path }
import from tempfile { mkdtemp }
import from jaclang.scale.tests.support { get_free_port }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}
import from jaclang.scale.runtime.gateway.microservice_gateway { MicroserviceGateway }
import from jaclang.scale.runtime.orchestrator.process_manager { ServiceProcessManager }

"""Serve a real /healthz over HTTP: http.server answering GET /healthz -> 200."""
def _real_healthz_server(port: int) -> tuple {
    d = mkdtemp();
    (Path(d) / "healthz").write_text("ok");
    proc = subprocess.Popen(
        [sys.executable, "-m", "http.server", str(port), "--bind", "127.0.0.1"],
        cwd=d,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    );
    for _ in range(50) {
        try {
            if requests.get(f"http://127.0.0.1:{port}/healthz", timeout=1).status_code
                == 200 {
                return (proc, d);
            }
        } except Exception {
            time.sleep(0.2);
        }
    }
    proc.terminate();
    raise RuntimeError("healthz helper server did not come up");
}

def _entry(name: str, prefix: str, url: str) -> ServiceEntry {
    return ServiceEntry(
        name=name,
        file=f"{name}.jac",
        prefix=prefix,
        url=url,
        status=ServiceStatus.STARTING
    );
}

test "probe marks a live upstream healthy and a ghost unhealthy" {
    live_port = get_free_port();
    ghost_port = get_free_port();
    (helper, _d) = _real_healthz_server(live_port);
    try {
        reg = ServiceRegistry();
        reg.register(_entry("live", "/live", f"http://127.0.0.1:{live_port}"));
        reg.register(_entry("ghost", "/ghost", f"http://127.0.0.1:{ghost_port}"));
        pm = ServiceProcessManager(registry=reg);
        for _ in range(3) {
            pm.check_all_health();
        }
        assert reg.entries["live"].status == ServiceStatus.HEALTHY , (
            f"live upstream not marked healthy: {reg.entries['live'].status}"
        );
        assert reg.entries["ghost"].status == ServiceStatus.UNHEALTHY , (
            f"ghost not marked unhealthy: {reg.entries['ghost'].status}"
        );
    } finally {
        helper.terminate();
        with contextlib.suppress(Exception) {
            helper.`wait(timeout=5);
        }
    }
}

test "healthz roll-up is computed, not a literal" {
    reg = ServiceRegistry();
    reg.register(_entry("a", "/a", "http://127.0.0.1:1"));
    reg.register(_entry("b", "/b", "http://127.0.0.1:2"));
    gw = MicroserviceGateway(registry=reg);

    resp = gw.handle_health();
    assert resp.content["status"] == "starting" , (
        f"declared-but-unobserved must not report healthy: {resp.content}"
    );
    assert resp.status_code == 200;

    reg.entries["a"].status = ServiceStatus.HEALTHY;
    reg.entries["b"].status = ServiceStatus.UNHEALTHY;
    resp = gw.handle_health();
    assert resp.content["status"] == "degraded" , f"got {resp.content}";
    assert resp.status_code == 503;

    reg.entries["b"].status = ServiceStatus.HEALTHY;
    resp = gw.handle_health();
    assert resp.content["status"] == "healthy" , f"got {resp.content}";
    assert resp.status_code == 200;
}

test "gateway-only mode does not report an unserved route healthy" {
    port = get_free_port();
    d = mkdtemp();
    toml = (
        '[project]\n'
        + 'name = "healthdemo"\n'
        + 'default-app = "web"\n\n'
        + '[apps.web]\n'
        + 'kind = "web-app"\n'
        + 'entry-point = "main.jac"\n\n'
        + '[apps.ghost_app]\n'
        + 'kind = "service"\n'
        + 'entry-point = "ghost_app.jac"\n'
        + 'route = "/ghost"\n\n'
        + '[scale.gateway]\n'
        + f"gateway_port = {port}\n"
    );
    (Path(d) / "jac.toml").write_text(toml);
    (Path(d) / "main.jac").write_text('with entry { print("stub"); }\n');
    (Path(d) / "ghost_app.jac").write_text(
        'def:pub ghost -> str {\n    return "never served";\n}\n'
    );
    admin_dist = Path(d) / ".jac" / "admin";
    admin_dist.mkdir(parents=True, exist_ok=True);
    (admin_dist / "index.html").write_text("<html>staged</html>");
    import from jaclang.scale.runtime.context.util { jac_executable }
    env = dict(os.environ);
    env["KUBERNETES_SERVICE_HOST"] = "10.96.0.1";
    proc = subprocess.Popen(
        [jac_executable(), "scale", "gateway"],
        cwd=d,
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    );
    try {
        body: dict = {};
        for _ in range(120) {
            if proc.poll() is not None {
                raise RuntimeError(f"gateway exited early: {proc.returncode}");
            }
            try {
                r = requests.get(f"http://127.0.0.1:{port}/healthz", timeout=1);
                body = r.json();
                break;
            } except Exception {
                time.sleep(1);
            }
        }
        assert body , "gateway /healthz never answered";
        ghost = body.get("services", {}).get("ghost_app", {});
        assert ghost.get("status") != "healthy" , (
            f"unserved route reported healthy: {body!r}"
        );
        assert body.get("status") != "healthy" , (
            f"top-level status must not be healthy: {body!r}"
        );

        # The probe must eventually demote the ghost to unhealthy.
        demoted = False;
        for _ in range(60) {
            with contextlib.suppress(Exception) {
                r = requests.get(f"http://127.0.0.1:{port}/healthz", timeout=2);
                body = r.json();
                if body.get("services", {}).get("ghost_app", {}).get("status")
                    == "unhealthy" {
                    demoted = True;
                    break;
                }
            }
            time.sleep(2);
        }
        assert demoted , f"ghost never demoted to unhealthy: {body!r}";
        assert body.get("status") == "degraded" , f"got {body!r}";
    } finally {
        proc.terminate();
        with contextlib.suppress(Exception) {
            proc.`wait(timeout=10);
        }
    }
}
