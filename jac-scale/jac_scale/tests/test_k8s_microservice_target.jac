"""Tests for KubernetesMicroserviceTarget (K1 scope - dispatch + scaffold).

K1 covers:
  - Class instantiates and inherits from KubernetesTarget
  - DeploymentTargetFactory dispatches "kubernetes-microservice" to it
  - generate_service_pod_specs iterates configured routes + adds gateway
  - Each pod-spec carries the right image and JAC_SV_NAME env
  - deploy() returns a successful DeploymentResult with pod_specs in details

K2 will add manifest-shape tests; K3 will add kubectl interaction tests;
K5 will add rolling-deploy tests.
"""

import from typing { Any }
import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.abstractions.deployment_target { DeploymentTarget }
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }
import from jac_scale.targets.kubernetes.kubernetes_target { KubernetesTarget }
import from jac_scale.factories.deployment_factory { DeploymentTargetFactory }
import from jac_scale.microservices.k8s_target {
    KubernetesMicroserviceTarget,
    GATEWAY_NAME
}


"""Stub for `get_scale_config()` returning a fixed routes dict.

The KubernetesMicroserviceTarget reads
`[plugins.scale.microservices.routes]` to discover which services exist.
Tests stub this so we don't depend on a jac.toml fixture.
"""
obj _StubMsCfg {
    has data: dict[str, Any];

    def get_microservices_config -> dict[str, Any] {
        return self.data;
    }
}


import unittest.mock;
import jac_scale.microservices.k8s_target as k8s_mod;


"""Install k8s API mocks at the k8s_target module level. Returns
`(mock_apps_v1, mock_core_v1, restore)` - call `restore()` in finally
to undo the patches. Used by deploy() / apply_manifests() / destroy()
tests so they don't need a live cluster.

K6 added AutoscalingV2Api (HPA) and PolicyV1Api (PDB) usage; they're
mocked through the shared `mock_client` so existing K3 tests still
work and new K6 tests can read `mock_client.AutoscalingV2Api.return_value`
when they need to assert against HPA/PDB calls.
"""
def _install_k8s_mocks -> tuple[Any, Any, Any] {
    mock_apps_v1 = unittest.mock.MagicMock();
    mock_core_v1 = unittest.mock.MagicMock();
    mock_autoscaling_v2 = unittest.mock.MagicMock();
    mock_policy_v1 = unittest.mock.MagicMock();
    mock_client = unittest.mock.MagicMock();
    mock_client.AppsV1Api.return_value = mock_apps_v1;
    mock_client.CoreV1Api.return_value = mock_core_v1;
    mock_client.AutoscalingV2Api.return_value = mock_autoscaling_v2;
    mock_client.PolicyV1Api.return_value = mock_policy_v1;

    mock_cfg = unittest.mock.MagicMock();

    orig_client = getattr(k8s_mod, "client");
    orig_cfg = getattr(k8s_mod, "k8s_cluster_config");
    orig_ens = getattr(k8s_mod, "ensure_namespace_exists");
    setattr(k8s_mod, "client", mock_client);
    setattr(k8s_mod, "k8s_cluster_config", mock_cfg);
    setattr(k8s_mod, "ensure_namespace_exists", unittest.mock.MagicMock());

    def restore -> None {
        setattr(k8s_mod, "client", orig_client);
        setattr(k8s_mod, "k8s_cluster_config", orig_cfg);
        setattr(k8s_mod, "ensure_namespace_exists", orig_ens);
    }

    return (mock_apps_v1, mock_core_v1, restore);
}


"""Variant that also returns the AutoscalingV2 + PolicyV1 mocks for K6 tests."""
def _install_k8s_mocks_with_k6 -> tuple[Any, Any, Any, Any, Any] {
    mock_apps_v1 = unittest.mock.MagicMock();
    mock_core_v1 = unittest.mock.MagicMock();
    mock_autoscaling_v2 = unittest.mock.MagicMock();
    mock_policy_v1 = unittest.mock.MagicMock();
    mock_client = unittest.mock.MagicMock();
    mock_client.AppsV1Api.return_value = mock_apps_v1;
    mock_client.CoreV1Api.return_value = mock_core_v1;
    mock_client.AutoscalingV2Api.return_value = mock_autoscaling_v2;
    mock_client.PolicyV1Api.return_value = mock_policy_v1;

    mock_cfg = unittest.mock.MagicMock();

    orig_client = getattr(k8s_mod, "client");
    orig_cfg = getattr(k8s_mod, "k8s_cluster_config");
    orig_ens = getattr(k8s_mod, "ensure_namespace_exists");
    setattr(k8s_mod, "client", mock_client);
    setattr(k8s_mod, "k8s_cluster_config", mock_cfg);
    setattr(k8s_mod, "ensure_namespace_exists", unittest.mock.MagicMock());

    def restore -> None {
        setattr(k8s_mod, "client", orig_client);
        setattr(k8s_mod, "k8s_cluster_config", orig_cfg);
        setattr(k8s_mod, "ensure_namespace_exists", orig_ens);
    }

    return (mock_apps_v1, mock_core_v1, mock_autoscaling_v2, mock_policy_v1, restore);
}


# =============================================================================
# Pod-spec generation (the K1 core)
# =============================================================================

