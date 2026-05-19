"""DeployContext: per-deploy state threaded through manifest builders.
Replaces the prior `self.env_list` + `self._microservice_init_containers`
mutation pattern on K8s targets."""

import from typing { Any }


obj DeployContext {
    has env_list: list[dict[str, Any]] = [],
        init_containers: list[dict[str, Any]] = [];
}
