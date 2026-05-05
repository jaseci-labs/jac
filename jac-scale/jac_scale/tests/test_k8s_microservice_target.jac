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

    def restore {
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

    def restore {
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

    def restore {
        setattr(k8s_mod, "client", orig_client);
        setattr(k8s_mod, "k8s_cluster_config", orig_cfg);
        setattr(k8s_mod, "ensure_namespace_exists", orig_ens);
    }

    return (
        mock_apps_v1,
        mock_core_v1,
        mock_autoscaling_v2,
        mock_policy_v1,
        mock_networking_v1,
        restore
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
    setattr(
        cfg_mod,
        "get_scale_config",
        lambda :
            _StubMsCfg(
                data={
                    "routes": {
                        "orders": "/api/orders",
                        "cart": "/api/cart",
                        "products": "/api/products"
                    }
                }
            )
    );

    try {
        # build=False -> _handle_image_registry returns
        # k8s_config.python_image without doing any registry work.
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        specs = target.generate_service_pod_specs(ac);

        assert len(specs) == 4 , (
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
    setattr(
        cfg_mod,
        "get_scale_config",
        lambda : _StubMsCfg(data={"routes": {"orders": "/api/orders"}})
    );

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        specs = target.generate_service_pod_specs(ac);

        # The python_image fallback is what we expect (build=False path).
        expected_image = target.k8s_config.python_image;

        # Service pod-spec: image + JAC_SV_NAME=orders
        orders_spec = specs["orders"];
        orders_container = orders_spec["containers"][0];
        assert orders_container["image"] == expected_image;
        assert orders_container["env"] == [{"name": "JAC_SV_NAME", "value": "orders"}];
        assert orders_container["ports"][0]["containerPort"] == 8000;

        # Gateway pod-spec: same image, JAC_SV_NAME=GATEWAY_NAME sentinel
        gw_spec = specs[GATEWAY_NAME];
        gw_container = gw_spec["containers"][0];
        assert gw_container["image"] == expected_image , (
            "gateway must share the same image as services (single-image strategy)"
        );
        assert gw_container["env"] == [{"name": "JAC_SV_NAME", "value": GATEWAY_NAME}];
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
    }
}


# NOTE: the old "empty routes still produces a gateway pod-spec" test
# has been superseded by the P1.3 assertion at the end of this file
# ("empty routes produces actionable error, not silent gateway-only
# deploy"). Silently producing a gateway-only spec was the wrong
# behavior - users running `jac start --scale` against a misconfigured
# project should get a fail-fast error pointing at the exact jac.toml
# section to fix, not a confusing "gateway routes to nothing" deploy.
test "container port respects k8s_config.container_port override" {
    import jac_scale.config_loader as cfg_mod;

    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", container_port=9090)
    );

    original = getattr(cfg_mod, "get_scale_config");
    setattr(
        cfg_mod,
        "get_scale_config",
        lambda : _StubMsCfg(data={"routes": {"orders": "/api/orders"}})
    );

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        specs = target.generate_service_pod_specs(ac);

        # Both service and gateway pick up the configured port.
        assert specs["orders"]["containers"][0]["ports"][0]["containerPort"] == 9090;
        assert specs[GATEWAY_NAME]["containers"][0]["ports"][0][
            "containerPort"
        ] == 9090;
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
    }
}


# =============================================================================
# Inheritance + factory dispatch (the K1 wiring)
# =============================================================================
test "KubernetesMicroserviceTarget is a KubernetesTarget" {
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
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

    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));

    # Need to patch BOTH config (for routes discovery) AND the k8s
    # client (for apply_manifests). MagicMock's default-return (no
    # side_effect) makes read_*/patch_* succeed silently which is the
    # idempotent already-deployed path.
    (mock_apps_v1, mock_core_v1, k8s_restore) = _install_k8s_mocks();

    original = getattr(cfg_mod, "get_scale_config");
    setattr(
        cfg_mod,
        "get_scale_config",
        lambda :
            _StubMsCfg(data={"routes": {"orders": "/api/orders", "cart": "/api/cart"}})
    );

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        result = target.deploy(ac);

        assert result.success , f"deploy failed: {result.message}";
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

    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));

    obj _ExplodingCfg {
        def get_microservices_config -> dict[str, Any] {
            raise RuntimeError("simulated config read failure");
        }
    }

    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda : _ExplodingCfg());

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
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
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
        config=KubernetesConfig(app_name="demo", namespace="prod", container_port=8000)
    );
    pod_spec = {
        "containers": [
            {
                "name": "orders",
                "image": "demo:latest",
                "env": [{"name": "JAC_SV_NAME", "value": "orders"}],
                "ports": [{"containerPort": 8000}]
            }
        ]
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
        config=KubernetesConfig(app_name="demo", namespace="prod", container_port=9090)
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
    # P0.9: regular service pods stay round-robin (stateless wrt
    # connections; each request through the gateway is independent).
    # Only the gateway gets sticky sessions - see the next test.
    assert "sessionAffinity" not in svc["spec"];
}


test "P0.8: _provision_databases is no-op without _JAC_SCALE_AUTO_BUILD env" {
    # Same opt-in pattern as P0.5/P0.6. Tests calling deploy() directly
    # don't set the env var, so DB provisioning skips the real K8s API
    # calls (which would need a live cluster + actually create
    # StatefulSets). env_list + init_containers are reset to empty.
    import os;
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    # Pre-populate so we can assert reset.
    target.env_list = [{"name": "PREEXISTING", "value": "leftover"}];
    target._microservice_init_containers = [{"name": "leftover-init"}];
    prev_env = os.environ.get("_JAC_SCALE_AUTO_BUILD");
    os.environ.pop("_JAC_SCALE_AUTO_BUILD", None);

    try {
        target._provision_databases("demo");
        # Reset happened (so re-running deploy doesn't double-append),
        # but no K8s API calls were made (we'd have hung if so).
        assert target.env_list == [];
        assert target._microservice_init_containers == [];
    } finally {
        if prev_env is not None {
            os.environ["_JAC_SCALE_AUTO_BUILD"] = prev_env;
        }
    }
}


test "P0.8: pod-spec has no init_containers when _provision_databases didn't run" {
    # Tests asserting manifest shape don't run _provision_databases,
    # so pod-specs must NOT carry initContainers (K8s would 422 on an
    # empty list otherwise; ours uses getattr with default []).
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    spec = target._build_service_pod_spec("orders", "demo:latest");
    # initContainers field is OPTIONAL on a PodSpec - omit when empty
    # rather than emit `initContainers: []` which K8s 422s.
    assert "initContainers" not in spec;
}


test "P0.8: pod-spec includes init_containers when populated" {
    # Simulates the post-_provision_databases state: the wait-for-Mongo
    # init container is set on the target, and pod-specs must include
    # it so service pods don't crash-loop before Mongo is reachable.
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    target._microservice_init_containers = [
        {
            "name": "wait-mongo",
            "image": "busybox:1.36",
            "command": ["sh", "-c", "until nc -z mongo 27017; do sleep 2; done"]
        }
    ];
    spec = target._build_service_pod_spec("orders", "demo:latest");
    assert "initContainers" in spec;
    assert len(spec["initContainers"]) == 1;
    assert spec["initContainers"][0]["name"] == "wait-mongo";
}


