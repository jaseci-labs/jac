import from jaclang.scale._optdeps.kubernetes { client, ApiException, AutoscalingV2Api }
import from jaclang.scale.deploy.autoscale.autoscaler {
    Autoscaler,
    AutoscalerSpec,
    Trigger,
    TriggerAuth,
    DEFAULT_CPU_UTILIZATION_TARGET,
    DEFAULT_MEMORY_UTILIZATION_TARGET
}
import from jaclang.scale.observability.logger { Logger }

obj KEDAAutoscaler(Autoscaler) {
    has _custom_api: (any | None) = None,
        _v2_api: (any | None) = None,
        logger: (Logger | None) = None;

    static has _preflight_cache: dict[str, any] = {};

    def _get_cluster_key -> str;
    def _build_trigger(trigger: Trigger) -> dict[str, any];
    def _apply_trigger_auth(api: any, trigger: Trigger, namespace: str) -> None;
    def _build_manifests(spec: AutoscalerSpec) -> dict[str, any];
    def preflight -> list[str];
    def apply(spec: AutoscalerSpec) -> bool;
    def destroy(autoscaler_name: str, namespace: str) -> None;
    def destroy_collection(namespace: str, label_selector: str) -> None;
    def resource_name_for(target: str) -> str;
}
