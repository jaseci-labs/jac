"""Tests for jac_scale.config_loader against the real loader (other
tests stub get_microservices_config; this catches bugs in the loader
itself - e.g. when the ingress block was dropped from the return dict)."""

import os;
import from jac_scale.config_loader { JacScaleConfig }


test "get_microservices_config returns ingress block" {
    cfg = JacScaleConfig();
    cfg._config = {
        "microservices": {
            "enabled": True,
            "ingress": {
                "enabled": True,
                "host": "jac-shop.local",
                "ingress_class_name": "nginx",
                "annotations": {"nginx.ingress.kubernetes.io/proxy-body-size": "10m"}
            }
        }
    };
    out = cfg.get_microservices_config();
    assert "ingress" in out;
    ing = out["ingress"];
    assert ing["enabled"] is True;
    assert ing["host"] == "jac-shop.local";
    assert ing["ingress_class_name"] == "nginx";
    assert ing["annotations"]["nginx.ingress.kubernetes.io/proxy-body-size"] == "10m";
}


test "get_microservices_config ingress defaults to {} when section absent" {
    cfg = JacScaleConfig();
    cfg._config = {"microservices": {"enabled": True}};
    out = cfg.get_microservices_config();
    assert out["ingress"] == {};
}


test "get_microservices_config preserves all sections (regression guard)" {
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
        "enabled",
        "gateway_port",
        "gateway_host",
        "drain_timeout_seconds",
        "http_forward_timeout",
        "routes",
        "services",
        "rate_limit",
        "cors",
        "client",
        "ingress",
        "logs"
    };
    missing = expected_keys - set(out.keys());
    assert not missing , f"missing keys: {missing}";
}


test "get_microservices_config logs block defaults to {} when absent" {
    cfg = JacScaleConfig();
    cfg._config = {"microservices": {"enabled": True}};
    out = cfg.get_microservices_config();
    assert out["logs"] == {};
}


test "get_microservices_config logs block round-trips enabled flag" {
    cfg = JacScaleConfig();
    cfg._config = {"microservices": {"enabled": True, "logs": {"enabled": True}}};
    out = cfg.get_microservices_config();
    assert out["logs"] == {"enabled": True};
}


# =============================================================================
# Tri-state `enabled` (zero-config auto-detect). Absent must be None, not
# False, so _scale_pre_hook can tell auto-detect from an explicit opt-out.
# =============================================================================
test "get_microservices_config enabled is None when unset (auto-detect)" {
    cfg = JacScaleConfig();
    cfg._config = {"microservices": {"gateway_port": 8000}};
    out = cfg.get_microservices_config();
    assert out["enabled"] is None;
}

test "get_microservices_config enabled is None when section absent" {
    cfg = JacScaleConfig();
    cfg._config = {};
    out = cfg.get_microservices_config();
    assert out["enabled"] is None;
}

test "get_microservices_config preserves explicit enabled=False (opt-out)" {
    cfg = JacScaleConfig();
    cfg._config = {"microservices": {"enabled": False}};
    out = cfg.get_microservices_config();
    assert out["enabled"] is False;
}

test "get_microservices_config preserves explicit enabled=True" {
    cfg = JacScaleConfig();
    cfg._config = {"microservices": {"enabled": True}};
    out = cfg.get_microservices_config();
    assert out["enabled"] is True;
}


# =============================================================================
# Route propagation: JAC_SV_ROUTES env fallback (zero-config --scale pods read
# routes from the env the manifest builder injected, since the in-cluster
# jac.toml has no [routes] table).
# =============================================================================
test "get_microservices_config reads routes from JAC_SV_ROUTES when config empty" {
    cfg = JacScaleConfig();
    cfg._config = {"microservices": {"enabled": True}};
    os.environ["JAC_SV_ROUTES"] = "{\"orders_app\": \"/api/orders\", \"cart_app\": \"/api/cart\"}";
    try {
        out = cfg.get_microservices_config();
        assert out["routes"] == {"orders_app": "/api/orders", "cart_app": "/api/cart"};
    } finally {
        del os.environ["JAC_SV_ROUTES"];
    }
}

test "get_microservices_config: explicit config routes win over JAC_SV_ROUTES" {
    cfg = JacScaleConfig();
    cfg._config = {"microservices": {"routes": {"real_app": "/api/real"}}};
    os.environ["JAC_SV_ROUTES"] = "{\"ghost_app\": \"/api/ghost\"}";
    try {
        out = cfg.get_microservices_config();
        assert out["routes"] == {"real_app": "/api/real"};
    } finally {
        del os.environ["JAC_SV_ROUTES"];
    }
}

test "get_microservices_config: malformed JAC_SV_ROUTES falls back to empty" {
    cfg = JacScaleConfig();
    cfg._config = {"microservices": {}};
    os.environ["JAC_SV_ROUTES"] = "not-json";
    try {
        out = cfg.get_microservices_config();
        assert out["routes"] == {};
    } finally {
        del os.environ["JAC_SV_ROUTES"];
    }
}