test "P0.8: _build_env merges database env between JAC_SV_NAME and user env" {
    # Order matters:
    #   1. JAC_SV_NAME (sentinel - never overrideable)
    #   2. Database env (MONGODB_URI / REDIS_URL via secretKeyRef)
    #   3. User env from [...services.NAME.env]
    # User-set MONGODB_URI in service env would shadow our auto-injected
    # one (last write wins in K8s container.env), letting power users
    # point at a custom Mongo if they want.
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    target.env_list = [
        {
            "name": "MONGODB_URI",
            "valueFrom": {
                "secretKeyRef": {
                    "name": "demo-mongodb-secret",
                    "key": "connection-string"
                }
            }
        },
        {
            "name": "REDIS_URL",
            "valueFrom": {
                "secretKeyRef": {
                    "name": "demo-redis-secret",
                    "key": "connection-string"
                }
            }
        }
    ];
    env = target._build_env("orders", {"env": {"MY_OWN_KEY": "value123"}});

    # JAC_SV_NAME first, never overridden
    assert env[0]["name"] == "JAC_SV_NAME";
    assert env[0]["value"] == "orders";

    # Database env follows
    names = [e["name"] for e in env];
    assert "MONGODB_URI" in names;
    assert "REDIS_URL" in names;
    # User env still present
    assert "MY_OWN_KEY" in names;

    # MongoDB env uses secretKeyRef (not a plaintext value), confirming
    # we got the parent's secret-based shape (not a string we built).
    mongo_idx = names.index("MONGODB_URI");
    assert "valueFrom" in env[mongo_idx];
    assert env[mongo_idx]["valueFrom"]["secretKeyRef"]["key"] == "connection-string";
}


test "P0.9: gateway Service has ClientIP sticky sessions for WebSocket" {
    # Without sessionAffinity, kube-proxy round-robins TCP connections
    # across gateway replicas. WebSocket reconnects then land on a
    # different pod that doesn't have the existing session state -
    # session loss + auth re-prompt + lost subscriptions. ClientIP-based
    # stickiness is the standard Service-layer fix.
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    gw_svc = target._build_service_manifest(GATEWAY_NAME);
    assert gw_svc["spec"]["sessionAffinity"] == "ClientIP";
    timeout = gw_svc["spec"]["sessionAffinityConfig"]["clientIP"]["timeoutSeconds"];
    # 3h is generous enough for long-lived WS sessions; far below K8s
    # max (10800s == 3h, which is the practical upper bound anyway).
    assert timeout == 10800;
}


test "generate_manifests produces deployments + services per pod-spec" {
    import jac_scale.config_loader as cfg_mod;

    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );

    original = getattr(cfg_mod, "get_scale_config");
    setattr(
        cfg_mod,
        "get_scale_config",
        lambda :
            _StubMsCfg(data={"routes": {"orders": "/api/orders", "cart": "/api/cart"}})
    );

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        bundle = target.generate_manifests(ac);

        # Bundle has all keyed sections (K2 + K6).
        # Use a superset assertion so additions in later K-tasks don't
        # break this test.
        for required in ("deployments", "services", "pod_specs") {
            assert required in bundle , f"missing required section: {required}";
        }

        # Each section has 1 entry per service + 1 for the gateway.
        for section in ("deployments", "services", "pod_specs") {
            assert len(bundle[section]) == 3 , (
                f"section {section} expected 3 entries, got {len(bundle[section])}"
            );
            assert "orders" in bundle[section];
            assert "cart" in bundle[section];
            assert GATEWAY_NAME in bundle[section];
        }

        # Selectors must match across paired Deployment + Service so
        # kube-proxy routes correctly.
        for svc_name in ["orders", "cart"] {
            dep_selector = bundle["deployments"][svc_name]["spec"]["selector"][
                "matchLabels"
            ];
            svc_selector = bundle["services"][svc_name]["spec"]["selector"];
            assert dep_selector == svc_selector , (
                f"selector mismatch for {svc_name}: deployment={dep_selector}, service={svc_selector}"
            );
        }
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
    }
}


test "deploy returns K3 applied bundle in details" {
    import jac_scale.config_loader as cfg_mod;

    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));

    (_apps, _core, k8s_restore) = _install_k8s_mocks();
    original = getattr(cfg_mod, "get_scale_config");
    setattr(
        cfg_mod,
        "get_scale_config",
        lambda : _StubMsCfg(data={"routes": {"orders": "/api/orders"}})
    );

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        result = target.deploy(ac);

        assert result.success , f"deploy failed: {result.message}";
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
                "orders", {"containers": [{"name": "orders", "image": "demo:latest"}]}
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
                "orders", {"containers": [{"name": "orders", "image": "demo:latest"}]}
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
        assert first_dep > 0 , f"no dep_patch call: {names}";
        for (i, n) in enumerate(names) {
            if "svc_patch" in n {
                assert i < first_dep , (
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
        assert names == {"orders-service","gateway-service"};
    } finally {
        k8s_restore();
    }
}


test "deploy surfaces apply failure as DeploymentResult success=False" {
    import jac_scale.config_loader as cfg_mod;

    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (mock_apps_v1, mock_core_v1, k8s_restore) = _install_k8s_mocks();
    # Force apply to fail at the Service step.
    mock_core_v1.read_namespaced_service.side_effect = RuntimeError(
        "simulated cluster outage"
    );

    original = getattr(cfg_mod, "get_scale_config");
    setattr(
        cfg_mod,
        "get_scale_config",
        lambda : _StubMsCfg(data={"routes": {"orders": "/api/orders"}})
    );

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
import from jac_scale.microservices.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}
import from jac_scale.microservices.k8s_deployer {
    KubernetesDeployer,
    build_k8s_registry
}


test "KubernetesDeployer is a ServiceDeployer" {
    reg = ServiceRegistry();
    dep = KubernetesDeployer(registry=reg);
    assert isinstance(dep, ServiceDeployer);
    assert dep.target == "kubernetes";
}


test "KubernetesDeployer.url_for returns DNS-based URL" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    dep = KubernetesDeployer(registry=reg, namespace="prod", port=8080);

    url = dep.url_for(reg.entries["orders"]);
    assert url == "http://orders-service.prod.svc.cluster.local:8080";
}


test "KubernetesDeployer.url_for normalizes underscored names" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(name="orders_app", file="orders_app.jac", prefix="/api/orders")
    );
    dep = KubernetesDeployer(registry=reg, namespace="default", port=8000);

    # "orders_app" -> "orders-app" (DNS-1123: no underscores allowed).
    url = dep.url_for(reg.entries["orders_app"]);
    assert url == "http://orders-app-service.default.svc.cluster.local:8000";
}


