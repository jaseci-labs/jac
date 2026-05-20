"""DeployContext: per-deploy state threaded through manifest builders.
Replaces the prior `self.env_list` + `self._microservice_init_containers`
mutation pattern on K8s targets."""

obj DeployContext {
    has env_list: list[dict[str, any]] = [],
        init_containers: list[dict[str, any]] = [];
}
