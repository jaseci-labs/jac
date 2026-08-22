import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
    ManifestBuilder,
    GATEWAY_NAME
}
import from jaclang.scale.deploy.target.kubernetes.target { KubernetesTarget }
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


def _triggers(cfg: dict, k8s_config: KubernetesConfig | None = None) -> list[str] {
    target = KubernetesTarget(
        config=k8s_config or KubernetesConfig(app_name="t", namespace="t-ns")
    );
    return [t.type for t in target._resolve_service_triggers("billing_ops", cfg)];
}


test "builder resolves has_memory_request from service, global, and defaults" {
    b = _builder({"billing_ops": {}});
    assert b._get_autoscaler_config("billing_ops")["has_memory_request"];
    assert b._get_autoscaler_config(GATEWAY_NAME)["has_memory_request"];

    b = _builder({"billing_ops": {"memory_request": ""}});
    assert not b._get_autoscaler_config("billing_ops")["has_memory_request"];

    b = _builder(
        {"billing_ops": {}, "orders_ops": {"memory_request": "512Mi"}},
        k8s_config=KubernetesConfig(app_name="t", namespace="t-ns", memory_request="")
    );
    assert not b._get_autoscaler_config("billing_ops")["has_memory_request"];
    assert b._get_autoscaler_config("orders_ops")["has_memory_request"];
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
    assert b._get_autoscaler_config("billing_ops")["behavior"]
        == {"scaleDown": {"selectPolicy": "Min"}};
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

test "memory triggers are seeded or skipped based on the resolved request" {
    assert _triggers({}) == ["cpu", "memory"];
    assert _triggers({"has_memory_request": False}) == ["cpu"];

    explicit = {
        "has_memory_request": False,
        "triggers": [
            {"type": "memory", "metadata": {"averageUtilization": "80"}},
            {"type": "prometheus", "metadata": {"threshold": "100"}}
        ]
    };
    assert _triggers(explicit) == ["prometheus"];

    gw_k8s = KubernetesConfig(
        app_name="t",
        namespace="t-ns",
        extra_triggers=[
            {"type": "memory", "metadata": {"averageUtilization": "80"}},
            {"type": "cpu", "metadata": {"averageUtilization": "50"}}
        ]
    );
    gw_target = KubernetesTarget(config=gw_k8s);
    gw_types = [
        t.type
        for t in gw_target._resolve_service_triggers(
            GATEWAY_NAME, {"has_memory_request": False}
        )
    ];
    assert gw_types == ["cpu"];
}

test "hpa.behavior works for the gateway via the __gateway__ service key" {
    b = _builder(
        {GATEWAY_NAME: {"hpa": {"behavior": {"scaleDown": {"selectPolicy": "Min"}}}}}
    );
    assert b._get_autoscaler_config(GATEWAY_NAME)["behavior"]
        == {"scaleDown": {"selectPolicy": "Min"}};
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
    assert "billing_ops" in logger.warning.call_args[0][0];
}


# The preflight reads the pod architecture from the cluster, and node_arch()
# silently falls back to the HOST arch when no kubeconfig is loaded. Deploy must
# therefore load the cluster config first, or a macOS host deploying to a linux
# x86_64 cluster checks the wrong release asset and can refuse a valid pin.
test "deploy loads the cluster config before it resolves the pod arch" {
    import unittest.mock;
    import tempfile;
    import from pathlib { Path }
    import from jaclang.scale.deploy.target.kubernetes.target { KubernetesTarget }
    import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
        KubernetesConfig
    }
    import from jaclang.scale.config.app_config { AppConfig }
    import jaclang.scale.injector.binary as binary_mod;

    d = tempfile.mkdtemp();
    (Path(d) / "jac.toml").write_text(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = "==0.34.99"\n'
    );
    order: list[str] = [];
    target = KubernetesTarget(config=KubernetesConfig(app_name="t", namespace="t-ns"));

    def _note_config {
        order.append("config");
    }

    def _note_arch -> str {
        order.append("arch");
        return "x86_64";
    }

    with unittest.mock.patch.object(target, "_load_cluster_config", _note_config), unittest.mock.patch.object(
        binary_mod, "node_arch", _note_arch
    ), unittest.mock.patch.object(
        binary_mod, "preflight_pod_runtime", return_value="0.0.0"
    ), unittest.mock.patch.object(
        KubernetesTarget, "generate_manifests", side_effect=RuntimeError("stop")
    ) {
        target.deploy(AppConfig(code_folder=d, file_name="main.jac", app_name="t"));
    }
    assert order[:2] == ["config", "arch"];
}
