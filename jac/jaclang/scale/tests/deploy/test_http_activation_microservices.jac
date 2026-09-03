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
import from jaclang.scale.deploy.autoscale.keda_autoscaler { KEDAAutoscaler }
import from jaclang.scale.deploy.autoscale.autoscaler {
    AutoscalerSpec,
    Trigger,
    TriggerAuth
}
import from jaclang.scale.deploy.autoscale.http_activation {
    HTTPRoutingRule,
    HTTPPathMatch,
    HTTPHeaderMatch,
    HTTPServiceTarget,
    HTTPRequestRateMetric,
    HTTPStaticResponse,
    HTTPColdStartSpec,
    HTTPTimeoutSpec
}
import from jaclang.scale.tests.deploy.http_activation_test_support {
    default_http_activation_config as _cfg,
    default_http_activation_spec as _spec,
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

test "apply_http_activations_for_bundle is a no-op on an empty bundle" {
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
    assert deleted_names == {
        "worker-deployment-http-route",
        "worker-deployment-http-scaledobject"
    };
}

test "an HTTP_ACTIVATION service has its stale metric autoscaler destroyed, activation left alone" {
    # destroy() resolves its own resource name internally (resource_name_for
    # is called inside KEDAAutoscaler.destroy / HPAAutoscaler.destroy), so
    # the reap call site must pass the plain k8s-safe service name, not a
    # pre-resolved one -- a MagicMock with a canned resource_name_for return
    # would stay green even if the call site started double-wrapping it, so
    # this pins the literal argument destroy() receives instead.
    (keda, custom_api, _, _) = _mocked_keda();
    autoscaler = unittest.mock.MagicMock();
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
    autoscaler.destroy.assert_called_once_with("billing-ops", "t-ns");
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
    import tempfile;
    import from pathlib { Path }
    services = {"billing_ops": {"http_activation": {"enabled": True}}, "worker": {}};
    with tempfile.TemporaryDirectory() as project {
        for name in list(services.keys()) + ["main"] {
            (Path(project) / f"{name}.jac").write_text("");
        }
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
            b.generate_manifests(AppConfig(code_folder=project, app_name="t"), "");
        } except ValueError as e {
            raised = True;
            assert "billing_ops" in str(e);
            assert "worker" in str(e);
        }
        assert raised;
    }
}


# --- Section F: _apply_or_replace's patch_body contract ---------------------
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


# --- Section G: KEDA ScaledObject/TriggerAuthentication -- manifest shape,
# apply/redeploy sequencing, and destroy, exercised together end to end
# instead of one private helper at a time. Only the Kubernetes API client is
# mocked; KEDAAutoscaler.apply()/destroy() run for real.
def _as_any(v: any) -> any {
    return v;
}

def _keda_apply_mocks -> tuple[any, any];

impl _keda_apply_mocks -> tuple[any, any] {
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.return_value = {};
    mock_api.get_namespaced_custom_object.side_effect = ApiException(status=404);
    return (mock_api, unittest.mock.MagicMock());
}

test "apply() produces a complete multi-trigger ScaledObject, creates its TriggerAuthentication first with the right labels, and rejects a duplicate trigger identity before any write" {
    (mock_api, mock_v2) = _keda_apply_mocks();
    keda = KEDAAutoscaler(_custom_api=mock_api, _v2_api=mock_v2);
    spec = AutoscalerSpec(
        scale_target_name="orders-deployment",
        app_name="orders",
        namespace="staging",
        min_replicas=2,
        max_replicas=10,
        idle_replicas=0,
        initial_cooldown_period=120,
        behavior_overlay={
            "scaleDown": {"stabilizationWindowSeconds": 600, "selectPolicy": "Min"}
        },
        triggers=[
            Trigger(type="cpu", metadata={"averageUtilization": "60"}),
            Trigger(type="memory", metadata={}),
            Trigger(
                type="prometheus",
                metadata={"serverAddress": "http://prom:9090", "threshold": 100}
            ),
            Trigger(
                type="redis",
                metadata={"address": "redis:6379"},
                name="cache",
                auth=TriggerAuth(
                    secret_refs={"password": {"name": "redis-secret", "key": "pw"}}
                )
            )
        ]
    );
    result = keda.apply(spec);
    assert result == True;

    create_calls = mock_api.create_namespaced_custom_object.call_args_list;
    assert len(create_calls) == 2;
    assert create_calls[0][1]["plural"] == "triggerauthentications";
    assert create_calls[1][1]["plural"] == "scaledobjects";

    ta_body = create_calls[0][1]["body"];
    so_body = create_calls[1][1]["body"];
    assert ta_body["metadata"]["labels"]["app"] == "orders";
    assert so_body["metadata"]["name"] == "orders-scaledobject";
    assert ta_body["metadata"]["labels"]["jac-scale/owner"] == "orders-scaledobject";
    triggers = so_body["spec"]["triggers"];
    ref_name = triggers[3]["authenticationRef"]["name"];
    assert ta_body["metadata"]["name"] == ref_name;

    assert so_body["spec"]["scaleTargetRef"]["name"] == "orders-deployment";
    assert so_body["spec"]["minReplicaCount"] == 2;
    assert so_body["spec"]["maxReplicaCount"] == 10;
    assert so_body["spec"]["idleReplicaCount"] == 0;
    assert so_body["spec"]["initialCooldownPeriod"] == 120;
    assert [t["type"] for t in triggers] == ["cpu", "memory", "prometheus", "redis"];
    # cpu/memory resolve to KEDA's Utilization shape, memory defaulting to 80
    # when its metadata is empty; a non-resource type carries no metricType
    # and coerces integer metadata values to strings for the KEDA API.
    assert triggers[0]["metricType"] == "Utilization";
    assert triggers[0]["metadata"]["value"] == "60";
    assert triggers[1]["metricType"] == "Utilization";
    assert triggers[1]["metadata"]["value"] == "80";
    assert "metricType" not in triggers[2];
    assert triggers[2]["metadata"]["threshold"] == "100";
    assert triggers[3]["name"] == "cache";
    behavior = so_body["spec"]["advanced"]["horizontalPodAutoscalerConfig"]["behavior"];
    assert behavior["scaleDown"]["selectPolicy"] == "Min";

    dup_spec = AutoscalerSpec(
        scale_target_name="orders-deployment",
        app_name="orders",
        namespace="staging",
        triggers=[
            Trigger(type="redis", metadata={}, name="cache"),
            Trigger(type="rabbitmq", metadata={}, name="cache")
        ]
    );
    raised = False;
    try {
        keda.apply(dup_spec);
    } except ValueError as e {
        raised = True;
        assert "cache" in str(e);
    }
    assert raised;
    # The rejected spec must not have written anything beyond the first apply.
    assert len(mock_api.create_namespaced_custom_object.call_args_list) == 2;
}