test "KubernetesDeployer.url_for maps GATEWAY_NAME sentinel to 'gateway'" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name=GATEWAY_NAME, file="", prefix="/"));
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
            routes={"orders": "/api/orders", "cart": "/api/cart"}, port=9090
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
    setattr(
        cfg_mod,
        "get_scale_config",
        lambda :
            _StubMsCfg(
                data={
                    "routes": {"orders": "/api/orders", "cart": "/api/cart"},
                    "gateway_port": 8000
                }
            )
    );

    try {
        registry = JacScalePlugin.get_sv_registry();
        assert registry["orders"] == (
            "http://orders-service.prod.svc.cluster.local:8000"
        );
        assert registry["cart"] == ("http://cart-service.prod.svc.cluster.local:8000");
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
    setattr(cfg_mod, "get_scale_config", lambda : _ExplodingCfg());

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
    assert probe["httpGet"]["path"] == "/healthz/ready" , (
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
    assert probe["httpGet"]["path"] == "/healthz/live" , (
        f"livenessProbe should hit /healthz/live, got {probe['httpGet']}"
    );
    assert probe["httpGet"]["port"] == 8000;
    assert probe["initialDelaySeconds"] == 15;
    assert probe["periodSeconds"] == 10;
    assert probe["failureThreshold"] == 3;
}


test "service pod-spec carries lifecycle.preStop sleep" {
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
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
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    spec = target._build_service_pod_spec("orders", "demo:latest");

    # Default drain_timeout is 10s (memory + jfast_api default), so
    # grace = 15s. The +5s cushion gives uvicorn time to actually
    # exit AFTER drain returns; without it SIGKILL can land mid-drain.
    assert spec["terminationGracePeriodSeconds"] == 15;
}


test "pod-spec terminationGracePeriodSeconds tracks drain_timeout config override" {
    import jac_scale.config_loader as cfg_mod;
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));

    original = getattr(cfg_mod, "get_scale_config");
    setattr(
        cfg_mod,
        "get_scale_config",
        lambda : _StubMsCfg(data={"drain_timeout_seconds": 60})
    );

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
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));

    obj _ExplodingCfg {
        def get_microservices_config -> dict[str, Any] {
            raise RuntimeError("simulated config failure");
        }
    }
    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda : _ExplodingCfg());

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
    setattr(
        cfg_mod,
        "get_scale_config",
        lambda : _StubMsCfg(data={"routes": {"orders": "/api/orders"}})
    );

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
                "orders", {"containers": [{"name": "orders", "image": "demo:latest"}]}
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
    core_v1.list_namespaced_service.return_value = unittest.mock.MagicMock(items=[]);

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
def _with_services_config(
    services: dict[str, Any], routes: dict[str, str] = {}
) -> tuple[Any, Any] {
    import jac_scale.config_loader as cfg_mod;
    original = getattr(cfg_mod, "get_scale_config");
    setattr(
        cfg_mod,
        "get_scale_config",
        lambda : _StubMsCfg(data={"routes": routes, "services": services})
    );
    def restore {
        setattr(cfg_mod, "get_scale_config", original);
    }
    return (cfg_mod, restore);
}


"""P0.25 helper: stub microservices config with shared_volumes entries.

Each entry mirrors the [[plugins.scale.microservices.shared_volumes]]
schema so tests can assert against realistic configs.
"""
def _with_shared_volumes(
    shared_volumes: list[dict[str, Any]],
    services: dict[str, Any] = {},
    routes: dict[str, str] = {}
) -> tuple[Any, Any] {
    import jac_scale.config_loader as cfg_mod;
    original = getattr(cfg_mod, "get_scale_config");
    setattr(
        cfg_mod,
        "get_scale_config",
        lambda : _StubMsCfg(
            data={
                "routes": routes,
                "services": services,
                "shared_volumes": shared_volumes
            }
        )
    );
    def restore {
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
            "orders", {"containers": [{"name": "orders", "image": "demo:latest"}]}
        );
        assert dep["spec"]["replicas"] == 5;
    } finally {
        restore();
    }
}


test "container env merges JAC_SV_NAME with per-service env (sentinel always first)" {
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_services_config(
        {
            "orders": {
                "env": {"LOG_LEVEL": "DEBUG", "JAC_SV_NAME": "evil_override_attempt"}
            }
        }
    );
    try {
        spec = target._build_service_pod_spec("orders", "demo:latest");
        env: list[dict[str, str]] = spec["containers"][0]["env"];

        # JAC_SV_NAME must be FIRST and uncorrupted.
        assert env[0] == {"name": "JAC_SV_NAME", "value": "orders"};
        # Other env keys appended after.
        log_level_entries = [
            e
            for e in env
            if e["name"] == "LOG_LEVEL"
        ];
        assert len(log_level_entries) == 1;
        assert log_level_entries[0]["value"] == "DEBUG";
        # Attempted shadow of JAC_SV_NAME was dropped.
        assert sum(
            1
            for e in env
            if e["name"] == "JAC_SV_NAME"
        ) == 1;
    } finally {
        restore();
    }
}


test "container resources reflect cpu/memory request and limit overrides" {
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_services_config(
        {
            "llm_app": {
                "cpu_request": "500m",
                "cpu_limit": "2000m",
                "memory_request": "1Gi",
                "memory_limit": "4Gi"
            }
        }
    );
    try {
        spec = target._build_service_pod_spec("llm_app", "demo:latest");
        resources = spec["containers"][0]["resources"];
        assert resources["requests"] == {"cpu": "500m", "memory": "1Gi"};
        assert resources["limits"] == {"cpu": "2000m", "memory": "4Gi"};
    } finally {
        restore();
    }
}


test "P0.8b: container has DEFAULT resources when no overrides set (Burstable QoS)" {
    # P0.8b: Without resource requests, K8s assigns BestEffort QoS class
    # which is the FIRST to be evicted under memory pressure. We saw this
    # bite hard on a 7.6GB EC2 box where transient compile peaks caused
    # a ~25min eviction storm before pods stabilized. Sane defaults bump
    # QoS to Burstable.
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_services_config({});
    try {
        spec = target._build_service_pod_spec("orders", "demo:latest");
        resources = spec["containers"][0]["resources"];
        # Defaults present
        assert resources["requests"]["memory"] == "128Mi";
        assert resources["requests"]["cpu"] == "50m";
        assert resources["limits"]["memory"] == "1Gi";
        # cpu_limit deliberately omitted (CPU limits often counterproductive
        # vs cgroup fair-share)
        assert "cpu" not in resources["limits"];
    } finally {
        restore();
    }
}


test "P0.8b: empty-string user override opts back into BestEffort" {
    # Escape hatch for users who explicitly want BestEffort QoS (e.g.
    # dev clusters where you don't care about resource accounting).
    # Set every field to empty string to opt out of every default.
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_services_config(
        {
            "orders": {
                "memory_request": "",
                "memory_limit": "",
                "cpu_request": ""
            }
        }
    );
    try {
        spec = target._build_service_pod_spec("orders", "demo:latest");
        # Empty values mean no requests/limits emitted -> back to BestEffort
        assert "resources" not in spec["containers"][0];
    } finally {
        restore();
    }
}


test "container resources can be partial (user requests, no limits)" {
    # Per-service config layers OVER defaults. User-specified values win;
    # unset defaults still apply.
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_services_config(
        {"orders": {"cpu_request": "100m", "memory_request": "64Mi"}}
    );
    try {
        spec = target._build_service_pod_spec("orders", "demo:latest");
        resources = spec["containers"][0]["resources"];
        # User overrides
        assert resources["requests"]["cpu"] == "100m";
        assert resources["requests"]["memory"] == "64Mi";
        # Default memory_limit still applies (user only set requests)
        assert resources["limits"]["memory"] == "1Gi";
        # cpu_limit still omitted (default behavior)
        assert "cpu" not in resources.get("limits", {});
    } finally {
        restore();
    }
}


# =============================================================================
# P0.20: [plugins.scale.kubernetes] resource + probe values must reach the
# microservice manifest (used to be silently dropped on the floor)
# =============================================================================

test "P0.20: resources fall back to KubernetesConfig before P0.8b floor" {
    # Without this, jac.toml's [plugins.scale.kubernetes].memory_limit was
    # silently ignored - every service got the 1Gi P0.8b floor regardless
    # of what the user configured. Real apps (jacBuilder) OOMKilled at
    # first import. Priority: per-service > kubernetes block > P0.8b floor.
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(
            app_name="demo",
            memory_request="2Gi",
            memory_limit="4Gi",
            cpu_request="500m",
            cpu_limit="2000m"
        )
    );
    (_cfg, restore) = _with_services_config({});  # no per-service overrides
    try {
        spec = target._build_service_pod_spec("orders", "demo:latest");
        resources = spec["containers"][0]["resources"];
        # k8s_config values should land - NOT the P0.8b floor.
        assert resources["requests"]["memory"] == "2Gi" , (
            f"expected 2Gi from k8s_config, got {resources['requests']['memory']}"
        );
        assert resources["requests"]["cpu"] == "500m";
        assert resources["limits"]["memory"] == "4Gi" , (
            f"expected 4Gi from k8s_config, got {resources['limits']['memory']}"
        );
        assert resources["limits"]["cpu"] == "2000m";
    } finally {
        restore();
    }
}


