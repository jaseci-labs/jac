import unittest.mock;
import from kubernetes.client.exceptions { ApiException }
import from jaclang.scale.deploy.autoscale.keda_autoscaler { KEDAAutoscaler }
import from jaclang.scale.deploy.autoscale.http_activation_config {
    build_http_activation_spec,
    apply_http_activation_for_target,
    destroy_http_activation_for_target
}
import from jaclang.scale.tests.deploy.http_activation_test_support {
    default_http_activation_config as _cfg,
    mocked_keda_autoscaler as _mocked_keda
}


# --- Section A: enabled gating -----------------------------------------------
test "disabled or missing enabled key returns None instead of a spec" {
    assert build_http_activation_spec(
        _cfg(enabled=False), "preview-deployment", "staging", "preview-svc"
    )
        is None;
    assert build_http_activation_spec(
        {}, "preview-deployment", "staging", "preview-svc"
    )
        is None;
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
    assert spec.concurrency is not None;
    assert spec.concurrency.target_value == 10;
    assert spec.request_rate is None;
    assert spec.min_replicas == 0;
    assert spec.max_replicas == 1;
    assert spec.polling_interval == 30;
    assert spec.cooldown_period == 300;
    assert len(spec.rules) == 2;
    assert spec.rules[0].hosts == ["*"];
    # The auto-derived internal-routing rule: always appended last,
    # host-only (matches any path/header), so cluster-internal gateway
    # forwards and sv-to-sv RPC calls can reach this service through the
    # interceptor without any operator-authored rule covering them.
    assert spec.rules[-1].hosts == ["preview-svc.staging.svc.cluster.local"];
    assert spec.rules[-1].paths == [];
    assert spec.rules[-1].headers == [];
    assert spec.cold_start is None;
    assert spec.timeouts is None;
    assert spec.scale_target_kind == "Deployment";
    assert spec.scale_target_api_version == "apps/v1";
    assert spec.scale_target_plural is None;
}


# --- Section B2: the auto-derived internal-routing rule ---------------------
test "the auto-derived rule's host is the target's real Service DNS name, computed independently here" {
    spec = build_http_activation_spec(
        _cfg(), "orders-deployment", "shop", "orders-app-service"
    );
    assert spec is not None;
    expected_host = "orders-app-service.shop.svc.cluster.local";
    assert spec.rules[-1].hosts == [expected_host] , (
        f"expected the auto-rule to match '{expected_host}', got {spec.rules[-1].hosts}"
    );
}

test "an empty operator rules list still raises before the auto-rule could paper over it" {
    _assert_config_error(_cfg(rules=[]), "rules");
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
    assert spec is not None;
    assert spec.min_replicas == 1;
    assert spec.max_replicas == 5;
    assert spec.polling_interval == 15;
    assert spec.cooldown_period == 120;
    assert spec.target.port is None;
    assert spec.target.port_name == "http";
    assert spec.concurrency is None;
    assert spec.request_rate is not None;
    assert spec.request_rate.target_value == 50;
    assert spec.request_rate.rate_window == "5m";
    assert spec.request_rate.granularity == "10s";
    assert len(spec.rules) == 2;
    assert spec.rules[0].hosts == ["preview.jac.dev"];
    assert spec.rules[0].paths[0].value == "/app";
    assert spec.rules[0].headers[0].name == "x-preview-id";
    assert spec.rules[0].headers[0].value == "123";
    assert spec.rules[-1].hosts == ["preview-svc.staging.svc.cluster.local"];
    assert spec.rules[-1].paths == [];
    assert spec.rules[-1].headers == [];
    assert spec.cold_start is not None;
    assert spec.cold_start.placeholder is not None;
    assert spec.cold_start.placeholder.status_code == 503;
    assert spec.cold_start.placeholder.body == "warming up";
    assert spec.cold_start.placeholder.headers == {"Retry-After": "2"};
    assert spec.cold_start.fallback_service is not None;
    assert spec.cold_start.fallback_service.service == "fallback-svc";
    assert spec.cold_start.fallback_service.port == 8080;
    assert spec.timeouts is not None;
    assert spec.timeouts.readiness == "30s";
    assert spec.timeouts.request == "60s";
    assert spec.timeouts.response_header == "5s";
    assert spec.scale_target_kind == "StatefulSet";
}


# --- Section D: jac.toml-relative validation errors --------------------------
# One shape, four inputs: each bad cfg must raise ValueError (never a bare
# KeyError or anything else -- left uncaught here, so it fails the test loudly
# instead of silently) naming the jac.toml key(s) at fault.
def _assert_config_error(cfg: dict[str, any], *substrings: str) -> None {
    try {
        build_http_activation_spec(cfg, "preview-deployment", "staging", "preview-svc");
    } except ValueError as e {
        msg = str(e);
        for s in substrings {
            assert s in msg , f"expected '{s}' in error message: {msg}";
        }
        return;
    }
    assert False , "expected build_http_activation_spec to raise ValueError";
}

test "config with both target_port and target_port_name raises a jac.toml-relative error" {
    _assert_config_error(
        _cfg(target_port=8080, target_port_name="http"),
        "target_port",
        "http_activation"
    );
}

test "config with neither concurrency_target nor request_rate_target raises a jac.toml-relative error" {
    _assert_config_error(
        _cfg(concurrency_target=None), "concurrency_target", "request_rate_target"
    );
}

