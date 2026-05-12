"""DeployContext value type for K8s microservice deployment.

Replaces the prior pattern of mutating `self.env_list` and
`self._microservice_init_containers` on the K8s target. DeployContext
is constructed once per deploy by the database provisioner and flows
through manifest builders explicitly. Eliminates the
`getattr(self, "env_list", [])` defensive reads scattered across the
old k8s_target.jac god object.
"""

import from typing { Any }


"""Per-deploy state threaded through manifest builders.

  env_list: env entries (each `{"name": ..., "value": ...}` or with
            `valueFrom.secretKeyRef`). Currently populated by
            MicroserviceDatabaseProvisioner with MONGODB_URI / REDIS_URL
            entries. Builders APPEND service-specific env to this list
            without mutating it (each builder owns its env composition).

  init_containers: wait-for-DB init containers. Pod-spec builders attach
                   these so pods don't crash-loop on database not-ready.
"""
obj DeployContext {
    has env_list: list[dict[str, Any]] = [],
        init_containers: list[dict[str, Any]] = [];
}
