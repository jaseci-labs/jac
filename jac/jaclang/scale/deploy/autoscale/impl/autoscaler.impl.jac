impl transition_from(
    status: AutoscalerRuntimeStatus,
    scale_target_name: str,
    namespace: str,
    previous_state: (ResourceStatus | None)
) -> AutoscalerTransition {
    import from datetime { datetime, timezone }
    return AutoscalerTransition(
        scale_target_name=scale_target_name,
        namespace=namespace,
        state=status.status,
        previous_state=previous_state,
        autoscaler_name=status.autoscaler_name,
        engine=status.engine,
        observed_at=datetime.now(timezone.utc).isoformat(),
        resource_version=status.resource_version,
        reason=status.reason,
        message=status.message
    );
}

impl normalize_conditions(raw: any) -> list[dict[str, any]] {
    out: list[dict[str, any]] = [];
    for cond in (raw or []) {
        out.append(
            {
                key: str(field_of(cond, key) or "")
                for key in ["type", "status", "reason", "message"]
            }
        );
    }
    return out;
}

impl condition(conditions: list[dict[str, any]], kind: str) -> (dict[str, any] | None) {
    for cond in conditions {
        if cond.get("type") == kind {
            return cond;
        }
    }
    return None;
}

impl tristate(conditions: list[dict[str, any]], kind: str) -> (bool | None) {
    cond = condition(conditions, kind);
    if cond is None {
        return None;
    }
    status = cond.get("status", "");
    if status == "True" {
        return True;
    }
    if status == "False" {
        return False;
    }
    return None;
}

impl Autoscaler._managed_labels -> dict[str, str] {
    return {"managed": "jac-scale"};
}

impl Autoscaler._build_behavior(spec: AutoscalerSpec) -> dict[str, any] {
    `default: dict[str, any] = {
        "scaleUp": {
            "stabilizationWindowSeconds": min(
                3600, max(0, spec.scale_up_stabilization)
            ),
            "policies": [
                {
                    "type": "Pods",
                    "value": max(1, spec.scale_up_max_pods),
                    "periodSeconds": 60
                }
            ]
        },
        "scaleDown": {
            "stabilizationWindowSeconds": min(3600, max(0, spec.cooldown_period)),
            "policies": [{"type": "Percent", "value": 50, "periodSeconds": 60}]
        }
    };
    if not spec.behavior_overlay {
        return `default;
    }

    return merge_manifest_overlay(`default, spec.behavior_overlay);
}

impl Autoscaler._build_manifests(
    self: Autoscaler, spec: AutoscalerSpec
) -> list[dict[str, any]] {
    raise NotImplementedError(
        "_build_manifests() must be implemented by a concrete Autoscaler subclass"
    );
}

impl Autoscaler.apply(self: Autoscaler, spec: AutoscalerSpec) -> bool {
    raise NotImplementedError(
        "apply() must be implemented by a concrete Autoscaler subclass"
    );
}

impl Autoscaler.destroy(self: Autoscaler, app_name: str, namespace: str) {
    raise NotImplementedError(
        "destroy() must be implemented by a concrete Autoscaler subclass"
    );
}

impl Autoscaler.destroy_collection(
    self: Autoscaler, namespace: str, label_selector: str
) {
    raise NotImplementedError(
        "destroy_collection() must be implemented by a concrete Autoscaler subclass"
    );
}

impl Autoscaler.preflight(self: Autoscaler) -> list[str] {
    return [];
}

impl Autoscaler.read_workload(
    self: Autoscaler,
    scale_target_name: str,
    namespace: str,
    apps_api: (any | None) = None
) -> (any | None) {
    api = apps_api or client.AppsV1Api();
    try {
        return api.read_namespaced_deployment(
            name=scale_target_name, namespace=namespace
        );
    } except ApiException as e {
        if e.status == 404 {
            return None;
        }
        raise;
    }
}

impl Autoscaler.get_runtime_status(
    self: Autoscaler,
    scale_target_name: str,
    namespace: str,
    autoscaler_name: (str | None) = None
) -> AutoscalerRuntimeStatus {
    return self.workload_runtime_status(scale_target_name, namespace);
}

impl Autoscaler.watch_scale_targets(
    self: Autoscaler,
    namespace: str,
    label_selector: (str | None) = None,
    timeout_seconds: (int | None) = None
) -> any {
    raise NotImplementedError(
        "watch_scale_targets() is implemented by engines whose scaling "
        "intent is a watchable resource; this engine has none."
    );
}

impl Autoscaler.workload_runtime_status(
    self: Autoscaler,
    scale_target_name: str,
    namespace: str,
    replica_floor: (int | None) = None,
    apps_api: (any | None) = None
) -> AutoscalerRuntimeStatus {
    deployment = self.read_workload(scale_target_name, namespace, apps_api);
    health = assess_workload(deployment, replica_floor=replica_floor);
    version = field_of(field_of(deployment, "metadata"), "resource_version");
    return AutoscalerRuntimeStatus(
        **health.__dict__,
        conditions=normalize_conditions(
            field_of(field_of(deployment, "status"), "conditions")
        ),
        resource_version=str(version) if version is not None else None
    );
}

impl Autoscaler.resource_name_for(self: Autoscaler, target: str) -> str {
    raise NotImplementedError(
        "resource_name_for() must be implemented by a concrete Autoscaler subclass."
    );
}
