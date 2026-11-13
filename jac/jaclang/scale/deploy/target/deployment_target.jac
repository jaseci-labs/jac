class DeploymentTarget {
    has config: BaseConfig,
        logger: (Logger | None) = None;

    def deploy(self: DeploymentTarget, app_config: AppConfig) -> DeploymentResult abst;
    def destroy(
        self: DeploymentTarget, app_name: str, component: str = ""
    ) -> None abst;

    def get_status(self: DeploymentTarget, app_name: str) -> ResourceStatusInfo abst;
    def scale(self: DeploymentTarget, app_name: str, replicas: int) -> None abst;
    def get_service_url(self: DeploymentTarget, app_name: str) -> (str | None) abst;
    def get_full_status(self: DeploymentTarget, app_name: str) -> dict[str, any] abst;
}
