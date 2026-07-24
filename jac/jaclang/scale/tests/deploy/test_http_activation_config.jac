import from jaclang.scale.deploy.autoscale.http_activation_config {
    build_http_activation_spec
}
import from jaclang.scale.tests.deploy.http_activation_test_support {
    default_http_activation_config as _cfg
}


# --- Section A: enabled gating -----------------------------------------------
test "disabled or missing enabled key returns None instead of a spec" {
    assert build_http_activation_spec(
        _cfg(enabled=False), "preview-deployment", "staging", "preview-svc"
    ) is None;
    assert build_http_activation_spec(
        {}, "preview-deployment", "staging", "preview-svc"
    ) is None;
}


# --- Section B: minimal config -----------------------------------------------
test "minimal config (enabled, target_port, concurrency_target) builds a spec with correct defaults everywhere else" {
    spec = build_http_activation_spec(
        _cfg(), "preview-deployment", "staging", "preview-svc"
    );
    assert spec is not None;
    assert spec.scale_target_name == "preview-deployment";
    assert spec.namespace == "staging";
    assert spec.target.service == "preview-svc";
    assert spec.target.port == 8080;
    assert spec.target.port_name is None;
    assert spec.concurrency.target_value == 10;
    assert spec.request_rate is None;
    assert spec.min_replicas == 0;
    assert spec.max_replicas == 1;
    assert spec.polling_interval == 30;
    assert spec.cooldown_period == 300;
    assert spec.rules == [];
    assert spec.cold_start is None;
    assert spec.timeouts is None;
    assert spec.scale_target_kind == "Deployment";
    assert spec.scale_target_api_version == "apps/v1";
    assert spec.scale_target_plural is None;
}


# --- Section C: full config (every optional field, exercised once) ----------
test "full config translates rules, cold_start, timeouts, request_rate, and custom target kind" {
    cfg = _cfg(
        min_replicas=1,
        max_replicas=5,
        polling_interval=15,
        cooldown_period=120,
        target_port=None,
        target_port_name="http",
        request_rate_target=50,
        request_rate_window="5m",
        request_rate_granularity="10s",
        rules=[
            {
                "hosts": ["preview.jac.dev"],
                "paths": ["/app"],
                "headers": [{"name": "x-preview-id", "value": "123"}]
            }
        ],
        cold_start_status_code=503,
        cold_start_body="warming up",
        cold_start_headers={"Retry-After": "2"},
        cold_start_fallback_service="fallback-svc",
        cold_start_fallback_port=8080,
        timeout_readiness="30s",
        timeout_request="60s",
        timeout_response_header="5s",
        scale_target_kind="StatefulSet"
    );
    spec = build_http_activation_spec(
        cfg, "preview-deployment", "staging", "preview-svc"
    );
    assert spec.min_replicas == 1;
    assert spec.max_replicas == 5;
    assert spec.polling_interval == 15;
    assert spec.cooldown_period == 120;
    assert spec.target.port is None;
    assert spec.target.port_name == "http";
    assert spec.concurrency is None;
    assert spec.request_rate.target_value == 50;
    assert spec.request_rate.window == "5m";
    assert spec.request_rate.granularity == "10s";
    assert len(spec.rules) == 1;
    assert spec.rules[0].hosts == ["preview.jac.dev"];
    assert spec.rules[0].paths[0].value == "/app";
    assert spec.rules[0].headers[0].name == "x-preview-id";
    assert spec.rules[0].headers[0].value == "123";
    assert spec.cold_start.placeholder.status_code == 503;
    assert spec.cold_start.placeholder.body == "warming up";
    assert spec.cold_start.placeholder.headers == {"Retry-After": "2"};
    assert spec.cold_start.fallback_service.service == "fallback-svc";
    assert spec.cold_start.fallback_service.port == 8080;
    assert spec.timeouts.readiness == "30s";
    assert spec.timeouts.request == "60s";
    assert spec.timeouts.response_header == "5s";
    assert spec.scale_target_kind == "StatefulSet";
}


# --- Section D: jac.toml-relative validation errors --------------------------
test "config with both target_port and target_port_name raises a jac.toml-relative error" {
    cfg = _cfg(target_port=8080, target_port_name="http");
    raised = False;
    error_msg = "";
    try {
        build_http_activation_spec(cfg, "preview-deployment", "staging", "preview-svc");
    } except ValueError as e {
        raised = True;
        error_msg = str(e);
    }
    assert raised , "Expected ValueError when both target_port and target_port_name are set";
    assert "target_port" in error_msg;
    assert "http_activation" in error_msg;
}

test "config with neither concurrency_target nor request_rate_target raises a jac.toml-relative error" {
    cfg = _cfg(concurrency_target=None);
    raised = False;
    error_msg = "";
    try {
        build_http_activation_spec(cfg, "preview-deployment", "staging", "preview-svc");
    } except ValueError as e {
        raised = True;
        error_msg = str(e);
    }
    assert raised , "Expected ValueError when neither concurrency_target nor request_rate_target is set";
    assert "concurrency_target" in error_msg;
    assert "request_rate_target" in error_msg;
}
