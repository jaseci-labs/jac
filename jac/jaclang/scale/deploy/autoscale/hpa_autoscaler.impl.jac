impl HPAAutoscaler._build_manifests{
    hpa_name = spec.autoscaler_name or f"{spec.scale_target_name}-hpa";
    metrics: list[dict[str, any]] = [];
    for trigger in spec.triggers {
        if trigger.type not in ["cpu", "memory"] {
            continue;
        }
        default_target = DEFAULT_CPU_UTILIZATION_TARGET
            if trigger.type == "cpu"
            else DEFAULT_MEMORY_UTILIZATION_TARGET;
        metrics.append(
            {
                "type": "Resource",
                "resource": {
                    "name": trigger.type,
                    "target": {
                        "type": "Utilization",
                        "averageUtilization": int(
                            trigger.metadata.get(
                                "averageUtilization", str(default_target)
                            )
                        )
                    }
                }
            }
        );
    }
    if not metrics {
        metrics.append(
            {
                "type": "Resource",
                "resource": {
                    "name": "cpu",
                    "target": {
                        "type": "Utilization",
                        "averageUtilization": DEFAULT_CPU_UTILIZATION_TARGET
                    }
                }
            }
        );
    }
    return [
        {
            "apiVersion": "autoscaling/v2",
            "kind": "HorizontalPodAutoscaler",
            "metadata": {
                "name": hpa_name,
                "namespace": spec.namespace,
                "labels": {
                    "app": spec.scale_target_name,
                    ** Autoscaler._managed_labels()
                }
            },
            "spec": {
                "scaleTargetRef": {
                    "apiVersion": "apps/v1",
                    "kind": "Deployment",
                    "name": spec.scale_target_name
                },
                "minReplicas": spec.min_replicas,
                "maxReplicas": spec.max_replicas,
                "metrics": metrics,
                "behavior": Autoscaler._build_behavior(spec)
            }
        }
    ];
}

impl HPAAutoscaler.apply{
    for trigger in spec.triggers {
        if trigger.type not in ["cpu", "memory"] {
            raise ValueError(
                f"Trigger '{trigger.name or trigger.type}' (type='{trigger.type}') requires KEDA. "
                "Set autoscaler_engine = \"keda\" in [scale.kubernetes] in jac.toml."
            );
        }
    }
    manifest = self._build_manifests(spec)[0];
    name = manifest["metadata"]["name"];
    namespace = manifest["metadata"]["namespace"];

    try {
        client.CustomObjectsApi().delete_namespaced_custom_object(
            group="keda.sh",
            version="v1alpha1",
            namespace=namespace,
            plural="scaledobjects",
            name=f"{spec.app_name or spec.scale_target_name}-scaledobject"
        );
    } except ApiException as e {
        if e.status not in [404, 422] {
            raise;
        }
    }
    autoscaling_v2: any = AutoscalingV2Api();
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
    return True;
}

impl HPAAutoscaler.destroy{
    autoscaling_v2: any = AutoscalingV2Api();
    delete_if_exists(
        autoscaling_v2.delete_namespaced_horizontal_pod_autoscaler,
        self.resource_name_for(app_name),
        namespace,
        'HorizontalPodAutoscaler'
    );
}

impl HPAAutoscaler.destroy_collection{
    AutoscalingV2Api().delete_collection_namespaced_horizontal_pod_autoscaler(
        namespace=namespace, label_selector=label_selector
    );

    custom_api = client.CustomObjectsApi();
    for plural in ["scaledobjects", "triggerauthentications"] {
        try {
            items = custom_api.list_namespaced_custom_object(
                group="keda.sh",
                version="v1alpha1",
                namespace=namespace,
                plural=plural,
                label_selector=label_selector
            );
            for item in items.get("items", []) {
                item_name = item["metadata"]["name"];
                try {
                    custom_api.delete_namespaced_custom_object(
                        group="keda.sh",
                        version="v1alpha1",
                        namespace=namespace,
                        plural=plural,
                        name=item_name
                    );
                } except ApiException as e {
                    if e.status != 404 {
                        raise;
                    }
                }
            }
        } except ApiException as e {
            if e.status not in [404, 422] {
                raise;
            }
        }
    }
}

impl HPAAutoscaler.resource_name_for{
    return f"{target}-hpa";
}

impl HPAAutoscaler._normalize_hpa_status{
    if hpa is None {
        return AutoscalerRuntimeStatus(
            state=AutoscalerState.UNKNOWN.value,
            desired_replicas=0,
            current_replicas=0,
            ready_replicas=0,
            message="HorizontalPodAutoscaler not found"
        );
    }

    status = hpa.get("status", {});
    current = status.get("current_replicas", 0) or 0;
    desired = status.get("desired_replicas", 0) or 0;
    conditions = status.get("conditions", []);
    resource_version = hpa.get("metadata", {}).get("resource_version");
    cond_by_type = {c["type"]: c for c in conditions};
    scaling_active = cond_by_type.get("ScalingActive");

    if scaling_active is None {
        return AutoscalerRuntimeStatus(
            state=AutoscalerState.UNKNOWN.value,
            desired_replicas=desired,
            current_replicas=current,
            ready_replicas=current,
            conditions=conditions,
            resource_version=resource_version,
            message="ScalingActive condition missing from HorizontalPodAutoscaler status"
        );
    }

    scaler_ready = scaling_active.get("status") == "True";
    if not scaler_ready {
        return AutoscalerRuntimeStatus(
            state=AutoscalerState.DEGRADED.value,
            desired_replicas=desired,
            current_replicas=current,
            ready_replicas=current,
            scaler_ready=False,
            conditions=conditions,
            resource_version=resource_version,
            message=scaling_active.get("message") or scaling_active.get("reason")
        );
    }

    return AutoscalerRuntimeStatus(
        state=AutoscalerState.ACTIVE.value,
        desired_replicas=desired,
        current_replicas=current,
        ready_replicas=current,
        scaler_ready=True,
        conditions=conditions,
        resource_version=resource_version
    );
}

impl HPAAutoscaler.get_runtime_status{
    try {
        hpa: any = AutoscalingV2Api().read_namespaced_horizontal_pod_autoscaler(
            name=autoscaler_name, namespace=namespace
        );
    } except ApiException as e {
        if e.status in [404, 422] {
            return self._normalize_hpa_status(None);
        }
        raise;
    }
    return self._normalize_hpa_status(hpa.to_dict());
}