test "P0.20: per-service overrides win over KubernetesConfig values" {
    # Per-service config is the most-specific signal - must beat
    # the project-wide kubernetes block.
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(
            app_name="demo",
            memory_request="2Gi",
            memory_limit="4Gi"
        )
    );
    (_cfg, restore) = _with_services_config(
        {"hot_service": {"memory_request": "8Gi", "memory_limit": "16Gi"}}
    );
    try {
        spec = target._build_service_pod_spec("hot_service", "demo:latest");
        resources = spec["containers"][0]["resources"];
        # Per-service wins
        assert resources["requests"]["memory"] == "8Gi";
        assert resources["limits"]["memory"] == "16Gi";
    } finally {
        restore();
    }
}


test "P0.20: P0.8b floor still applies when neither per-service nor cfg set" {
    # Compatibility check: existing apps with no resource config at any
    # level should still get the Burstable QoS floor (P0.8b behavior).
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    # KubernetesConfig defaults: memory_request/limit/cpu_request all None
    (_cfg, restore) = _with_services_config({});
    try {
        spec = target._build_service_pod_spec("orders", "demo:latest");
        resources = spec["containers"][0]["resources"];
        # P0.8b defaults
        assert resources["requests"]["memory"] == "128Mi";
        assert resources["requests"]["cpu"] == "50m";
        assert resources["limits"]["memory"] == "1Gi";
    } finally {
        restore();
    }
}


test "P0.20: empty-string per-service override still trumps KubernetesConfig" {
    # The `""` opt-out should win over a non-empty kubernetes block too -
    # otherwise users who set memory_limit at the project level lose the
    # ability to opt one service back into BestEffort.
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", memory_request="2Gi", memory_limit="4Gi")
    );
    (_cfg, restore) = _with_services_config(
        {
            "raw_service": {
                "memory_request": "", "memory_limit": "", "cpu_request": ""
            }
        }
    );
    try {
        spec = target._build_service_pod_spec("raw_service", "demo:latest");
        # Empty values mean no requests/limits emitted -> back to BestEffort
        assert "resources" not in spec["containers"][0];
    } finally {
        restore();
    }
}


test "P0.20: readiness probe uses KubernetesConfig values" {
    # Real apps with slow first boot (jac compile + heavy imports) need
    # to bump the probe windows. jac.toml's [plugins.scale.kubernetes].
    # readiness_initial_delay was previously dropped on the floor.
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(
            app_name="demo",
            container_port=8000,
            readiness_initial_delay=300,
            readiness_period=20
        )
    );
    spec = target._build_service_pod_spec("orders", "demo:latest");
    probe = spec["containers"][0]["readinessProbe"];
    assert probe["initialDelaySeconds"] == 300 , (
        f"expected 300s from k8s_config, got {probe['initialDelaySeconds']}"
    );
    assert probe["periodSeconds"] == 20 , (
        f"expected 20s from k8s_config, got {probe['periodSeconds']}"
    );
    # Path/port unchanged
    assert probe["httpGet"]["path"] == "/healthz/ready";
    assert probe["httpGet"]["port"] == 8000;
}


test "P0.20: liveness probe uses KubernetesConfig values" {
    # Same story as readiness, plus failureThreshold for apps that
    # legitimately stall (LLM streaming, long-running compiles).
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(
            app_name="demo",
            container_port=8000,
            liveness_initial_delay=600,
            liveness_period=30,
            liveness_failure_threshold=10
        )
    );
    spec = target._build_service_pod_spec("orders", "demo:latest");
    probe = spec["containers"][0]["livenessProbe"];
    assert probe["initialDelaySeconds"] == 600 , (
        f"expected 600s from k8s_config, got {probe['initialDelaySeconds']}"
    );
    assert probe["periodSeconds"] == 30;
    assert probe["failureThreshold"] == 10;
    assert probe["httpGet"]["path"] == "/healthz/live";
}


test "P0.20: gateway pod-spec also reads probes from KubernetesConfig" {
    # The gateway gets the same probe wires as services (it's a pod
    # too). Without honoring k8s_config, gateway boots would hit the
    # same too-aggressive default probes.
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(
            app_name="demo",
            readiness_initial_delay=120,
            liveness_initial_delay=240
        )
    );
    spec = target._build_gateway_pod_spec("demo:latest");
    container = spec["containers"][0];
    assert container["readinessProbe"]["initialDelaySeconds"] == 120;
    assert container["livenessProbe"]["initialDelaySeconds"] == 240;
}


test "image_tag override replaces tag in repo/name:tag" {
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_services_config({"orders": {"image_tag": "v2.0-canary"}});
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
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_services_config({"orders": {"image_tag": "canary"}});
    try {
        # No tag in input, just registry+port+name.
        spec1 = target._build_service_pod_spec("orders", "myregistry.io:5000/demo");
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
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_services_config(
        {"llm_app": {"hpa": {"min": 3, "max": 20, "cpu_target": 60}}}
    );
    try {
        hpa = target._build_hpa_manifest("llm_app");
        assert hpa is not None;
        assert hpa["spec"]["minReplicas"] == 3;
        assert hpa["spec"]["maxReplicas"] == 20;
        assert hpa["spec"]["metrics"][0]["resource"]["target"][
            "averageUtilization"
        ] == 60;
    } finally {
        restore();
    }
}


test "HPA returns None when hpa.enabled = false" {
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_services_config(
        {"leader_only": {"hpa": {"enabled": False}}}
    );
    try {
        hpa = target._build_hpa_manifest("leader_only");
        assert hpa is None;
    } finally {
        restore();
    }
}


test "PDB max_unavailable reflects per-service override" {
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_services_config(
        {"orders": {"pdb": {"max_unavailable": 3}}}
    );
    try {
        pdb = target._build_pdb_manifest("orders");
        assert pdb is not None;
        assert pdb["spec"]["maxUnavailable"] == 3;
    } finally {
        restore();
    }
}


test "PDB returns None when pdb.enabled = false" {
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_services_config({"orders": {"pdb": {"enabled": False}}});
    try {
        pdb = target._build_pdb_manifest("orders");
        assert pdb is None;
    } finally {
        restore();
    }
}


test "generate_manifests skips disabled HPAs and PDBs" {
    import jac_scale.config_loader as cfg_mod;
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));

    original = getattr(cfg_mod, "get_scale_config");
    setattr(
        cfg_mod,
        "get_scale_config",
        lambda :
            _StubMsCfg(
                data={
                    "routes": {"orders": "/api/orders", "leader": "/api/leader"},
                    "services": {
                        "leader": {"hpa": {"enabled": False}, "pdb": {"enabled": False}}
                    }
                }
            )
    );

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
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_services_config(
        {
            GATEWAY_NAME: {
                "replicas": 3,
                "cpu_request": "200m",
                "env": {"GATEWAY_DEBUG": "1"}
            }
        }
    );
    try {
        # Deployment replicas
        dep = target._build_deployment_manifest(
            GATEWAY_NAME, target._build_gateway_pod_spec("demo:latest")
        );
        assert dep["spec"]["replicas"] == 3;

        # Pod-spec resources + env
        spec = target._build_gateway_pod_spec("demo:latest");
        container = spec["containers"][0];
        assert container["resources"]["requests"]["cpu"] == "200m";
        gateway_debug = [
            e
            for e in container["env"]
            if e["name"] == "GATEWAY_DEBUG"
        ];
        assert len(gateway_debug) == 1;
    } finally {
        restore();
    }
}