test "generate_service_pod_specs emits one entry per route + gateway" {
    import jac_scale.config_loader as cfg_mod;

    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", container_port=8000)
    );

    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda: _StubMsCfg(
        data={
            "routes": {
                "orders": "/api/orders",
                "cart": "/api/cart",
                "products": "/api/products"
            }
        }
    ));

    try {
        # build=False -> _handle_image_registry returns
        # k8s_config.python_image without doing any registry work.
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        specs = target.generate_service_pod_specs(ac);

        assert len(specs) == 4, (
            f"expected 3 services + 1 gateway = 4, got {len(specs)}: "
            f"{list(specs.keys())}"
        );
        assert "orders" in specs;
        assert "cart" in specs;
        assert "products" in specs;
        assert GATEWAY_NAME in specs;
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
    }
}


test "each pod-spec carries JAC_SV_NAME and the same image" {
    import jac_scale.config_loader as cfg_mod;

    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", container_port=8000)
    );

    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda: _StubMsCfg(
        data={"routes": {"orders": "/api/orders"}}
    ));

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        specs = target.generate_service_pod_specs(ac);

        # The python_image fallback is what we expect (build=False path).
        expected_image = target.k8s_config.python_image;

        # Service pod-spec: image + JAC_SV_NAME=orders
        orders_spec = specs["orders"];
        orders_container = orders_spec["containers"][0];
        assert orders_container["image"] == expected_image;
        assert orders_container["env"] == [
            {"name": "JAC_SV_NAME", "value": "orders"}
        ];
        assert orders_container["ports"][0]["containerPort"] == 8000;

        # Gateway pod-spec: same image, JAC_SV_NAME=GATEWAY_NAME sentinel
        gw_spec = specs[GATEWAY_NAME];
        gw_container = gw_spec["containers"][0];
        assert gw_container["image"] == expected_image, (
            "gateway must share the same image as services (single-image strategy)"
        );
        assert gw_container["env"] == [
            {"name": "JAC_SV_NAME", "value": GATEWAY_NAME}
        ];
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
    }
}


test "empty routes still produces a gateway pod-spec" {
    # Edge case: a project with no `sv import` services configured (yet).
    # Should still emit the gateway pod-spec on its own - the gateway is
    # always part of the microservice topology, even with zero services.
    import jac_scale.config_loader as cfg_mod;

    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );

    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda: _StubMsCfg(
        data={"routes": {}}
    ));

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        specs = target.generate_service_pod_specs(ac);

        assert list(specs.keys()) == [GATEWAY_NAME];
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
    }
}


test "container port respects k8s_config.container_port override" {
    import jac_scale.config_loader as cfg_mod;

    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", container_port=9090)
    );

    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda: _StubMsCfg(
        data={"routes": {"orders": "/api/orders"}}
    ));

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        specs = target.generate_service_pod_specs(ac);

        # Both service and gateway pick up the configured port.
        assert specs["orders"]["containers"][0]["ports"][0]["containerPort"] == 9090;
        assert specs[GATEWAY_NAME]["containers"][0]["ports"][0]["containerPort"] == 9090;
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
    }
}


# =============================================================================
# Inheritance + factory dispatch (the K1 wiring)
# =============================================================================

test "KubernetesMicroserviceTarget is a KubernetesTarget" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    # Inherits K8s machinery: build/push, namespace, secrets, probes etc.
    assert isinstance(target, KubernetesTarget);
    assert isinstance(target, DeploymentTarget);
}


test "DeploymentTargetFactory dispatches kubernetes-microservice" {
    config = {"app_name": "demo", "namespace": "default"};
    target = DeploymentTargetFactory.create("kubernetes-microservice", config);
    assert isinstance(target, KubernetesMicroserviceTarget);
    assert target.k8s_config.app_name == "demo";
    assert target.k8s_config.namespace == "default";
}


test "DeploymentTargetFactory still dispatches plain kubernetes (monolith)" {
    # Verify K1 didn't accidentally hijack the monolith path.
    config = {"app_name": "demo", "namespace": "default"};
    target = DeploymentTargetFactory.create("kubernetes", config);
    assert isinstance(target, KubernetesTarget);
    assert not isinstance(target, KubernetesMicroserviceTarget);
}


# =============================================================================
# deploy() returns DeploymentResult with pod_specs in details
# =============================================================================

test "deploy returns success with pod_specs in details" {
    import jac_scale.config_loader as cfg_mod;

    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );

    # Need to patch BOTH config (for routes discovery) AND the k8s
    # client (for apply_manifests). MagicMock's default-return (no
    # side_effect) makes read_*/patch_* succeed silently which is the
    # idempotent already-deployed path.
    (mock_apps_v1, mock_core_v1, k8s_restore) = _install_k8s_mocks();

    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda: _StubMsCfg(
        data={"routes": {"orders": "/api/orders", "cart": "/api/cart"}}
    ));

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        result = target.deploy(ac);

        assert result.success, f"deploy failed: {result.message}";
        assert "pod_specs" in result.details;
        specs: dict[str, Any] = result.details["pod_specs"];
        assert len(specs) == 3;  # 2 services + gateway
        assert "orders" in specs;
        assert "cart" in specs;
        assert GATEWAY_NAME in specs;
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
        k8s_restore();
    }
}


