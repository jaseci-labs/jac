"""Tests for A-05a's JacAPIServerLogs mixin. Verifies the 3 endpoint
paths get registered correctly on the endpoint host; the actual
handler bodies are integration-tested via the real-cluster e2e
(scripts/k8s_microservice_real_e2e.sh) since they require a live
Loki backend."""

import asyncio;
import os;
import from types { SimpleNamespace }
import from unittest.mock { patch, MagicMock }
import from kubernetes.client.exceptions { ApiException }
import from jaclang.scale.admin { logs as logs_mod }
import from jaclang.scale.admin.logs { JacAPIServerLogs }
import from jaclang.scale.tests.support { RecordingHost }


obj LogsHost(JacAPIServerLogs) {
    has server: any = None;
}


obj FakePodApi {
    has logs_by_pod: dict[str, str];

    def list_namespaced_pod(namespace: str, label_selector: str) -> any {
        return SimpleNamespace(
            items=[
                SimpleNamespace(
                    metadata=SimpleNamespace(name=name),
                    spec=SimpleNamespace(containers=[SimpleNamespace(name="app")])
                ) for name in self.logs_by_pod
            ]
        );
    }

    def read_namespaced_pod_log(
        name: str,
        namespace: str,
        container: str,
        timestamps: bool,
        since_seconds: int,
        tail_lines: int
    ) -> str {
        return self.logs_by_pod[name];
    }
}


test "register_logs_endpoints adds /admin/logs, /admin/logs/services, /admin/logs/trace/{id}" {
    host = LogsHost();
    host.server = RecordingHost();

    host.register_logs_endpoints();

    paths = [e.path for e in host.server._endpoints];
    # The 3 endpoints the React LogsPage talks to.
    assert "/admin/logs/services" in paths;
    assert "/admin/logs" in paths;
    assert "/admin/logs/trace/{trace_id}" in paths;
}


test "all logs endpoints are GET (read-only surface)" {
    import from jaclang.server.serving.endpoint { HTTPMethod }

    host = LogsHost();
    host.server = RecordingHost();
    host.register_logs_endpoints();

    for ep in host.server._endpoints {
        if ep.path.startswith("/admin/logs") {
            assert ep.method == HTTPMethod.GET , f"{ep.path} should be GET, got {ep.method}";
        }
    }
}


test "logs endpoints are tagged 'Logs' so OpenAPI groups them" {
    host = LogsHost();
    host.server = RecordingHost();
    host.register_logs_endpoints();

    for ep in host.server._endpoints {
        if ep.path.startswith("/admin/logs") {
            assert ep.tags == ["Logs"] , f"{ep.path} should be tagged ['Logs'], got {ep.tags}";
        }
    }
}


test "flatten newest-first vs oldest-first via ascending flag" {
    # Listing wants newest-first (matches `kubectl logs --tail` UX);
    # trace-detail wants oldest-first (causal order). Same flattener,
    # different `ascending=` argument; nanosecond ts_ns is what we
    # sort on, not the lossy ISO string.
    import from jaclang.scale.admin.logs { _flatten_loki_response }

    payload = {
        "data": {
            "result": [
                {
                    "stream": {"namespace": "ns", "pod": "p1"},
                    "values": [
                        ["1716412345000000000", "older"],
                        ["1716412355000000000", "newer"]
                    ]
                }
            ]
        }
    };

    asc = _flatten_loki_response(payload, ascending=True);
    assert asc[0].get("msg") == "older" , f"asc[0] = {asc[0]}";
    assert asc[1].get("msg") == "newer" , f"asc[1] = {asc[1]}";

    desc = _flatten_loki_response(payload, ascending=False);
    assert desc[0].get("msg") == "newer" , f"desc[0] = {desc[0]}";
    assert desc[1].get("msg") == "older" , f"desc[1] = {desc[1]}";

    # ts_ns must survive flattening so the listing endpoint can use
    # it as a `before` cursor for older-page pagination.
    assert desc[0].get("ts_ns") == "1716412355000000000" , f"ts_ns missing: {desc[0]}";
}


test "trace filter renders bracket escapes Loki's parser accepts" {
    # Regression: pre-fix, the trace_id pipeline produced a LogQL
    # string containing a bare `\[` which Go's strconv.Unquote
    # rejects with "invalid char escape", so Loki returned HTTP 400
    # and the admin UI showed "Log backend unavailable" whenever the
    # user clicked into a trace row. Brackets must be encoded as
    # `\\[` / `\\]` in the LogQL string so unescaping yields `\[` /
    # `\]` for the regex engine.
    import from jaclang.scale.admin.logs { _build_logql }

    q = _build_logql("ns", "", "", "", "abc12345-dead-beef-cafe-000000000001");
    assert "\\\\[trace=" in q , f"expected `\\\\[` in {q}";
    assert "\\\\]" in q , f"expected `\\\\]` in {q}";
    # And no bare `\[` (which would re-introduce the parser error).
    assert "\\[" not in q.replace("\\\\[", "") , f"bare `\\[` found in {q}";
}


test "search filter doubles backslashes before escaping quotes" {
    # Regression: pre-fix, the replace order was quotes-first then
    # backslashes, which re-doubled the backslashes the quote-escape
    # had just inserted, delivering stray `\` chars to Loki's
    # substring match. Doubling backslashes first keeps quote
    # escapes intact.
    import from jaclang.scale.admin.logs { _build_logql }

    q = _build_logql("ns", "", "", 'say "hi"', "");
    # The final LogQL fragment must read: |= "say \"hi\""
    assert '|= "say \\"hi\\""' in q , f"unexpected escape shape: {q}";
}


