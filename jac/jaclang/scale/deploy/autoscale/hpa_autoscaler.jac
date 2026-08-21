import from jaclang.scale._optdeps.kubernetes { AutoscalingV2Api, ApiException, client }
import from jaclang.scale.deploy.autoscale.autoscaler {
    Autoscaler,
    AutoscalerSpec,
    AutoscalerState,
    AutoscalerRuntimeStatus,
    DEFAULT_CPU_UTILIZATION_TARGET,
    DEFAULT_MEMORY_UTILIZATION_TARGET
}
import from jaclang.scale.observability.logger { Logger }
import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    delete_if_exists
}

obj HPAAutoscaler(Autoscaler) {
    has logger: (Logger | None) = None;

    def _build_manifests(spec: AutoscalerSpec) -> dict[str, any];
    def apply(spec: AutoscalerSpec) -> bool;
    def destroy(autoscaler_name: str, namespace: str) -> None;
    def destroy_collection(namespace: str, label_selector: str) -> None;
    def resource_name_for(target: str) -> str;
    def _normalize_hpa_status(hpa: (dict[str, any] | None)) -> AutoscalerRuntimeStatus;
    def get_runtime_status(
        autoscaler_name: str, scale_target_name: str, namespace: str
    ) -> AutoscalerRuntimeStatus;
}
