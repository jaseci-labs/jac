"""Database provisioner for K8s microservice mode.

Extracted from KubernetesMicroserviceTarget._provision_databases.
Provisions MongoDB + Redis (when enabled in k8s_config), returning a
DeployContext with the connection env vars and wait-for-DB init
containers populated.

Delegates the actual K8s API work to the KubernetesTarget parent class
(whose _deploy_databases method handles the StatefulSet machinery).
This class owns the gating, the result collection, and the lifecycle
around the parent's call.
"""

import from typing { Any }
import from jac_scale.abstractions.models.deploy_context { DeployContext }
import from jac_scale._optdeps.kubernetes { client }
import from jac_scale.targets.kubernetes.utils.kubernetes_utils {
    ensure_namespace_exists
}


"""Provisions DB StatefulSets, collects connection env + init containers
into a DeployContext for downstream manifest builders. Stateless
beyond the target reference held in the constructor.

`enabled=False` (the default) returns an empty DeployContext without
touching the cluster. The target sets `enabled=True` on the production
`jac start --scale` path so unit tests calling deploy() directly skip
cluster-touching work."""
obj MicroserviceDatabaseProvisioner {
    has k8s_target: Any,
        logger: Any = None,
        enabled: bool = False;

    """Provision DBs, return populated DeployContext.

    Returns an empty context when:
    - `enabled` is False (test / dry-run path), OR
    - both `mongodb_enabled` and `redis_enabled` are false in k8s_config.
    """
    def provision(app_name: str) -> DeployContext {
        ctx = DeployContext();

        # Reset target's env_list before parent's method appends to it.
        # The parent's _deploy_databases accumulates env entries on the
        # target's env_list; if re-deploy without reset, duplicates accrue.
        self.k8s_target.env_list = [];

        # Skip when disabled (unit tests that exercise deploy() directly
        # don't set enabled=True and thus skip cluster-touching work).
        if not self.enabled {
            return ctx;
        }

        cfg = self.k8s_target.k8s_config;
        mongo_on = cfg.mongodb_enabled;
        redis_on = cfg.redis_enabled;
        if not (mongo_on or redis_on) {
            if self.logger {
                self.logger.info(
                    "Database provisioning skipped (mongodb_enabled=false, "
                    "redis_enabled=false)",
                    {"app_name": app_name}
                );
            }
            return ctx;
        }

        self.k8s_target._load_kube_config();
        apps_v1 = client.AppsV1Api();
        core_v1 = client.CoreV1Api();
        namespace: str = cfg.namespace;
        ensure_namespace_exists(namespace);

        # Apply DB StatefulSets + Services + Secrets + ServiceAccounts via
        # the parent KubernetesTarget._deploy_databases. cluster_env is a
        # monolith-only knob; pass empty string.
        if self.logger {
            self.logger.info(
                f"Provisioning databases for '{app_name}': "
                f"mongodb={mongo_on}, redis={redis_on}",
                {"namespace": namespace}
            );
        }
        self.k8s_target._deploy_databases(app_name, namespace, apps_v1, core_v1, "");

        # Collect into context. Pod-spec builders will attach init
        # containers so pods block startup until Mongo / Redis Endpoints
        # are reachable - without this, pods crash-loop with
        # connection-refused on every restart until the DB happens to win
        # the race.
        ctx.env_list = list(self.k8s_target.env_list);
        ctx.init_containers = self.k8s_target._get_database_init_containers(
            app_name
        );

        if self.logger {
            self.logger.info(
                f"Database env injected ({len(ctx.env_list)} vars), "
                f"init containers ({len(ctx.init_containers)})",
                {"app_name": app_name}
            );
        }
        return ctx;
    }
}