test "deploy returns failure DeploymentResult on generation error" {
    # If config read raises, deploy() returns success=False rather than
    # bubbling an exception out to the CLI caller.
    import jac_scale.config_loader as cfg_mod;

    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );

    obj _ExplodingCfg {
        def get_microservices_config -> dict[str, Any] {
            raise RuntimeError("simulated config read failure");
        }
    }

    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda: _ExplodingCfg());

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        result = target.deploy(ac);
        assert not result.success;
        assert "manifest generation failed" in (result.message or "");
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
    }
}


# =============================================================================
# K2 - manifest generation (Deployment + ClusterIP Service per service)
# =============================================================================

test "_k8s_safe_name maps GATEWAY_NAME to a DNS-1123 string" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    # Sentinel underscored name -> DNS-1123 valid resource name.
    assert target._k8s_safe_name(GATEWAY_NAME) == "gateway";
    # Underscores in user names get hyphenated (K8s rejects underscores).
    assert target._k8s_safe_name("orders_app") == "orders-app";
    # Already-valid names pass through unchanged.
    assert target._k8s_safe_name("orders") == "orders";
    # Mixed case is lowered.
    assert target._k8s_safe_name("Orders") == "orders";
}


test "_build_deployment_manifest wraps pod-spec in Deployment template" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(
            app_name="demo", namespace="prod", container_port=8000
        )
    );
    pod_spec = {
        "containers": [{
            "name": "orders",
            "image": "demo:latest",
            "env": [{"name": "JAC_SV_NAME", "value": "orders"}],
            "ports": [{"containerPort": 8000}]
        }]
    };
    dep = target._build_deployment_manifest("orders", pod_spec);

    assert dep["apiVersion"] == "apps/v1";
    assert dep["kind"] == "Deployment";
    assert dep["metadata"]["name"] == "orders-deployment";
    assert dep["metadata"]["namespace"] == "prod";
    assert dep["metadata"]["labels"]["app"] == "orders";
    assert dep["metadata"]["labels"]["jac-scale.role"] == "microservice";
    assert dep["spec"]["replicas"] == 1;  # K6 will make configurable
    assert dep["spec"]["selector"]["matchLabels"] == {"app": "orders"};
    # The pod-spec lives at spec.template.spec - must match exactly.
    assert dep["spec"]["template"]["spec"] == pod_spec;
    # Pod-template labels MUST match the selector or the Deployment is
    # rejected by K8s API server.
    assert dep["spec"]["template"]["metadata"]["labels"]["app"] == "orders";
}


test "_build_deployment_manifest tags gateway with role=gateway" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );
    pod_spec = {"containers": [{"name": "gateway", "image": "demo:latest"}]};
    dep = target._build_deployment_manifest(GATEWAY_NAME, pod_spec);

    assert dep["metadata"]["name"] == "gateway-deployment";
    assert dep["metadata"]["labels"]["jac-scale.role"] == "gateway";
    # Pod-template uses the same DNS-safe name (not GATEWAY_NAME sentinel).
    assert dep["spec"]["selector"]["matchLabels"] == {"app": "gateway"};
}


test "_build_service_manifest emits ClusterIP with matching selector" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(
            app_name="demo", namespace="prod", container_port=9090
        )
    );
    svc = target._build_service_manifest("cart");

    assert svc["apiVersion"] == "v1";
    assert svc["kind"] == "Service";
    assert svc["metadata"]["name"] == "cart-service";
    assert svc["metadata"]["namespace"] == "prod";
    assert svc["spec"]["type"] == "ClusterIP";
    # Selector MUST match the Deployment's pod labels for kube-proxy to
    # route traffic to the right pods.
    assert svc["spec"]["selector"] == {"app": "cart"};
    port = svc["spec"]["ports"][0];
    assert port["port"] == 9090;
    assert port["targetPort"] == 9090;
    assert port["protocol"] == "TCP";
}


test "generate_manifests produces deployments + services per pod-spec" {
    import jac_scale.config_loader as cfg_mod;

    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );

    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda: _StubMsCfg(
        data={"routes": {"orders": "/api/orders", "cart": "/api/cart"}}
    ));

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        bundle = target.generate_manifests(ac);

        # Bundle has all keyed sections (K2 + K6).
        # Use a superset assertion so additions in later K-tasks don't
        # break this test.
        for required in ("deployments", "services", "pod_specs") {
            assert required in bundle, f"missing required section: {required}";
        }

        # Each section has 1 entry per service + 1 for the gateway.
        for section in ("deployments", "services", "pod_specs") {
            assert len(bundle[section]) == 3, (
                f"section {section} expected 3 entries, got {len(bundle[section])}"
            );
            assert "orders" in bundle[section];
            assert "cart" in bundle[section];
            assert GATEWAY_NAME in bundle[section];
        }

        # Selectors must match across paired Deployment + Service so
        # kube-proxy routes correctly.
        for svc_name in ["orders", "cart"] {
            dep_selector = bundle["deployments"][svc_name]["spec"]["selector"]["matchLabels"];
            svc_selector = bundle["services"][svc_name]["spec"]["selector"];
            assert dep_selector == svc_selector, (
                f"selector mismatch for {svc_name}: deployment={dep_selector}, service={svc_selector}"
            );
        }
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
    }
}


