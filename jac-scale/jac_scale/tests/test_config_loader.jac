"""Tests for jac_scale.config_loader (impl-level, not stub-level).

These exercise the real `JacScaleConfig.get_*` methods against a
manually-injected `_config` dict to assert the shape they return.
The unit tests elsewhere (test_gateway.jac, test_k8s_microservice_target.jac)
stub out `get_microservices_config` entirely - that catches consumers
but not bugs in the loader itself.
"""

import from typing { Any }
import from jac_scale.config_loader { JacScaleConfig }


test "get_microservices_config returns ingress block" {
    # Regression: [...microservices.ingress] was added but the loader's
    # explicit return dict didn't include it, so even with
    # `ingress.enabled = true` in jac.toml the K8s target's
    # _build_ingress_manifest received {} and silently returned None.
    # The Ingress object was never applied in CI's real-app e2e.
    cfg = JacScaleConfig();
    cfg._config = {
        "microservices": {
            "enabled": True,
            "ingress": {
                "enabled": True,
                "host": "jac-shop.local",
                "ingress_class_name": "nginx",
                "annotations": {
                    "nginx.ingress.kubernetes.io/proxy-body-size": "10m"
                }
            }
        }
    };
    out = cfg.get_microservices_config();
    assert "ingress" in out, (
        "get_microservices_config() must include 'ingress' so K8s "
        "target's _build_ingress_manifest sees user config"
    );
    ing = out["ingress"];
    assert ing["enabled"] is True;
    assert ing["host"] == "jac-shop.local";
    assert ing["ingress_class_name"] == "nginx";
    assert ing["annotations"]["nginx.ingress.kubernetes.io/proxy-body-size"] == "10m";
}


test "get_microservices_config ingress defaults to {} when section absent" {
    # Default-off invariant: omitting the section entirely yields {},
    # not a partially-populated dict. _build_ingress_manifest treats
    # {} as opt-out (returns None), so deployments that don't want
    # an Ingress don't accidentally grow one.
    cfg = JacScaleConfig();
    cfg._config = {
        "microservices": {
            "enabled": True
        }
    };
    out = cfg.get_microservices_config();
    assert out["ingress"] == {};
}


test "get_microservices_config preserves all other sections (no regression)" {
    # Guards against a future "trim the dict" refactor accidentally
    # dropping a section the way ingress was dropped. If this fails,
    # check the loader's return-dict for the named section.
    cfg = JacScaleConfig();
    cfg._config = {
        "microservices": {
            "enabled": True,
            "gateway_port": 9000,
            "drain_timeout_seconds": 15,
            "http_forward_timeout": 60,
            "routes": {"orders_app": "/api/orders"},
            "services": {"orders_app": {"replicas": 2}},
            "ingress": {"enabled": False}
        }
    };
    out = cfg.get_microservices_config();
    expected_keys: set[str] = {
        "enabled", "gateway_port", "gateway_host",
        "drain_timeout_seconds", "http_forward_timeout",
        "routes", "services", "rate_limit", "cors", "client", "ingress"
    };
    missing = expected_keys - set(out.keys());
    assert not missing, f"missing keys: {missing}";
}