test "_service_config returns {} on read failure (graceful)" {
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    import jac_scale.config_loader as cfg_mod;

    obj _ExplodingCfg {
        def get_microservices_config -> dict[str, Any] {
            raise RuntimeError("simulated config failure");
        }
    }
    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda : _ExplodingCfg());

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
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
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
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    spec = target._build_gateway_pod_spec("demo:latest");
    container = spec["containers"][0];

    # Same dispatch script - the JAC_SV_NAME=__gateway__ env (set by
    # _build_env) flips the if/else inside the script at runtime.
    assert container["command"] == ["sh", "-c"];
    assert "jac scale gateway" in container["args"][0];
    # Gateway env still sets JAC_SV_NAME to the sentinel; runtime
    # script reads it and takes the gateway branch.
    sv_name_entries = [
        e
        for e in container["env"]
        if e["name"] == "JAC_SV_NAME"
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
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    spec = target._build_service_pod_spec("orders_app", "demo:latest");
    container_name: str = spec["containers"][0]["name"];
    assert container_name == "orders-app" , (
        f"container.name must be DNS-1123 (no underscores), got {container_name!r}"
    );
    # JAC_SV_NAME env preserves the raw name (entrypoint dispatch needs
    # the original to find <name>.jac).
    env_jac_name = next(
        e
        for e in spec["containers"][0]["env"]
        if e["name"] == "JAC_SV_NAME"
    );
    assert env_jac_name["value"] == "orders_app";
}


test "_pod_entrypoint command/args are stable (regression guard)" {
    # If we ever change the entrypoint shape, the Dockerfile template
    # documentation might drift. Pin the structure so that's caught
    # by the test suite.
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    entry = target._pod_entrypoint();
    assert entry["command"] == ["sh", "-c"];
    assert isinstance(entry["args"], list);
    assert len(entry["args"]) == 1;
}


# =============================================================================
# K10 - optional Ingress manifest pointing at the gateway
# =============================================================================
test "_build_ingress_manifest returns None when not enabled" {
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    # Default: disabled.
    assert target._build_ingress_manifest({}) is None;
    # Explicit disable.
    assert target._build_ingress_manifest({"enabled": False}) is None;
}


test "_build_ingress_manifest emits Ingress with sensible defaults" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod", container_port=8000)
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
    ing = target._build_ingress_manifest(
        {"enabled": True, "host": "shop.example.com", "ingress_class_name": "nginx"}
    );
    assert ing is not None;
    assert ing["spec"]["rules"][0]["host"] == "shop.example.com";
    assert ing["spec"]["ingressClassName"] == "nginx";
}


test "_build_ingress_manifest carries controller-specific annotations" {
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    ing = target._build_ingress_manifest(
        {
            "enabled": True,
            "annotations": {
                "nginx.ingress.kubernetes.io/proxy-body-size": "10m",
                "alb.ingress.kubernetes.io/scheme": "internet-facing"
            }
        }
    );
    assert ing is not None;
    annotations = ing["metadata"]["annotations"];
    assert annotations["nginx.ingress.kubernetes.io/proxy-body-size"] == "10m";
    assert annotations["alb.ingress.kubernetes.io/scheme"] == "internet-facing";
}


test "generate_manifests includes ingress when enabled" {
    import jac_scale.config_loader as cfg_mod;
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));

    original = getattr(cfg_mod, "get_scale_config");
    setattr(
        cfg_mod,
        "get_scale_config",
        lambda :
            _StubMsCfg(
                data={
                    "routes": {"orders": "/api/orders"},
                    "ingress": {
                        "enabled": True,
                        "host": "demo.example.com",
                        "ingress_class_name": "nginx"
                    }
                }
            )
    );

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
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));

    original = getattr(cfg_mod, "get_scale_config");
    setattr(
        cfg_mod,
        "get_scale_config",
        lambda : _StubMsCfg(data={"routes": {"orders": "/api/orders"}})
    );

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

    ingress = target._build_ingress_manifest(
        {"enabled": True, "host": "demo.example.com"}
    );
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
    core_v1.list_namespaced_service.return_value = unittest.mock.MagicMock(items=[]);

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


# =============================================================================
# P1.3: helpful error messages on common new-user K8s failures
# =============================================================================
test "P0.5: _handle_image_registry override uses auto-build when env var is set" {
    # When _JAC_SCALE_AUTO_BUILD=1 is set (production path), the override
    # should hand off to auto_build_and_distribute and return its image
    # tag. When the env var is unset (test default), it should fall
    # through to the parent's behavior.
    import jac_scale.config_loader as cfg_mod;
    import jac_scale.microservices.k8s_target as kt_mod;
    import unittest.mock as mock;
    import os;

    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    original_cfg = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda : _StubMsCfg(data={"routes": {}}));
    prev_env = os.environ.get("_JAC_SCALE_AUTO_BUILD");
    os.environ["_JAC_SCALE_AUTO_BUILD"] = "1";

    # Mock the auto-build pipeline so we don't shell out
    auto_build_calls: dict = {};
    def fake_auto_build(app_name: str, app_config: Any) -> str {
        auto_build_calls["app_name"] = app_name;
        return "myapp:auto-built-tag";
    }

    try {
        with mock.patch.object(
            target, "_auto_build_image", side_effect=fake_auto_build
        ) {
            ac = AppConfig(code_folder=".", app_name="demo", build=False);
            image = target._handle_image_registry("demo", ac);
        }
        assert image == "myapp:auto-built-tag";
        assert auto_build_calls["app_name"] == "demo";
    } finally {
        if prev_env is None {
            del os.environ["_JAC_SCALE_AUTO_BUILD"];
        } else {
            os.environ["_JAC_SCALE_AUTO_BUILD"] = prev_env;
        }
        setattr(cfg_mod, "get_scale_config", original_cfg);
    }
}


test "P0.5: _handle_image_registry honors pre-set docker_image_name (no rebuild)" {
    # If the user explicitly set [plugins.scale.kubernetes].docker_image_name
    # to something non-default, trust they pre-built it - don't waste time
    # auto-building. Only the default `<app_name>:latest` triggers auto-
    # build (since that's what KubernetesConfig.from_dict synthesizes
    # when the user didn't set anything).
    import jac_scale.config_loader as cfg_mod;
    import os;

    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(
            app_name="demo", docker_image_name="myregistry.io/myapp:v1.2.3"
        )
    );
    original_cfg = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda : _StubMsCfg(data={"routes": {}}));
    prev_env = os.environ.get("_JAC_SCALE_AUTO_BUILD");
    os.environ["_JAC_SCALE_AUTO_BUILD"] = "1";

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        image = target._handle_image_registry("demo", ac);
        # Should return the user's pre-set image, no auto-build invocation
        assert image == "myregistry.io/myapp:v1.2.3";
    } finally {
        if prev_env is None {
            del os.environ["_JAC_SCALE_AUTO_BUILD"];
        } else {
            os.environ["_JAC_SCALE_AUTO_BUILD"] = prev_env;
        }
        setattr(cfg_mod, "get_scale_config", original_cfg);
    }
}


