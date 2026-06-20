"""Base autoscaler abstraction for jac-scale."""

"""Single authoritative CPU utilization default for all autoscaler paths."""
glob DEFAULT_CPU_UTILIZATION_TARGET: int = 50;

"""Single authoritative memory utilization default for all autoscaler paths."""
glob DEFAULT_MEMORY_UTILIZATION_TARGET: int = 80;

"""Secret references for a KEDA TriggerAuthentication resource."""
obj TriggerAuth {
    has secret_refs: dict[str, dict[str, str]] = {};
}

"""A single scaling trigger with engine-specific metadata."""
obj Trigger {
    has type: str,
        metadata: dict[str, any] = {},
        name: (str | None) = None,
        auth: (TriggerAuth | None) = None;
}

"""Specification for an autoscaler resource."""
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


"""Base class for all autoscaler engine implementations."""
class Autoscaler {
    """Labels applied to every resource created by any engine.

    Implementations MUST use these in apply() so that destroy_collection()
    can reliably select all managed resources by label.
    """
    static def _managed_labels -> dict[str, str] {
        return {"managed": "jac-scale"};
    }

    """Create or update the autoscaler resource on the cluster.

    Returns True when the resource was written to the cluster, False when a
    preflight check determined the engine is unavailable and apply() exited
    early without writing anything.  Callers must check the return value
    before stamping a success detail or emitting an 'applied' log line —
    engines like KEDAAutoscaler can degrade gracefully (no raise) yet still
    have written nothing, so an unconditional 'Successful' would be a lie.

    Args:
        spec: Autoscaler specification including target, replicas, and triggers
    """
    def apply(self: Autoscaler, spec: AutoscalerSpec) -> bool {
        raise NotImplementedError(
            "apply() must be implemented by a concrete Autoscaler subclass"
        );
    }

    """Remove the autoscaler resource from the cluster.

    Args:
        autoscaler_name: Name of the autoscaler resource to delete
        namespace: Kubernetes namespace
    """
    def destroy(self: Autoscaler, autoscaler_name: str, namespace: str) {
        raise NotImplementedError(
            "destroy() must be implemented by a concrete Autoscaler subclass"
        );
    }

    """Delete all autoscaler resources in namespace matching label_selector.

    Use Autoscaler._managed_labels() to build the selector string so the
    label set stays in sync with what apply() stamps on each resource.

    Args:
        namespace: Kubernetes namespace
        label_selector: Label selector string, e.g. 'managed=jac-scale'
    """
    def destroy_collection(self: Autoscaler, namespace: str, label_selector: str) {
        raise NotImplementedError(
            "destroy_collection() must be implemented by a concrete Autoscaler subclass"
        );
    }

    """Check for missing cluster dependencies before any cluster write.

    Returns:
        List of warning strings; empty list means all prerequisites are met.
        Override in engines that require cluster-side components (e.g. KEDA CRDs).
    """
    def preflight(self: Autoscaler) -> list[str] {
        return [];
    }

    """Return the cluster resource name for the given scale target.
    Override in each engine: HPA returns `{target}-hpa, KEDA returns `{target}-scaledobject`."""
    def resource_name_for(self: Autoscaler, target: str) -> str {
        raise NotImplementedError(
            "resource_name_for() must be implemented by a concrete Autoscaler subclass."
        );
    }
}
