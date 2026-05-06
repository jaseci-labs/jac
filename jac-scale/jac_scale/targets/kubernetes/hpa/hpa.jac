import from jac_scale._optdeps.kubernetes {
    AutoscalingV2Api,
    V2CrossVersionObjectReference,
    V2HorizontalPodAutoscaler,
    V2HorizontalPodAutoscalerSpec,
    V2MetricSpec,
    V2ResourceMetricSource,
    ApiException
}

def create_hpa(
    namespace: str,
    deployment_name: str,
    min_replicas: int = 1,
    max_replicas: int = 3,
    cpu_target: int = 50
) -> None;