test "P0.6: python_image fallback raises actionable error when guard env is set" {
    # Regression: KubernetesTarget._handle_image_registry returns
    # k8s_config.python_image (typically "python:3.12-slim") when build
    # is False or the registry isn't configured. For microservice mode
    # that fallback is always wrong - pod entrypoint invokes
    # `jac scale gateway` / `jac start <svc>.jac`, neither of which
    # exists in a vanilla python image. The guard is opt-in via env var
    # `_JAC_SCALE_GUARD_FALLBACK_IMAGE=1` so existing build=False tests
    # don't trip it; the production path (`_scale_pre_hook` in plugin.jac)
    # sets the env var before invoking deploy.
    import jac_scale.config_loader as cfg_mod;
    import os;
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", python_image="python:3.12-slim")
    );
    original = getattr(cfg_mod, "get_scale_config");
    setattr(
        cfg_mod,
        "get_scale_config",
        lambda : _StubMsCfg(data={"routes": {"orders_app": "/api/orders"}})
    );
    prev_env = os.environ.get("_JAC_SCALE_GUARD_FALLBACK_IMAGE");
    os.environ["_JAC_SCALE_GUARD_FALLBACK_IMAGE"] = "1";

    try {
        # build=False -> _handle_image_registry returns python_image fallback
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        raised = False;
        msg = "";
        try {
            target.generate_service_pod_specs(ac);
        } except RuntimeError as e {
            raised = True;
            msg = str(e);
        }
        assert raised , (
            "fallback to python:3.12-slim must raise when guard env is set"
        );
        # Error must be actionable: name the symptom + the e2e script + docs.
        assert "CrashLoopBackOff" in msg or "jac: command not found" in msg;
        assert "k8s_microservice_real_e2e.sh" in msg;
        assert "troubleshooting.md" in msg;
    } finally {
        if prev_env is None {
            del os.environ["_JAC_SCALE_GUARD_FALLBACK_IMAGE"];
        } else {
            os.environ["_JAC_SCALE_GUARD_FALLBACK_IMAGE"] = prev_env;
        }
        setattr(cfg_mod, "get_scale_config", original);
    }
}


test "P0.6: fallback image does NOT raise when guard env is unset (back-compat)" {
    # Existing tests use build=False to assert manifest shape without
    # actually building anything; they rely on the python_image fallback
    # being silently accepted. The guard must be opt-in to keep that path
    # working for tests + any caller that intentionally pre-builds the
    # image elsewhere.
    import jac_scale.config_loader as cfg_mod;
    import os;
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", python_image="python:3.12-slim")
    );
    original = getattr(cfg_mod, "get_scale_config");
    setattr(
        cfg_mod,
        "get_scale_config",
        lambda : _StubMsCfg(data={"routes": {"orders_app": "/api/orders"}})
    );
    # Make sure the env var is unset (it's the default).
    prev_env = os.environ.pop("_JAC_SCALE_GUARD_FALLBACK_IMAGE", None);

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        # Should NOT raise - the fallback is allowed when guard is off.
        specs = target.generate_service_pod_specs(ac);
        assert GATEWAY_NAME in specs;
        assert "orders_app" in specs;
    } finally {
        if prev_env is not None {
            os.environ["_JAC_SCALE_GUARD_FALLBACK_IMAGE"] = prev_env;
        }
        setattr(cfg_mod, "get_scale_config", original);
    }
}


test "P1.3: empty routes produces actionable error, not silent gateway-only deploy" {
    # Without this guard, the user gets a deploy with just a gateway pod
    # routing to nothing. The error message must point at the exact
    # jac.toml section so they can fix it without paging through docs.
    import jac_scale.config_loader as cfg_mod;
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda : _StubMsCfg(data={"routes": {}}));

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        raised = False;
        msg = "";
        try {
            target.generate_service_pod_specs(ac);
        } except ValueError as e {
            raised = True;
            msg = str(e);
        }
        assert raised , "empty routes must raise, not silently produce a gateway-only spec";
        # Error must be actionable: name the config key + show an example.
        assert "[plugins.scale.microservices.routes]" in msg;
        assert "my_service" in msg or "/api/" in msg;
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
    }
}


# =============================================================================
# P4.1: K8s Secrets injection for user [plugins.scale.secrets]
# =============================================================================

test "P4.1: _build_user_secret_manifest produces Opaque Secret with stringData" {
    # Mirrors what the parent KubernetesTarget already does for monolith
    # deploys. The K-track subclass had the gap - it set self.secrets
    # but never created a K8s Secret nor wired envFrom into pod specs,
    # so jacBuilder's 17 secrets sat in memory and never reached pods.
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="myapp", namespace="prod")
    );
    target.secrets = {
        "OPENAI_API_KEY": "sk-real-key",
        "HOST": "https://api.example.com",
        "GOOGLE_CLIENT_ID": "google-id-123"
    };

    secret = target._build_user_secret_manifest();
    assert secret is not None;
    assert secret["kind"] == "Secret";
    assert secret["apiVersion"] == "v1";
    assert secret["type"] == "Opaque";
    assert secret["metadata"]["name"] == "myapp-secrets";
    assert secret["metadata"]["namespace"] == "prod";
    # stringData (vs data) so values aren't base64-encoded client-side -
    # K8s server encodes them. Same shape as parent's create_k8s_secret.
    assert secret["stringData"]["OPENAI_API_KEY"] == "sk-real-key";
    assert secret["stringData"]["HOST"] == "https://api.example.com";
    assert secret["stringData"]["GOOGLE_CLIENT_ID"] == "google-id-123";
    # Standard managed-by label so destroy / inspection commands can
    # filter to jac-scale-owned objects.
    assert secret["metadata"]["labels"]["managed"] == "jac-scale";
}


test "P4.1: _build_user_secret_manifest returns None when self.secrets empty" {
    # Apps with no [plugins.scale.secrets] block must NOT get an empty
    # Secret object created (would clutter the namespace + confuse
    # operators looking at `kubectl get secrets`).
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="bare"));
    target.secrets = {};
    assert target._build_user_secret_manifest() is None;

    # Also handles the never-set case (some test paths construct the
    # target without going through plugin.jac).
    target2 = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="bare2"));
    if hasattr(target2, "secrets") and target2.secrets {
        target2.secrets = {};
    }
    assert target2._build_user_secret_manifest() is None;
}


test "P4.1: pod-spec injects envFrom secretRef when user secrets present" {
    # All keys of <app>-secrets become env vars in the container - one
    # envFrom entry beats N per-key env entries (smaller spec, simpler
    # to update when secret values change without redeploying pods).
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="myapp", namespace="default")
    );
    target.secrets = {"OPENAI_API_KEY": "sk-test", "HOST": "x"};

    spec = target._build_service_pod_spec("orders", "demo:latest");
    container = spec["containers"][0];
    env_from = container.get("envFrom", []);
    assert len(env_from) == 1;
    assert env_from[0]["secretRef"]["name"] == "myapp-secrets";

    # JAC_SV_NAME (the sentinel) still appears in the explicit env list -
    # envFrom doesn't replace it, just adds alongside.
    env = container["env"];
    assert any(e["name"] == "JAC_SV_NAME" and e["value"] == "orders" for e in env);
}


test "P4.1: pod-spec OMITS envFrom when self.secrets empty" {
    # Back-compat: pod specs for apps without secrets stay byte-identical
    # to the pre-P4.1 shape - no envFrom field at all.
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="myapp"));
    target.secrets = {};

    spec = target._build_service_pod_spec("orders", "demo:latest");
    container = spec["containers"][0];
    assert "envFrom" not in container;
}


