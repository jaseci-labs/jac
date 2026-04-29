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
    mock_networking_v1 = unittest.mock.MagicMock();
    mock_client = unittest.mock.MagicMock();
    mock_client.AppsV1Api.return_value = mock_apps_v1;
    mock_client.CoreV1Api.return_value = mock_core_v1;
    mock_client.AutoscalingV2Api.return_value = mock_autoscaling_v2;
    mock_client.PolicyV1Api.return_value = mock_policy_v1;
    mock_client.NetworkingV1Api.return_value = mock_networking_v1;

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


"""Variant that ALSO returns the NetworkingV1 mock for K10 tests."""
def _install_k8s_mocks_with_k10 -> tuple[Any, Any, Any, Any, Any, Any] {
    mock_apps_v1 = unittest.mock.MagicMock();
    mock_core_v1 = unittest.mock.MagicMock();
    mock_autoscaling_v2 = unittest.mock.MagicMock();
    mock_policy_v1 = unittest.mock.MagicMock();
    mock_networking_v1 = unittest.mock.MagicMock();
    mock_client = unittest.mock.MagicMock();
    mock_client.AppsV1Api.return_value = mock_apps_v1;
    mock_client.CoreV1Api.return_value = mock_core_v1;
    mock_client.AutoscalingV2Api.return_value = mock_autoscaling_v2;
    mock_client.PolicyV1Api.return_value = mock_policy_v1;
    mock_client.NetworkingV1Api.return_value = mock_networking_v1;

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

    return (
        mock_apps_v1, mock_core_v1, mock_autoscaling_v2,
        mock_policy_v1, mock_networking_v1, restore
    );
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
        # Deployments use the strict role-bearing selector (their pod
        # templates carry jac-scale.role).
        kwargs = mock_apps_v1.delete_collection_namespaced_deployment.call_args.kwargs;
        assert kwargs["namespace"] == "prod";
        sel: str = kwargs["label_selector"];
        assert "managed=jac-scale" in sel;
        assert "jac-scale.role in" in sel;
        assert "microservice" in sel;
        assert "gateway" in sel;

        # Services use the role-LESS selector since their manifests only
        # carry `app=<name>` + `managed=jac-scale` (no jac-scale.role
        # label - that's only on Deployments). CI caught this when the
        # strict selector left Services orphaned after destroy.
        list_kwargs = mock_core_v1.list_namespaced_service.call_args.kwargs;
        assert list_kwargs["label_selector"] == "managed=jac-scale";
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


test "service pod-spec readinessProbe hits /healthz/ready" {
    # K5 v2: readiness gates Endpoints membership. /healthz/ready returns
    # 503 during drain so kube-proxy stops routing to the pod within
    # 1-2 probe periods (gives in-flight requests time to finish).
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", container_port=8000)
    );
    spec = target._build_service_pod_spec("orders", "demo:latest");
    container = spec["containers"][0];

    probe = container["readinessProbe"];
    assert probe["httpGet"]["path"] == "/healthz/ready", (
        f"readinessProbe should hit /healthz/ready, got {probe['httpGet']}"
    );
    assert probe["httpGet"]["port"] == 8000;
    # Tight cadence (5s/3 = ~15s to fully drop from Endpoints).
    assert probe["periodSeconds"] == 5;
    assert probe["failureThreshold"] == 3;
}


test "service pod-spec livenessProbe hits /healthz/live (more lenient)" {
    # K5 v2: liveness gates pod restart. Lenient (15s initial, 10s
    # period) because restart is expensive and a too-strict liveness
    # can cascade. /healthz/live deliberately checks nothing other
    # than dispatcher responsiveness so transient dependency blips
    # don't restart the pod.
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", container_port=8000)
    );
    spec = target._build_service_pod_spec("orders", "demo:latest");
    container = spec["containers"][0];

    probe = container["livenessProbe"];
    assert probe["httpGet"]["path"] == "/healthz/live", (
        f"livenessProbe should hit /healthz/live, got {probe['httpGet']}"
    );
    assert probe["httpGet"]["port"] == 8000;
    assert probe["initialDelaySeconds"] == 15;
    assert probe["periodSeconds"] == 10;
    assert probe["failureThreshold"] == 3;
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


# =============================================================================
# K7 - per-service config layering
# =============================================================================