test "redeploy patches the ScaledObject instead of duplicating it, prunes a dropped trigger's TriggerAuthentication, and keeps one still referenced" {
    (mock_api, mock_v2) = _keda_apply_mocks();
    keda = KEDAAutoscaler(_custom_api=mock_api, _v2_api=mock_v2);
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        app_name="svc",
        namespace="default",
        triggers=[
            Trigger(
                type="redis",
                metadata={"address": "redis:6379"},
                name="cache",
                auth=TriggerAuth(
                    secret_refs={"password": {"name": "redis-secret", "key": "pw"}}
                )
            )
        ]
    );
    keda.apply(spec);

    # Redeploy dropping the auth trigger: the ScaledObject now exists (get
    # succeeds) and the stale TriggerAuthentication is still on the cluster.
    stale_ta_name = mock_api.create_namespaced_custom_object.call_args_list[0][1][
        "body"
    ]["metadata"]["name"];
    mock_api.get_namespaced_custom_object.side_effect = None;
    mock_api.get_namespaced_custom_object.return_value = {
        "metadata": {"name": "svc-deployment-scaledobject"}
    };
    mock_api.list_namespaced_custom_object.return_value = {
        "items": [{"metadata": {"name": stale_ta_name}}]
    };
    result = keda.apply(
        AutoscalerSpec(
            scale_target_name="svc-deployment",
            app_name="svc",
            namespace="default",
            triggers=[Trigger(type="cpu", metadata={})]
        )
    );
    assert result == True;
    patch_calls = [
        c
        for c in mock_api.patch_namespaced_custom_object.call_args_list
        if c[1]["plural"] == "scaledobjects"
    ];
    assert len(patch_calls) == 1;
    prune_calls = [
        c
        for c in mock_api.delete_namespaced_custom_object.call_args_list
        if c[1]["plural"] == "triggerauthentications"
    ];
    assert len(prune_calls) == 1;
    assert prune_calls[0][1]["name"] == stale_ta_name;

    # A third deploy that keeps the same auth trigger must not prune it.
    mock_api.delete_namespaced_custom_object.reset_mock();
    keda2 = KEDAAutoscaler(_custom_api=mock_api, _v2_api=mock_v2);
    keep_spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        app_name="svc",
        namespace="default",
        triggers=[
            Trigger(
                type="redis",
                metadata={"address": "redis:6379"},
                name="cache",
                auth=TriggerAuth(
                    secret_refs={"password": {"name": "redis-secret", "key": "pw"}}
                )
            )
        ]
    );
    desired_name = keda2._trigger_auth_name("svc", keep_spec.triggers[0], 0);
    mock_api.list_namespaced_custom_object.return_value = {
        "items": [{"metadata": {"name": desired_name}}]
    };
    keda2.apply(keep_spec);
    kept_prune_calls = [
        c
        for c in mock_api.delete_namespaced_custom_object.call_args_list
        if c[1]["plural"] == "triggerauthentications"
    ];
    assert len(kept_prune_calls) == 0;
}

