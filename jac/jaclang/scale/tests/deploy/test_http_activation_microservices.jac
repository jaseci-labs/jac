import from kubernetes.client.exceptions { ApiException }
import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
    ManifestBuilder,
    GATEWAY_NAME,
    ScalingMode
}
import from jaclang.scale.deploy.target.kubernetes.target {
    KubernetesTarget,
    apply_http_activations_for_bundle,
    reap_stale_scaling_resources_for_bundle
}
import unittest.mock;
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

test "per-service http_activation inherits unset keys from [scale.kubernetes.http_activation], down to no per-service block at all" {
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

    # Same merge at its edge: no per-service key at all still inherits
    # `enabled` too -- absent and {} are the same input to the merge.
    b2 = _builder(
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
    cfg2 = b2._get_http_activation_config("other_svc");
    assert cfg2 is not None;
    assert cfg2["target_port"] == 8080;
    assert cfg2["concurrency_target"] == 10;
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
        {
            "billing_ops": {
                "http_activation": {
                    "enabled": True,
                    "target_port": 8080,
                    "concurrency_target": 10,
                    "rules": [{"hosts": ["*"]}]
                }
            }
        }
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


# --- Section D: reap_stale_scaling_resources_for_bundle (mode-switch cleanup)
# A service can switch scaling mode between deploys. Applying the new mode's
# resource never removes the old one on its own, so these prove the reap step
# deletes whichever mode a service is NOT in, for every mode transition -
# exactly what a fresh-deploy-only e2e cannot exercise.
test "a METRIC service has its stale HTTP activation resources reaped, autoscaler left alone" {
    (keda, custom_api, _, _) = _mocked_keda();
    autoscaler = unittest.mock.MagicMock();
    bundle = {
        "scaling": {
            "worker": {
                "mode": ScalingMode.METRIC,
                "scale_target_name": "worker-deployment",
                "service_name": "worker-service",
                "autoscaler": {"min": 1, "max": 3},
                "http_activation": {}
            }
        }
    };
    reap_stale_scaling_resources_for_bundle(bundle, "t-ns", autoscaler, keda);
    autoscaler.destroy.assert_not_called();
    delete_calls = custom_api.delete_namespaced_custom_object.call_args_list;
    assert len(delete_calls) == 2;
    deleted_names = {c[1]["name"] for c in delete_calls};
    assert deleted_names
        == {"worker-deployment-http-route", "worker-deployment-http-scaledobject"};
}

test "an HTTP_ACTIVATION service has its stale metric autoscaler destroyed, activation left alone" {
    (keda, custom_api, _, _) = _mocked_keda();
    autoscaler = unittest.mock.MagicMock();
    autoscaler.resource_name_for.return_value = "billing-ops-deployment-scaledobject";
    bundle = {
        "scaling": {
            "billing_ops": {
                "mode": ScalingMode.HTTP_ACTIVATION,
                "scale_target_name": "billing-ops-deployment",
                "service_name": "billing-ops-service",
                "autoscaler": {},
                "http_activation": _cfg()
            }
        }
    };
    reap_stale_scaling_resources_for_bundle(bundle, "t-ns", autoscaler, keda);
    autoscaler.destroy.assert_called_once_with(
        "billing-ops-deployment-scaledobject", "t-ns"
    );
    custom_api.delete_namespaced_custom_object.assert_not_called();
}

test "a NONE service has both its stale autoscaler and HTTP activation resources reaped" {
    (keda, custom_api, _, _) = _mocked_keda();
    autoscaler = unittest.mock.MagicMock();
    bundle = {
        "scaling": {
            "idle_svc": {
                "mode": ScalingMode.NONE,
                "scale_target_name": "idle-svc-deployment",
                "service_name": "idle-svc-service",
                "autoscaler": {},
                "http_activation": {}
            }
        }
    };
    reap_stale_scaling_resources_for_bundle(bundle, "t-ns", autoscaler, keda);
    autoscaler.destroy.assert_called_once();
    assert len(custom_api.delete_namespaced_custom_object.call_args_list) == 2;
}

test "reap_stale_scaling_resources_for_bundle is a no-op on an empty bundle" {
    (keda, custom_api, _, _) = _mocked_keda();
    autoscaler = unittest.mock.MagicMock();
    reap_stale_scaling_resources_for_bundle({}, "t-ns", autoscaler, keda);
    autoscaler.destroy.assert_not_called();
    custom_api.delete_namespaced_custom_object.assert_not_called();
}


# --- Section E: _validate_http_activation_rules (interceptor routing collisions)
# Two services that both inherit the shared [scale.kubernetes.http_activation]
# default unchanged resolve to identical InterceptorRoute match rules; the
# interceptor then has no way to tell which target a matching request wakes.
test "two services sharing identical non-empty rules raise ValueError" {
    b = _builder({});
    scaling = {
        "billing_ops": {
            "mode": ScalingMode.HTTP_ACTIVATION,
            "http_activation": {"rules": [{"hosts": ["*"]}]}
        },
        "worker": {
            "mode": ScalingMode.HTTP_ACTIVATION,
            "http_activation": {"rules": [{"hosts": ["*"]}]}
        },
        "gateway_ok": {"mode": ScalingMode.METRIC, "http_activation": {}}
    };
    raised = False;
    try {
        b._validate_http_activation_rules(scaling);
    } except ValueError as e {
        raised = True;
        assert "billing_ops" in str(e);
        assert "worker" in str(e);
    }
    assert raised;
}

def _activated(hosts: list[str] | None = None) -> dict[str, any] {
    rules = [{"hosts": hosts}] if hosts else [];
    return {"mode": ScalingMode.HTTP_ACTIVATION, "http_activation": {"rules": rules}};
}

test "distinct rules, both-empty rules, and a lone HTTP_ACTIVATION peer never collide" {
    b = _builder({});
    non_colliding_scalings = [
        # distinct rules per service: no shared match criteria to collide on
        {
            "billing_ops": _activated(["billing.example.com"]),
            "worker": _activated(["worker.example.com"])
        },
        # both empty: already individually dead, not ambiguous with each other
        {"billing_ops": _activated(), "worker": _activated()},
        # only one is HTTP_ACTIVATION; a METRIC peer's rules don't matter
        {
            "billing_ops": _activated(["*"]),
            "worker": {"mode": ScalingMode.METRIC, "http_activation": {}}
        }
    ];
    for scaling in non_colliding_scalings {
        b._validate_http_activation_rules(scaling);
    }
}

test "generate_manifests raises when two services inherit the shared catch-all rule unchanged" {
    import from jaclang.scale.config.app_config { AppConfig }
    services = {"billing_ops": {"http_activation": {"enabled": True}}, "worker": {}};
    b = ManifestBuilder(
        k8s_config=KubernetesConfig(
            app_name="t",
            namespace="t-ns",
            bundle_storage_class="standard",
            http_activation={
                "enabled": True,
                "target_port": 8080,
                "concurrency_target": 10,
                "rules": [{"hosts": ["*"]}]
            }
        ),
        microservices_config={
            "routes": {name: f"/{name}" for name in services},
            "services": services
        },
        dry_run=True
    );
    raised = False;
    try {
        b.generate_manifests(AppConfig(code_folder=".", app_name="t"), "");
    } except ValueError as e {
        raised = True;
        assert "billing_ops" in str(e);
        assert "worker" in str(e);
    }
    assert raised;
}


# --- Section E: _apply_or_replace's patch_body contract ---------------------
# HTTP activation's "a redeploy doesn't reset a scaled-to-zero target" guarantee
# depends entirely on _apply_or_replace sending patch_body (with replicas
# stripped) to `update` instead of the full manifest, while a fresh `create`
# still gets the full manifest. Pin that contract directly so a future change
# to _apply_or_replace can't silently break it.

def _target -> KubernetesTarget {
    return KubernetesTarget(config=KubernetesConfig(app_name="t", namespace="t-ns"));
}


test "_apply_or_replace sends patch_body, not the full manifest, to update when the target exists" {
    mock_api = unittest.mock.MagicMock();
    manifest = {
        "metadata": {"name": "svc-deployment"},
        "spec": {"replicas": 3, "template": {}}
    };
    patch_body = {"metadata": {"name": "svc-deployment"}, "spec": {"template": {}}};
    _target()._apply_or_replace(
        mock_api,
        "read_namespaced_deployment",
        "patch_namespaced_deployment",
        "create_namespaced_deployment",
        "t-ns",
        manifest,
        patch_body
    );
    mock_api.patch_namespaced_deployment.assert_called_once_with(
        name="svc-deployment", namespace="t-ns", body=patch_body
    );
    mock_api.create_namespaced_deployment.assert_not_called();
}


test "_apply_or_replace's create path gets the full manifest, replicas included, even when patch_body omits it" {
    mock_api = unittest.mock.MagicMock();
    mock_api.read_namespaced_deployment.side_effect = ApiException(status=404);
    manifest = {
        "metadata": {"name": "svc-deployment"},
        "spec": {"replicas": 3, "template": {}}
    };
    patch_body = {"metadata": {"name": "svc-deployment"}, "spec": {"template": {}}};
    _target()._apply_or_replace(
        mock_api,
        "read_namespaced_deployment",
        "patch_namespaced_deployment",
        "create_namespaced_deployment",
        "t-ns",
        manifest,
        patch_body
    );
    mock_api.create_namespaced_deployment.assert_called_once_with(
        namespace="t-ns", body=manifest
    );
    mock_api.patch_namespaced_deployment.assert_not_called();
}


test "_apply_or_replace sends the full manifest to update when no patch_body is given" {
    mock_api = unittest.mock.MagicMock();
    manifest = {"metadata": {"name": "svc-deployment"}, "spec": {"replicas": 3}};
    _target()._apply_or_replace(
        mock_api,
        "read_namespaced_deployment",
        "patch_namespaced_deployment",
        "create_namespaced_deployment",
        "t-ns",
        manifest
    );
    mock_api.patch_namespaced_deployment.assert_called_once_with(
        name="svc-deployment", namespace="t-ns", body=manifest
    );
}
