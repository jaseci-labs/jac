import from jac_scale._optdeps.kubernetes { AutoscalingV2Api, ApiException }
import from jac_scale.abstractions.autoscaler { Autoscaler, AutoscalerSpec }
import from jac_scale.targets.kubernetes.utils.kubernetes_utils { delete_if_exists }

"""HPA-backed autoscaler engine; implements the Autoscaler interface."""
obj HPAAutoscaler(Autoscaler) {
    """Build the HPA manifest dict from spec; used by apply() and dry-run."""
    def _build_manifests(spec: AutoscalerSpec) -> dict[str, any];

    """Validate triggers then create or patch the HPA on the cluster."""
    def apply(spec: AutoscalerSpec) -> None;

    """Delete the HPA resource from the cluster."""
    def destroy(target_name: str, namespace: str) -> None;
}
