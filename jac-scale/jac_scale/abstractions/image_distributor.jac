"""Cluster-aware image distribution abstraction. Strategy pattern: one
concrete subclass per cluster type (Minikube / K3d / Kind / RegistryPush).
Where ImageRegistry covers external registry push, ImageDistributor
covers the cluster-side `get this image to the nodes` step."""

import from pathlib { Path }


class ImageDistributor {
    """Build the image from `project_dir` and make it reachable to nodes
    in the target cluster. Returns the image tag as referenced from pod
    manifests (may differ from input when the distributor rewrites it)."""
    def build_and_distribute(
        self: ImageDistributor, project_dir: Path, image_tag: str
    ) -> str;
}