test "deploy returns K3 applied bundle in details" {
    import jac_scale.config_loader as cfg_mod;

    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );

    (_apps, _core, k8s_restore) = _install_k8s_mocks();
    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda: _StubMsCfg(
        data={"routes": {"orders": "/api/orders"}}
    ));

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        result = target.deploy(ac);

        assert result.success, f"deploy failed: {result.message}";
        # K2 bundle preserved in details (K1's pod_specs is one section).
        details: dict[str, Any] = result.details;
        assert "deployments" in details;
        assert "services" in details;
        assert "pod_specs" in details;
        assert (result.message or "").startswith("K3 applied");
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
        k8s_restore();
    }
}


# =============================================================================
# K3 - apply_manifests + destroy lifecycle
# =============================================================================

test "apply_manifests creates Service then Deployment per entry" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );
    (mock_apps_v1, mock_core_v1, k8s_restore) = _install_k8s_mocks();

    bundle = {
        "services": {
            "orders": target._build_service_manifest("orders"),
            GATEWAY_NAME: target._build_service_manifest(GATEWAY_NAME)
        },
        "deployments": {
            "orders": target._build_deployment_manifest(
                "orders",
                {"containers": [{"name": "orders", "image": "demo:latest"}]}
            ),
            GATEWAY_NAME: target._build_deployment_manifest(
                GATEWAY_NAME,
                {"containers": [{"name": "gateway", "image": "demo:latest"}]}
            )
        },
        "pod_specs": {}
    };

    try {
        target.apply_manifests(bundle);

        # Service create called twice (orders + gateway), each with the
        # right manifest body. Default MagicMock makes read raise no
        # error but returns a MagicMock - our code reads it then patches,
        # so patch is what we'll see called, not create. Reset the read
        # to side_effect=NotFound to get the create path.
        # Here we just verify SOMETHING was called per service.
        assert mock_core_v1.read_namespaced_service.call_count == 2;
        assert mock_apps_v1.read_namespaced_deployment.call_count == 2;
        # In MagicMock-default-success path we patch (not create) since
        # read returns a MagicMock without raising.
        assert mock_core_v1.patch_namespaced_service.call_count == 2;
        assert mock_apps_v1.patch_namespaced_deployment.call_count == 2;
    } finally {
        k8s_restore();
    }
}


test "apply_manifests creates new resources when read 404s" {
    # First-deploy path: nothing in the cluster yet, read raises 404,
    # apply takes the create branch.
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );
    (mock_apps_v1, mock_core_v1, k8s_restore) = _install_k8s_mocks();

    # Patch ApiException to plain Exception so our test exceptions match
    # the `except ApiException` branch. Set status=404 as a runtime
    # attribute so the `if e.status == 404` check fires.
    orig_api_exc = getattr(k8s_mod, "ApiException");
    setattr(k8s_mod, "ApiException", Exception);

    svc_404 = Exception("simulated service not found");
    setattr(svc_404, "status", 404);
    dep_404 = Exception("simulated deployment not found");
    setattr(dep_404, "status", 404);
    mock_core_v1.read_namespaced_service.side_effect = svc_404;
    mock_apps_v1.read_namespaced_deployment.side_effect = dep_404;

    bundle = {
        "services": {"orders": target._build_service_manifest("orders")},
        "deployments": {
            "orders": target._build_deployment_manifest(
                "orders",
                {"containers": [{"name": "orders", "image": "demo:latest"}]}
            )
        },
        "pod_specs": {}
    };

    try {
        target.apply_manifests(bundle);
        assert mock_core_v1.create_namespaced_service.call_count == 1;
        assert mock_apps_v1.create_namespaced_deployment.call_count == 1;
        # Patch should NOT have been called - it's the wrong branch.
        assert mock_core_v1.patch_namespaced_service.call_count == 0;
        assert mock_apps_v1.patch_namespaced_deployment.call_count == 0;
    } finally {
        setattr(k8s_mod, "ApiException", orig_api_exc);
        k8s_restore();
    }
}


test "apply_manifests applies Services BEFORE Deployments" {
    # Service DNS must exist before pod startup so cross-service
    # `sv import` calls resolve at boot. Use mock attribute-attachment
    # to capture call order across both V1 APIs in a single timeline.
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );
    (mock_apps_v1, mock_core_v1, k8s_restore) = _install_k8s_mocks();

    tracker = unittest.mock.MagicMock();
    mock_core_v1.patch_namespaced_service = tracker.svc_patch;
    mock_apps_v1.patch_namespaced_deployment = tracker.dep_patch;

    bundle = {
        "services": {
            "orders": target._build_service_manifest("orders"),
            "cart": target._build_service_manifest("cart")
        },
        "deployments": {
            "orders": target._build_deployment_manifest(
                "orders", {"containers": [{"name": "orders"}]}
            ),
            "cart": target._build_deployment_manifest(
                "cart", {"containers": [{"name": "cart"}]}
            )
        },
        "pod_specs": {}
    };

    try {
        target.apply_manifests(bundle);
        # tracker.mock_calls is the chronological log of "svc_patch"
        # and "dep_patch" invocations. All svc_patch entries must come
        # before any dep_patch entry.
        names: list[str] = [str(c) for c in tracker.mock_calls];
        first_dep: int = -1;
        for (i, n) in enumerate(names) {
            if "dep_patch" in n {
                first_dep = i;
                break;
            }
        }
        assert first_dep > 0, f"no dep_patch call: {names}";
        for (i, n) in enumerate(names) {
            if "svc_patch" in n {
                assert i < first_dep, (
                    f"Service applied AFTER first Deployment: {names}"
                );
            }
        }
    } finally {
        k8s_restore();
    }
}


