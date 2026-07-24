import from kubernetes.client.exceptions { ApiException }
import from jaclang.scale.deploy.target.kubernetes.microservice.manifest_builder {
    MicroserviceManifestBuilder
}
import from jaclang.scale.deploy.target.kubernetes.microservice.target {
    apply_http_activations_for_bundle
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.tests.deploy.http_activation_test_support {
    default_http_activation_config as _cfg,
    mocked_keda_autoscaler as _mocked_keda
}


def _builder(services: dict) -> MicroserviceManifestBuilder {
    return MicroserviceManifestBuilder(
        k8s_config=KubernetesConfig(app_name="t", namespace="t-ns"),
        microservices_config={"services": services},
        dry_run=True
    );
}


# --- Section A: MicroserviceManifestBuilder._get_http_activation_config -----
# Thin pass-through (config dict in, same dict or None out) - the actual
# dict-to-spec translation is build_http_activation_spec's job, already
# covered in test_http_activation_config.jac. This only needs to prove the
# enabled gate, matching how _get_autoscaler_config gates on hpa.enabled.
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
    b = MicroserviceManifestBuilder(
        k8s_config=KubernetesConfig(
            app_name="t",
            namespace="t-ns",
            http_activation={"concurrency_target": 10, "polling_interval": 15}
        ),
        microservices_config={
            "services": {
                "billing_ops": {
                    "http_activation": {"enabled": True, "target_port": 8080}
                }
            }
        },
        dry_run=True
    );
    cfg = b._get_http_activation_config("billing_ops");
    assert cfg is not None;
    assert cfg["target_port"] == 8080;
    assert cfg["concurrency_target"] == 10;
    assert cfg["polling_interval"] == 15;
}

test "per-service http_activation overrides [scale.kubernetes.http_activation] on shared keys" {
    b = MicroserviceManifestBuilder(
        k8s_config=KubernetesConfig(
            app_name="t",
            namespace="t-ns",
            http_activation={"enabled": True, "concurrency_target": 10}
        ),
        microservices_config={
            "services": {
                "billing_ops": {
                    "http_activation": {"enabled": True, "concurrency_target": 5}
                }
            }
        },
        dry_run=True
    );
    cfg = b._get_http_activation_config("billing_ops");
    assert cfg["concurrency_target"] == 5;
}

test "a service with no http_activation block still inherits enabled from the top-level default" {
    b = MicroserviceManifestBuilder(
        k8s_config=KubernetesConfig(
            app_name="t",
            namespace="t-ns",
            http_activation={
                "enabled": True,
                "target_port": 8080,
                "concurrency_target": 10
            }
        ),
        microservices_config={"services": {"other_svc": {}}},
        dry_run=True
    );
    cfg = b._get_http_activation_config("other_svc");
    assert cfg is not None;
    assert cfg["target_port"] == 8080;
    assert cfg["concurrency_target"] == 10;
}

test "a service can explicitly opt out with enabled=false even when the top-level default is enabled" {
    b = MicroserviceManifestBuilder(
        k8s_config=KubernetesConfig(
            app_name="t", namespace="t-ns", http_activation={"enabled": True}
        ),
        microservices_config={
            "services": {"opted_out": {"http_activation": {"enabled": False}}}
        },
        dry_run=True
    );
    assert b._get_http_activation_config("opted_out") is None;
}


# --- Section B: apply_http_activations_for_bundle (per-service apply loop) --
test "apply_http_activations_for_bundle calls apply_http_activation only for the enabled service, targeting its own Service" {
    (keda, custom_api, _, _) = _mocked_keda();
    custom_api.get_namespaced_custom_object.side_effect = ApiException(status=404);
    bundle = {
        "http_activations": {"billing_ops": _cfg(), "other_svc": _cfg(enabled=False)}
    };
    apply_http_activations_for_bundle(bundle, "t-ns", keda);
    create_calls = custom_api.create_namespaced_custom_object.call_args_list;
    assert len(create_calls) == 2;
    route_body = create_calls[0][1]["body"];
    assert route_body["spec"]["target"]["service"] == "billing-ops-service";
    assert route_body["metadata"]["namespace"] == "t-ns";
}

test "apply_http_activations_for_bundle is a no-op when the bundle has no http_activations key" {
    (keda, custom_api, _, _) = _mocked_keda();
    apply_http_activations_for_bundle({}, "t-ns", keda);
    custom_api.create_namespaced_custom_object.assert_not_called();
}
