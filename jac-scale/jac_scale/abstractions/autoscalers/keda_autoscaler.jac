import from jac_scale._optdeps.kubernetes { client, ApiException, AutoscalingV2Api }
import from jac_scale.abstractions.autoscaler {
    Autoscaler,
    AutoscalerSpec,
    Trigger,
    TriggerAuth,
    DEFAULT_CPU_UTILIZATION_TARGET,
    DEFAULT_MEMORY_UTILIZATION_TARGET
}
import from jac_scale.abstractions.logger { Logger }

obj KEDAAutoscaler(Autoscaler) {
    has _custom_api: (any | None) = None,
        _v2_api: (any | None) = None,
        logger: (Logger | None) = None;

    static has _preflight_cache: dict[str, any] = {};

    """Return a cache key identifying the current cluster"""
    def _get_cluster_key -> str;

    """Build a single KEDA trigger dict from a Trigger object."""
    def _build_trigger(trigger: Trigger) -> dict[str, any];

    """Create or patch the TriggerAuthentication resource for a trigger."""
    def _apply_trigger_auth(api: any, trigger: Trigger, namespace: str) -> None;

    """Build the ScaledObject manifest dict from spec."""
    def _build_manifests(spec: AutoscalerSpec) -> dict[str, any];

    """Check that KEDA CRDs are installed; return warnings if not."""
    def preflight -> list[str];

    """Create or patch ScaledObject (and TriggerAuthentications) on the cluster."""
    def apply(spec: AutoscalerSpec) -> bool;

    """Delete a single ScaledObject from the cluster"""
    def destroy(autoscaler_name: str, namespace: str) -> None;

    """Delete all labeled ScaledObjects and TriggerAuthentications in namespace."""
    def destroy_collection(namespace: str, label_selector: str) -> None;

    """Return `{target}-scaledobject`."""
    def resource_name_for(target: str) -> str;
}