"""Helper: stub get_scale_config to return a fixed services config.

Tests use this to inject `[plugins.scale.microservices.services.NAME]`
overrides without needing a jac.toml fixture.
"""
def _with_services_config(services: dict[str, Any], routes: dict[str, str] = {}) -> tuple[Any, Any] {
    import jac_scale.config_loader as cfg_mod;
    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda: _StubMsCfg(
        data={"routes": routes, "services": services}
    ));
    def restore -> None {
        setattr(cfg_mod, "get_scale_config", original);
    }
    return (cfg_mod, restore);
}


test "Deployment.spec.replicas honors per-service config" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );
    (_cfg, restore) = _with_services_config({"orders": {"replicas": 5}});
    try {
        dep = target._build_deployment_manifest(
            "orders",
            {"containers": [{"name": "orders", "image": "demo:latest"}]}
        );
        assert dep["spec"]["replicas"] == 5;
    } finally {
        restore();
    }
}


test "container env merges JAC_SV_NAME with per-service env (sentinel always first)" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    (_cfg, restore) = _with_services_config({
        "orders": {
            "env": {
                "LOG_LEVEL": "DEBUG",
                "JAC_SV_NAME": "evil_override_attempt"  # must be ignored
            }
        }
    });
    try {
        spec = target._build_service_pod_spec("orders", "demo:latest");
        env: list[dict[str, str]] = spec["containers"][0]["env"];

        # JAC_SV_NAME must be FIRST and uncorrupted.
        assert env[0] == {"name": "JAC_SV_NAME", "value": "orders"};
        # Other env keys appended after.
        log_level_entries = [e for e in env if e["name"] == "LOG_LEVEL"];
        assert len(log_level_entries) == 1;
        assert log_level_entries[0]["value"] == "DEBUG";
        # Attempted shadow of JAC_SV_NAME was dropped.
        assert sum(1 for e in env if e["name"] == "JAC_SV_NAME") == 1;
    } finally {
        restore();
    }
}


test "container resources reflect cpu/memory request and limit overrides" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    (_cfg, restore) = _with_services_config({
        "llm_app": {
            "cpu_request": "500m",
            "cpu_limit": "2000m",
            "memory_request": "1Gi",
            "memory_limit": "4Gi"
        }
    });
    try {
        spec = target._build_service_pod_spec("llm_app", "demo:latest");
        resources = spec["containers"][0]["resources"];
        assert resources["requests"] == {"cpu": "500m", "memory": "1Gi"};
        assert resources["limits"] == {"cpu": "2000m", "memory": "4Gi"};
    } finally {
        restore();
    }
}


test "container has no resources field when no overrides set" {
    # We don't want to emit an empty `resources: {}` since it serializes
    # noisy in K8s manifests; if no overrides, just omit the field.
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    (_cfg, restore) = _with_services_config({});
    try {
        spec = target._build_service_pod_spec("orders", "demo:latest");
        assert "resources" not in spec["containers"][0];
    } finally {
        restore();
    }
}


test "container resources can be partial (only requests, no limits)" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    (_cfg, restore) = _with_services_config({
        "orders": {"cpu_request": "100m", "memory_request": "64Mi"}
    });
    try {
        spec = target._build_service_pod_spec("orders", "demo:latest");
        resources = spec["containers"][0]["resources"];
        assert resources == {
            "requests": {"cpu": "100m", "memory": "64Mi"}
        };
        # No limits key emitted.
        assert "limits" not in resources;
    } finally {
        restore();
    }
}


test "image_tag override replaces tag in repo/name:tag" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    (_cfg, restore) = _with_services_config({
        "orders": {"image_tag": "v2.0-canary"}
    });
    try {
        spec = target._build_service_pod_spec("orders", "myorg/demo:latest");
        assert spec["containers"][0]["image"] == "myorg/demo:v2.0-canary";
    } finally {
        restore();
    }
}


test "image_tag override preserves registry hostname with port" {
    # Regression guard: registry hostnames can have ports
    # (myregistry.io:5000/name:tag); we must split on the LAST colon
    # AND verify the part after has no slash, otherwise we'd mistake
    # the registry port for a tag.
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    (_cfg, restore) = _with_services_config({
        "orders": {"image_tag": "canary"}
    });
    try {
        # No tag in input, just registry+port+name.
        spec1 = target._build_service_pod_spec(
            "orders", "myregistry.io:5000/demo"
        );
        assert spec1["containers"][0]["image"] == "myregistry.io:5000/demo:canary";

        # Already has a tag.
        spec2 = target._build_service_pod_spec(
            "orders", "myregistry.io:5000/demo:latest"
        );
        assert spec2["containers"][0]["image"] == "myregistry.io:5000/demo:canary";
    } finally {
        restore();
    }
}


