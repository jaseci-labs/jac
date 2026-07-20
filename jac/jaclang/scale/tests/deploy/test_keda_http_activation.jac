import unittest.mock;
import from kubernetes.client.exceptions { ApiException }
import from jaclang.scale.deploy.autoscale.keda_autoscaler { KEDAAutoscaler }
import from jaclang.scale.deploy.autoscale.http_activation {
    HTTPActivationSpec,
    HTTPRoutingRule,
    HTTPPathMatch,
    HTTPHeaderMatch,
    HTTPServiceTarget,
    HTTPConcurrencyMetric,
    HTTPRequestRateMetric,
    HTTPStaticResponse,
    HTTPColdStartSpec,
    HTTPTimeoutSpec
}

# Base HTTPActivationSpec shared by most tests below: a Deployment target on
# port 8080 with a concurrency=10 trigger. Override only what a given test
# cares about; pass concurrency=None when testing the metric-required check.
def _spec(**overrides: any) -> HTTPActivationSpec {
    defaults = {
        "name": "preview",
        "namespace": "default",
        "scale_target_name": "preview-deployment",
        "target": HTTPServiceTarget(service="preview-svc", port=8080),
        "concurrency": HTTPConcurrencyMetric(target_value=10)
    };
    if "request_rate" in overrides {
        defaults.pop("concurrency");
    }
    defaults.update(overrides);
    return HTTPActivationSpec(**defaults);
}

# KEDAAutoscaler wired to MagicMock clients, with the HTTP Add-on preflight
# check (list_cluster_custom_object) pre-configured as installed by default.
# Pass a pre-configured apps_api/core_api/custom_api to control target,
# Service, or route/ScaledObject existence for a specific test. Returns the
# mocks alongside the instance since KEDAAutoscaler's api fields are typed
# `any | None`, which the checker won't let a caller re-narrow after the fact.
def _mocked_keda(
    http_addon_installed: bool = True,
    custom_api: any = None,
    apps_api: any = None,
    core_api: any = None
) -> tuple[KEDAAutoscaler, any, any, any] {
    KEDAAutoscaler._http_preflight_cache.clear();
    custom_api = custom_api or unittest.mock.MagicMock();
    if http_addon_installed {
        custom_api.list_cluster_custom_object.return_value = {};
    } else {
        custom_api.list_cluster_custom_object.side_effect = ApiException(status=404);
    }
    apps_api = apps_api or unittest.mock.MagicMock();
    core_api = core_api or unittest.mock.MagicMock();
    keda = KEDAAutoscaler(
        _custom_api=custom_api, _apps_api=apps_api, _core_api=core_api
    );
    return (keda, custom_api, apps_api, core_api);
}


# --- Section A: typed model validation -------------------------------------
test "validate rejects a Service target with both port and port_name set" {
    keda = KEDAAutoscaler();
    spec = _spec(
        target=HTTPServiceTarget(service="preview-svc", port=8080, port_name="http")
    );
    raised = False;
    try {
        keda._validate_http_activation_spec(spec);
    } except ValueError as e {
        raised = True;
    }
    assert raised , "Expected ValueError when both port and port_name are set";
}

test "validate rejects a Service target with neither port nor port_name set" {
    keda = KEDAAutoscaler();
    spec = _spec(target=HTTPServiceTarget(service="preview-svc"));
    raised = False;
    try {
        keda._validate_http_activation_spec(spec);
    } except ValueError as e {
        raised = True;
    }
    assert raised , "Expected ValueError when neither port nor port_name is set";
}

test "validate requires at least one of concurrency or request_rate" {
    keda = KEDAAutoscaler();
    spec = _spec(concurrency=None);
    raised = False;
    try {
        keda._validate_http_activation_spec(spec);
    } except ValueError as e {
        raised = True;
    }
    assert raised , "Expected ValueError when neither concurrency nor request_rate is set";
}

test "request_rate defaults window to 1m and granularity to 1s when unset" {
    metric = HTTPRequestRateMetric(target_value=100);
    assert metric.window == "1m";
    assert metric.granularity == "1s";
}


