import from jaclang.scale._optdeps.kubernetes { client, ApiException, AutoscalingV2Api }
import from jaclang.scale.deploy.autoscale.autoscaler {
    Autoscaler,
    AutoscalerSpec,
    Trigger,
    TriggerAuth,
    DEFAULT_CPU_UTILIZATION_TARGET,
    DEFAULT_MEMORY_UTILIZATION_TARGET
}
import from jaclang.scale.deploy.autoscale.http_activation {
    HTTPActivationSpec,
    HTTPRoutingRule
}
import from jaclang.scale.observability.logger { Logger }
import hashlib;

obj KEDAAutoscaler(Autoscaler) {
    has _custom_api: (any | None) = None,
        _v2_api: (any | None) = None,
        _apps_api: (any | None) = None,
        _core_api: (any | None) = None,
        http_scaler_address: str = "keda-add-ons-http-external-scaler.keda:9090",
        logger: (Logger | None) = None;

    static has _preflight_cache: dict[str, any] = {},
        _http_preflight_cache: dict[str, any] = {};

    def _get_cluster_key -> str;
    def _trigger_key(trigger: Trigger, trigger_index: int) -> str;
    def _trigger_auth_name(app_name: str, trigger: Trigger, trigger_index: int) -> str;
    def _validate_triggers(spec: AutoscalerSpec, app_name: str) -> None;
    def _build_trigger(
        trigger: Trigger, app_name: str, trigger_index: int
    ) -> dict[str, any];

    def _apply_trigger_auth(
        api: any, trigger: Trigger, namespace: str, app_name: str, trigger_index: int
    ) -> None;

    def _build_manifests(spec: AutoscalerSpec) -> dict[str, any];
    def preflight -> list[str];
    def apply(spec: AutoscalerSpec) -> bool;
    def destroy(autoscaler_name: str, namespace: str) -> None;
    def destroy_collection(namespace: str, label_selector: str) -> None;
    def resource_name_for(target: str) -> str;
    def _validate_http_activation_spec(spec: HTTPActivationSpec) -> None;
    def _build_routing_rules(rules: list[HTTPRoutingRule]) -> list[dict[str, any]];
    def _build_interceptor_route(spec: HTTPActivationSpec) -> dict[str, any];
    def _build_http_scaled_object(spec: HTTPActivationSpec) -> dict[str, any];
    def interceptor_route_name_for(target: str) -> str;
    def http_scaled_object_name_for(target: str) -> str;
    def apply_http_activation(spec: HTTPActivationSpec) -> bool;
    def destroy_http_activation(target: str, namespace: str) -> None;
}