test "HPA bounds reflect per-service hpa overrides" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    (_cfg, restore) = _with_services_config({
        "llm_app": {"hpa": {"min": 3, "max": 20, "cpu_target": 60}}
    });
    try {
        hpa = target._build_hpa_manifest("llm_app");
        assert hpa is not None;
        assert hpa["spec"]["minReplicas"] == 3;
        assert hpa["spec"]["maxReplicas"] == 20;
        assert hpa["spec"]["metrics"][0]["resource"]["target"]["averageUtilization"] == 60;
    } finally {
        restore();
    }
}


test "HPA returns None when hpa.enabled = false" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    (_cfg, restore) = _with_services_config({
        "leader_only": {"hpa": {"enabled": False}}
    });
    try {
        hpa = target._build_hpa_manifest("leader_only");
        assert hpa is None;
    } finally {
        restore();
    }
}


test "PDB max_unavailable reflects per-service override" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    (_cfg, restore) = _with_services_config({
        "orders": {"pdb": {"max_unavailable": 3}}
    });
    try {
        pdb = target._build_pdb_manifest("orders");
        assert pdb is not None;
        assert pdb["spec"]["maxUnavailable"] == 3;
    } finally {
        restore();
    }
}


test "PDB returns None when pdb.enabled = false" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    (_cfg, restore) = _with_services_config({
        "orders": {"pdb": {"enabled": False}}
    });
    try {
        pdb = target._build_pdb_manifest("orders");
        assert pdb is None;
    } finally {
        restore();
    }
}


test "generate_manifests skips disabled HPAs and PDBs" {
    import jac_scale.config_loader as cfg_mod;
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );

    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda: _StubMsCfg(
        data={
            "routes": {"orders": "/api/orders", "leader": "/api/leader"},
            "services": {
                "leader": {
                    "hpa": {"enabled": False},
                    "pdb": {"enabled": False}
                }
            }
        }
    ));

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        bundle = target.generate_manifests(ac);

        # `orders` and gateway: HPA + PDB present.
        # `leader`: skipped from both sections.
        assert "orders" in bundle["hpas"];
        assert GATEWAY_NAME in bundle["hpas"];
        assert "leader" not in bundle["hpas"];
        assert "orders" in bundle["pdbs"];
        assert GATEWAY_NAME in bundle["pdbs"];
        assert "leader" not in bundle["pdbs"];
        # Deployment + Service still present for leader (only HPA/PDB
        # are opt-out).
        assert "leader" in bundle["deployments"];
        assert "leader" in bundle["services"];
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
    }
}


test "gateway honors per-service config under __gateway__ key" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    (_cfg, restore) = _with_services_config({
        GATEWAY_NAME: {
            "replicas": 3,
            "cpu_request": "200m",
            "env": {"GATEWAY_DEBUG": "1"}
        }
    });
    try {
        # Deployment replicas
        dep = target._build_deployment_manifest(
            GATEWAY_NAME,
            target._build_gateway_pod_spec("demo:latest")
        );
        assert dep["spec"]["replicas"] == 3;

        # Pod-spec resources + env
        spec = target._build_gateway_pod_spec("demo:latest");
        container = spec["containers"][0];
        assert container["resources"]["requests"]["cpu"] == "200m";
        gateway_debug = [e for e in container["env"] if e["name"] == "GATEWAY_DEBUG"];
        assert len(gateway_debug) == 1;
    } finally {
        restore();
    }
}


test "_service_config returns {} on read failure (graceful)" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    import jac_scale.config_loader as cfg_mod;

    obj _ExplodingCfg {
        def get_microservices_config -> dict[str, Any] {
            raise RuntimeError("simulated config failure");
        }
    }
    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda: _ExplodingCfg());

    try {
        # No raise; empty dict so all manifest paths use defaults.
        assert target._service_config("orders") == {};
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
    }
}


# =============================================================================
# K9 - pod entrypoint dispatch (command + args on container spec)
# =============================================================================

