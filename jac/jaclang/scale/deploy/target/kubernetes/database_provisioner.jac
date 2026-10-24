obj DatabaseProvisioner {
    has k8s_target: any,
        logger: any = None;

    def provision(app_name: str) -> DeployContext;
}
