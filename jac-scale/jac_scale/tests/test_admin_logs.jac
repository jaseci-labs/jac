"""Tests for A-05a's JacAPIServerLogs mixin. Verifies the 3 endpoint
paths get registered correctly on the JFastApiServer; the actual
handler bodies are integration-tested via the real-cluster e2e
(scripts/k8s_microservice_real_e2e.sh) since they require a live
Loki backend."""

import from jac_scale.admin.logs { JacAPIServerLogs }
import from jac_scale.jserver.jfast_api { JFastApiServer }


obj LogsHost(JacAPIServerLogs) {
    has server: any = None;
}


test "register_logs_endpoints adds /admin/logs, /admin/logs/services, /admin/logs/trace/{id}" {
    host = LogsHost();
    host.server = JFastApiServer();

    host.register_logs_endpoints();

    paths = [e.path for e in host.server._endpoints];
    # The 3 endpoints the React LogsPage talks to.
    assert "/admin/logs/services" in paths;
    assert "/admin/logs" in paths;
    assert "/admin/logs/trace/{trace_id}" in paths;
}


test "all logs endpoints are GET (read-only surface)" {
    import from jac_scale.jserver.jserver { HTTPMethod }

    host = LogsHost();
    host.server = JFastApiServer();
    host.register_logs_endpoints();

    for ep in host.server._endpoints {
        if ep.path.startswith("/admin/logs") {
            assert ep.method == HTTPMethod.GET , f"{ep.path} should be GET, got {ep.method}";
        }
    }
}


test "logs endpoints are tagged 'Logs' so OpenAPI groups them" {
    host = LogsHost();
    host.server = JFastApiServer();
    host.register_logs_endpoints();

    for ep in host.server._endpoints {
        if ep.path.startswith("/admin/logs") {
            assert ep.tags == ["Logs"] , f"{ep.path} should be tagged ['Logs'], got {ep.tags}";
        }
    }
}
