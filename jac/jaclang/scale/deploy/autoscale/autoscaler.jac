import from jaclang.scale.models.resource_status {
    ResourceStatus,
    ResourceStatusInfo,
    assess_workload,
    field_of
}

glob DEFAULT_CPU_UTILIZATION_TARGET: int = 50,
     DEFAULT_MEMORY_UTILIZATION_TARGET: int = 80;

obj TriggerAuth {
    has secret_refs: dict[str, dict[str, str]] = {};
}

obj Trigger {
    has type: str,
        metadata: dict[str, any] = {},
        name: (str | None) = None,
        auth: (TriggerAuth | None) = None;
}

obj AutoscalerSpec {
    has scale_target_name: str,
        namespace: str,
        min_replicas: int = 1,
        max_replicas: int = 3,
        target_kind: str = "Deployment",
        triggers: list[Trigger] = [],
        autoscaler_name: (str | None) = None,
        app_name: (str | None) = None,
        idle_replicas: (int | None) = None,
        polling_interval: int = 30,
        cooldown_period: int = 300,
        initial_cooldown_period: int = 0,
        scale_up_stabilization: int = 60,
        scale_up_max_pods: int = 2,
        behavior_overlay: dict[str, any] = {};
}


obj AutoscalerRuntimeStatus(ResourceStatusInfo) {
    has engine: str = "",
        autoscaler_name: (str | None) = None,
        trigger_active: (bool | None) = None,
        scaler_ready: (bool | None) = None,
        conditions: list[dict[str, any]] = [],
        resource_version: (str | None) = None;
}


obj AutoscalerTransition {
    has scale_target_name: str,
        namespace: str,
        state: ResourceStatus,
        previous_state: (ResourceStatus | None) = None,
        autoscaler_name: (str | None) = None,
        engine: str = "",
        observed_at: str = "",
        resource_version: (str | None) = None,
        reason: str = "",
        message: (str | None) = None;
}


def transition_from(
    status: AutoscalerRuntimeStatus,
    scale_target_name: str,
    namespace: str,
    previous_state: (ResourceStatus | None)
) -> AutoscalerTransition {
    """A transition built from the same status the point-in-time API returns.

    Derived rather than recomputed so an observer and get_runtime_status can
    never disagree about one target. `observed_at` is stamped here, when this
    observer saw the change, which is not when the change happened: a
    transition that occurred while the observer was down is reported as current
    state on the next relist and carries that later timestamp. Callers that
    need the real moment something happened keep their own record.
    """;
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


def normalize_conditions(raw: any) -> list[dict[str, any]] {
    """Kubernetes conditions as plain dicts, whichever client produced them.

    A ScaledObject read through CustomObjectsApi is dicts, an HPA read through
    a typed client is objects. field_of already spans that, and every key read
    here is spelled the same in both forms, so no case mapping is needed.
    """;
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


def condition(conditions: list[dict[str, any]], kind: str) -> (dict[str, any] | None) {
    for cond in conditions {
        if cond.get("type") == kind {
            return cond;
        }
    }
    return None;
}


def tristate(conditions: list[dict[str, any]], kind: str) -> (bool | None) {
    """A Kubernetes condition as True, False, or None when it is absent.

    Kubernetes conditions are tri-state on purpose: "Unknown" and "not reported
    yet" both mean the controller has not decided, and collapsing either to
    False would read as "broken". This is why AutoscalerRuntimeStatus carries
    `trigger_active` and `scaler_ready` as (bool | None): an HPA has no trigger
    concept at all, and a ScaledObject that could not be read leaves both
    unknown rather than claiming the scaler failed.
    """;
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


class Autoscaler {
    static def _managed_labels -> dict[str, str] {
        return {"managed": "jac-scale"};
    }

    static def _build_behavior(spec: AutoscalerSpec) -> dict[str, any] {
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
        import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
            merge_manifest_overlay
        }
        return merge_manifest_overlay(`default, spec.behavior_overlay);
    }

    def _build_manifests(
        self: Autoscaler, spec: AutoscalerSpec
    ) -> list[dict[str, any]] {
        raise NotImplementedError(
            "_build_manifests() must be implemented by a concrete Autoscaler subclass"
        );
    }

    def apply(self: Autoscaler, spec: AutoscalerSpec) -> bool {
        raise NotImplementedError(
            "apply() must be implemented by a concrete Autoscaler subclass"
        );
    }

    def destroy(self: Autoscaler, app_name: str, namespace: str) {
        raise NotImplementedError(
            "destroy() must be implemented by a concrete Autoscaler subclass"
        );
    }

    def destroy_collection(self: Autoscaler, namespace: str, label_selector: str) {
        raise NotImplementedError(
            "destroy_collection() must be implemented by a concrete Autoscaler subclass"
        );
    }

    def preflight(self: Autoscaler) -> list[str] {
        return [];
    }

    def read_workload(
        self: Autoscaler,
        scale_target_name: str,
        namespace: str,
        apps_api: (any | None) = None
    ) -> (any | None) {
        import from jaclang.scale._optdeps.kubernetes { client, ApiException }
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

    def get_runtime_status(
        self: Autoscaler,
        scale_target_name: str,
        namespace: str,
        autoscaler_name: (str | None) = None
    ) -> AutoscalerRuntimeStatus {
        """The scale target's normalized state, point in time.

        The engine-neutral answer is the workload's own, so an engine that
        cannot be read, or a third-party engine that never implements this,
        still reports the same vocabulary as `ScaleClient.resource_status`
        rather than nothing. A concrete engine overrides to add what only it
        knows: whether a trigger is firing, and whether its scaler is healthy.

        `autoscaler_name` is optional because a caller that had to supply it
        would first have to work out which of the engine's resource names
        exists for this target, which is the derivation this method is here to
        do for them.
        """;
        return self.workload_runtime_status(scale_target_name, namespace);
    }

    def watch_scale_targets(
        self: Autoscaler,
        namespace: str,
        label_selector: (str | None) = None,
        timeout_seconds: (int | None) = None
    ) -> any {
        """Stream deduplicated state transitions for a namespace's targets.

        Cardinality is the caller's: one call opens a bounded number of watches
        for that namespace and nothing here shares them between callers, so a
        control plane that wants one stream for many targets makes one call and
        fans out in its own process. An engine without a resource that reports
        scaling intent has nothing to watch and says so rather than silently
        yielding nothing.
        """;
        raise NotImplementedError(
            "watch_scale_targets() is implemented by engines whose scaling "
            "intent is a watchable resource; this engine has none."
        );
    }

    def workload_runtime_status(
        self: Autoscaler,
        scale_target_name: str,
        namespace: str,
        replica_floor: (int | None) = None,
        apps_api: (any | None) = None
    ) -> AutoscalerRuntimeStatus {
        """The workload half, shared by every engine.

        Delegates to assess_workload so an autoscaler's view of a Deployment
        and `jac scale status`' view can never drift apart.
        """;
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

    def resource_name_for(self: Autoscaler, target: str) -> str {
        raise NotImplementedError(
            "resource_name_for() must be implemented by a concrete Autoscaler subclass."
        );
    }
}
