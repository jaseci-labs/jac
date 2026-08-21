import from threading { Thread, Event as _ThreadStop, Lock }
import from jaclang.scale._optdeps.kubernetes {
    AppsV1Api,
    AutoscalingV2Api,
    CustomObjectsApi,
    Watch
}
import from jaclang.scale.deploy.autoscale.observer {
    AutoscalerObserver,
    AutoscalerSubscription,
    BackpressurePolicy
}
import from jaclang.scale.deploy.autoscale.autoscaler {
    AutoscalerState,
    AutoscalerRuntimeStatus,
    AutoscalerTransition
}
import from jaclang.scale.observability.logger { Logger }

glob WATCHED_KINDS: list[str] = ["scaled_object", "hpa", "deployment"];

obj KubernetesAutoscalerObserver(AutoscalerObserver) {
    has _custom_api: (any | None) = None,
        _v2_api: (any | None) = None,
        _apps_api: (any | None) = None,
        _watch_factory: (any | None) = None,
        logger: (Logger | None) = None,
        _stop_event: _ThreadStop = _ThreadStop(),
        _lock: Lock = Lock(),
        _threads: dict[str, Thread] = {},
        _subscriptions: list[AutoscalerSubscription] = [],
        _target_cache: dict[str, dict[str, (dict[str, any] | None)]] = {},
        _last_state: dict[str, (str | None)] = {};

    def start -> None;
    def stop(drain: bool = True) -> None;
    def watch_namespace(namespace: str, label_selector: (str | None) = None) -> None;
    def subscribe(
        autoscaler_name: (str | None) = None,
        scale_target_name: (str | None) = None,
        max_queue: int = 100,
        backpressure: str = BackpressurePolicy.DROP_OLDEST.value
    ) -> AutoscalerSubscription;

    def health -> dict[str, any];
    def _kind_config(kind: str) -> dict[str, any];
    def _list_and_seed(
        kind: str, namespace: str, label_selector: (str | None)
    ) -> tuple[(str | None), list[dict[str, any]], any];

    def _stream(
        kind: str,
        list_fn: any,
        namespace: str,
        label_selector: (str | None),
        resource_version: (str | None)
    ) -> any;

    def _watch_loop(namespace: str, kind: str, label_selector: (str | None)) -> None;
    def _target_name_for(kind: str, resource: dict[str, any]) -> (str | None);
    def _handle_event(
        namespace: str, kind: str, event_type: str, resource: dict[str, any]
    ) -> None;

    def _reconcile_target(namespace: str, scale_target_name: str) -> None;
    def _emit(transition: AutoscalerTransition) -> None;
}