test "config with empty rules raises instead of silently deploying an unreachable target" {
    _assert_config_error(_cfg(rules=[]), "rules");
}

test "a rule header missing its required 'name' key raises a jac.toml-relative error, not a bare KeyError" {
    _assert_config_error(_cfg(rules=[{"headers": [{"value": "yes"}]}]), "name");
}


# --- Section E: apply/destroy wiring helpers (injectable KEDAAutoscaler) ----
# These back the monolith (kubernetes_target.jac) and microservices
# (manifest_builder.jac / microservice/target.jac) deploy-path call sites.
# kubernetes_target.jac's deploy() is a single large method that talks to a
# real cluster end to end with no isolated seam to unit test (it is only
# ever exercised against a live cluster, in test_deploy_k8s.jac) - these two
# functions exist so the HTTP-activation call itself stays testable without
# that whole method, by taking the KEDAAutoscaler as an explicit parameter.
test "apply_http_activation_for_target calls apply_http_activation with a correctly-targeted spec when enabled" {
    (keda, custom_api, _, _) = _mocked_keda();
    custom_api.get_namespaced_custom_object.side_effect = ApiException(status=404);
    result = apply_http_activation_for_target(
        _cfg(), "preview-deployment", "staging", "preview-svc", keda
    );
    assert result == True;
    create_calls = custom_api.create_namespaced_custom_object.call_args_list;
    assert len(create_calls) == 2;
    route_body = create_calls[0][1]["body"];
    assert route_body["spec"]["target"]["service"] == "preview-svc";
    applied_rules = route_body["spec"]["rules"];
    assert len(applied_rules) == 2 , (
        "expected the operator rule plus the auto-derived internal rule to "
        f"both reach the applied InterceptorRoute body, got {applied_rules}"
    );
    assert applied_rules[-1]["hosts"] == ["preview-svc.staging.svc.cluster.local"];
    scaled_obj_body = create_calls[1][1]["body"];
    assert scaled_obj_body["metadata"]["name"]
        == keda.http_scaled_object_name_for("preview-deployment");
}

test "apply_http_activation_for_target is a no-op when disabled or unset" {
    (keda, custom_api, _, _) = _mocked_keda();
    assert apply_http_activation_for_target(
        _cfg(enabled=False), "preview-deployment", "staging", "preview-svc", keda
    )
        is None;
    assert apply_http_activation_for_target(
        {}, "preview-deployment", "staging", "preview-svc", keda
    )
        is None;
    custom_api.create_namespaced_custom_object.assert_not_called();
}

test "destroy_http_activation_for_target always sweeps both resources, independent of current config" {
    # Deliberately unconditional: a resource created while http_activation was
    # enabled must still be cleaned up if the config later disables it or
    # drops the block entirely, otherwise it is orphaned. destroy_http_
    # activation is 404-safe per-resource, so calling it unconditionally
    # (mirroring the base autoscaler's own unconditional destroy() call) is
    # always safe, whether or not anything was ever actually created.
    mock_api = unittest.mock.MagicMock();
    keda = KEDAAutoscaler(_custom_api=mock_api);
    destroy_http_activation_for_target("preview-deployment", "staging", keda);
    delete_calls = mock_api.delete_namespaced_custom_object.call_args_list;
    plurals = [c[1]["plural"] for c in delete_calls];
    assert "interceptorroutes" in plurals;
    assert "scaledobjects" in plurals;
}

test "destroy_http_activation_for_target swallows a permission error instead of aborting the rest of teardown" {
    # The HTTP Add-on CRD group (http.keda.sh) is installed separately from
    # core KEDA; a cluster's RBAC may cover keda.sh (which the base
    # autoscaler already needs) without yet covering this newer group. A 403
    # here must not stop the Deployment/Service/PVC/ingress/monitoring/
    # database cleanup that runs after this call in the monolith destroy
    # path, mirroring the "HTTP Add-on might not be fully available" warn-
    # and-continue precedent already used by apply_http_activation's
    # preflight check.
    mock_api = unittest.mock.MagicMock();
    mock_api.delete_namespaced_custom_object.side_effect = ApiException(status=403);
    keda = KEDAAutoscaler(_custom_api=mock_api);
    raised = False;
    try {
        destroy_http_activation_for_target("preview-deployment", "staging", keda);
    } except ApiException {
        raised = True;
    }
    assert not raised , "A 403 must not propagate out of destroy_http_activation_for_target";
}

test "destroy_http_activation_for_target still propagates an unexpected error like a 500" {
    # Only a 403 is treated as "HTTP Add-on RBAC not provisioned yet" and
    # swallowed. A 500/502/503 is a genuinely different failure mode (the
    # API server itself is having trouble, not a permission gap) and must
    # still surface to the caller instead of silently leaving the
    # InterceptorRoute/ScaledObject orphaned with no error reported.
    mock_api = unittest.mock.MagicMock();
    mock_api.delete_namespaced_custom_object.side_effect = ApiException(status=500);
    keda = KEDAAutoscaler(_custom_api=mock_api);
    raised = False;
    try {
        destroy_http_activation_for_target("preview-deployment", "staging", keda);
    } except ApiException {
        raised = True;
    }
    assert raised , "A 500 must propagate out of destroy_http_activation_for_target";
}
