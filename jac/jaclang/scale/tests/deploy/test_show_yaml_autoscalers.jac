"""--show-yaml must print the autoscaler objects a deploy would apply. The
bundle carries autoscaler CONFIGS, not manifests; render_autoscaler_manifests
turns them into the same objects the apply path builds, from the same spec."""

import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.target { KubernetesTarget }
import from jaclang.scale.deploy.target.kubernetes.manifest_builder { ScalingMode }


test "hpa engine renders the HPA manifest the apply path would build" {
    target = KubernetesTarget(config=KubernetesConfig(app_name="t", namespace="t-ns"));
    bundle = {
        "scaling": {
            "api": {
                "mode": ScalingMode.METRIC,
                "scale_target_name": "api-deployment",
                "autoscaler": {"min": 2, "max": 7, "cpu_target": 60}
            }
        }
    };
    manifests = target.render_autoscaler_manifests(bundle);
    assert len(manifests) == 1;
    m = manifests[0];
    assert m["kind"] == "HorizontalPodAutoscaler";
    assert m["metadata"]["namespace"] == "t-ns";
    assert m["spec"]["scaleTargetRef"]["name"] == "api-deployment";
    assert m["spec"]["minReplicas"] == 2;
    assert m["spec"]["maxReplicas"] == 7;
}


test "keda engine renders the ScaledObject body, not the name/body wrapper" {
    target = KubernetesTarget(
        config=KubernetesConfig(
            app_name="t", namespace="t-ns", autoscaler_engine="keda"
        )
    );
    bundle = {
        "scaling": {
            "api": {
                "mode": ScalingMode.METRIC,
                "scale_target_name": "api-deployment",
                "autoscaler": {"min": 1, "max": 4}
            }
        }
    };
    manifests = target.render_autoscaler_manifests(bundle);
    assert len(manifests) == 1;
    m = manifests[0];
    assert m["kind"] == "ScaledObject";
    assert m["spec"]["scaleTargetRef"]["name"] == "api-deployment";
    assert m["spec"]["minReplicaCount"] == 1;
    assert m["spec"]["maxReplicaCount"] == 4;
}


test "the scale target comes from the resolved plan, not re-derived from the service name" {
    target = KubernetesTarget(config=KubernetesConfig(app_name="t", namespace="t-ns"));
    bundle = {
        "scaling": {
            "api": {
                "mode": ScalingMode.METRIC,
                "scale_target_name": "not-the-k8s-safe-name-deployment",
                "autoscaler": {"min": 1, "max": 3}
            }
        }
    };
    manifests = target.render_autoscaler_manifests(bundle);
    assert manifests[0]["spec"]["scaleTargetRef"]["name"] == "not-the-k8s-safe-name-deployment";
}


test "a service scaled by http_activation renders no autoscaler manifest" {
    target = KubernetesTarget(config=KubernetesConfig(app_name="t", namespace="t-ns"));
    bundle = {
        "scaling": {"api": {"mode": ScalingMode.HTTP_ACTIVATION, "autoscaler": {}}}
    };
    assert target.render_autoscaler_manifests(bundle) == [];
}


test "a bundle with no scaling renders nothing" {
    target = KubernetesTarget(config=KubernetesConfig(app_name="t", namespace="t-ns"));
    assert target.render_autoscaler_manifests({"deployments": {}}) == [];
}


test "keda engine renders the TriggerAuthentication apply() would create for an authenticated trigger" {
    # --show-yaml only rendered the ScaledObject, so a config with an
    # auth-bearing trigger dry-ran clean and then apply() created a
    # TriggerAuthentication the preview never showed.
    target = KubernetesTarget(
        config=KubernetesConfig(
            app_name="t", namespace="t-ns", autoscaler_engine="keda"
        )
    );
    bundle = {
        "scaling": {
            "api": {
                "mode": ScalingMode.METRIC,
                "scale_target_name": "api-deployment",
                "autoscaler": {
                    "min": 1,
                    "max": 4,
                    "triggers": [
                        {
                            "type": "redis",
                            "name": "cache",
                            "metadata": {"address": "redis:6379"},
                            "auth": {
                                "secret_refs": {
                                    "password": {"name": "redis-secret", "key": "pw"}
                                }
                            }
                        }
                    ]
                }
            }
        }
    };
    manifests = target.render_autoscaler_manifests(bundle);
    assert len(manifests) == 2;
    assert manifests[0]["kind"] == "ScaledObject";
    auth_name = manifests[0]["spec"]["triggers"][0]["authenticationRef"]["name"];
    assert manifests[1]["kind"] == "TriggerAuthentication";
    assert manifests[1]["metadata"]["name"] == auth_name;
    assert manifests[1]["spec"]["secretTargetRef"] == [
        {"parameter": "password", "name": "redis-secret", "key": "pw"}
    ];
}
