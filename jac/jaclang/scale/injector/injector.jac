obj Injector {
    def prepare(app_name: str, namespace: str, project_dir: str);
    def seed(app_name: str, namespace: str);
    def mutate_pod_spec(pod_spec: dict[str, any], base_image: str) -> dict[str, any];
    def extra_manifests(app_name: str, namespace: str) -> list[dict[str, any]];
}
