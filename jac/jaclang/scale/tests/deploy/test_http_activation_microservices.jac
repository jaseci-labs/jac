import from kubernetes.client.exceptions { ApiException }
import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
    ManifestBuilder,
    GATEWAY_NAME,
    ScalingMode
}
import from jaclang.scale.deploy.target.kubernetes.target {
    apply_http_activations_for_bundle
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.observability.standard_logger { StandardLogger }
import from jaclang.scale.tests.deploy.http_activation_test_support {
    default_http_activation_config as _cfg,
    mocked_keda_autoscaler as _mocked_keda
}


def _builder(
    services: dict, k8s_config: KubernetesConfig | None = None
) -> ManifestBuilder {
    return ManifestBuilder(
        k8s_config=k8s_config or KubernetesConfig(app_name="t", namespace="t-ns"),
        microservices_config={"services": services},
        dry_run=True
    );
}


# Minimal Deployment/Service manifests: _resolve_scaling only reads
# metadata.name off each, so a full manifest is unnecessary here.
def _dep(name: str) -> dict {
    return {"metadata": {"name": name}};
}


def _svc(name: str) -> dict {
    return {"metadata": {"name": name}};
}


# --- Section A: ManifestBuilder._get_http_activation_config -----------------
# Thin pass-through (config dict in, same merged dict or None out) - the actual
# dict-to-spec translation is build_http_activation_spec's job, already covered
# in test_http_activation_config.jac. This only proves the enabled gate and the
# per-service <- top-level inheritance merge; the gateway exclusion and the
# metric-vs-activation decision live one layer up, in _resolve_scaling.
test "service with http_activation.enabled=true returns the config dict unchanged" {
    b = _builder(
        {"billing_ops": {"http_activation": {"enabled": True, "target_port": 8080}}}
    );
    cfg = b._get_http_activation_config("billing_ops");
    assert cfg is not None;
    assert cfg["target_port"] == 8080;
}

test "service with http_activation disabled or unset returns None" {
    b = _builder(
        {"billing_ops": {"http_activation": {"enabled": False}}, "other_svc": {}}
    );
    assert b._get_http_activation_config("billing_ops") is None;
    assert b._get_http_activation_config("other_svc") is None;
}

test "per-service http_activation inherits unset keys from [scale.kubernetes.http_activation]" {
    b = _builder(
        {"billing_ops": {"http_activation": {"enabled": True, "target_port": 8080}}},
        k8s_config=KubernetesConfig(
            app_name="t",
            namespace="t-ns",
            http_activation={"concurrency_target": 10, "polling_interval": 15}
        )
    );
    cfg = b._get_http_activation_config("billing_ops");
    assert cfg is not None;
    assert cfg["target_port"] == 8080;
    assert cfg["concurrency_target"] == 10;
    assert cfg["polling_interval"] == 15;
}

test "per-service http_activation overrides [scale.kubernetes.http_activation] on shared keys" {
    b = _builder(
        {
            "billing_ops": {
                "http_activation": {"enabled": True, "concurrency_target": 5}
            }
        },
        k8s_config=KubernetesConfig(
            app_name="t",
            namespace="t-ns",
            http_activation={"enabled": True, "concurrency_target": 10}
        )
    );
    cfg = b._get_http_activation_config("billing_ops");
    assert cfg["concurrency_target"] == 5;
}

test "a service with no http_activation block still inherits enabled from the top-level default" {
    b = _builder(
        {"other_svc": {}},
        k8s_config=KubernetesConfig(
            app_name="t",
            namespace="t-ns",
            http_activation={
                "enabled": True,
                "target_port": 8080,
                "concurrency_target": 10
            }
        )
    );
    cfg = b._get_http_activation_config("other_svc");
    assert cfg is not None;
    assert cfg["target_port"] == 8080;
    assert cfg["concurrency_target"] == 10;
}

test "a service can explicitly opt out with enabled=false even when the top-level default is enabled" {
    b = _builder(
        {"opted_out": {"http_activation": {"enabled": False}}},
        k8s_config=KubernetesConfig(
            app_name="t", namespace="t-ns", http_activation={"enabled": True}
        )
    );
    assert b._get_http_activation_config("opted_out") is None;
}


# --- Section B: _resolve_scaling (the single scaling decision) --------------
test "_resolve_scaling: an http_activation service is HTTP_ACTIVATION, carries the {name}-deployment target, and emits no metric autoscaler" {
    b = _builder(
        {"billing_ops": {"http_activation": {"enabled": True, "target_port": 8080}}}
    );
    plan = b._resolve_scaling(
        "billing_ops", _dep("billing-ops-deployment"), _svc("billing-ops-service")
    );
    assert plan["mode"] == ScalingMode.HTTP_ACTIVATION;
    # The scale target is the real Deployment name, never the bare k8s name -
    # this is the exact drift that 404'd apply_http_activation on a real cluster.
    assert plan["scale_target_name"] == "billing-ops-deployment";
    assert plan["service_name"] == "billing-ops-service";
    # Mutual exclusion: activation replaces the metric autoscaler, never coexists
    # (KEDA rejects a second ScaledObject on an HPA-managed target).
    assert plan["autoscaler"] == {};
}

test "_resolve_scaling: the gateway never inherits http_activation even when the top-level default enables it" {
    b = _builder(
        {},
        k8s_config=KubernetesConfig(
            app_name="t",
            namespace="t-ns",
            http_activation={
                "enabled": True,
                "target_port": 8080,
                "concurrency_target": 10
            }
        )
    );
    # A real logger (not None, not a MagicMock) so the gateway-exclusion branch
    # actually calls logger.warn - this is what catches a wrong method name like
    # .warning, which only surfaces on a live deploy otherwise.
    b.logger = StandardLogger();
    plan = b._resolve_scaling(
        GATEWAY_NAME, _dep("gateway-deployment"), _svc("gateway-service")
    );
    # The gateway is the ingress entry point: scaling it to zero black-holes all
    # inbound traffic, so it must never pick up the shared activation default.
    assert plan["mode"] != ScalingMode.HTTP_ACTIVATION;
    assert plan["http_activation"] == {};
}

test "_resolve_scaling: a plain service with the default hpa is METRIC, not activation" {
    b = _builder({"worker": {}});
    plan = b._resolve_scaling(
        "worker", _dep("worker-deployment"), _svc("worker-service")
    );
    assert plan["mode"] == ScalingMode.METRIC;
    assert plan["autoscaler"] != {};
    assert plan["http_activation"] == {};
    assert plan["scale_target_name"] == "worker-deployment";
}


# --- Section C: apply_http_activations_for_bundle (per-service apply loop) ---
test "apply_http_activations_for_bundle applies only HTTP_ACTIVATION services, using the carried scale-target + service names" {
    (keda, custom_api, _, _) = _mocked_keda();
    custom_api.get_namespaced_custom_object.side_effect = ApiException(status=404);
    bundle = {
        "scaling": {
            "billing_ops": {
                "mode": ScalingMode.HTTP_ACTIVATION,
                "scale_target_name": "billing-ops-deployment",
                "service_name": "billing-ops-service",
                "autoscaler": {},
                "http_activation": _cfg()
            },
            "worker": {
                "mode": ScalingMode.METRIC,
                "scale_target_name": "worker-deployment",
                "service_name": "worker-service",
                "autoscaler": {"min": 1, "max": 3},
                "http_activation": {}
            }
        }
    };
    apply_http_activations_for_bundle(bundle, "t-ns", keda);
    create_calls = custom_api.create_namespaced_custom_object.call_args_list;
    # Two resources (InterceptorRoute + ScaledObject) for billing_ops only; the
    # METRIC-mode worker is skipped entirely.
    assert len(create_calls) == 2;
    route_body = create_calls[0][1]["body"];
    assert route_body["spec"]["target"]["service"] == "billing-ops-service";
    assert route_body["metadata"]["namespace"] == "t-ns";
}

test "apply_http_activations_for_bundle is a no-op when no service is in HTTP_ACTIVATION mode" {
    (keda, custom_api, _, _) = _mocked_keda();
    apply_http_activations_for_bundle({}, "t-ns", keda);
    custom_api.create_namespaced_custom_object.assert_not_called();
}
