"""--show-yaml must print the autoscaler objects a deploy would apply. The
bundle carries autoscaler CONFIGS, not manifests; render_autoscaler_manifests
turns them into the same objects the apply path builds, from the same spec."""

import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.target { KubernetesTarget }
import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
    ManifestBuilder,
    ScalingMode
}
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.runtime.fleet { fleet_of }


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
    assert manifests[0]["spec"]["scaleTargetRef"]["name"]
        == "not-the-k8s-safe-name-deployment";
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
    assert manifests[1]["spec"]["secretTargetRef"]
        == [{"parameter": "password", "name": "redis-secret", "key": "pw"}];
}


# Drive the real bundle the deploy builds, then render the autoscaler objects
# the apply path would send, so a declared bound is followed all the way to the
# manifest instead of being asserted at an intermediate hop.
def _applied_hpas(k8s_config: KubernetesConfig, services: dict) -> list[dict] {
    import tempfile;
    import from pathlib { Path }
    with tempfile.TemporaryDirectory() as project {
        for name in list(services.keys()) + ["main"] {
            (Path(project) / f"{name}.jac").write_text("");
        }
        builder = ManifestBuilder(
            k8s_config=k8s_config,
            fleet=fleet_of(
                {name: f"/{name}" for name in services},
                overrides=services,
                files={name: f"{name}.jac" for name in services}
            ),
            dry_run=True
        );
        bundle = builder.generate_manifests(
            AppConfig(code_folder=project, app_name=k8s_config.app_name), ""
        );
        rendered = KubernetesTarget(config=k8s_config).render_autoscaler_manifests(
            bundle
        );
        return [
            m
            for m in rendered
            if m["kind"] == "HorizontalPodAutoscaler"
        ];
    }
}


test "a declared [scale.kubernetes] bound reaches the applied HPA" {
    hpas = _applied_hpas(
        KubernetesConfig(
            app_name="shop",
            namespace="shop-ns",
            bundle_storage_class="standard",
            min_replicas=3,
            max_replicas=9,
            cpu_utilization_target=40
        ),
        {"orders": {"file": "orders.jac"}}
    );
    assert hpas , "the deploy rendered no HorizontalPodAutoscaler at all";
    for m in hpas {
        assert m["spec"]["minReplicas"] == 3 , (
            f"applied minReplicas is {m['spec']['minReplicas']}, not the declared 3"
        );
        assert m["spec"]["maxReplicas"] == 9 , (
            f"applied maxReplicas is {m['spec']['maxReplicas']}, not the declared 9"
        );
    }
}


test "a per-service hpa key beats the config-level bound in the applied HPA" {
    hpas = _applied_hpas(
        KubernetesConfig(
            app_name="shop",
            namespace="shop-ns",
            bundle_storage_class="standard",
            min_replicas=3,
            max_replicas=9
        ),
        {"orders": {"file": "orders.jac", "hpa": {"min": 2, "max": 4}}}
    );
    named = {m["metadata"]["name"]: m["spec"] for m in hpas};
    overridden = [
        spec
        for (name, spec) in named.items()
        if "orders" in name
    ];
    rendered_names = sorted(named.keys());
    assert overridden , f"no autoscaler was rendered for orders: {rendered_names}";
    got_min = overridden[0]["minReplicas"];
    assert got_min == 2 , f"the per-service floor lost to the app-wide one: {got_min}";
    assert overridden[0]["maxReplicas"] == 4;

    # The app-wide bound still governs everything that did not override it,
    # the gateway included, which is what makes [scale.kubernetes] a default
    # rather than a per-service setting.
    inherited = [
        spec
        for (name, spec) in named.items()
        if "orders" not in name
    ];
    assert inherited , f"only the overriding service was scaled: {rendered_names}";
    inherited_min = inherited[0]["minReplicas"];
    assert inherited_min == 3 , (
        f"a service that set no hpa key did not inherit the app-wide floor: {inherited_min}"
    );
}
