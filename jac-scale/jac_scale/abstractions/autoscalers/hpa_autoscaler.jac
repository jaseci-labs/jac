import from jac_scale._optdeps.kubernetes { AutoscalingV2Api, ApiException }
import from jac_scale.abstractions.autoscaler {
    Autoscaler,
    AutoscalerSpec,
    DEFAULT_CPU_UTILIZATION_TARGET
}
import from jac_scale.abstractions.logger { Logger }
import from jac_scale.targets.kubernetes.utils.kubernetes_utils { delete_if_exists }

"""HPA-backed autoscaler engine; implements the Autoscaler interface."""
obj HPAAutoscaler(Autoscaler) {
    has logger: (Logger | None) = None;

    """Build the HPA manifest dict from spec; used by apply() and dry-run."""
    def _build_manifests(spec: AutoscalerSpec) -> dict[str, any];

    """Validate triggers then create or patch the HPA on the cluster."""
    def apply(spec: AutoscalerSpec) -> None;

    """Delete the HPA resource from the cluster."""
    def destroy(autoscaler_name: str, namespace: str) -> None;

    """Delete all HPA resources in namespace matching label_selector."""
    def destroy_collection(namespace: str, label_selector: str) -> None;
}