test "service pod-spec carries command + args that exec jac start" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    spec = target._build_service_pod_spec("orders", "demo:latest");
    container = spec["containers"][0];

    # The pod-spec wires entrypoint logic into the container itself
    # so any image with `jac` + `jac-scale[deploy]` installed Just Works
    # (no app-side ENTRYPOINT needed).
    assert container["command"] == ["sh", "-c"];
    assert len(container["args"]) == 1;
    arg = container["args"][0];
    # JAC_SV_SIBLING=1 prevents the in-pod jac process from re-entering
    # the local-mode orchestrator (it would try to spawn peers again).
    assert "JAC_SV_SIBLING=1" in arg;
    # Service path: jac start <name>.jac
    assert "jac start" in arg;
    # Sentinel branch: gateway-only mode
    assert "jac scale gateway" in arg;
    # JAC_SV_NAME drives the dispatch
    assert "JAC_SV_NAME" in arg;
}


test "gateway pod-spec carries the same dispatch wiring" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    spec = target._build_gateway_pod_spec("demo:latest");
    container = spec["containers"][0];

    # Same dispatch script - the JAC_SV_NAME=__gateway__ env (set by
    # _build_env) flips the if/else inside the script at runtime.
    assert container["command"] == ["sh", "-c"];
    assert "jac scale gateway" in container["args"][0];
    # Gateway env still sets JAC_SV_NAME to the sentinel; runtime
    # script reads it and takes the gateway branch.
    sv_name_entries = [
        e for e in container["env"] if e["name"] == "JAC_SV_NAME"
    ];
    assert len(sv_name_entries) == 1;
    assert sv_name_entries[0]["value"] == GATEWAY_NAME;
}


test "container name is DNS-1123 normalized (regression guard for K8s 422)" {
    # Real K8s API rejects underscores in container.name with 422
    # Unprocessable Entity (RFC 1123 label rules). Found by CI when the
    # smoke applied a pod-spec with `containers[0].name = "orders_app"`.
    # The resource names (Deployment, Service) were already normalized
    # via k8s_safe_name; this test ensures the container.name is too.
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    spec = target._build_service_pod_spec("orders_app", "demo:latest");
    container_name: str = spec["containers"][0]["name"];
    assert container_name == "orders-app", (
        f"container.name must be DNS-1123 (no underscores), got {container_name!r}"
    );
    # JAC_SV_NAME env preserves the raw name (entrypoint dispatch needs
    # the original to find <name>.jac).
    env_jac_name = next(
        e for e in spec["containers"][0]["env"] if e["name"] == "JAC_SV_NAME"
    );
    assert env_jac_name["value"] == "orders_app";
}


test "_pod_entrypoint command/args are stable (regression guard)" {
    # If we ever change the entrypoint shape, the Dockerfile template
    # documentation might drift. Pin the structure so that's caught
    # by the test suite.
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    entry = target._pod_entrypoint();
    assert entry["command"] == ["sh", "-c"];
    assert isinstance(entry["args"], list);
    assert len(entry["args"]) == 1;
}


# =============================================================================
# K10 - optional Ingress manifest pointing at the gateway
# =============================================================================

test "_build_ingress_manifest returns None when not enabled" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    # Default: disabled.
    assert target._build_ingress_manifest({}) is None;
    # Explicit disable.
    assert target._build_ingress_manifest({"enabled": False}) is None;
}


test "_build_ingress_manifest emits Ingress with sensible defaults" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(
            app_name="demo", namespace="prod", container_port=8000
        )
    );
    ing = target._build_ingress_manifest({"enabled": True});

    assert ing is not None;
    assert ing["apiVersion"] == "networking.k8s.io/v1";
    assert ing["kind"] == "Ingress";
    assert ing["metadata"]["name"] == "gateway-ingress";
    assert ing["metadata"]["namespace"] == "prod";
    assert ing["metadata"]["labels"]["app"] == "gateway";
    assert ing["metadata"]["labels"]["managed"] == "jac-scale";

    rules = ing["spec"]["rules"];
    assert len(rules) == 1;
    rule = rules[0];
    # No host -> Ingress matches any host.
    assert "host" not in rule;
    paths = rule["http"]["paths"];
    assert len(paths) == 1;
    path = paths[0];
    assert path["path"] == "/";
    assert path["pathType"] == "Prefix";
    backend = path["backend"]["service"];
    assert backend["name"] == "gateway-service";
    assert backend["port"]["number"] == 8000;
    # No ingressClassName by default - user picks their controller.
    assert "ingressClassName" not in ing["spec"];
}


