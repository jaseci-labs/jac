import from jac_scale._optdeps.kubernetes {
    AutoscalingV2Api,
    V2CrossVersionObjectReference,
    V2HorizontalPodAutoscaler,
    V2HorizontalPodAutoscalerBehavior,
    V2HorizontalPodAutoscalerSpec,
    V2HPAScalingRules,
    V2MetricSpec,
    V2ResourceMetricSource,
    ApiException
}

def create_hpa(
    namespace: str,
    deployment_name: str,
    min_replicas: int = 1,
    max_replicas: int = 3,
    cpu_target: int | None = 70,
    memory_target: int | None = 70,
    scale_up_stabilization_window: int = 60,
    scale_down_stabilization_window: int = 300
) -> None;
