import from jac_scale.models.deploy_context { DeployContext }
import from jac_scale._optdeps.kubernetes { client }
import from jac_scale.deploy.target.kubernetes.utils.kubernetes_utils {
    ensure_namespace_exists
}


obj MicroserviceDatabaseProvisioner {
    has k8s_target: any,
        logger: any = None,
        enabled: bool = False;

    def provision(app_name: str) -> DeployContext {
        ctx = DeployContext();

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
        self.k8s_target._deploy_databases(app_name, namespace, apps_v1, core_v1);

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