# --- Section B: routing-rule grouping (AND-within-rule / OR-between-rules) -
test "single rule with host, path, and header collapses into one AND-grouped match block" {
    keda = KEDAAutoscaler();
    rules = [
        HTTPRoutingRule(
            hosts=["preview.jac.dev"],
            paths=[HTTPPathMatch(value="/app")],
            headers=[HTTPHeaderMatch(name="x-preview-id", value="123")]
        )
    ];
    result = keda._build_routing_rules(rules);
    assert len(result) == 1;
    assert result[0]["hosts"] == ["preview.jac.dev"];
    assert result[0]["path"]["value"] == "/app";
    assert result[0]["headers"][0]["name"] == "x-preview-id";
}

test "two rules in the list produce two separate OR-grouped match blocks" {
    keda = KEDAAutoscaler();
    rules = [
        HTTPRoutingRule(hosts=["a.jac.dev"]),
        HTTPRoutingRule(hosts=["b.jac.dev"])
    ];
    result = keda._build_routing_rules(rules);
    assert len(result) == 2;
    assert result[0]["hosts"] == ["a.jac.dev"];
    assert result[1]["hosts"] == ["b.jac.dev"];
}

test "rule with only hosts omits empty path and headers keys" {
    keda = KEDAAutoscaler();
    rules = [HTTPRoutingRule(hosts=["a.jac.dev"])];
    result = keda._build_routing_rules(rules);
    assert "hosts" in result[0];
    assert "path" not in result[0];
    assert "headers" not in result[0];
}

test "rule with multiple paths expands into one OR-grouped match block per path" {
    keda = KEDAAutoscaler();
    rules = [
        HTTPRoutingRule(
            hosts=["preview.jac.dev"],
            paths=[HTTPPathMatch(value="/app"), HTTPPathMatch(value="/api")],
            headers=[HTTPHeaderMatch(name="x-preview-id", value="123")]
        )
    ];
    result = keda._build_routing_rules(rules);
    assert len(result) == 2;
    path_values = [entry["path"]["value"] for entry in result];
    assert "/app" in path_values;
    assert "/api" in path_values;
    for entry in result {
        assert entry["hosts"] == ["preview.jac.dev"];
        assert entry["headers"][0]["name"] == "x-preview-id";
    }
}


# --- Section C: InterceptorRoute manifest builder ---------------------------
test "build_interceptor_route produces a complete and valid InterceptorRoute body" {
    keda = KEDAAutoscaler();
    spec = _spec(
        namespace="staging", rules=[HTTPRoutingRule(hosts=["preview.jac.dev"])]
    );
    m = keda._build_interceptor_route(spec);
    body = m["body"];
    assert body["apiVersion"] == "http.keda.sh/v1beta1";
    assert body["kind"] == "InterceptorRoute";
    assert body["metadata"]["namespace"] == "staging";
    assert body["metadata"]["labels"]["managed"] == "jac-scale";
    assert body["spec"]["target"]["service"] == "preview-svc";
    assert body["spec"]["target"]["port"] == 8080;
    assert body["spec"]["scalingMetric"]["concurrency"]["targetValue"] == 10;
    assert len(body["spec"]["rules"]) == 1;
}

test "build_interceptor_route uses port_name instead of port when port is unset" {
    keda = KEDAAutoscaler();
    spec = _spec(target=HTTPServiceTarget(service="preview-svc", port_name="http"));
    m = keda._build_interceptor_route(spec);
    assert m["body"]["spec"]["target"]["portName"] == "http";
    assert "port" not in m["body"]["spec"]["target"];
}

test "build_interceptor_route includes cold_start placeholder only when set" {
    keda = KEDAAutoscaler();
    with_cold_start = keda._build_interceptor_route(
        _spec(
            cold_start=HTTPColdStartSpec(
                placeholder=HTTPStaticResponse(status_code=503, body="warming up")
            )
        )
    );
    without_cold_start = keda._build_interceptor_route(_spec());
    assert with_cold_start["body"]["spec"]["coldStart"]["placeholder"]["response"][
        "statusCode"
    ] == 503;
    assert "coldStart" not in without_cold_start["body"]["spec"];
}

