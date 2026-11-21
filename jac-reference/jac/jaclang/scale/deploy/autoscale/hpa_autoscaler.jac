obj HPAAutoscaler(Autoscaler) {
    has logger: (Logger | None) = None;

    def _build_manifests(spec: AutoscalerSpec) -> list[dict[str, any]];
    def apply(spec: AutoscalerSpec) -> bool;
    def destroy(app_name: str, namespace: str) -> None;
    def destroy_collection(namespace: str, label_selector: str) -> None;
    def resource_name_for(target: str) -> str;
    def get_runtime_status(
        scale_target_name: str, namespace: str, autoscaler_name: (str | None) = None
    ) -> AutoscalerRuntimeStatus;
}
