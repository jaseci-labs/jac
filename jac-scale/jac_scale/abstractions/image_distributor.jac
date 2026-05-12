"""Cluster-aware image distribution abstraction.

Where `ImageRegistry` is about pushing to an external registry (Docker
Hub, ECR, GCR, ACR, etc.), `ImageDistributor` covers the cluster-side
"get this image to the nodes" step. Local clusters distribute through
their native import mechanism (`minikube docker-env` shared daemon,
`k3d image import`, `kind load docker-image`); remote clusters
distribute by pushing to a registry the cluster can pull from.

Strategy pattern: one concrete subclass per cluster type. The
`distribute(image)` call is the contract; everything else is
implementation detail.
"""

import from pathlib { Path }


"""Distributes a built image to a target cluster. Strategy pattern.
Concrete implementations:

  MinikubeDistributor    -> build in cluster's docker daemon via minikube docker-env
  K3dDistributor         -> `k3d image import`
  KindDistributor        -> `kind load docker-image`
  RegistryPushDistributor -> docker push to a configured registry URL
"""
class ImageDistributor {
    """Make `image_tag` reachable to nodes in the target cluster.

    Args:
        image_tag: Fully-qualified image tag (e.g. `myapp:latest` or
                   `123.dkr.ecr.us-west-2.amazonaws.com/myapp:v1`).

    Returns:
        The image tag as it should be referenced from pod manifests.
        Distinct from the input when the distributor rewrites the
        reference (e.g. registry push prepends the registry URL).
    """
    def distribute(self: ImageDistributor, image_tag: str) -> str;

    """Build the image from `project_dir` and distribute it.

    Default implementation: build via local docker, then call distribute.
    Concrete distributors that share the cluster's docker daemon (e.g.
    minikube docker-env) override this to build directly in-cluster.

    Args:
        project_dir: Directory containing the Dockerfile and source.
        image_tag: Tag to apply to the built image.

    Returns:
        The image tag as it should be referenced from pod manifests.
    """
    def build_and_distribute(
        self: ImageDistributor, project_dir: Path, image_tag: str
    ) -> str;
}
