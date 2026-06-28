obj Injector {
    def prepare(app_name: str, namespace: str, project_dir: str) {
        raise NotImplementedError("prepare() must be implemented by an Injector");
    }

    def seed(app_name: str, namespace: str) {
        return;
    }

    def mutate_pod_spec(pod_spec: dict[str, any], base_image: str) -> dict[str, any] {
        raise NotImplementedError(
            "mutate_pod_spec() must be implemented by an Injector"
        );
    }

    def extra_manifests(app_name: str, namespace: str) -> list[dict[str, any]] {
        raise NotImplementedError(
            "extra_manifests() must be implemented by an Injector"
        );
    }
}
