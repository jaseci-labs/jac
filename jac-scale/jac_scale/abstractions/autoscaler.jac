"""Base autoscaler abstraction for jac-scale."""

"""A single scaling trigger with engine-specific metadata."""
obj Trigger {
    has type: str,
        metadata: dict[str, any] = {},
        name: (str | None) = None;
}

"""Specification for an autoscaler resource."""
obj AutoscalerSpec {
    has scale_target_name: str,
        namespace: str,
        min_replicas: int = 1,
        max_replicas: int = 3,
        target_kind: str = "Deployment",
        triggers: list[Trigger] = [],
        autoscaler_name: (str | None) = None;
}


"""Base class for all autoscaler engine implementations."""
class Autoscaler {
    """Create or update the autoscaler resource on the cluster.

    Args:
        spec: Autoscaler specification including target, replicas, and triggers
    """
    def apply(self: Autoscaler, spec: AutoscalerSpec) {
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

    """Check for missing cluster dependencies before any cluster write.

    Returns:
        List of warning strings; empty list means all prerequisites are met.
        Override in engines that require cluster-side components (e.g. KEDA CRDs).
    """
    def preflight(self: Autoscaler) -> list[str] {
        return [];
    }
}