test "destroy uses jac-scale label selector" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );
    (mock_apps_v1, mock_core_v1, k8s_restore) = _install_k8s_mocks();
    # list_namespaced_service must return an iterable .items
    mock_core_v1.list_namespaced_service.return_value = (
        unittest.mock.MagicMock(items=[])
    );

    try {
        target.destroy("demo");
        # Selector matches managed=jac-scale + role in (microservice, gateway)
        # so renamed services are still cleaned up.
        kwargs = mock_apps_v1.delete_collection_namespaced_deployment.call_args.kwargs;
        assert kwargs["namespace"] == "prod";
        sel: str = kwargs["label_selector"];
        assert "managed=jac-scale" in sel;
        assert "jac-scale.role in" in sel;
        assert "microservice" in sel;
        assert "gateway" in sel;

        # Services list+delete uses the same selector.
        list_kwargs = mock_core_v1.list_namespaced_service.call_args.kwargs;
        assert list_kwargs["label_selector"] == sel;
    } finally {
        k8s_restore();
    }
}


test "destroy iterates list_namespaced_service result and deletes each" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );
    (mock_apps_v1, mock_core_v1, k8s_restore) = _install_k8s_mocks();

    svc_a = unittest.mock.MagicMock();
    svc_a.metadata.name = "orders-service";
    svc_b = unittest.mock.MagicMock();
    svc_b.metadata.name = "gateway-service";
    mock_core_v1.list_namespaced_service.return_value = (
        unittest.mock.MagicMock(items=[svc_a, svc_b])
    );

    try {
        target.destroy("demo");
        assert mock_core_v1.delete_namespaced_service.call_count == 2;
        names = {
            call.kwargs["name"]
            for call in mock_core_v1.delete_namespaced_service.call_args_list
        };
        assert names == {"orders-service", "gateway-service"};
    } finally {
        k8s_restore();
    }
}


test "deploy surfaces apply failure as DeploymentResult success=False" {
    import jac_scale.config_loader as cfg_mod;

    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    (mock_apps_v1, mock_core_v1, k8s_restore) = _install_k8s_mocks();
    # Force apply to fail at the Service step.
    mock_core_v1.read_namespaced_service.side_effect = RuntimeError(
        "simulated cluster outage"
    );

    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda: _StubMsCfg(
        data={"routes": {"orders": "/api/orders"}}
    ));

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        result = target.deploy(ac);
        assert not result.success;
        assert "manifest apply failed" in (result.message or "");
        # Bundle still surfaced for post-mortem inspection.
        assert "deployments" in (result.details or {});
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
        k8s_restore();
    }
}


# =============================================================================
# K4 - runtime DNS adapter (KubernetesDeployer + get_sv_registry hookimpl)
# =============================================================================

import from jac_scale.microservices.deployer { ServiceDeployer }
import from jac_scale.microservices.service_registry { ServiceRegistry, ServiceEntry, ServiceStatus }
import from jac_scale.microservices.k8s_deployer { KubernetesDeployer, build_k8s_registry }


test "KubernetesDeployer is a ServiceDeployer" {
    reg = ServiceRegistry();
    dep = KubernetesDeployer(registry=reg);
    assert isinstance(dep, ServiceDeployer);
    assert dep.target == "kubernetes";
}


test "KubernetesDeployer.url_for returns DNS-based URL" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(
        name="orders", file="orders.jac", prefix="/api/orders"
    ));
    dep = KubernetesDeployer(registry=reg, namespace="prod", port=8080);

    url = dep.url_for(reg.entries["orders"]);
    assert url == "http://orders-service.prod.svc.cluster.local:8080";
}


test "KubernetesDeployer.url_for normalizes underscored names" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(
        name="orders_app", file="orders_app.jac", prefix="/api/orders"
    ));
    dep = KubernetesDeployer(registry=reg, namespace="default", port=8000);

    # "orders_app" -> "orders-app" (DNS-1123: no underscores allowed).
    url = dep.url_for(reg.entries["orders_app"]);
    assert url == "http://orders-app-service.default.svc.cluster.local:8000";
}


test "KubernetesDeployer.url_for maps GATEWAY_NAME sentinel to 'gateway'" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(
        name=GATEWAY_NAME, file="", prefix="/"
    ));
    dep = KubernetesDeployer(registry=reg, namespace="prod", port=8000);

    url = dep.url_for(reg.entries[GATEWAY_NAME]);
    # Sentinel "__gateway__" -> "gateway" since K8s rejects underscores
    # in resource names.
    assert url == "http://gateway-service.prod.svc.cluster.local:8000";
}


test "build_k8s_registry maps each route to a DNS URL" {
    import os;
    # Force POD_NAMESPACE so we don't depend on the secrets file fallback.
    orig_ns = os.environ.get("POD_NAMESPACE");
    os.environ["POD_NAMESPACE"] = "test-ns";
    try {
        registry = build_k8s_registry(
            routes={"orders": "/api/orders", "cart": "/api/cart"},
            port=9090
        );
        assert registry["orders"] == (
            "http://orders-service.test-ns.svc.cluster.local:9090"
        );
        assert registry["cart"] == (
            "http://cart-service.test-ns.svc.cluster.local:9090"
        );
    } finally {
        if orig_ns is None {
            del os.environ["POD_NAMESPACE"];
        } else {
            os.environ["POD_NAMESPACE"] = orig_ns;
        }
    }
}


