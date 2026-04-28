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

    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda: _StubMsCfg(
        data={"routes": {"orders": "/api/orders", "cart": "/api/cart"}}
    ));

    try {
        ac = AppConfig(code_folder=".", app_name="demo", build=False);
        result = target.deploy(ac);

        assert result.success;
        assert "pod_specs" in result.details;
        specs: dict[str, Any] = result.details["pod_specs"];
        assert len(specs) == 3;  # 2 services + gateway
        assert "orders" in specs;
        assert "cart" in specs;
        assert GATEWAY_NAME in specs;
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
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

        # Bundle has all three keyed sections.
        assert set(bundle.keys()) == {"deployments", "services", "pod_specs"};

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


test "deploy returns K2 manifest bundle in details" {
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
        result = target.deploy(ac);

        assert result.success;
        # K2 bundle now in details (K1's pod_specs is preserved as one section).
        details: dict[str, Any] = result.details;
        assert "deployments" in details;
        assert "services" in details;
        assert "pod_specs" in details;
        assert (result.message or "").startswith("K2 manifests generated");
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
    }
}
