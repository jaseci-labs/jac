"""`jac start --scale` entry: detect cluster, FE bundle, pick distributor."""

import from pathlib { Path }
import from jac_scale.microservices.images.cluster_detect {
    detect_cluster_type,
    k3d_cluster_name,
    kind_cluster_name,
    _active_context_name,
    CLUSTER_MINIKUBE,
    CLUSTER_K3D,
    CLUSTER_KIND,
    CLUSTER_REMOTE,
    CLUSTER_UNKNOWN
}
import from jac_scale.microservices.images.build_helpers {
    build_client_bundle,
    _read_client_entry
}
import from jac_scale.microservices.images.distributors {
    MinikubeDistributor,
    K3dDistributor,
    KindDistributor,
    RegistryPushDistributor
}


"""Build user app image, distribute to cluster, return final image tag.
`registry_url` is required for remote clusters, ignored for local."""
def auto_build_and_distribute(
    app_name: str, project_dir: Path, registry_url: str | None = None
) -> str {
    cluster_type = detect_cluster_type();

    if cluster_type == CLUSTER_UNKNOWN {
        raise RuntimeError(
            "Could not detect K8s cluster type. Set up kubectl context:\n"
            "  - Local:  minikube start  (or k3d / kind)\n"
            "  - Remote: aws eks update-kubeconfig / gcloud container clusters get-credentials\n"
            "Then: kubectl cluster-info"
        );
    }

    # Build FE bundle before docker build so the image contains .jac/client/dist.
    client_entry = _read_client_entry();
    if client_entry {
        build_client_bundle(project_dir, client_entry);
    }

    if cluster_type == CLUSTER_MINIKUBE {
        distributor = MinikubeDistributor();
        image_tag = f"{app_name}:dev";
        return distributor.build_and_distribute(project_dir, image_tag);
    }

    if cluster_type == CLUSTER_K3D {
        cluster = k3d_cluster_name(_active_context_name());
        distributor = K3dDistributor(cluster_name=cluster);
        image_tag = f"{app_name}:dev";
        return distributor.build_and_distribute(project_dir, image_tag);
    }

    if cluster_type == CLUSTER_KIND {
        cluster = kind_cluster_name(_active_context_name());
        distributor = KindDistributor(cluster_name=cluster);
        image_tag = f"{app_name}:dev";
        return distributor.build_and_distribute(project_dir, image_tag);
    }

    # CLUSTER_REMOTE
    if not registry_url {
        raise RuntimeError(
            "Remote K8s needs a registry. Add to jac.toml:\n"
            "  [plugins.scale.kubernetes]\n"
            "  image_registry = \"my-registry.example.com/myorg\"\n"
            "Or use a local cluster (minikube/k3d/kind)."
        );
    }
    registry_prefix = registry_url.rstrip("/");
    image_tag = f"{registry_prefix}/{app_name}:dev";
    distributor = RegistryPushDistributor();
    return distributor.build_and_distribute(project_dir, image_tag);
}
