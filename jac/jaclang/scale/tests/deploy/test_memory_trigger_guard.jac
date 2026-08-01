import from jaclang.scale.deploy.target.kubernetes.microservice.manifest_builder {
    MicroserviceManifestBuilder,
    GATEWAY_NAME
}
import from jaclang.scale.deploy.target.kubernetes.microservice.target {
    KubernetesMicroserviceTarget
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}


def _builder(
    services: dict, k8s_config: KubernetesConfig | None = None
) -> MicroserviceManifestBuilder {
    return MicroserviceManifestBuilder(
        k8s_config=k8s_config or KubernetesConfig(app_name="t", namespace="t-ns"),
        microservices_config={"services": services},
        dry_run=True
    );
}


def _triggers(cfg: dict, k8s_config: KubernetesConfig | None = None) -> list[str] {
    target = KubernetesMicroserviceTarget(
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
    gw_target = KubernetesMicroserviceTarget(config=gw_k8s);
    gw_types = [
        t.type
        for t in gw_target._resolve_service_triggers(
            GATEWAY_NAME, {"has_memory_request": False}
        )
    ];
    assert gw_types == ["cpu"];
}