test "switching the autoscaler engine to keda deletes a competing HPA (a no-op when none exists), and a missing CRD skips creation with a cached, logged diagnostic" {
    (mock_api, mock_v2) = _keda_apply_mocks();
    mock_logger = unittest.mock.MagicMock();
    keda = KEDAAutoscaler(
        _custom_api=mock_api, _v2_api=mock_v2, logger=_as_any(mock_logger)
    );
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        app_name="svc",
        namespace="default",
        triggers=[Trigger(type="cpu", metadata={})]
    );
    keda.apply(spec);
    mock_v2.delete_namespaced_horizontal_pod_autoscaler.assert_called_once_with(
        name="svc-hpa", namespace="default"
    );

    mock_v2.delete_namespaced_horizontal_pod_autoscaler.side_effect = ApiException(
        status=404
    );
    keda2 = KEDAAutoscaler(_custom_api=mock_api, _v2_api=mock_v2);
    assert keda2.apply(spec) == True , "engine-switch HPA deletion must be a no-op, not a failure, when no HPA exists";

    KEDAAutoscaler._preflight_cache.clear();
    missing_crd_api = unittest.mock.MagicMock();
    missing_crd_api.list_cluster_custom_object.side_effect = ApiException(status=404);
    keda3 = KEDAAutoscaler(_custom_api=missing_crd_api, logger=_as_any(mock_logger));
    assert keda3.apply(spec) == False;
    missing_crd_api.create_namespaced_custom_object.assert_not_called();
    mock_logger.warn.assert_called_once();
    warn_msg = mock_logger.warn.call_args[0][0];
    assert "KEDA CRDs not found" in warn_msg;
    assert "keda.sh/docs" in warn_msg;
    keda3.preflight();
    assert missing_crd_api.list_cluster_custom_object.call_count == 1 , "the missing-CRD result must be cached, not re-queried";
}

test "destroy sweeps the ScaledObject and every TriggerAuthentication it owns, tolerating an already-gone resource or an absent TriggerAuthentication CRD; destroy_collection also sweeps competing HPAs and is silent when KEDA itself is not installed" {
    mock_api = unittest.mock.MagicMock();
    mock_api.list_namespaced_custom_object.return_value = {
        "items": [{"metadata": {"name": "my-svc-scaledobject-89abcdef-ta"}}]
    };
    keda = KEDAAutoscaler(_custom_api=mock_api);
    keda.destroy("my-svc", "staging");
    mock_api.list_namespaced_custom_object.assert_called_once_with(
        group="keda.sh",
        version="v1alpha1",
        namespace="staging",
        plural="triggerauthentications",
        label_selector="jac-scale/owner=my-svc-scaledobject,managed=jac-scale"
    );
    delete_calls = mock_api.delete_namespaced_custom_object.call_args_list;
    assert len(delete_calls) == 2;
    assert delete_calls[0][1]["plural"] == "triggerauthentications";
    assert delete_calls[0][1]["name"] == "my-svc-scaledobject-89abcdef-ta";
    assert delete_calls[1][1]["plural"] == "scaledobjects";
    assert delete_calls[1][1]["name"] == "my-svc-scaledobject";

    # Already gone: a 404 on both deletes is tolerated, not raised.
    mock_api2 = unittest.mock.MagicMock();
    mock_api2.list_namespaced_custom_object.return_value = {"items": []};
    mock_api2.delete_namespaced_custom_object.side_effect = ApiException(status=404);
    KEDAAutoscaler(_custom_api=mock_api2).destroy("my-svc", "staging");

    # TriggerAuthentication CRD absent entirely: the ScaledObject delete
    # still runs.
    mock_api3 = unittest.mock.MagicMock();
    mock_api3.list_namespaced_custom_object.side_effect = ApiException(status=404);
    KEDAAutoscaler(_custom_api=mock_api3).destroy("my-svc", "staging");
    mock_api3.delete_namespaced_custom_object.assert_called_once_with(
        group="keda.sh",
        version="v1alpha1",
        namespace="staging",
        plural="scaledobjects",
        name="my-svc-scaledobject"
    );

    # destroy_collection sweeps ScaledObjects, TriggerAuthentications, and
    # InterceptorRoutes together, plus any competing HPA, and stays silent
    # when the CRD group itself is missing (404/422).
    mock_api4 = unittest.mock.MagicMock();
    mock_api4.list_namespaced_custom_object.return_value = {
        "items": [{"metadata": {"name": "svc-scaledobject"}}]
    };
    mock_v2 = unittest.mock.MagicMock();
    KEDAAutoscaler(_custom_api=mock_api4, _v2_api=mock_v2).destroy_collection(
        "staging", "managed=jac-scale"
    );
    plurals = [
        c[1]["plural"] for c in mock_api4.delete_namespaced_custom_object.call_args_list
    ];
    assert set(plurals) == {
        "scaledobjects",
        "triggerauthentications",
        "interceptorroutes"
    };
    mock_v2.delete_collection_namespaced_horizontal_pod_autoscaler.assert_called_once_with(
        namespace="staging", label_selector="managed=jac-scale"
    );

    for status in (404, 422) {
        mock_api5 = unittest.mock.MagicMock();
        mock_api5.list_namespaced_custom_object.side_effect = ApiException(
            status=status
        );
        KEDAAutoscaler(
            _custom_api=mock_api5, _v2_api=unittest.mock.MagicMock()
        ).destroy_collection(
            "staging", "managed=jac-scale"
        );
    }
}