test "build_interceptor_route includes cold_start fallback_service only when set" {
    keda = KEDAAutoscaler();
    spec = _spec(
        cold_start=HTTPColdStartSpec(
            fallback_service=HTTPServiceTarget(service="fallback-svc", port=8080)
        )
    );
    m = keda._build_interceptor_route(spec);
    assert m["body"]["spec"]["coldStart"]["fallback"]["service"]["name"] == "fallback-svc";
    assert "placeholder" not in m["body"]["spec"]["coldStart"];
}

test "build_interceptor_route encodes request_rate as scalingMetric.requestRate" {
    keda = KEDAAutoscaler();
    spec = _spec(
        request_rate=HTTPRequestRateMetric(
            target_value=50, window="5m", granularity="10s"
        )
    );
    m = keda._build_interceptor_route(spec);
    scaling_metric = m["body"]["spec"]["scalingMetric"];
    assert scaling_metric["requestRate"]["targetValue"] == 50;
    assert scaling_metric["requestRate"]["window"] == "5m";
    assert scaling_metric["requestRate"]["granularity"] == "10s";
    assert "concurrency" not in scaling_metric;
}

test "build_interceptor_route includes timeouts only when set, omitted otherwise" {
    keda = KEDAAutoscaler();
    with_timeouts = keda._build_interceptor_route(
        _spec(
            timeouts=HTTPTimeoutSpec(
                readiness="30s", request="60s", response_header="5s"
            )
        )
    );
    without_timeouts = keda._build_interceptor_route(_spec());
    assert with_timeouts["body"]["spec"]["timeouts"]["readiness"] == "30s";
    assert with_timeouts["body"]["spec"]["timeouts"]["request"] == "60s";
    assert "timeouts" not in without_timeouts["body"]["spec"];
}


# --- Section D: ScaledObject external-push builder --------------------------
test "build_http_scaled_object produces a complete external-push ScaledObject" {
    keda = KEDAAutoscaler();
    spec = _spec(namespace="staging", min_replicas=0, max_replicas=5);
    m = keda._build_http_scaled_object(spec);
    body = m["body"];
    trigger = body["spec"]["triggers"][0];
    assert body["apiVersion"] == "keda.sh/v1alpha1";
    assert body["kind"] == "ScaledObject";
    assert body["spec"]["minReplicaCount"] == 0;
    assert body["spec"]["maxReplicaCount"] == 5;
    assert trigger["type"] == "external-push";
    assert trigger["metadata"]["interceptorRoute"] == keda.interceptor_route_name_for(
        "preview-deployment"
    );
    assert "scalerAddress" in trigger["metadata"];
}

test "build_http_scaled_object encodes concurrency metric as targetValue" {
    keda = KEDAAutoscaler();
    spec = _spec(concurrency=HTTPConcurrencyMetric(target_value=25));
    m = keda._build_http_scaled_object(spec);
    metadata = m["body"]["spec"]["triggers"][0]["metadata"];
    assert metadata["targetValue"] == "25";
    assert "window" not in metadata;
}

test "build_http_scaled_object encodes request_rate metric with window and granularity" {
    keda = KEDAAutoscaler();
    spec = _spec(
        request_rate=HTTPRequestRateMetric(
            target_value=50, window="5m", granularity="10s"
        )
    );
    m = keda._build_http_scaled_object(spec);
    metadata = m["body"]["spec"]["triggers"][0]["metadata"];
    assert metadata["targetValue"] == "50";
    assert metadata["window"] == "5m";
    assert metadata["granularity"] == "10s";
}


# --- Section E: standalone-Pod rejection ------------------------------------
test "apply_http_activation rejects a standalone Pod target with a /scale explanation" {
    keda = KEDAAutoscaler();
    spec = _spec(scale_target_name="preview-pod", scale_target_kind="Pod");
    raised = False;
    error_msg = "";
    try {
        keda.apply_http_activation(spec);
    } except ValueError as e {
        raised = True;
        error_msg = str(e);
    }
    assert raised , "Expected ValueError when scale_target_kind is Pod";
    assert "/scale" in error_msg , "Error message must explain the /scale requirement";
}

