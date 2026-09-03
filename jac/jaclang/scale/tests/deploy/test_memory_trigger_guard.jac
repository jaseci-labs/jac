import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
    ManifestBuilder,
    GATEWAY_NAME
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
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

test "_get_autoscaler_config surfaces the per-service hpa.behavior fragment" {
    b = _builder(
        {
            "billing_ops": {
                "hpa": {
                    "behavior": {
                        "scaleDown": {
                            "stabilizationWindowSeconds": 600,
                            "policies": [
                                {"type": "Pods", "value": 2, "periodSeconds": 300}
                            ]
                        }
                    }
                }
            }
        }
    );
    cfg = b._get_autoscaler_config("billing_ops");
    assert cfg["behavior"]["scaleDown"]["stabilizationWindowSeconds"] == 600;
}

test "_get_autoscaler_config defaults behavior to an empty dict when unset" {
    b = _builder({"billing_ops": {}});
    cfg = b._get_autoscaler_config("billing_ops");
    assert cfg["behavior"] == {};
}

test "hpa.behavior on one service does not leak onto another" {
    b = _builder(
        {
            "billing_ops": {
                "hpa": {"behavior": {"scaleDown": {"selectPolicy": "Min"}}}
            },
            "orders_ops": {}
        }
    );
    assert b._get_autoscaler_config("billing_ops")["behavior"] == {
        "scaleDown": {"selectPolicy": "Min"}
    };
    assert b._get_autoscaler_config("orders_ops")["behavior"] == {};
}

test "hpa.enabled false still short-circuits before behavior is considered" {
    b = _builder(
        {
            "billing_ops": {
                "hpa": {
                    "enabled": False,
                    "behavior": {"scaleDown": {"selectPolicy": "Min"}}
                }
            }
        }
    );
    assert b._get_autoscaler_config("billing_ops") is None;
}


test "hpa.behavior works for the gateway via the __gateway__ service key" {
    b = _builder(
        {GATEWAY_NAME: {"hpa": {"behavior": {"scaleDown": {"selectPolicy": "Min"}}}}}
    );
    assert b._get_autoscaler_config(GATEWAY_NAME)["behavior"] == {
        "scaleDown": {"selectPolicy": "Min"}
    };
}

test "malformed hpa.behavior warns and falls back to the empty fragment" {
    import unittest.mock;

    logger = unittest.mock.MagicMock();
    b = ManifestBuilder(
        k8s_config=KubernetesConfig(app_name="t", namespace="t-ns"),
        microservices_config={
            "services": {"billing_ops": {"hpa": {"behavior": "gentle"}}}
        },
        dry_run=True,
        logger=logger
    );
    cfg = b._get_autoscaler_config("billing_ops");
    assert cfg["behavior"] == {};
    logger.warning.assert_called_once();
    assert "billing_ops" in str(logger.warning.call_args[0][0]);
}