test "P4.1: gateway pod-spec also gets envFrom (SSO/JWT/HOST need it)" {
    # The gateway's middleware reads HOST, SSO client_ids, JWT secret,
    # etc. - all of which live in [plugins.scale.secrets]. Same Secret
    # as services; no need for a gateway-only one.
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="myapp"));
    target.secrets = {"HOST": "https://example.com", "GOOGLE_CLIENT_ID": "x"};

    spec = target._build_gateway_pod_spec("demo:latest");
    container = spec["containers"][0];
    env_from = container.get("envFrom", []);
    assert len(env_from) == 1;
    assert env_from[0]["secretRef"]["name"] == "myapp-secrets";
}


test "P4.1: generate_manifests bundles user_secret alongside deployments" {
    # apply_manifests reads bundle["user_secret"] and applies the Secret
    # BEFORE Deployments. Without the bundle entry, the apply path skips
    # the Secret and pods crash on "secret not found".
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="myapp"));
    target.secrets = {"OPENAI_API_KEY": "sk"};
    (_cfg, restore) = _with_services_config(
        {}, routes={"orders": "/api/orders"}
    );
    try {
        ac = AppConfig(code_folder=".", app_name="myapp", build=False);
        bundle = target.generate_manifests(ac);
        assert "user_secret" in bundle;
        assert bundle["user_secret"]["kind"] == "Secret";
        assert bundle["user_secret"]["metadata"]["name"] == "myapp-secrets";
    } finally {
        restore();
    }
}


test "P4.1: generate_manifests OMITS user_secret entry when self.secrets empty" {
    # Same back-compat check at the bundle level - apps without secrets
    # don't get a phantom bundle["user_secret"] = None entry.
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="bare"));
    target.secrets = {};
    (_cfg, restore) = _with_services_config(
        {}, routes={"orders": "/api/orders"}
    );
    try {
        ac = AppConfig(code_folder=".", app_name="bare", build=False);
        bundle = target.generate_manifests(ac);
        assert "user_secret" not in bundle;
    } finally {
        restore();
    }
}


# =============================================================================
# P0.25: cross-service shared volumes
# =============================================================================

test "P0.25: PVC-mode shared volume creates PVC manifest" {
    # Most common case: production cloud K8s, RWX-capable storage class
    # (EFS / Filestore). Apps that share filesystem state across pods
    # (jacBuilder's IDE workspace) need the PVC pre-created so the pod
    # specs can mount it.
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", namespace="prod")
    );
    (_cfg, restore) = _with_shared_volumes(
        [
            {
                "name": "ide-workspace",
                "mount_path": "/root/.jac-ide/projects",
                "services": ["builder_sv", "jac_coder_sv"],
                "size": "10Gi",
                "access_mode": "ReadWriteMany",
                "storage_class": "efs-sc"
            }
        ]
    );
    try {
        pvcs = target._build_shared_pvc_manifests();
        assert "ide-workspace" in pvcs , (
            f"expected PVC keyed by 'ide-workspace', got {list(pvcs.keys())}"
        );
        pvc = pvcs["ide-workspace"];
        assert pvc["kind"] == "PersistentVolumeClaim";
        assert pvc["metadata"]["name"] == "ide-workspace";
        assert pvc["metadata"]["namespace"] == "prod";
        assert pvc["spec"]["accessModes"] == ["ReadWriteMany"];
        assert pvc["spec"]["resources"]["requests"]["storage"] == "10Gi";
        assert pvc["spec"]["storageClassName"] == "efs-sc";
        # Labels for managed-by tracking + destroy filtering
        assert pvc["metadata"]["labels"]["managed"] == "jac-scale";
    } finally {
        restore();
    }
}


test "P0.25: hostPath-mode shared volume skips PVC creation" {
    # k3d / kind / minikube single-node case. hostPath uses the same
    # node directory on every pod - no PVC needed.
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_shared_volumes(
        [
            {
                "name": "ide-workspace",
                "mount_path": "/root/.jac-ide/projects",
                "services": ["builder_sv", "jac_coder_sv"],
                "host_path": "/var/lib/jacbuilder/projects"
            }
        ]
    );
    try {
        pvcs = target._build_shared_pvc_manifests();
        # No PVCs emitted - hostPath doesn't need one
        assert pvcs == {} , (
            f"hostPath shared_volume must NOT emit a PVC, got {pvcs}"
        );
    } finally {
        restore();
    }
}


test "P0.25: PVC defaults to ReadWriteOnce + 1Gi when not specified" {
    # The bare-minimum config still works - users who don't care about
    # the access_mode/size details get sane defaults that work on every
    # cluster OOTB (ReadWriteOnce is the only universally-supported mode).
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_shared_volumes(
        [
            {
                "name": "scratch",
                "mount_path": "/scratch",
                "services": ["worker_a"]
            }
        ]
    );
    try {
        pvcs = target._build_shared_pvc_manifests();
        pvc = pvcs["scratch"];
        assert pvc["spec"]["accessModes"] == ["ReadWriteOnce"];
        assert pvc["spec"]["resources"]["requests"]["storage"] == "1Gi";
        # storageClassName omitted = cluster default class wins
        assert "storageClassName" not in pvc["spec"];
    } finally {
        restore();
    }
}


test "P0.25: PVC name + volume name normalized to DNS-1123" {
    # Underscores / camelCase aren't valid DNS-1123 labels and would
    # be rejected by the K8s API server. k8s_safe_name converts them
    # to kebab-case before they hit any K8s resource name field.
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_shared_volumes(
        [
            {
                "name": "my_shared_volume",  # underscores -> hyphens
                "mount_path": "/data",
                "services": ["worker"],
                "size": "5Gi"
            }
        ]
    );
    try {
        pvcs = target._build_shared_pvc_manifests();
        # Sanitized
        assert "my-shared-volume" in pvcs;
        assert pvcs["my-shared-volume"]["metadata"]["name"] == "my-shared-volume";
    } finally {
        restore();
    }
}


test "P0.25: pod-spec injects volumeMount + PVC volume for matching service" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="demo", container_port=8000)
    );
    (_cfg, restore) = _with_shared_volumes(
        [
            {
                "name": "workspace",
                "mount_path": "/root/.jac-ide/projects",
                "services": ["builder_sv"],
                "size": "10Gi",
                "access_mode": "ReadWriteMany"
            }
        ]
    );
    try {
        spec = target._build_service_pod_spec("builder_sv", "demo:latest");
        # Volume in pod spec
        vols = spec.get("volumes", []);
        assert len(vols) == 1 , f"expected 1 volume, got {vols}";
        vol = vols[0];
        assert vol["name"] == "workspace";
        assert "persistentVolumeClaim" in vol;
        assert vol["persistentVolumeClaim"]["claimName"] == "workspace";

        # VolumeMount in container
        container = spec["containers"][0];
        mounts = container.get("volumeMounts", []);
        assert len(mounts) == 1;
        assert mounts[0]["name"] == "workspace";
        assert mounts[0]["mountPath"] == "/root/.jac-ide/projects";
    } finally {
        restore();
    }
}


test "P0.25: pod-spec uses hostPath volume when host_path set (dev clusters)" {
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_shared_volumes(
        [
            {
                "name": "workspace",
                "mount_path": "/root/.jac-ide/projects",
                "services": ["builder_sv"],
                "host_path": "/var/lib/jacbuilder/projects"
            }
        ]
    );
    try {
        spec = target._build_service_pod_spec("builder_sv", "demo:latest");
        vols = spec.get("volumes", []);
        assert len(vols) == 1;
        vol = vols[0];
        assert vol["name"] == "workspace";
        assert "hostPath" in vol , f"expected hostPath, got {vol}";
        assert vol["hostPath"]["path"] == "/var/lib/jacbuilder/projects";
        # DirectoryOrCreate so missing path doesn't fail pod boot - the
        # shared dir gets created on first mount.
        assert vol["hostPath"]["type"] == "DirectoryOrCreate";
    } finally {
        restore();
    }
}