test "apply_http_activation accepts a StatefulSet target without raising" {
    (keda, custom_api, _, _) = _mocked_keda();
    custom_api.get_namespaced_custom_object.side_effect = ApiException(status=404);
    spec = _spec(
        scale_target_name="preview-statefulset", scale_target_kind="StatefulSet"
    );
    result = keda.apply_http_activation(spec);
    assert result == True;
}

test "apply_http_activation raises for an unrecognized scale_target_kind when scale_target_plural is unset" {
    (keda, custom_api, apps_api, _) = _mocked_keda();
    spec = _spec(scale_target_name="preview-rollout", scale_target_kind="Rollout");
    raised = False;
    error_msg = "";
    try {
        keda.apply_http_activation(spec);
    } except ValueError as e {
        raised = True;
        error_msg = str(e);
    }
    assert raised , "Expected ValueError when scale_target_kind is unrecognized and scale_target_plural is unset";
    assert "Rollout" in error_msg;
    assert "scale_target_plural" in error_msg;
    apps_api.read_namespaced_deployment.assert_not_called();
    apps_api.read_namespaced_stateful_set.assert_not_called();
    custom_api.create_namespaced_custom_object.assert_not_called();
}

test "apply_http_activation validates a custom target when scale_target_plural is set" {
    (keda, custom_api, apps_api, _) = _mocked_keda();
    spec = _spec(
        scale_target_name="preview-rollout",
        scale_target_kind="Rollout",
        scale_target_api_version="argoproj.io/v1alpha1",
        scale_target_plural="rollouts"
    );
    result = keda.apply_http_activation(spec);
    assert result == True;
    apps_api.read_namespaced_deployment.assert_not_called();
    apps_api.read_namespaced_stateful_set.assert_not_called();
    target_check_calls = [
        c
        for c in custom_api.get_namespaced_custom_object.call_args_list
        if c[1].get("plural") == "rollouts"
    ];
    assert len(target_check_calls) == 1;
    assert target_check_calls[0][1]["group"] == "argoproj.io";
    assert target_check_calls[0][1]["version"] == "v1alpha1";
    assert target_check_calls[0][1]["name"] == "preview-rollout";
}

test "apply_http_activation raises when a custom target with scale_target_plural is missing" {
    (keda, custom_api, _, _) = _mocked_keda();
    custom_api.get_namespaced_custom_object.side_effect = ApiException(status=404);
    spec = _spec(
        scale_target_name="missing-rollout",
        scale_target_kind="Rollout",
        scale_target_api_version="argoproj.io/v1alpha1",
        scale_target_plural="rollouts"
    );
    raised = False;
    try {
        keda.apply_http_activation(spec);
    } except ValueError as e {
        raised = True;
    }
    assert raised , "Expected ValueError when a custom target with scale_target_plural is missing";
    custom_api.create_namespaced_custom_object.assert_not_called();
}


# --- Section F: naming -------------------------------------------------------
test "InterceptorRoute and ScaledObject names are deterministic and distinct" {
    keda = KEDAAutoscaler();
    route_name = keda.interceptor_route_name_for("preview-deployment");
    scaled_obj_name = keda.http_scaled_object_name_for("preview-deployment");
    assert route_name != scaled_obj_name;
    assert route_name == keda.interceptor_route_name_for("preview-deployment");
    assert scaled_obj_name == keda.http_scaled_object_name_for("preview-deployment");
}


# --- Section G: apply ordering, validation, and preflight -------------------
test "apply_http_activation creates InterceptorRoute before ScaledObject when neither exists" {
    (keda, custom_api, _, _) = _mocked_keda();
    custom_api.get_namespaced_custom_object.side_effect = ApiException(status=404);
    result = keda.apply_http_activation(_spec());
    assert result == True;
    create_calls = custom_api.create_namespaced_custom_object.call_args_list;
    assert len(create_calls) == 2;
    assert create_calls[0][1]["plural"] == "interceptorroutes";
    assert create_calls[1][1]["plural"] == "scaledobjects";
}

