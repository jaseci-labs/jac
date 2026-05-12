"""Concrete ImageDistributor strategies, one per cluster type.

Replaces the if/elif cluster-type branching that lived in
auto_build_and_distribute. Each cluster type owns a single class:

  MinikubeDistributor       -> build in minikube's docker daemon via docker-env
  K3dDistributor            -> docker build locally, then `k3d image import`
  KindDistributor           -> docker build locally, then `kind load docker-image`
  RegistryPushDistributor   -> docker build locally, then docker push to registry

Adding a new cluster type (EKS, GKE, AKS) is a new subclass, not an
edit to a branching function.
"""

import from pathlib { Path }
import from jac_scale.abstractions.image_distributor { ImageDistributor }
import from jac_scale.microservices.images.build_helpers {
    resolve_dockerfile,
    run_docker_build,
    run_docker_push,
    run_k3d_image_import,
    run_kind_image_load,
    _retag_with_content_id
}
import from jac_scale.microservices.images.cluster_detect { get_minikube_docker_env }


"""Builds directly in minikube's docker daemon by sourcing docker-env;
no separate distribute step (image is already on the node)."""
obj MinikubeDistributor(ImageDistributor) {
    def build_and_distribute(project_dir: Path, image_tag: str) -> str {
        (dockerfile, context_dir, build_args) = resolve_dockerfile(project_dir);
        env_overrides = get_minikube_docker_env();
        run_docker_build(
            context_dir, image_tag, dockerfile, build_args, env_overrides
        );
        return _retag_with_content_id(image_tag, env_overrides);
    }

    def distribute(image_tag: str) -> str {
        # Minikube distribution happens at build time via docker-env.
        return image_tag;
    }
}


"""Builds locally with docker, retags with content id, then `k3d image
import` loads the image into all k3d cluster nodes."""
obj K3dDistributor(ImageDistributor) {
    has cluster_name: str = "";

    def build_and_distribute(project_dir: Path, image_tag: str) -> str {
        (dockerfile, context_dir, build_args) = resolve_dockerfile(project_dir);
        run_docker_build(context_dir, image_tag, dockerfile, build_args);
        # Retag BEFORE import so the cluster holds the new content-addressed tag.
        tagged = _retag_with_content_id(image_tag);
        run_k3d_image_import(tagged, self.cluster_name);
        return tagged;
    }

    def distribute(image_tag: str) -> str {
        run_k3d_image_import(image_tag, self.cluster_name);
        return image_tag;
    }
}


"""Builds locally with docker, retags with content id, then `kind load
docker-image` loads the image into all kind cluster nodes."""
obj KindDistributor(ImageDistributor) {
    has cluster_name: str = "";

    def build_and_distribute(project_dir: Path, image_tag: str) -> str {
        (dockerfile, context_dir, build_args) = resolve_dockerfile(project_dir);
        run_docker_build(context_dir, image_tag, dockerfile, build_args);
        tagged = _retag_with_content_id(image_tag);
        run_kind_image_load(tagged, self.cluster_name);
        return tagged;
    }

    def distribute(image_tag: str) -> str {
        run_kind_image_load(image_tag, self.cluster_name);
        return image_tag;
    }
}


"""Builds locally with docker, retags with content id, then `docker push`
to the configured registry. Used for any remote K8s cluster."""
obj RegistryPushDistributor(ImageDistributor) {
    def build_and_distribute(project_dir: Path, image_tag: str) -> str {
        (dockerfile, context_dir, build_args) = resolve_dockerfile(project_dir);
        run_docker_build(context_dir, image_tag, dockerfile, build_args);
        tagged = _retag_with_content_id(image_tag);
        run_docker_push(tagged);
        return tagged;
    }

    def distribute(image_tag: str) -> str {
        run_docker_push(image_tag);
        return image_tag;
    }
}
