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


# --- Section A: typed model validation -------------------------------------
test "validate rejects a Service target with both port and port_name set" {
    keda = KEDAAutoscaler();
    spec = HTTPActivationSpec(
        name="preview",
        namespace="default",
        scale_target_name="preview-deployment",
        target=HTTPServiceTarget(service="preview-svc", port=8080, port_name="http")
    );
    with self.assertRaises(ValueError) {
        keda._validate_http_activation_spec(spec);
    }
}

test "validate rejects a Service target with neither port nor port_name set" {
    keda = KEDAAutoscaler();
    spec = HTTPActivationSpec(
        name="preview",
        namespace="default",
        scale_target_name="preview-deployment",
        target=HTTPServiceTarget(service="preview-svc")
    );
    with self.assertRaises(ValueError) {
        keda._validate_http_activation_spec(spec);
    }
}

test "validate requires at least one of concurrency or request_rate" {
    keda = KEDAAutoscaler();
    spec = HTTPActivationSpec(
        name="preview",
        namespace="default",
        scale_target_name="preview-deployment",
        target=HTTPServiceTarget(service="preview-svc", port=8080)
    );
    with self.assertRaises(ValueError) {
        keda._validate_http_activation_spec(spec);
    }
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


# --- Section C: InterceptorRoute manifest builder ---------------------------
test "build_interceptor_route produces a complete and valid InterceptorRoute body" {
    keda = KEDAAutoscaler();
    spec = HTTPActivationSpec(
        name="preview",
        namespace="staging",
        scale_target_name="preview-deployment",
        target=HTTPServiceTarget(service="preview-svc", port=8080),
        rules=[HTTPRoutingRule(hosts=["preview.jac.dev"])],
        concurrency=HTTPConcurrencyMetric(target_value=10)
    );
    m = keda._build_interceptor_route(spec);
    body = m["body"];
    assert body["apiVersion"] == "http.keda.sh/v1beta1";
    assert body["kind"] == "InterceptorRoute";
    assert body["metadata"]["namespace"] == "staging";
    assert body["metadata"]["labels"]["managed"] == "jac-scale";
    assert body["spec"]["scaleTargetRef"]["name"] == "preview-deployment";
    assert body["spec"]["scaleTargetRef"]["kind"] == "Deployment";
    assert body["spec"]["service"]["name"] == "preview-svc";
    assert body["spec"]["service"]["port"] == 8080;
    assert len(body["spec"]["rules"]) == 1;
}

test "build_interceptor_route uses port_name instead of port when port is unset" {
    keda = KEDAAutoscaler();
    spec = HTTPActivationSpec(
        name="preview",
        namespace="default",
        scale_target_name="preview-deployment",
        target=HTTPServiceTarget(service="preview-svc", port_name="http"),
        concurrency=HTTPConcurrencyMetric(target_value=10)
    );
    m = keda._build_interceptor_route(spec);
    assert m["body"]["spec"]["service"]["portName"] == "http";
    assert "port" not in m["body"]["spec"]["service"];
}

test "build_interceptor_route includes cold_start placeholder only when set" {
    keda = KEDAAutoscaler();
    base_kwargs = {
        "name": "preview",
        "namespace": "default",
        "scale_target_name": "preview-deployment",
        "target": HTTPServiceTarget(service="preview-svc", port=8080),
        "concurrency": HTTPConcurrencyMetric(target_value=10)
    };
    with_cold_start = keda._build_interceptor_route(
        HTTPActivationSpec(
            **base_kwargs,
            cold_start=HTTPColdStartSpec(
                placeholder=HTTPStaticResponse(status_code=503, body="warming up")
            )
        )
    );
    without_cold_start = keda._build_interceptor_route(
        HTTPActivationSpec(**base_kwargs)
    );
    assert with_cold_start["body"]["spec"]["coldStart"]["placeholder"][
        "statusCode"
    ] == 503;
    assert "coldStart" not in without_cold_start["body"]["spec"];
}

test "build_interceptor_route includes cold_start fallback_service only when set" {
    keda = KEDAAutoscaler();
    spec = HTTPActivationSpec(
        name="preview",
        namespace="default",
        scale_target_name="preview-deployment",
        target=HTTPServiceTarget(service="preview-svc", port=8080),
        concurrency=HTTPConcurrencyMetric(target_value=10),
        cold_start=HTTPColdStartSpec(
            fallback_service=HTTPServiceTarget(service="fallback-svc", port=8080)
        )
    );
    m = keda._build_interceptor_route(spec);
    assert m["body"]["spec"]["coldStart"]["fallbackService"]["name"] == "fallback-svc";
    assert "placeholder" not in m["body"]["spec"]["coldStart"];
}

test "build_interceptor_route includes timeouts only when set, omitted otherwise" {
    keda = KEDAAutoscaler();
    base_kwargs = {
        "name": "preview",
        "namespace": "default",
        "scale_target_name": "preview-deployment",
        "target": HTTPServiceTarget(service="preview-svc", port=8080),
        "concurrency": HTTPConcurrencyMetric(target_value=10)
    };
    with_timeouts = keda._build_interceptor_route(
        HTTPActivationSpec(
            **base_kwargs,
            timeouts=HTTPTimeoutSpec(
                readiness="30s", request="60s", response_header="5s"
            )
        )
    );
    without_timeouts = keda._build_interceptor_route(HTTPActivationSpec(**base_kwargs));
    assert with_timeouts["body"]["spec"]["timeouts"]["readiness"] == "30s";
    assert with_timeouts["body"]["spec"]["timeouts"]["request"] == "60s";
    assert "timeouts" not in without_timeouts["body"]["spec"];
}


# --- Section D: ScaledObject external-push builder --------------------------
test "build_http_scaled_object produces a complete external-push ScaledObject" {
    keda = KEDAAutoscaler();
    spec = HTTPActivationSpec(
        name="preview",
        namespace="staging",
        scale_target_name="preview-deployment",
        target=HTTPServiceTarget(service="preview-svc", port=8080),
        min_replicas=0,
        max_replicas=5,
        concurrency=HTTPConcurrencyMetric(target_value=10)
    );
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
    spec = HTTPActivationSpec(
        name="preview",
        namespace="default",
        scale_target_name="preview-deployment",
        target=HTTPServiceTarget(service="preview-svc", port=8080),
        concurrency=HTTPConcurrencyMetric(target_value=25)
    );
    m = keda._build_http_scaled_object(spec);
    metadata = m["body"]["spec"]["triggers"][0]["metadata"];
    assert metadata["targetValue"] == "25";
    assert "window" not in metadata;
}

test "build_http_scaled_object encodes request_rate metric with window and granularity" {
    keda = KEDAAutoscaler();
    spec = HTTPActivationSpec(
        name="preview",
        namespace="default",
        scale_target_name="preview-deployment",
        target=HTTPServiceTarget(service="preview-svc", port=8080),
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
    spec = HTTPActivationSpec(
        name="preview",
        namespace="default",
        scale_target_name="preview-pod",
        scale_target_kind="Pod",
        target=HTTPServiceTarget(service="preview-svc", port=8080),
        concurrency=HTTPConcurrencyMetric(target_value=10)
    );
    with self.assertRaises(ValueError) as ctx {
        keda.apply_http_activation(spec);
    }
    assert "/scale" in str(ctx.exception);
}

test "apply_http_activation accepts a StatefulSet target without raising" {
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.return_value = {};
    mock_api.get_namespaced_custom_object.side_effect = ApiException(status=404);
    mock_apps = unittest.mock.MagicMock();
    mock_core = unittest.mock.MagicMock();
    keda = KEDAAutoscaler(
        _custom_api=mock_api, _apps_api=mock_apps, _core_api=mock_core
    );
    spec = HTTPActivationSpec(
        name="preview",
        namespace="default",
        scale_target_name="preview-statefulset",
        scale_target_kind="StatefulSet",
        target=HTTPServiceTarget(service="preview-svc", port=8080),
        concurrency=HTTPConcurrencyMetric(target_value=10)
    );
    result = keda.apply_http_activation(spec);
    assert result == True;
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
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.return_value = {};
    mock_api.get_namespaced_custom_object.side_effect = ApiException(status=404);
    mock_apps = unittest.mock.MagicMock();
    mock_core = unittest.mock.MagicMock();
    keda = KEDAAutoscaler(
        _custom_api=mock_api, _apps_api=mock_apps, _core_api=mock_core
    );
    spec = HTTPActivationSpec(
        name="preview",
        namespace="default",
        scale_target_name="preview-deployment",
        target=HTTPServiceTarget(service="preview-svc", port=8080),
        concurrency=HTTPConcurrencyMetric(target_value=10)
    );
    result = keda.apply_http_activation(spec);
    assert result == True;
    create_calls = mock_api.create_namespaced_custom_object.call_args_list;
    assert len(create_calls) == 2;
    assert create_calls[0][1]["plural"] == "interceptorroutes";
    assert create_calls[1][1]["plural"] == "scaledobjects";
}

test "apply_http_activation patches InterceptorRoute and ScaledObject when both already exist" {
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.return_value = {};
    mock_api.get_namespaced_custom_object.return_value = {
        "metadata": {"name": "existing"}
    };
    mock_apps = unittest.mock.MagicMock();
    mock_core = unittest.mock.MagicMock();
    keda = KEDAAutoscaler(
        _custom_api=mock_api, _apps_api=mock_apps, _core_api=mock_core
    );
    spec = HTTPActivationSpec(
        name="preview",
        namespace="default",
        scale_target_name="preview-deployment",
        target=HTTPServiceTarget(service="preview-svc", port=8080),
        concurrency=HTTPConcurrencyMetric(target_value=10)
    );
    result = keda.apply_http_activation(spec);
    assert result == True;
    patch_calls = mock_api.patch_namespaced_custom_object.call_args_list;
    assert len(patch_calls) == 2;
    assert patch_calls[0][1]["plural"] == "interceptorroutes";
    assert patch_calls[1][1]["plural"] == "scaledobjects";
    mock_api.create_namespaced_custom_object.assert_not_called();
}

test "apply_http_activation raises when the referenced scale target or Service does not exist" {
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.return_value = {};

    missing_target_apps = unittest.mock.MagicMock();
    missing_target_apps.read_namespaced_deployment.side_effect = ApiException(
        status=404
    );
    keda = KEDAAutoscaler(
        _custom_api=mock_api,
        _apps_api=missing_target_apps,
        _core_api=unittest.mock.MagicMock()
    );
    spec = HTTPActivationSpec(
        name="preview",
        namespace="default",
        scale_target_name="missing-deployment",
        target=HTTPServiceTarget(service="preview-svc", port=8080),
        concurrency=HTTPConcurrencyMetric(target_value=10)
    );
    with self.assertRaises(ValueError) {
        keda.apply_http_activation(spec);
    }

    missing_service_core = unittest.mock.MagicMock();
    missing_service_core.read_namespaced_service.side_effect = ApiException(status=404);
    keda2 = KEDAAutoscaler(
        _custom_api=mock_api,
        _apps_api=unittest.mock.MagicMock(),
        _core_api=missing_service_core
    );
    spec2 = HTTPActivationSpec(
        name="preview",
        namespace="default",
        scale_target_name="preview-deployment",
        target=HTTPServiceTarget(service="missing-svc", port=8080),
        concurrency=HTTPConcurrencyMetric(target_value=10)
    );
    with self.assertRaises(ValueError) {
        keda2.apply_http_activation(spec2);
    }
    mock_api.create_namespaced_custom_object.assert_not_called();
}

test "apply_http_activation returns False and skips creation when HTTP Add-on CRDs are not installed" {
    KEDAAutoscaler._http_preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.side_effect = ApiException(status=404);
    mock_apps = unittest.mock.MagicMock();
    mock_core = unittest.mock.MagicMock();
    keda = KEDAAutoscaler(
        _custom_api=mock_api, _apps_api=mock_apps, _core_api=mock_core
    );
    spec = HTTPActivationSpec(
        name="preview",
        namespace="default",
        scale_target_name="preview-deployment",
        target=HTTPServiceTarget(service="preview-svc", port=8080),
        concurrency=HTTPConcurrencyMetric(target_value=10)
    );
    result = keda.apply_http_activation(spec);
    assert result == False;
    mock_api.create_namespaced_custom_object.assert_not_called();
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