test "apply_http_activation patches InterceptorRoute and ScaledObject when both already exist" {
    (keda, custom_api, _, _) = _mocked_keda();
    custom_api.get_namespaced_custom_object.return_value = {
        "metadata": {"name": "existing"}
    };
    result = keda.apply_http_activation(_spec());
    assert result == True;
    patch_calls = custom_api.patch_namespaced_custom_object.call_args_list;
    assert len(patch_calls) == 2;
    assert patch_calls[0][1]["plural"] == "interceptorroutes";
    assert patch_calls[1][1]["plural"] == "scaledobjects";
    custom_api.create_namespaced_custom_object.assert_not_called();
}

test "apply_http_activation raises when the referenced scale target or Service does not exist" {
    custom_api = unittest.mock.MagicMock();

    missing_target_apps = unittest.mock.MagicMock();
    missing_target_apps.read_namespaced_deployment.side_effect = ApiException(
        status=404
    );
    (keda, _, _, _) = _mocked_keda(custom_api=custom_api, apps_api=missing_target_apps);
    raised_for_missing_target = False;
    try {
        keda.apply_http_activation(_spec(scale_target_name="missing-deployment"));
    } except ValueError as e {
        raised_for_missing_target = True;
    }
    assert raised_for_missing_target , "Expected ValueError when the scale target is missing";

    missing_service_core = unittest.mock.MagicMock();
    missing_service_core.read_namespaced_service.side_effect = ApiException(status=404);
    (keda2, _, _, _) = _mocked_keda(
        custom_api=custom_api, core_api=missing_service_core
    );
    raised_for_missing_service = False;
    try {
        keda2.apply_http_activation(
            _spec(target=HTTPServiceTarget(service="missing-svc", port=8080))
        );
    } except ValueError as e {
        raised_for_missing_service = True;
    }
    assert raised_for_missing_service , "Expected ValueError when the Service is missing";
    custom_api.create_namespaced_custom_object.assert_not_called();
}

test "apply_http_activation returns False and skips creation when HTTP Add-on CRDs are not installed" {
    (keda, custom_api, _, _) = _mocked_keda(http_addon_installed=False);
    result = keda.apply_http_activation(_spec());
    assert result == False;
    custom_api.create_namespaced_custom_object.assert_not_called();
}


# --- Section H: destroy / partial-apply cleanup ------------------------------
test "destroy_http_activation removes both InterceptorRoute and ScaledObject" {
    mock_api = unittest.mock.MagicMock();
    keda = KEDAAutoscaler(_custom_api=mock_api);
    keda.destroy_http_activation("preview-deployment", "staging");
    delete_calls = mock_api.delete_namespaced_custom_object.call_args_list;
    plurals = [c[1]["plural"] for c in delete_calls];
    assert "interceptorroutes" in plurals;
    assert "scaledobjects" in plurals;
}

test "destroy_http_activation is a no-op for the InterceptorRoute when it is already gone" {
    mock_api = unittest.mock.MagicMock();
    mock_api.delete_namespaced_custom_object.side_effect = [
        ApiException(status=404),
        None
    ];
    keda = KEDAAutoscaler(_custom_api=mock_api);
    keda.destroy_http_activation("preview-deployment", "staging");
    assert mock_api.delete_namespaced_custom_object.call_count == 2;
}

test "destroy_collection sweeps InterceptorRoutes alongside ScaledObjects and TriggerAuthentications" {
    mock_api = unittest.mock.MagicMock();
    mock_api.list_namespaced_custom_object.return_value = {
        "items": [{"metadata": {"name": "preview-deployment-http-route"}}]
    };
    keda = KEDAAutoscaler(_custom_api=mock_api, _v2_api=unittest.mock.MagicMock());
    keda.destroy_collection("staging", "managed=jac-scale");
    delete_calls = mock_api.delete_namespaced_custom_object.call_args_list;
    plurals = [c[1]["plural"] for c in delete_calls];
    assert "interceptorroutes" in plurals;
}