# --- Section H: KEDA HTTP Add-on activation -- InterceptorRoute/ScaledObject
# shape, apply ordering, target validation, capability discovery, and
# destroy, exercised together end to end. Only the Kubernetes API client is
# mocked; KEDAAutoscaler.apply_http_activation()/destroy_http_activation()
# run for real.
test "apply_http_activation encodes multi-rule routing (AND-within-rule, OR-between-rules, multi-path expansion), cold_start, timeouts, and request_rate, then creates InterceptorRoute before ScaledObject; a redeploy patches both instead of duplicating" {
    (keda, custom_api, _, _) = _mocked_keda();
    custom_api.get_namespaced_custom_object.side_effect = ApiException(status=404);
    spec = _spec(
        namespace="staging",
        rules=[
            HTTPRoutingRule(
                hosts=["preview.jac.dev"],
                paths=[HTTPPathMatch(value="/app"), HTTPPathMatch(value="/api")],
                headers=[HTTPHeaderMatch(name="x-preview-id", value="123")]
            ),
            HTTPRoutingRule(hosts=["fallback.jac.dev"])
        ],
        cold_start=HTTPColdStartSpec(
            placeholder=HTTPStaticResponse(status_code=503, body="warming up"),
            fallback_service=HTTPServiceTarget(service="fallback-svc", port=8080)
        ),
        timeouts=HTTPTimeoutSpec(readiness="30s", request="60s", response_header="5s"),
        concurrency=None,
        request_rate=HTTPRequestRateMetric(
            target_value=50, rate_window="5m", granularity="10s"
        )
    );
    result = keda.apply_http_activation(spec);
    assert result == True;

    create_calls = custom_api.create_namespaced_custom_object.call_args_list;
    assert len(create_calls) == 2;
    assert create_calls[0][1]["plural"] == "interceptorroutes";
    assert create_calls[1][1]["plural"] == "scaledobjects";

    route_spec = create_calls[0][1]["body"]["spec"];
    # The multi-path rule expands into two OR-grouped match blocks, each
    # still carrying its shared hosts/headers (AND-within-rule); the
    # single-host fallback rule stays its own separate block.
    assert len(route_spec["rules"]) == 3;
    app_rules = [
        r
        for r in route_spec["rules"]
        if r["hosts"] == ["preview.jac.dev"]
    ];
    assert len(app_rules) == 2;
    path_values = [r["path"]["value"] for r in app_rules];
    assert sorted(path_values) == ["/api", "/app"];
    for r in app_rules {
        assert r["headers"][0]["name"] == "x-preview-id";
    }
    fallback_rules = [
        r
        for r in route_spec["rules"]
        if r["hosts"] == ["fallback.jac.dev"]
    ];
    assert len(fallback_rules) == 1;
    assert "path" not in fallback_rules[0];

    assert route_spec["coldStart"]["placeholder"]["response"]["statusCode"] == 503;
    assert route_spec["coldStart"]["fallback"]["service"]["name"] == "fallback-svc";
    assert route_spec["timeouts"]["readiness"] == "30s";
    assert route_spec["timeouts"]["request"] == "60s";
    scaling_metric = route_spec["scalingMetric"];
    assert scaling_metric["requestRate"]["targetValue"] == 50;
    assert scaling_metric["requestRate"]["window"] == "5m";
    assert "concurrency" not in scaling_metric;

    so_spec = create_calls[1][1]["body"]["spec"];
    trigger_metadata = so_spec["triggers"][0]["metadata"];
    assert trigger_metadata["targetValue"] == "50";
    assert trigger_metadata["window"] == "5m";
    assert trigger_metadata["granularity"] == "10s";
    assert so_spec["triggers"][0]["metadata"]["interceptorRoute"] == keda.interceptor_route_name_for(
        spec.scale_target_name
    );

    # Redeploy: both resources now exist, so both get patched, not recreated.
    custom_api.get_namespaced_custom_object.side_effect = None;
    custom_api.get_namespaced_custom_object.return_value = {
        "metadata": {"name": "existing"}
    };
    keda.apply_http_activation(spec);
    patch_calls = custom_api.patch_namespaced_custom_object.call_args_list;
    assert len(patch_calls) == 2;
    assert patch_calls[0][1]["plural"] == "interceptorroutes";
    assert patch_calls[1][1]["plural"] == "scaledobjects";
    assert len(custom_api.create_namespaced_custom_object.call_args_list) == 2 , "the redeploy must not create a second time";
}

