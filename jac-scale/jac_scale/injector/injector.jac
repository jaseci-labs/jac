"""Injector port: the contract for getting a service's code into its pod.

Four responsibilities, mirrored by every adapter:
  prepare()         pack the code artifact (build-time, no cluster I/O)
  extra_manifests() cluster-scoped manifests the strategy requires (e.g. the PVC)
  seed()            publish the artifact into the cluster (deploy-time I/O, run
                    AFTER extra_manifests() are applied so the target exists)
  mutate_pod_spec() add the volumes / init container / mounts the strategy needs

prepare() and seed() are deliberately split: the PVC the bundle lands on does not
exist until the deploy path applies extra_manifests(), so the side-effecting
publish must happen after that, not during manifest generation.

The default PvcInjector publishes to a shared ReadWriteMany PVC; a deferred
ImageInjector will publish a built image. Selection happens once, in the realizer,
so the rest of the deploy path is adapter-agnostic.
"""

obj Injector {
    """Pack the code artifact for `app_name` and record whatever mutate_pod_spec()
    and seed() need (object key, packed bytes, image ref). Build-time and free of
    cluster I/O, so it can run during manifest generation before anything exists."""
    def prepare(app_name: str, namespace: str, project_dir: str) {
        raise NotImplementedError("prepare() must be implemented by an Injector");
    }

    """Publish the prepared artifact into the cluster. Deploy-time, side-effecting,
    and run AFTER extra_manifests() are applied (so the bundle PVC / store exists).
    Default no-op: adapters that publish to a pre-existing store override it."""
    def seed(app_name: str, namespace: str) {
        return;
    }

    """Return `pod_spec` with the volumes, init container, mounts, and env this
    strategy requires so the main container starts against ready code."""
    def mutate_pod_spec(pod_spec: dict[str, any], base_image: str) -> dict[str, any] {
        raise NotImplementedError(
            "mutate_pod_spec() must be implemented by an Injector"
        );
    }

    """Cluster-scoped manifests this strategy needs (e.g. the object store
    Deployment/Service/Secret). Empty list when none are required."""
    def extra_manifests(app_name: str, namespace: str) -> list[dict[str, any]] {
        raise NotImplementedError(
            "extra_manifests() must be implemented by an Injector"
        );
    }
}
