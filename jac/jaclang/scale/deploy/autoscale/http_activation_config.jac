def build_http_activation_spec(
    cfg: dict[str, any], scale_target_name: str, namespace: str, service_name: str
) -> HTTPActivationSpec | None;

def apply_http_activation_for_target(
    cfg: dict[str, any],
    scale_target_name: str,
    namespace: str,
    service_name: str,
    keda: KEDAAutoscaler
) -> bool | None;

def destroy_http_activation_for_target(
    scale_target_name: str, namespace: str, keda: KEDAAutoscaler
);
