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
        initial_cooldown_period: int = 0;
}


class Autoscaler {
    static def _managed_labels -> dict[str, str] {
        return {"managed": "jac-scale"};
    }

    def apply(self: Autoscaler, spec: AutoscalerSpec) -> bool {
        raise NotImplementedError(
            "apply() must be implemented by a concrete Autoscaler subclass"
        );
    }

    def destroy(self: Autoscaler, autoscaler_name: str, namespace: str) {
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

    def resource_name_for(self: Autoscaler, target: str) -> str {
        raise NotImplementedError(
            "resource_name_for() must be implemented by a concrete Autoscaler subclass."
        );
    }
}
