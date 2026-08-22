import from jaclang.scale.models.deploy_context { DeployContext }
import from jaclang.scale._optdeps.kubernetes { client }
import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    ensure_namespace_exists
}


obj DatabaseProvisioner {
    has k8s_target: any,
        logger: any = None;

    def provision(app_name: str) -> DeployContext {
        ctx = DeployContext();

        self.k8s_target.env_list = [];

        cfg = self.k8s_target.k8s_config;
        if not cfg.database_enabled() {
            if self.logger {
                self.logger.info(
                    "Database wiring skipped (database_mode=none)",
                    {"app_name": app_name}
                );
            }
            return ctx;
        }

        self.k8s_target._load_cluster_config();
        apps_v1 = client.AppsV1Api();
        core_v1 = client.CoreV1Api();
        namespace: str = cfg.namespace;
        ensure_namespace_exists(namespace);

        if self.logger {
            self.logger.info(
                f"Provisioning postgres for '{app_name}'", {"namespace": namespace}
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
