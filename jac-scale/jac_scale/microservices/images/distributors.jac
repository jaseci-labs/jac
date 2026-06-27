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


obj MinikubeDistributor(ImageDistributor) {
    def build_and_distribute(project_dir: Path, image_tag: str) -> str {
        (dockerfile, context_dir, build_args) = resolve_dockerfile(project_dir);
        env_overrides = get_minikube_docker_env();
        run_docker_build(context_dir, image_tag, dockerfile, build_args, env_overrides);
        return _retag_with_content_id(image_tag, env_overrides);
    }
}


obj K3dDistributor(ImageDistributor) {
    has cluster_name: str = "";

    def build_and_distribute(project_dir: Path, image_tag: str) -> str {
        (dockerfile, context_dir, build_args) = resolve_dockerfile(project_dir);
        run_docker_build(context_dir, image_tag, dockerfile, build_args);
        tagged = _retag_with_content_id(image_tag);
        run_k3d_image_import(tagged, self.cluster_name);
        return tagged;
    }
}


obj KindDistributor(ImageDistributor) {
    has cluster_name: str = "";

    def build_and_distribute(project_dir: Path, image_tag: str) -> str {
        (dockerfile, context_dir, build_args) = resolve_dockerfile(project_dir);
        run_docker_build(context_dir, image_tag, dockerfile, build_args);
        tagged = _retag_with_content_id(image_tag);
        run_kind_image_load(tagged, self.cluster_name);
        return tagged;
    }
}


obj RegistryPushDistributor(ImageDistributor) {
    def build_and_distribute(project_dir: Path, image_tag: str) -> str {
        (dockerfile, context_dir, build_args) = resolve_dockerfile(project_dir);
        run_docker_build(context_dir, image_tag, dockerfile, build_args);
        tagged = _retag_with_content_id(image_tag);
        run_docker_push(tagged);
        return tagged;
    }
}
