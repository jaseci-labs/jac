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
) -> AutoscalerTransition;


def normalize_conditions(raw: any) -> list[dict[str, any]];


def condition(conditions: list[dict[str, any]], kind: str) -> (dict[str, any] | None);


def tristate(conditions: list[dict[str, any]], kind: str) -> (bool | None);


class Autoscaler {
    static def _managed_labels -> dict[str, str];
    static def _build_behavior(spec: AutoscalerSpec) -> dict[str, any];
    def _build_manifests(
        self: Autoscaler, spec: AutoscalerSpec
    ) -> list[dict[str, any]];

    def apply(self: Autoscaler, spec: AutoscalerSpec) -> bool;
    def destroy(self: Autoscaler, app_name: str, namespace: str);
    def destroy_collection(self: Autoscaler, namespace: str, label_selector: str);
    def preflight(self: Autoscaler) -> list[str];
    def read_workload(
        self: Autoscaler,
        scale_target_name: str,
        namespace: str,
        apps_api: (any | None) = None
    ) -> (any | None);

    def get_runtime_status(
        self: Autoscaler,
        scale_target_name: str,
        namespace: str,
        autoscaler_name: (str | None) = None
    ) -> AutoscalerRuntimeStatus;

    def watch_scale_targets(
        self: Autoscaler,
        namespace: str,
        label_selector: (str | None) = None,
        timeout_seconds: (int | None) = None
    ) -> any;

    def workload_runtime_status(
        self: Autoscaler,
        scale_target_name: str,
        namespace: str,
        replica_floor: (int | None) = None,
        apps_api: (any | None) = None
    ) -> AutoscalerRuntimeStatus;

    def resource_name_for(self: Autoscaler, target: str) -> str;
}
