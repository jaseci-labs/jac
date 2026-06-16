"""DeployContext: per-deploy state threaded through manifest builders.
Replaces the prior `self.env_list` + `self._microservice_init_containers`
mutation pattern on K8s targets."""

obj DeployContext {
    has env_list: list[dict[str, any]] = [],
        init_containers: list[dict[str, any]] = [],
        # Code-injection mode (no per-app image build): siblings boot a base
        # image, an init container fetches the code, and a shared volume holds
        # it. These let a target inject that without the manifest builder
        # knowing how the code arrives.
        volumes: list[dict[str, any]] = [],
        volume_mounts: list[dict[str, any]] = [],
        image_override: str = "",
        entrypoint_command: str = "";
}