test "apply_http_activation validates the spec itself (port XOR port_name, concurrency or request_rate) and its scale target and Service before writing anything: rejects a bare Pod, an unrecognized kind without scale_target_plural, and a missing target or Service; accepts a StatefulSet and a custom kind with scale_target_plural set" {
    rejections = [
        (
            "bare Pod",
            _spec(scale_target_name="preview-pod", scale_target_kind="Pod"),
            "/scale"
        ),
        (
            "unrecognized kind, no plural",
            _spec(scale_target_name="preview-rollout", scale_target_kind="Rollout"),
            "scale_target_plural"
        ),
        (
            "both port and port_name set",
            _spec(
                target=HTTPServiceTarget(
                    service="preview-svc", port=8080, port_name="http"
                )
            ),
            "not both"
        ),
        (
            "neither port nor port_name set",
            _spec(target=HTTPServiceTarget(service="preview-svc")),
            "must set exactly one of port or port_name."
        ),
        (
            "neither concurrency nor request_rate set",
            _spec(concurrency=None),
            "concurrency or request_rate"
        )
    ];
    for (label, spec, expected_substring) in rejections {
        (keda, custom_api, _, _) = _mocked_keda();
        raised = False;
        error_msg = "";
        try {
            keda.apply_http_activation(spec);
        } except ValueError as e {
            raised = True;
            error_msg = str(e);
        }
        assert raised , f"'{label}' must raise ValueError";
        assert expected_substring in error_msg , f"'{label}': expected '{expected_substring}' in: {error_msg}";
        custom_api.create_namespaced_custom_object.assert_not_called();
    }

    (keda2, custom_api2, _, _) = _mocked_keda();
    custom_api2.get_namespaced_custom_object.side_effect = ApiException(status=404);
    assert keda2.apply_http_activation(
        _spec(scale_target_name="preview-sts", scale_target_kind="StatefulSet")
    ) == True;

    (keda3, custom_api3, _, _) = _mocked_keda();
    result = keda3.apply_http_activation(
        _spec(
            scale_target_name="preview-rollout",
            scale_target_kind="Rollout",
            scale_target_api_version="argoproj.io/v1alpha1",
            scale_target_plural="rollouts"
        )
    );
    assert result == True;
    target_checks = [
        c
        for c in custom_api3.get_namespaced_custom_object.call_args_list
        if c[1].get("plural") == "rollouts"
    ];
    assert len(target_checks) == 1;
    assert target_checks[0][1]["group"] == "argoproj.io";

    (keda4, custom_api4, _, _) = _mocked_keda();
    custom_api4.get_namespaced_custom_object.side_effect = ApiException(status=404);
    raised = False;
    try {
        keda4.apply_http_activation(
            _spec(
                scale_target_name="missing-rollout",
                scale_target_kind="Rollout",
                scale_target_api_version="argoproj.io/v1alpha1",
                scale_target_plural="rollouts"
            )
        );
    } except ValueError {
        raised = True;
    }
    assert raised , "a custom target with scale_target_plural set must still be checked for existence";

    missing_target_apps = unittest.mock.MagicMock();
    missing_target_apps.read_namespaced_deployment.side_effect = ApiException(
        status=404
    );
    (keda5, _, _, _) = _mocked_keda(apps_api=missing_target_apps);
    raised = False;
    try {
        keda5.apply_http_activation(_spec(scale_target_name="missing-deployment"));
    } except ValueError {
        raised = True;
    }
    assert raised , "a missing Deployment scale target must raise";

    missing_service_core = unittest.mock.MagicMock();
    missing_service_core.read_namespaced_service.side_effect = ApiException(status=404);
    (keda6, _, _, _) = _mocked_keda(core_api=missing_service_core);
    raised = False;
    try {
        keda6.apply_http_activation(
            _spec(target=HTTPServiceTarget(service="missing-svc", port=8080))
        );
    } except ValueError {
        raised = True;
    }
    assert raised , "a missing Service target must raise";
}

