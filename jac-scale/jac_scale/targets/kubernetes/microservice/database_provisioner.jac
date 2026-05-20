"""Database provisioner for K8s microservice mode. Provisions MongoDB +
Redis (when enabled in k8s_config) via the parent KubernetesTarget's
_deploy_databases, returns a DeployContext with the connection env vars
and wait-for-DB init containers populated."""

import from jac_scale.abstractions.models.deploy_context { DeployContext }
import from jac_scale._optdeps.kubernetes { client }
import from jac_scale.targets.kubernetes.utils.kubernetes_utils {
    ensure_namespace_exists
}


"""`enabled=False` (default) returns an empty DeployContext without
touching the cluster - the test path."""
obj MicroserviceDatabaseProvisioner {
    has k8s_target: any,
        logger: any = None,
        enabled: bool = False;

    """Returns empty context when disabled or both DBs disabled in config."""
    def provision(app_name: str) -> DeployContext {
        ctx = DeployContext();

        # Reset target's env_list before parent's method appends to it.
        # _deploy_databases accumulates env entries on the target's env_list;
        # without reset, duplicates accrue across re-deploys.
        self.k8s_target.env_list = [];

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

        if self.logger {
            self.logger.info(
                f"Provisioning databases for '{app_name}': "
                f"mongodb={mongo_on}, redis={redis_on}",
                {"namespace": namespace}
            );
        }
        # cluster_env is a monolith-only knob; pass empty string.
        self.k8s_target._deploy_databases(app_name, namespace, apps_v1, core_v1, "");

        # Init containers block pod startup until DB Endpoints are reachable -
        # without this, pods crash-loop with connection-refused on every
        # restart until the DB happens to win the race.
        ctx.env_list = list(self.k8s_target.env_list);
        ctx.init_containers = self.k8s_target._get_database_init_containers(app_name);

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
