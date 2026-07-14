import from jaclang.scale.deploy.autoscale.hpa_autoscaler { HPAAutoscaler }
import from jaclang.scale.deploy.autoscale.autoscaler { AutoscalerSpec, Trigger }


test "memory trigger produces a memory metric, not a cpu one" {
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        namespace="default",
        triggers=[Trigger(type="memory", metadata={"averageUtilization": "75"})]
    );
    m = HPAAutoscaler()._build_manifests(spec);
    metrics = m["spec"]["metrics"];
    assert len(metrics) == 1;
    assert metrics[0]["resource"]["name"] == "memory";
    assert metrics[0]["resource"]["target"]["averageUtilization"] == 75;
}

test "cpu and memory triggers each get their own metric" {
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        namespace="default",
        triggers=[
            Trigger(type="cpu", metadata={"averageUtilization": "60"}),
            Trigger(type="memory", metadata={})
        ]
    );
    m = HPAAutoscaler()._build_manifests(spec);
    metrics = m["spec"]["metrics"];
    assert len(metrics) == 2;
    assert metrics[0]["resource"]["name"] == "cpu";
    assert metrics[0]["resource"]["target"]["averageUtilization"] == 60;
    assert metrics[1]["resource"]["name"] == "memory";
    assert metrics[1]["resource"]["target"]["averageUtilization"] == 80;
}

test "empty triggers fall back to the default cpu metric" {
    spec = AutoscalerSpec(scale_target_name="svc-deployment", namespace="default");
    m = HPAAutoscaler()._build_manifests(spec);
    metrics = m["spec"]["metrics"];
    assert len(metrics) == 1;
    assert metrics[0]["resource"]["name"] == "cpu";
    assert metrics[0]["resource"]["target"]["averageUtilization"] == 50;
}

test "behavior block rate-limits scale-up and stabilizes scale-down from the spec" {
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        namespace="default",
        cooldown_period=600,
        scale_up_stabilization=120,
        scale_up_max_pods=4
    );
    behavior = HPAAutoscaler()._build_manifests(spec)["spec"]["behavior"];
    assert behavior["scaleUp"]["stabilizationWindowSeconds"] == 120;
    assert behavior["scaleUp"]["policies"] == [
        {"type": "Pods", "value": 4, "periodSeconds": 60}
    ];
    assert behavior["scaleDown"]["stabilizationWindowSeconds"] == 600;
    assert behavior["scaleDown"]["policies"] == [
        {"type": "Percent", "value": 50, "periodSeconds": 60}
    ];
}

test "non-resource triggers are excluded from HPA metrics" {
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        namespace="default",
        triggers=[
            Trigger(type="prometheus", metadata={"threshold": "100"}),
            Trigger(type="cpu", metadata={"averageUtilization": "55"})
        ]
    );
    metrics = HPAAutoscaler()._build_manifests(spec)["spec"]["metrics"];
    assert len(metrics) == 1;
    assert metrics[0]["resource"]["name"] == "cpu";
}