test "apply_http_activation returns False and creates nothing when the HTTP Add-on's CRDs are absent or core KEDA itself is missing, and raises when the Add-on is installed but genuinely broken" {
    (keda, custom_api, _, _) = _mocked_keda(http_addon_installed=False);
    assert keda.apply_http_activation(_spec()) == False;
    custom_api.create_namespaced_custom_object.assert_not_called();

    core_missing_api = unittest.mock.MagicMock();
    def core_missing_side_effect(*args: any, **kwargs: any) -> any {
        if kwargs.get("group") == "keda.sh" {
            raise ApiException(status=404);
        }
        return {};
    }
    core_missing_api.list_cluster_custom_object.side_effect = core_missing_side_effect;
    keda2 = KEDAAutoscaler(
        _custom_api=core_missing_api,
        _core_api=unittest.mock.MagicMock(),
        _apps_api=unittest.mock.MagicMock()
    );
    assert keda2.apply_http_activation(_spec()) == False , "core KEDA missing must skip activation even if the Add-on itself is healthy";
    core_missing_api.create_namespaced_custom_object.assert_not_called();

    broken_scaler_core = unittest.mock.MagicMock();
    def broken_scaler_side_effect(name: str, *args: any, **kwargs: any) -> any {
        if "scaler" in name {
            raise ApiException(status=404);
        }
        return {};
    }
    broken_scaler_core.read_namespaced_service.side_effect = broken_scaler_side_effect;
    keda3 = KEDAAutoscaler(
        _custom_api=unittest.mock.MagicMock(),
        _core_api=broken_scaler_core,
        _apps_api=unittest.mock.MagicMock()
    );
    raised = False;
    error_msg = "";
    try {
        keda3.apply_http_activation(_spec());
    } except ValueError as e {
        raised = True;
        error_msg = str(e);
    }
    assert raised , "an installed but broken Add-on (missing scaler Service) must raise, not silently skip";
    assert "scaler" in error_msg.lower();
}

test "InterceptorRoute and ScaledObject names are deterministic and distinct; destroy_http_activation always sweeps both, tolerating a 403 on one while still attempting the other, and never masking a genuine 500 behind a later tolerable 403; destroy_collection sweeps InterceptorRoutes too but only tolerates a 403 there, not on keda.sh, unless best_effort" {
    keda = KEDAAutoscaler();
    route_name = keda.interceptor_route_name_for("preview-deployment");
    scaled_obj_name = keda.http_scaled_object_name_for("preview-deployment");
    assert route_name != scaled_obj_name;
    assert route_name == keda.interceptor_route_name_for("preview-deployment");

    mock_api = unittest.mock.MagicMock();
    KEDAAutoscaler(_custom_api=mock_api).destroy_http_activation(
        "preview-deployment", "staging"
    );
    plurals = [
        c[1]["plural"] for c in mock_api.delete_namespaced_custom_object.call_args_list
    ];
    assert set(plurals) == {"interceptorroutes", "scaledobjects"};

    mock_api2 = unittest.mock.MagicMock();
    mock_api2.delete_namespaced_custom_object.side_effect = [
        ApiException(status=403),  # InterceptorRoute delete forbidden
        None  # ScaledObject delete still attempted, and succeeds
    ];
    status2 = None;
    try {
        KEDAAutoscaler(_custom_api=mock_api2).destroy_http_activation(
            "preview-deployment", "staging"
        );
    } except ApiException as e {
        status2 = e.status;
    }
    assert status2 == 403 , "the 403 must still surface after both deletes are attempted";
    plurals2 = [
        c[1]["plural"] for c in mock_api2.delete_namespaced_custom_object.call_args_list
    ];
    assert set(plurals2) == {"interceptorroutes", "scaledobjects"};

    mock_api3 = unittest.mock.MagicMock();
    mock_api3.delete_namespaced_custom_object.side_effect = [
        ApiException(status=500),  # a genuine server error on the first delete
        ApiException(status=403)  # a tolerable error on the second
    ];
    status3 = None;
    try {
        KEDAAutoscaler(_custom_api=mock_api3).destroy_http_activation(
            "preview-deployment", "staging"
        );
    } except ApiException as e {
        status3 = e.status;
    }
    assert status3 == 500 , "a 500 on the first delete must not be masked by a later tolerable 403";

    # The same priority the other way around: a tolerable 403 on the first
    # delete must not mask a genuine 500 on the second.
    mock_api3b = unittest.mock.MagicMock();
    mock_api3b.delete_namespaced_custom_object.side_effect = [
        ApiException(status=403),
        ApiException(status=500)
    ];
    status3b = None;
    try {
        KEDAAutoscaler(_custom_api=mock_api3b).destroy_http_activation(
            "preview-deployment", "staging"
        );
    } except ApiException as e {
        status3b = e.status;
    }
    assert status3b == 500 , "a 500 on the second delete must not be masked by a tolerable 403 on the first";

    def destroy_collection_raised(mock: any, best_effort: bool = False) -> bool {
        try {
            KEDAAutoscaler(
                _custom_api=mock, _v2_api=unittest.mock.MagicMock()
            ).destroy_collection(
                "staging", "managed=jac-scale", best_effort=best_effort
            );
        } except ApiException {
            return True;
        }
        return False;
    }

    mock_api4 = unittest.mock.MagicMock();
    def list_side_effect(**kwargs: any) -> any {
        if kwargs.get("group") == "http.keda.sh" {
            raise ApiException(status=403);
        }
        return {"items": [{"metadata": {"name": "preview-deployment-scaledobject"}}]};
    }
    mock_api4.list_namespaced_custom_object.side_effect = list_side_effect;
    assert not destroy_collection_raised(mock_api4) , "a 403 listing InterceptorRoutes must not abort the sweep of the other resource kinds";
    swept_plurals = [
        c[1]["plural"] for c in mock_api4.delete_namespaced_custom_object.call_args_list
    ];
    assert "scaledobjects" in swept_plurals;
    assert "triggerauthentications" in swept_plurals;

    mock_api5 = unittest.mock.MagicMock();
    mock_api5.list_namespaced_custom_object.side_effect = ApiException(status=403);
    assert destroy_collection_raised(mock_api5) , "a 403 on the core keda.sh group is not tolerated by default";
    assert not destroy_collection_raised(mock_api5, best_effort=True) , "best_effort=True must tolerate a 403 on every resource group, including keda.sh";
}