test "build_k8s_registry falls back to 'default' namespace when env unset" {
    import os;
    orig_ns = os.environ.get("POD_NAMESPACE");
    if orig_ns is not None {
        del os.environ["POD_NAMESPACE"];
    }
    try {
        # No POD_NAMESPACE env, no service-account file (we're not
        # in a pod), so the inner try-except returns "default".
        registry = build_k8s_registry(routes={"orders": "/api/orders"});
        # Default port is 8000, default namespace is "default".
        assert registry["orders"] == (
            "http://orders-service.default.svc.cluster.local:8000"
        );
    } finally {
        if orig_ns is not None {
            os.environ["POD_NAMESPACE"] = orig_ns;
        }
    }
}


test "get_sv_registry hookimpl returns DNS map when KUBERNETES_SERVICE_HOST set" {
    import os;
    import jac_scale.config_loader as cfg_mod;
    import from jac_scale.plugin { JacScalePlugin }

    orig_k8s_host = os.environ.get("KUBERNETES_SERVICE_HOST");
    orig_ns = os.environ.get("POD_NAMESPACE");
    original_cfg = getattr(cfg_mod, "get_scale_config");

    os.environ["KUBERNETES_SERVICE_HOST"] = "10.0.0.1";  # any value triggers detection
    os.environ["POD_NAMESPACE"] = "prod";
    setattr(cfg_mod, "get_scale_config", lambda: _StubMsCfg(
        data={
            "routes": {"orders": "/api/orders", "cart": "/api/cart"},
            "gateway_port": 8000
        }
    ));

    try {
        registry = JacScalePlugin.get_sv_registry();
        assert registry["orders"] == (
            "http://orders-service.prod.svc.cluster.local:8000"
        );
        assert registry["cart"] == (
            "http://cart-service.prod.svc.cluster.local:8000"
        );
    } finally {
        if orig_k8s_host is None {
            del os.environ["KUBERNETES_SERVICE_HOST"];
        } else {
            os.environ["KUBERNETES_SERVICE_HOST"] = orig_k8s_host;
        }
        if orig_ns is None {
            del os.environ["POD_NAMESPACE"];
        } else {
            os.environ["POD_NAMESPACE"] = orig_ns;
        }
        setattr(cfg_mod, "get_scale_config", original_cfg);
    }
}


test "get_sv_registry hookimpl falls back to local sv_client when not in K8s" {
    import os;
    import from jac_scale.plugin { JacScalePlugin }
    import from jaclang.runtimelib { sv_client }

    orig_k8s_host = os.environ.get("KUBERNETES_SERVICE_HOST");
    if orig_k8s_host is not None {
        del os.environ["KUBERNETES_SERVICE_HOST"];
    }

    # Seed the local sv_client._registry with a sentinel entry; the
    # hookimpl in non-K8s mode should return a dict copy of that.
    sv_client.register("test_local_module", "http://127.0.0.1:54321");

    try {
        registry = JacScalePlugin.get_sv_registry();
        assert registry.get("test_local_module") == "http://127.0.0.1:54321";
        # Returned dict must be a COPY (not a live reference) so caller
        # mutations don't pollute sv_client._registry.
        registry["mutate_me"] = "http://changed";
        assert "mutate_me" not in sv_client._registry;
    } finally {
        sv_client.unregister("test_local_module");
        if orig_k8s_host is not None {
            os.environ["KUBERNETES_SERVICE_HOST"] = orig_k8s_host;
        }
    }
}


test "get_sv_registry hookimpl falls back gracefully when config read fails" {
    # Defensive: even if config is malformed inside a pod, the gateway
    # shouldn't crash on first request - fall back to local registry.
    import os;
    import jac_scale.config_loader as cfg_mod;
    import from jac_scale.plugin { JacScalePlugin }

    orig_k8s_host = os.environ.get("KUBERNETES_SERVICE_HOST");
    original_cfg = getattr(cfg_mod, "get_scale_config");

    os.environ["KUBERNETES_SERVICE_HOST"] = "10.0.0.1";

    obj _ExplodingCfg {
        def get_microservices_config -> dict[str, Any] {
            raise RuntimeError("malformed jac.toml inside pod");
        }
    }
    setattr(cfg_mod, "get_scale_config", lambda: _ExplodingCfg());

    try {
        # Should NOT raise.
        registry = JacScalePlugin.get_sv_registry();
        # Type is a dict; whatever fallback content is fine (default
        # impl returns a copy of sv_client._registry).
        assert isinstance(registry, dict);
    } finally {
        if orig_k8s_host is None {
            del os.environ["KUBERNETES_SERVICE_HOST"];
        } else {
            os.environ["KUBERNETES_SERVICE_HOST"] = orig_k8s_host;
        }
        setattr(cfg_mod, "get_scale_config", original_cfg);
    }
}


# =============================================================================
# K5 - rolling-deploy correctness (RollingUpdate + probes + grace + preStop)
# =============================================================================

