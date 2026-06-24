"""Injector port: the contract for getting a service's code into its pod.

Three responsibilities, mirrored by every adapter:
  prepare()         publish the code artifact (side-effecting, deploy-time)
  mutate_pod_spec() add the volumes / init container / mounts the strategy needs
  extra_manifests() cluster-scoped manifests the strategy requires

The default PvcInjector publishes to a shared ReadWriteMany PVC; a deferred
ImageInjector will publish a built image. Selection happens once, in the realizer,
so the rest of the deploy path is adapter-agnostic.
"""

obj Injector {
    """Pack and publish the code artifact for `app_name`. Side-effecting and run
    at deploy time; subclasses store whatever they need (object key, image ref)
    for mutate_pod_spec()."""
    def prepare(app_name: str, namespace: str, project_dir: str) -> None {
        raise NotImplementedError("prepare() must be implemented by an Injector");
    }

    """Return `pod_spec` with the volumes, init container, mounts, and env this
    strategy requires so the main container starts against ready code."""
    def mutate_pod_spec(pod_spec: dict[str, any], base_image: str) -> dict[str, any] {
        raise NotImplementedError("mutate_pod_spec() must be implemented by an Injector");
    }

    """Cluster-scoped manifests this strategy needs (e.g. the object store
    Deployment/Service/Secret). Empty list when none are required."""
    def extra_manifests(app_name: str, namespace: str) -> list[dict[str, any]] {
        raise NotImplementedError("extra_manifests() must be implemented by an Injector");
    }
}