test "service list collapses to [app_name] in monolith mode" {
    # Regression: pre-fix the dropdown was hard-coded to
    # ['gateway'] + routes.keys(), so monolith deploys offered
    # one bogus entry ('gateway') and no way to pick the actual
    # app's pods.
    import from jaclang.scale.admin.logs { _services_for_mode }

    mono = _services_for_mode(False, [], "jac-builder-dev");
    assert mono == ["jac-builder-dev"] , f"monolith services = {mono}";

    mono_no_name = _services_for_mode(False, [], "");
    assert mono_no_name == [] , f"monolith w/o name = {mono_no_name}";

    micro = _services_for_mode(True, ["jac-coder-sv", "builder-sv"], "jac-builder-dev");
    # Gateway first, then apps sorted - matches kubectl get pods order.
    assert micro == ["gateway", "builder-sv", "jac-coder-sv"] , f"microservice services = {micro}";
}


test "pod regex drops -deployment- infix in monolith mode" {
    # Microservice pods are `<svc>-deployment-<rs>-<rand>`; monolith
    # pods are `<app_name>-<rs>-<rand>` with no `-deployment-` infix.
    # The Loki `pod=~...` filter needs the right shape for each
    # mode or it silently matches zero lines.
    import from jaclang.scale.admin.logs { _service_to_pod_regex_for_mode }

    micro = _service_to_pod_regex_for_mode("builder-sv", True);
    assert micro == "builder-sv-deployment-.*" , f"micro regex = {micro}";

    mono = _service_to_pod_regex_for_mode("jac-builder-dev", False);
    assert mono == "jac-builder-dev-.*" , f"mono regex = {mono}";

    # Underscore-to-hyphen sanity (some users key services with `_`).
    assert _service_to_pod_regex_for_mode("Foo_Bar", True) == "foo-bar-deployment-.*";
    assert _service_to_pod_regex_for_mode("Foo_Bar", False) == "foo-bar-.*";
}


test "logs fall back to pod logs only when Loki is unconfigured and in-cluster" {
    cases = [
        ("", False, True, True),
        ("", True, True, False),
        ("http://loki:3100", False, True, False),
        ("", False, False, False)
    ];
    for (loki_url, logs_enabled, in_cluster, expected) in cases {
        cfg = MagicMock();
        cfg.get_gateway_config.return_value = {"logs": {"enabled": logs_enabled}};
        with patch.dict(os.environ, {"LOKI_URL": loki_url}), patch.object(
            logs_mod, "get_scale_config", lambda { cfg; }
        ), patch.object(logs_mod, "k8s_available", lambda { in_cluster; }) {
            got = logs_mod._use_pod_logs();
        }
        assert got == expected , f"{(loki_url, logs_enabled, in_cluster)} -> {got}";
    }
}


test "pod log fallback applies the service, level, search, trace and before filters" {
    api = FakePodApi(
        logs_by_pod={
            "gateway-deployment-abc-1": (
                '2026-10-03T00:00:01.000000001Z {"level":"ERROR","trace_id":"abc12345-0000","msg":"boom"}\n'
                "2026-10-03T00:00:02Z [trace=abc12345] INFO hello\n"
            ),
            "builder-sv-deployment-def-1": "2026-10-03T00:00:03Z INFO built\n"
        }
    );
    second_ns = 1790985602000000000;
    far = 10 ** 19;
    cases = [
        (
            "",
            "",
            "",
            "",
            far,
            10,
            ["INFO built", "[trace=abc12345] INFO hello", "boom"]
        ),
        ("gateway", "", "", "", far, 10, ["[trace=abc12345] INFO hello", "boom"]),
        ("", "error", "", "", far, 10, ["boom"]),
        ("", "", "hello", "", far, 10, ["[trace=abc12345] INFO hello"]),
        ("", "", "", "abc12345-0000", far, 10, ["[trace=abc12345] INFO hello", "boom"]),
        ("", "", "", "", second_ns, 10, ["[trace=abc12345] INFO hello", "boom"]),
        ("", "", "", "", far, 1, ["INFO built"])
    ];
    with patch.object(logs_mod, "_use_pod_logs", lambda { True; }), patch.object(
        logs_mod, "_fleet_names", lambda { ["builder-sv"]; }
    ), patch.object(logs_mod, "core_api", lambda { api; }), patch.object(
        logs_mod, "ops_namespace", lambda { "ns"; }
    ) {
        for (service, level, search, trace, end_ns, limit, expected) in cases {
            (lines, query) = asyncio.run(
                logs_mod._fetch_log_lines(
                    service, level, search, trace, 0, end_ns, limit, False
                )
            );
            msgs = [line["msg"] for line in lines];
            assert msgs == expected , f"{(service, level, search, trace, end_ns)} -> {msgs}";
            assert query == "";
        }
        assert lines[0]["pod"] == "builder-sv-deployment-def-1";
        assert lines[0]["ts_ns"] == "1790985603000000000";
        denied = MagicMock();
        denied.list_namespaced_pod.side_effect = ApiException(
            status=403, reason="Forbidden"
        );
        with patch.object(logs_mod, "core_api", lambda { denied; }) {
            try {
                logs_mod._collect_pod_logs("", "", "", "", 0, far);
                assert False , "expected ConnectionError on RBAC denial";
            } except ConnectionError as e {
                assert "ops_console = true" in str(e);
            }
        }
    }
}
