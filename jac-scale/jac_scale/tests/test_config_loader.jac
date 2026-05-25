"""Tests for jac_scale.config_loader against the real loader (other
tests stub get_microservices_config; this catches bugs in the loader
itself - e.g. when the ingress block was dropped from the return dict)."""

import from jac_scale.config_loader { JacScaleConfig }
import from jac_scale.plugin_config { JacScalePluginConfig }


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
    expected_keys: set[str] = {"enabled","gateway_port","gateway_host","drain_timeout_seconds","http_forward_timeout","routes","services","rate_limit","cors","client","ingress"};
    missing = expected_keys - set(out.keys());
    assert not missing , f"missing keys: {missing}";
}


test "get_kubernetes_config parses autoscaler keys" {
    cfg = JacScaleConfig();
    cfg._config = {
        "kubernetes": {
            "autoscaler_engine": "keda",
            "idle_replicas": 0,
            "autoscaler_polling_interval": 15,
            "autoscaler_cooldown": 120,
            "autoscaler_initial_cooldown": 45,
            "extra_triggers": [
                {
                    "type": "prometheus",
                    "metadata": {"metricName": "http_rps", "threshold": "5"}
                }
            ]
        }
    };
    out = cfg.get_kubernetes_config();
    assert out["autoscaler_engine"] == "keda";
    assert out["idle_replicas"] == 0;
    assert out["autoscaler_polling_interval"] == 15;
    assert out["autoscaler_cooldown"] == 120;
    assert out["autoscaler_initial_cooldown"] == 45;
    assert out["extra_triggers"][0]["type"] == "prometheus";
}


test "get_kubernetes_config autoscaler defaults are stable when absent" {
    cfg = JacScaleConfig();
    cfg._config = {"kubernetes": {}};
    out = cfg.get_kubernetes_config();
    assert out.get("autoscaler_engine", "hpa") == "hpa";
    assert out.get("idle_replicas") is None;
    assert out.get("autoscaler_polling_interval", 30) == 30;
    assert out.get("autoscaler_cooldown", 300) == 300;
    assert out.get("autoscaler_initial_cooldown", 0) == 0;
    assert out.get("extra_triggers", []) == [];
}


test "get_microservices_config parses autoscaler engine and triggers" {
    cfg = JacScaleConfig();
    cfg._config = {
        "microservices": {
            "enabled": True,
            "autoscaler_engine": "keda",
            "services": {
                "llm_worker": {
                    "triggers": [
                        {
                            "type": "redis",
                            "metadata": {
                                "address": "redis:6379",
                                "listName": "jobs",
                                "listLength": "5"
                            }
                        }
                    ]
                }
            }
        }
    };
    out = cfg.get_microservices_config();
    assert out["autoscaler_engine"] == "keda";
    assert out["services"]["llm_worker"]["triggers"][0]["type"] == "redis";
}


test "plugin config schema includes kubernetes autoscaler keys" {
    schema = JacScalePluginConfig.get_config_schema();
    k8s = schema["options"]["kubernetes"]["nested"];
    assert "autoscaler_engine" in k8s;
    assert "idle_replicas" in k8s;
    assert "autoscaler_polling_interval" in k8s;
    assert "autoscaler_cooldown" in k8s;
    assert "autoscaler_initial_cooldown" in k8s;
    assert "extra_triggers" in k8s;
}


test "plugin config schema includes microservices autoscaler keys" {
    schema = JacScalePluginConfig.get_config_schema();
    ms = schema["options"]["microservices"]["nested"];
    assert "autoscaler_engine" in ms;
    # Service-level triggers are nested under services.* and documented in description.
    assert "services" in ms;
    assert "trigger" in ms["services"]["description"].lower();
}