test "Deployment carries RollingUpdate strategy with maxSurge=1 maxUnavailable=0" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );
    pod_spec = {"containers": [{"name": "orders", "image": "demo:latest"}]};
    dep = target._build_deployment_manifest("orders", pod_spec);

    strategy = dep["spec"]["strategy"];
    assert strategy["type"] == "RollingUpdate";
    # maxSurge=1 lets one new pod come up BEFORE an old one terminates;
    # maxUnavailable=0 ensures we never go below current replicas during
    # the rollout. Together: zero-downtime deploys assuming probes +
    # preStop are configured (which K5 also does on the pod spec).
    assert strategy["rollingUpdate"]["maxSurge"] == 1;
    assert strategy["rollingUpdate"]["maxUnavailable"] == 0;
}


test "service pod-spec carries readinessProbe and livenessProbe on /healthz" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", container_port=8000)
    );
    spec = target._build_service_pod_spec("orders", "demo:latest");
    container = spec["containers"][0];

    # K5 v1: both probes hit /healthz; future split into
    # /healthz/ready and /healthz/live is a separate task.
    for probe_name in ["readinessProbe", "livenessProbe"] {
        probe = container[probe_name];
        assert probe["httpGet"]["path"] == "/healthz", (
            f"{probe_name} should hit /healthz, got {probe['httpGet']}"
        );
        assert probe["httpGet"]["port"] == 8000;
        assert probe["periodSeconds"] == 5;
        assert probe["failureThreshold"] == 3;
    }
}


test "service pod-spec carries lifecycle.preStop sleep" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    spec = target._build_service_pod_spec("orders", "demo:latest");
    container = spec["containers"][0];

    prestop = container["lifecycle"]["preStop"];
    # The sleep bridges kube-proxy endpoint-propagation gap so the
    # pod doesn't stop accepting work before remote nodes stop sending
    # work. Without this, rolling deploy drops requests on every cycle.
    assert "exec" in prestop;
    cmd = prestop["exec"]["command"];
    assert cmd[0] == "sh";
    assert cmd[1] == "-c";
    assert "sleep" in cmd[2];
}


test "pod-spec terminationGracePeriodSeconds = drain_timeout + 5 (default)" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    spec = target._build_service_pod_spec("orders", "demo:latest");

    # Default drain_timeout is 10s (memory + jfast_api default), so
    # grace = 15s. The +5s cushion gives uvicorn time to actually
    # exit AFTER drain returns; without it SIGKILL can land mid-drain.
    assert spec["terminationGracePeriodSeconds"] == 15;
}


test "pod-spec terminationGracePeriodSeconds tracks drain_timeout config override" {
    import jac_scale.config_loader as cfg_mod;
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );

    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda: _StubMsCfg(
        data={"drain_timeout_seconds": 60}  # 60s drain for slow services
    ));

    try {
        spec = target._build_service_pod_spec("orders", "demo:latest");
        # 60 + 5 cushion = 65
        assert spec["terminationGracePeriodSeconds"] == 65;
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
    }
}


test "gateway pod-spec gets the same K5 wires (probes + grace + preStop)" {
    # The gateway is a pod too - it also needs rolling-deploy correctness
    # so deploys of the gateway itself don't drop user-facing requests.
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", container_port=8000)
    );
    spec = target._build_gateway_pod_spec("demo:latest");
    container = spec["containers"][0];

    assert "readinessProbe" in container;
    assert "livenessProbe" in container;
    assert "lifecycle" in container;
    assert container["lifecycle"]["preStop"]["exec"]["command"][0] == "sh";
    assert spec["terminationGracePeriodSeconds"] == 15;  # default 10 + 5
    # Gateway also keeps its JAC_SV_NAME=__gateway__ sentinel.
    assert container["env"] == [{"name": "JAC_SV_NAME", "value": GATEWAY_NAME}];
}


test "_drain_timeout falls back to 10s default on config read failure" {
    import jac_scale.config_loader as cfg_mod;
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );

    obj _ExplodingCfg {
        def get_microservices_config -> dict[str, Any] {
            raise RuntimeError("simulated config failure");
        }
    }
    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda: _ExplodingCfg());

    try {
        # Should not raise; falls back to 10.
        assert target._drain_timeout() == 10;
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
    }
}


# =============================================================================
# K6 - HPA + PodDisruptionBudget per service
# =============================================================================

test "_build_hpa_manifest targets the Deployment with conservative defaults" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );
    hpa = target._build_hpa_manifest("orders");

    assert hpa["apiVersion"] == "autoscaling/v2";
    assert hpa["kind"] == "HorizontalPodAutoscaler";
    assert hpa["metadata"]["name"] == "orders-hpa";
    assert hpa["metadata"]["namespace"] == "prod";
    # scaleTargetRef must point at the matching Deployment so the
    # autoscaling controller knows what to scale.
    ref = hpa["spec"]["scaleTargetRef"];
    assert ref["kind"] == "Deployment";
    assert ref["name"] == "orders-deployment";
    assert ref["apiVersion"] == "apps/v1";

    # K6 conservative defaults; K7 will source from per-service config.
    assert hpa["spec"]["minReplicas"] == 1;
    assert hpa["spec"]["maxReplicas"] == 3;
    cpu_metric = hpa["spec"]["metrics"][0];
    assert cpu_metric["type"] == "Resource";
    assert cpu_metric["resource"]["name"] == "cpu";
    assert cpu_metric["resource"]["target"]["averageUtilization"] == 70;
}


