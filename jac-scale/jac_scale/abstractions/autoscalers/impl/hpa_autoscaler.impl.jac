"""Build HPA manifest dict from spec fields; no string manipulation on names."""
impl HPAAutoscaler._build_manifests{
    hpa_name = spec.autoscaler_name or f"{spec.scale_target_name}-hpa";
    cpu_target = int(
        spec.triggers[0].metadata.get(
            "averageUtilization", str(DEFAULT_CPU_UTILIZATION_TARGET)
        )
    )
        if spec.triggers
        else DEFAULT_CPU_UTILIZATION_TARGET;
    return {
        "apiVersion": "autoscaling/v2",
        "kind": "HorizontalPodAutoscaler",
        "metadata": {
            "name": hpa_name,
            "namespace": spec.namespace,
            "labels": {"app": spec.scale_target_name, ** Autoscaler._managed_labels()}
        },
        "spec": {
            "scaleTargetRef": {
                "apiVersion": "apps/v1",
                "kind": "Deployment",
                "name": spec.scale_target_name
            },
            "minReplicas": spec.min_replicas,
            "maxReplicas": spec.max_replicas,
            "metrics": [
                {
                    "type": "Resource",
                    "resource": {
                        "name": "cpu",
                        "target": {
                            "type": "Utilization",
                            "averageUtilization": cpu_target
                        }
                    }
                }
            ]
        }
    };
}

"""Validate all triggers are cpu/memory, then patch or create the HPA on the cluster."""
impl HPAAutoscaler.apply{
    for trigger in spec.triggers {
        if trigger.type not in ["cpu", "memory"] {
            raise ValueError(
                f"Trigger type '{trigger.type}' is not supported by engine='hpa'. Use an engine that supports this trigger type in jac.toml."
            );
        }
    }
    manifest = self._build_manifests(spec);
    name = manifest["metadata"]["name"];
    namespace = manifest["metadata"]["namespace"];
    autoscaling_v2 = AutoscalingV2Api();
    try {
        autoscaling_v2.read_namespaced_horizontal_pod_autoscaler(
            name=name, namespace=namespace
        );
        autoscaling_v2.patch_namespaced_horizontal_pod_autoscaler(
            name=name, namespace=namespace, body=manifest
        );
    } except ApiException as e {
        if e.status == 404 {
            autoscaling_v2.create_namespaced_horizontal_pod_autoscaler(
                namespace=namespace, body=manifest
            );
        } else {
            raise;
        }
    }
}

"""Delete the HPA resource; no-op if already absent."""
impl HPAAutoscaler.destroy{
    autoscaling_v2 = AutoscalingV2Api();
    delete_if_exists(
        autoscaling_v2.delete_namespaced_horizontal_pod_autoscaler,
        autoscaler_name,
        namespace,
        'HorizontalPodAutoscaler'
    );
}

"""Delete all HPAs in namespace matching label_selector."""
impl HPAAutoscaler.destroy_collection{
    AutoscalingV2Api().delete_collection_namespaced_horizontal_pod_autoscaler(
        namespace=namespace, label_selector=label_selector
    );
}
