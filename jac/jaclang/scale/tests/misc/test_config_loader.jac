import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.config.config_loader {
    JacScaleConfig,
    get_scale_config,
    reset_scale_config
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}


test "get_default_config kubernetes probe timings match KubernetesConfig defaults" {
    # get_default_config() is deep-merged over jac.toml, so its values are what
    # actually take effect when the user sets no probe keys. If these drift from
    # the KubernetesConfig struct defaults, the struct defaults become dead code
    # and users silently get different probe timings than documented (#6394).
    defaults = JacScaleConfig().get_default_config()["kubernetes"];
    struct_defaults = KubernetesConfig();
    for key in [
        "readiness_initial_delay",
        "readiness_period",
        "liveness_initial_delay",
        "liveness_period",
        "liveness_failure_threshold"
    ] {
        expected = getattr(struct_defaults, key);
        actual = defaults[key];
        assert actual == expected , f"{key}: get_default_config has {actual}, expected {expected}";
    }
}


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


test "get_microservices_config reads routes from JAC_SV_ROUTES when config empty" {
    cfg = JacScaleConfig();
    cfg._config = {"microservices": {"enabled": True}};
    os.environ["JAC_SV_ROUTES"] = "{\"orders_app\": \"/api/orders\", \"cart_app\": \"/api/cart\"}";
    try {
        out = cfg.get_microservices_config();
        assert out["routes"]
            == {
                "orders_app": "/api/orders",
                "cart_app": "/api/cart",
                "main": "/__main__"
            };
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
        assert out["routes"] == {"real_app": "/api/real", "main": "/__main__"};
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


test "every get_websocket_config key has a schema entry (#8000 1.2)" {
    # The websocket guide documented a backplane value that raised at boot and
    # none of the seven [scale.websocket] keys were schema-declared, so nothing
    # validated or surfaced them. Keep the runtime reader and the schema in
    # lockstep.
    import from jaclang.scale.config.plugin_config { JacScalePluginConfig }
    schema = JacScalePluginConfig.get_config_schema();
    ws_schema = schema["options"].get("websocket");
    assert ws_schema is not None , "[scale.websocket] missing from plugin_config schema";
    declared = set(ws_schema["nested"].keys());
    cfg = JacScaleConfig();
    cfg._config = {"websocket": {}};
    read_keys = set(cfg.get_websocket_config().keys());
    assert read_keys == declared , f"schema/read drift: schema-only={declared
        - read_keys}, read-only={read_keys - declared}";
}


test "config sections read by config_loader are schema-declared (#8000 1.2)" {
    import from jaclang.scale.config.plugin_config { JacScalePluginConfig }
    schema_sections = set(JacScalePluginConfig.get_config_schema()["options"].keys());
    cfg = JacScaleConfig();
    cfg._config = {};
    for section in [
        "websocket",
        "database",
        "kubernetes",
        "events",
        "monitoring",
        "server"
    ] {
        assert section in schema_sections , f"[scale.{section}] is read by config_loader but has no schema entry";
    }
}


test "get_kubernetes_config leaves the cached config dict unmutated" {
    # load() returns the cached dict by reference; deriving kubernetes keys
    # must not write them back, or later readers of the raw config see
    # derived values as if the user had configured them.
    cfg = JacScaleConfig();
    cfg._config = {
        "kubernetes": {"namespace": "demo"},
        "monitoring": {"namespace": "demo_metrics"}
    };
    cfg.get_kubernetes_config();
    leaked = cfg._config["kubernetes"];
    assert leaked == {"namespace": "demo"} , f"derived keys leaked into the cached config: {leaked}";
}


test "repeated get_kubernetes_config calls return equal results" {
    # Pre-copy, every call stacked derived keys onto the cached dict, so the
    # result depended on how many times it had been called before.
    cfg = JacScaleConfig();
    cfg._config = {
        "kubernetes": {"namespace": "demo"},
        "monitoring": {"namespace": "demo_metrics"}
    };
    first = cfg.get_kubernetes_config();
    second = cfg.get_kubernetes_config();
    assert first == second;
}


test "get_scale_config raises on a different project_dir instead of silently reusing" {
    reset_scale_config();
    dir_a = tempfile.mkdtemp(prefix="jac-cfg-a-");
    dir_b = tempfile.mkdtemp(prefix="jac-cfg-b-");
    try {
        first = get_scale_config(project_dir=Path(dir_a));
        assert get_scale_config() is first;
        assert get_scale_config(project_dir=Path(dir_a)) is first;
        raised = False;
        try {
            get_scale_config(project_dir=Path(dir_b));
        } except RuntimeError {
            raised = True;
        }
        assert raised , "a second project_dir was silently ignored and the first project's config returned";
    } finally {
        reset_scale_config();
        shutil.rmtree(dir_a, ignore_errors=True);
        shutil.rmtree(dir_b, ignore_errors=True);
    }
}
