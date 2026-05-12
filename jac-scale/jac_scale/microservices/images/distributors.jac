"""ImageDistributor strategies, one per cluster type."""

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


"""Builds directly in minikube's docker daemon via docker-env; no
separate distribute step (image is already on the node)."""
obj MinikubeDistributor(ImageDistributor) {
    def build_and_distribute(project_dir: Path, image_tag: str) -> str {
        (dockerfile, context_dir, build_args) = resolve_dockerfile(project_dir);
        env_overrides = get_minikube_docker_env();
        run_docker_build(context_dir, image_tag, dockerfile, build_args, env_overrides);
        return _retag_with_content_id(image_tag, env_overrides);
    }

    def distribute(image_tag: str) -> str {
        return image_tag;
    }
}


"""docker build locally; retag with content id; `k3d image import` to
load into all k3d cluster nodes."""
obj K3dDistributor(ImageDistributor) {
    has cluster_name: str = "";

    def build_and_distribute(project_dir: Path, image_tag: str) -> str {
        (dockerfile, context_dir, build_args) = resolve_dockerfile(project_dir);
        run_docker_build(context_dir, image_tag, dockerfile, build_args);
        # Retag BEFORE import so the cluster holds the content-addressed tag.
        tagged = _retag_with_content_id(image_tag);
        run_k3d_image_import(tagged, self.cluster_name);
        return tagged;
    }

    def distribute(image_tag: str) -> str {
        run_k3d_image_import(image_tag, self.cluster_name);
        return image_tag;
    }
}


"""docker build locally; retag; `kind load docker-image` to all nodes."""
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


"""docker build locally; retag; docker push to a configured registry.
Used for any remote K8s cluster."""
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