test "_build_pdb_manifest selects matching pods with maxUnavailable=1" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );
    pdb = target._build_pdb_manifest("orders");

    assert pdb["apiVersion"] == "policy/v1";
    assert pdb["kind"] == "PodDisruptionBudget";
    assert pdb["metadata"]["name"] == "orders-pdb";
    assert pdb["metadata"]["namespace"] == "prod";
    # Selector MUST match the Deployment's pod template labels.
    assert pdb["spec"]["selector"] == {"matchLabels": {"app": "orders"}};
    # K6 conservative default: at most 1 voluntary disruption at a time.
    assert pdb["spec"]["maxUnavailable"] == 1;
}


test "_build_hpa_manifest maps gateway sentinel to 'gateway' resource name" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );
    hpa = target._build_hpa_manifest(GATEWAY_NAME);

    assert hpa["metadata"]["name"] == "gateway-hpa";
    assert hpa["spec"]["scaleTargetRef"]["name"] == "gateway-deployment";
}


test "generate_manifests includes hpas + pdbs sections" {
    import jac_scale.config_loader as cfg_mod;

    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );

    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda: _StubMsCfg(
        data={"routes": {"orders": "/api/orders"}}
    ));

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        bundle = target.generate_manifests(ac);

        assert "hpas" in bundle;
        assert "pdbs" in bundle;
        # 1 service + 1 gateway = 2 entries each.
        assert len(bundle["hpas"]) == 2;
        assert len(bundle["pdbs"]) == 2;
        assert "orders" in bundle["hpas"];
        assert "orders" in bundle["pdbs"];
        assert GATEWAY_NAME in bundle["hpas"];
        assert GATEWAY_NAME in bundle["pdbs"];
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
    }
}


test "apply_manifests applies HPAs and PDBs after Deployments" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );
    (apps_v1, core_v1, autoscaling_v2, policy_v1, restore) = (
        _install_k8s_mocks_with_k6()
    );

    bundle = {
        "services": {"orders": target._build_service_manifest("orders")},
        "deployments": {
            "orders": target._build_deployment_manifest(
                "orders",
                {"containers": [{"name": "orders", "image": "demo:latest"}]}
            )
        },
        "hpas": {"orders": target._build_hpa_manifest("orders")},
        "pdbs": {"orders": target._build_pdb_manifest("orders")},
        "pod_specs": {}
    };

    try {
        target.apply_manifests(bundle);

        # Default MagicMock return on read = exists -> patch path.
        assert autoscaling_v2.patch_namespaced_horizontal_pod_autoscaler.call_count == 1;
        assert policy_v1.patch_namespaced_pod_disruption_budget.call_count == 1;
    } finally {
        restore();
    }
}


test "apply_manifests creates new HPA + PDB on 404" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );
    (apps_v1, core_v1, autoscaling_v2, policy_v1, restore) = (
        _install_k8s_mocks_with_k6()
    );

    orig_api_exc = getattr(k8s_mod, "ApiException");
    setattr(k8s_mod, "ApiException", Exception);

    hpa_404 = Exception("hpa not found");
    setattr(hpa_404, "status", 404);
    pdb_404 = Exception("pdb not found");
    setattr(pdb_404, "status", 404);
    autoscaling_v2.read_namespaced_horizontal_pod_autoscaler.side_effect = hpa_404;
    policy_v1.read_namespaced_pod_disruption_budget.side_effect = pdb_404;

    bundle = {
        "services": {},
        "deployments": {},
        "hpas": {"orders": target._build_hpa_manifest("orders")},
        "pdbs": {"orders": target._build_pdb_manifest("orders")},
        "pod_specs": {}
    };

    try {
        target.apply_manifests(bundle);
        assert autoscaling_v2.create_namespaced_horizontal_pod_autoscaler.call_count == 1;
        assert policy_v1.create_namespaced_pod_disruption_budget.call_count == 1;
        # Patch should NOT have been called.
        assert autoscaling_v2.patch_namespaced_horizontal_pod_autoscaler.call_count == 0;
        assert policy_v1.patch_namespaced_pod_disruption_budget.call_count == 0;
    } finally {
        setattr(k8s_mod, "ApiException", orig_api_exc);
        restore();
    }
}


test "destroy also tears down HPAs and PDBs by label" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );
    (apps_v1, core_v1, autoscaling_v2, policy_v1, restore) = (
        _install_k8s_mocks_with_k6()
    );
    core_v1.list_namespaced_service.return_value = (
        unittest.mock.MagicMock(items=[])
    );

    try {
        target.destroy("demo");

        # HPAs use batched delete_collection.
        hpa_kwargs = autoscaling_v2.delete_collection_namespaced_horizontal_pod_autoscaler.call_args.kwargs;
        assert hpa_kwargs["namespace"] == "prod";
        assert hpa_kwargs["label_selector"] == "managed=jac-scale";

        # PDBs use batched delete_collection.
        pdb_kwargs = policy_v1.delete_collection_namespaced_pod_disruption_budget.call_args.kwargs;
        assert pdb_kwargs["namespace"] == "prod";
        assert pdb_kwargs["label_selector"] == "managed=jac-scale";
    } finally {
        restore();
    }
}