def _keda_for(
    custom_api: any = None, core_api: any = None, apps_api: any = None
) -> KEDAAutoscaler {
    return KEDAAutoscaler(
        _custom_api=custom_api or unittest.mock.MagicMock(),
        _core_api=core_api or unittest.mock.MagicMock(),
        _apps_api=apps_api or unittest.mock.MagicMock()
    );
}

def _custom_api_for(
    core: (int | None) = None,
    http_v1beta1: (int | None) = None,
    legacy_v1alpha1: (int | None) = None
) -> any {
    api = unittest.mock.MagicMock();
    def side_effect(*args: any, **kwargs: any) -> any {
        status = None;
        if kwargs.get("group") == "keda.sh" {
            status = core;
        } elif kwargs.get("version") == "v1beta1" {
            status = http_v1beta1;
        } elif kwargs.get("version") == "v1alpha1" {
            status = legacy_v1alpha1;
        }
        if status is not None {
            raise ApiException(status=status);
        }
        return {};
    }
    api.list_cluster_custom_object.side_effect = side_effect;
    return api;
}

def _core_api_for(
    scaler: (int | None) = None, interceptor: (int | None) = None
) -> any {
    api = unittest.mock.MagicMock();
    def side_effect(name: str, *args: any, **kwargs: any) -> any {
        status = interceptor if "interceptor" in name else scaler;
        if status is not None {
            raise ApiException(status=status);
        }
        return {};
    }
    api.read_namespaced_service.side_effect = side_effect;
    return api;
}

test "discover_capabilities produces a distinct diagnostic for every install/permission combination" {
    # core-vs-Add-on presence, per-service health, and RBAC-denied vs
    # genuinely-absent must each report their own diagnosis -- an operator
    # debugging a broken activation reads this message, not the code.
    scenarios = [
        (
            "core-only",
            _custom_api_for(http_v1beta1=404, legacy_v1alpha1=404),
            _core_api_for()
        ),
        ("full-install", _custom_api_for(), _core_api_for()),
        ("missing-external-scaler", _custom_api_for(), _core_api_for(scaler=404)),
        (
            "missing-interceptor-service",
            _custom_api_for(),
            _core_api_for(interceptor=404)
        ),
        (
            "legacy-addon-needs-upgrade",
            _custom_api_for(http_v1beta1=404),
            _core_api_for()
        ),
        ("rbac-denied-on-core", _custom_api_for(core=403), _core_api_for()),
        (
            "rbac-denied-on-http-addon",
            _custom_api_for(http_v1beta1=403),
            _core_api_for()
        ),
        (
            "rbac-denied-on-legacy-probe",
            _custom_api_for(http_v1beta1=404, legacy_v1alpha1=403),
            _core_api_for()
        )
    ];
    for (label, custom_api, core_api) in scenarios {
        keda = _keda_for(custom_api=custom_api, core_api=core_api);
        caps = keda.discover_capabilities();
        msg = f"scenario '{label}' produced: warnings={caps.warnings} errors={caps.errors}";

        if label == "core-only" {
            assert caps.core_available == True , msg;
            assert caps.http_addon_available == False , msg;
        } elif label == "full-install" {
            assert caps.core_available == True , msg;
            assert caps.http_addon_available == True , msg;
            assert caps.errors == [] , msg;
            assert caps.interceptor_route_api_version == "v1beta1" , msg;
        } elif label == "missing-external-scaler" {
            assert any([("scaler" in e.lower()) for e in caps.errors]) , msg;
        } elif label == "missing-interceptor-service" {
            assert any([("interceptor" in e.lower()) for e in caps.errors]) , msg;
        } elif label == "legacy-addon-needs-upgrade" {
            assert any([("upgrade" in w.lower()) for w in caps.warnings]) , msg;
            assert caps.http_addon_available == False , msg;
        } elif label == "rbac-denied-on-core" {
            assert caps.core_available == False , msg;
            assert any(
                [
                    ("permission" in e.lower() or "rbac" in e.lower())
                    for e in caps.errors
                ]
            ) , msg;
        } elif label == "rbac-denied-on-http-addon" {
            assert any(
                [
                    ("permission" in e.lower() or "rbac" in e.lower())
                    for e in caps.errors
                ]
            ) , msg;
            legacy_calls = [
                c
                for c in custom_api.list_cluster_custom_object.call_args_list
                if c[1].get("plural") == "httpscaledobjects"
            ];
            assert legacy_calls == [] , (
                f"{label}: RBAC-denied v1beta1 must not fall through to the "
                "legacy-version probe (that's only for a genuinely absent API)"
            );
        } elif label == "rbac-denied-on-legacy-probe" {
            assert any(
                [
                    ("permission" in e.lower() or "rbac" in e.lower())
                    for e in caps.errors
                ]
            ) , (
                f"{label}: an RBAC-denied legacy probe must be reported as a "
                "permission error, not silently treated as 'not installed'"
            );
        }
    }
}