test "P0.25: services NOT in services list get NO volumeMount" {
    # The whole point of `services` is to scope the mount. A service
    # that doesn't appear in any volume's services list must not get
    # an unrelated mount injected.
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_shared_volumes(
        [
            {
                "name": "workspace",
                "mount_path": "/root/.jac-ide/projects",
                "services": ["builder_sv", "jac_coder_sv"],
                "size": "10Gi"
            }
        ]
    );
    try {
        # Different service - should NOT get the volume
        spec = target._build_service_pod_spec("orders_sv", "demo:latest");
        assert "volumes" not in spec , (
            f"orders_sv shouldn't get builder_sv/jac_coder_sv's volume, "
            f"got {spec.get('volumes')}"
        );
        assert "volumeMounts" not in spec["containers"][0];
    } finally {
        restore();
    }
}


test "P0.25: gateway can opt into shared volumes via __gateway__ in services list" {
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_shared_volumes(
        [
            {
                "name": "static-content",
                "mount_path": "/srv/static",
                "services": ["__gateway__"],
                "size": "1Gi"
            }
        ]
    );
    try {
        spec = target._build_gateway_pod_spec("demo:latest");
        # Gateway gets the mount because __gateway__ is in services
        assert spec["volumes"][0]["name"] == "static-content";
        assert spec["containers"][0]["volumeMounts"][0]["mountPath"] == "/srv/static";
    } finally {
        restore();
    }
}


test "P0.25: multiple shared volumes per service compose correctly" {
    # Multi-PVC apps: e.g. one PVC for project workspace, another for
    # cached build artifacts. Both should appear on the same pod.
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_shared_volumes(
        [
            {
                "name": "workspace",
                "mount_path": "/data/workspace",
                "services": ["builder_sv"],
                "size": "10Gi"
            },
            {
                "name": "cache",
                "mount_path": "/data/cache",
                "services": ["builder_sv"],
                "size": "5Gi"
            }
        ]
    );
    try {
        spec = target._build_service_pod_spec("builder_sv", "demo:latest");
        vols = spec["volumes"];
        mounts = spec["containers"][0]["volumeMounts"];
        assert len(vols) == 2;
        assert len(mounts) == 2;
        names = sorted([v["name"] for v in vols]);
        assert names == ["cache", "workspace"];
    } finally {
        restore();
    }
}


test "P0.25: subPath honored when set on a shared_volume entry" {
    # Storage-class-backed PVCs are usually shared across many use cases
    # via subPath. Avoids one PVC per (volume, service) cross-product.
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_shared_volumes(
        [
            {
                "name": "shared-data",
                "mount_path": "/app/builder",
                "services": ["builder_sv"],
                "sub_path": "builder",
                "size": "20Gi"
            }
        ]
    );
    try {
        spec = target._build_service_pod_spec("builder_sv", "demo:latest");
        mount = spec["containers"][0]["volumeMounts"][0];
        assert mount["subPath"] == "builder";
        assert mount["mountPath"] == "/app/builder";
    } finally {
        restore();
    }
}


test "P0.25: empty / missing shared_volumes config = no volumes injected" {
    # Back-compat: existing apps with no shared_volumes block get
    # exactly the same pod spec they got before P0.25.
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_shared_volumes([]);
    try {
        spec = target._build_service_pod_spec("orders", "demo:latest");
        assert "volumes" not in spec;
        assert "volumeMounts" not in spec["containers"][0];
        # PVCs bundle entry should be absent too
        assert target._build_shared_pvc_manifests() == {};
    } finally {
        restore();
    }
}


test "P0.25: malformed shared_volumes entries are skipped, not crashy" {
    # User forgot mount_path; user wrote `services` as a string instead
    # of a list. We tolerate both rather than crashing the whole deploy
    # (which would block their working services from being applied).
    target = KubernetesMicroserviceTarget(config=KubernetesConfig(app_name="demo"));
    (_cfg, restore) = _with_shared_volumes(
        [
            {"name": "no-mount-path", "services": ["worker"]},  # missing mount_path
            {"mount_path": "/data", "services": ["worker"]},  # missing name
            {"name": "bad-svcs", "mount_path": "/x", "services": "worker"},  # str not list
            {
                "name": "good",
                "mount_path": "/data",
                "services": ["worker"],
                "size": "1Gi"
            }
        ]
    );
    try {
        # Only the good one becomes a PVC + mount
        pvcs = target._build_shared_pvc_manifests();
        assert list(pvcs.keys()) == ["good"];

        spec = target._build_service_pod_spec("worker", "demo:latest");
        assert spec["volumes"][0]["name"] == "good";
    } finally {
        restore();
    }
}


# =============================================================================
# P0.30: service_account_name config knob — let apps point microservice
# Deployments at a pre-bound ServiceAccount (sandbox-spawning apps need
# cluster API access; the namespace `default` SA has none).
# =============================================================================

test "P0.30: empty service_account_name omits serviceAccountName from pod spec" {
    # Back-compat: pre-P0.30 K-track pods had no serviceAccountName field
    # (defaulted to namespace `default` SA). Apps that don't set the new
    # config knob get exactly the same pod spec shape.
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="myapp")
    );

    spec = target._build_service_pod_spec("orders", "demo:latest");
    assert "serviceAccountName" not in spec;

    gw_spec = target._build_gateway_pod_spec("demo:latest");
    assert "serviceAccountName" not in gw_spec;
}


test "P0.30: configured service_account_name propagates to service pod spec" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(
            app_name="myapp", service_account_name="myapp-sa"
        )
    );

    spec = target._build_service_pod_spec("orders", "demo:latest");
    assert spec["serviceAccountName"] == "myapp-sa";
}


test "P0.30: configured service_account_name propagates to gateway pod spec" {
    # Gateway runs subdomain-preview proxy middleware that may resolve
    # sandbox pods, so it needs the same RBAC as the services.
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(
            app_name="myapp", service_account_name="myapp-sa"
        )
    );

    spec = target._build_gateway_pod_spec("demo:latest");
    assert spec["serviceAccountName"] == "myapp-sa";
}


test "P0.30: whitespace-only service_account_name treated as unset" {
    # Defensive: TOML parsers and shell-substitution can leave stray
    # whitespace. An accidental "  " shouldn't pin the pod to a literal
    # whitespace SA name (which would fail at admission with a
    # confusing "ServiceAccount '  ' not found" error).
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="myapp", service_account_name="   ")
    );

    spec = target._build_service_pod_spec("orders", "demo:latest");
    assert "serviceAccountName" not in spec;
}


test "P0.30: KubernetesConfig.from_dict round-trips service_account_name" {
    # Config-loader path: jac.toml -> dict -> from_dict -> back to dict.
    # Every other field has this round-trip; service_account_name should
    # too so it shows up in the dict the microservice target receives.
    cfg_dict = {
        "app_name": "myapp",
        "namespace": "prod",
        "service_account_name": "myapp-sa"
    };
    cfg = KubernetesConfig.from_dict(KubernetesConfig, cfg_dict);
    assert cfg.service_account_name == "myapp-sa";
    assert cfg.to_dict()["service_account_name"] == "myapp-sa";
}


test "P0.30: KubernetesConfig.from_dict default empty service_account_name" {
    # Apps that don't declare the field get '' (back-compat with all
    # existing jac.toml files in the wild).
    cfg = KubernetesConfig.from_dict(
        KubernetesConfig, {"app_name": "bare"}
    );
    assert cfg.service_account_name == "";
}