test "_build_ingress_manifest honors host + ingress_class_name" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );
    ing = target._build_ingress_manifest({
        "enabled": True,
        "host": "shop.example.com",
        "ingress_class_name": "nginx"
    });
    assert ing is not None;
    assert ing["spec"]["rules"][0]["host"] == "shop.example.com";
    assert ing["spec"]["ingressClassName"] == "nginx";
}


test "_build_ingress_manifest carries controller-specific annotations" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );
    ing = target._build_ingress_manifest({
        "enabled": True,
        "annotations": {
            "nginx.ingress.kubernetes.io/proxy-body-size": "10m",
            "alb.ingress.kubernetes.io/scheme": "internet-facing"
        }
    });
    assert ing is not None;
    annotations = ing["metadata"]["annotations"];
    assert annotations["nginx.ingress.kubernetes.io/proxy-body-size"] == "10m";
    assert annotations["alb.ingress.kubernetes.io/scheme"] == "internet-facing";
}


test "generate_manifests includes ingress when enabled" {
    import jac_scale.config_loader as cfg_mod;
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );

    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda: _StubMsCfg(
        data={
            "routes": {"orders": "/api/orders"},
            "ingress": {
                "enabled": True,
                "host": "demo.example.com",
                "ingress_class_name": "nginx"
            }
        }
    ));

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        bundle = target.generate_manifests(ac);
        assert "ingress" in bundle;
        assert bundle["ingress"]["spec"]["rules"][0]["host"] == "demo.example.com";
        assert bundle["ingress"]["spec"]["ingressClassName"] == "nginx";
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
    }
}


test "generate_manifests OMITS ingress when not enabled" {
    import jac_scale.config_loader as cfg_mod;
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo")
    );

    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda: _StubMsCfg(
        data={"routes": {"orders": "/api/orders"}}
    ));

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        bundle = target.generate_manifests(ac);
        # Default-off: no ingress key at all in the bundle.
        assert "ingress" not in bundle;
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
    }
}


test "apply_manifests applies Ingress when present" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );
    (apps_v1, core_v1, autoscaling_v2, policy_v1, networking_v1, restore) = (
        _install_k8s_mocks_with_k10()
    );

    ingress = target._build_ingress_manifest({
        "enabled": True, "host": "demo.example.com"
    });
    bundle = {
        "services": {},
        "deployments": {},
        "hpas": {},
        "pdbs": {},
        "ingress": ingress,
        "pod_specs": {}
    };

    try {
        target.apply_manifests(bundle);
        # MagicMock default: read returns ok -> patch path taken.
        assert networking_v1.patch_namespaced_ingress.call_count == 1;
        call_kwargs = networking_v1.patch_namespaced_ingress.call_args.kwargs;
        assert call_kwargs["name"] == "gateway-ingress";
        assert call_kwargs["namespace"] == "prod";
    } finally {
        restore();
    }
}


test "apply_manifests skips Ingress when bundle has none" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );
    (apps_v1, core_v1, autoscaling_v2, policy_v1, networking_v1, restore) = (
        _install_k8s_mocks_with_k10()
    );

    bundle = {
        "services": {},
        "deployments": {},
        "hpas": {},
        "pdbs": {},
        "pod_specs": {}
        # No "ingress" key at all (default-off path).
    };

    try {
        target.apply_manifests(bundle);
        # NetworkingV1Api should never have been called for Ingress ops.
        assert networking_v1.read_namespaced_ingress.call_count == 0;
        assert networking_v1.create_namespaced_ingress.call_count == 0;
        assert networking_v1.patch_namespaced_ingress.call_count == 0;
    } finally {
        restore();
    }
}


test "destroy also tears down Ingresses by label" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );
    (apps_v1, core_v1, autoscaling_v2, policy_v1, networking_v1, restore) = (
        _install_k8s_mocks_with_k10()
    );
    core_v1.list_namespaced_service.return_value = (
        unittest.mock.MagicMock(items=[])
    );

    try {
        target.destroy("demo");
        # Ingress is batched-deleted by the same `managed=jac-scale` label.
        kw = networking_v1.delete_collection_namespaced_ingress.call_args.kwargs;
        assert kw["namespace"] == "prod";
        assert kw["label_selector"] == "managed=jac-scale";
    } finally {
        restore();
    }
}