test "discover_capabilities caches per (cluster, service-address, client-identity) and only re-queries on refresh=True or invalidate_capabilities(); format_capabilities and preflight agree with the underlying state, and FQDN service addresses resolve to name and namespace" {
    custom_api = _custom_api_for();
    keda = _keda_for(custom_api=custom_api, core_api=_core_api_for());
    keda.discover_capabilities();
    keda.discover_capabilities();
    assert custom_api.list_cluster_custom_object.call_count == 2 , "a second call must hit the cache (2 calls = one discovery round: core + http)";
    keda.discover_capabilities(refresh=True);
    assert custom_api.list_cluster_custom_object.call_count == 4 , "refresh=True must bypass the cache";
    keda.invalidate_capabilities();
    keda.discover_capabilities();
    assert custom_api.list_cluster_custom_object.call_count == 6 , "invalidate_capabilities must force the next call to requery";

    ready_keda = _keda_for(custom_api=_custom_api_for(), core_api=_core_api_for());
    ready_caps = ready_keda.discover_capabilities();
    assert "ready" in ready_keda.format_capabilities(ready_caps).lower();

    not_ready_keda = _keda_for(
        custom_api=_custom_api_for(http_v1beta1=404, legacy_v1alpha1=404),
        core_api=_core_api_for()
    );
    not_ready_caps = not_ready_keda.discover_capabilities();
    assert "helm" in not_ready_keda.format_capabilities(not_ready_caps).lower();

    core_missing_keda = _keda_for(
        custom_api=_custom_api_for(core=404), core_api=_core_api_for()
    );
    core_missing_caps = core_missing_keda.discover_capabilities();
    assert core_missing_caps.http_addon_available == True;
    assert "not ready" in core_missing_keda.format_capabilities(
        core_missing_caps
    ).lower() , (
        "a healthy Add-on with missing core KEDA must not be reported as ready"
    );

    # Two instances with the same cluster host but a different
    # http_scaler_address must not share a cache entry.
    keda_a = _keda_for(custom_api=_custom_api_for(), core_api=_core_api_for());
    caps_a = keda_a.discover_capabilities();
    assert caps_a.errors == [];
    keda_b = KEDAAutoscaler(
        _custom_api=_custom_api_for(),
        _core_api=_core_api_for(scaler=404),
        http_scaler_address="custom-scaler.other-ns:9090"
    );
    caps_b = keda_b.discover_capabilities();
    assert any([("scaler" in e.lower()) for e in caps_b.errors]) , "a distinct http_scaler_address must not reuse instance A's cached result";

    # Two instances with the same cluster key and service addresses but a
    # different injected client must not share a cache entry either.
    keda_c = _keda_for(custom_api=_custom_api_for(), core_api=_core_api_for());
    assert keda_c.discover_capabilities().errors == [];
    keda_d = KEDAAutoscaler(
        _custom_api=_custom_api_for(core=403), _core_api=_core_api_for()
    );
    caps_d = keda_d.discover_capabilities();
    assert any(
        [("permission" in e.lower() or "rbac" in e.lower()) for e in caps_d.errors]
    ) , "a distinct (RBAC-restricted) client must not reuse instance C's cached result";

    fqdn_core = _core_api_for();
    KEDAAutoscaler(
        _custom_api=_custom_api_for(),
        _core_api=fqdn_core,
        _apps_api=unittest.mock.MagicMock(),
        http_scaler_address="keda-add-ons-http-external-scaler.keda.svc.cluster.local:9090",
        interceptor_service_address="keda-add-ons-http-interceptor-proxy.keda.svc.cluster.local:8080"
    ).discover_capabilities();
    lookups = [
        (c[1]["name"], c[1]["namespace"])
        for c in fqdn_core.read_namespaced_service.call_args_list
    ];
    assert lookups == [
        ("keda-add-ons-http-external-scaler", "keda"),
        ("keda-add-ons-http-interceptor-proxy", "keda")
    ] , f"FQDN service addresses must parse as name.namespace; got: {lookups}";

    preflight_api = unittest.mock.MagicMock();
    preflight_api.list_cluster_custom_object.side_effect = ApiException(status=403);
    raised = False;
    try {
        KEDAAutoscaler(_custom_api=preflight_api).preflight();
    } except ApiException {
        raised = True;
    }
    assert not raised , "preflight must report a 403 as a warning, not an unhandled exception";
}
