"""
    Create or update HPA for a deployment based on CPU utilization.
"""

impl create_hpa(
    namespace: str,
    deployment_name: str,
    min_replicas: int = 1,
    max_replicas: int = 3,
    cpu_target: int = 50
) -> None {
    autoscaling_v2 = AutoscalingV2Api();
    hpa_name = f"{deployment_name}-hpa";
    hpa = V2HorizontalPodAutoscaler(
        api_version='autoscaling/v2',
        kind='HorizontalPodAutoscaler',
        metadata={'name': hpa_name, 'labels': {'managed': 'jac-scale'}},
        spec=V2HorizontalPodAutoscalerSpec(
            scale_target_ref=V2CrossVersionObjectReference(
                api_version='apps/v1', kind='Deployment', name=deployment_name
            ),
            min_replicas=min_replicas,
            max_replicas=max_replicas,
            metrics=[
                V2MetricSpec(
                    `type='Resource',
                    resource=V2ResourceMetricSource(
                        name='cpu',
                        target={'type': 'Utilization', 'averageUtilization': cpu_target}
                    )
                )
            ]
        )
    );
    try {
        autoscaling_v2.replace_namespaced_horizontal_pod_autoscaler(
            name=hpa_name, namespace=namespace, body=hpa
        );
    } except ApiException as e {
        if (e.status == 404) {
            autoscaling_v2.create_namespaced_horizontal_pod_autoscaler(
                namespace=namespace, body=hpa
            );
        } else {
            raise;
        }
    }
}
