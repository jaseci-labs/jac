import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.config.base_config { BaseConfig }
import from jaclang.scale.models.deployment_result { DeploymentResult }
import from jaclang.scale.models.resource_status { ResourceStatusInfo }
import from jaclang.scale.deploy.database.database_provider { DatabaseProvider }
import from jaclang.scale.observability.logger { Logger }

class DeploymentTarget {
    has config: BaseConfig,
        logger: (Logger | None) = None,
        database_providers: list[DatabaseProvider] = [];

    def deploy(self: DeploymentTarget, app_config: AppConfig) -> DeploymentResult;
    def destroy(self: DeploymentTarget, app_name: str, component: str = "") -> None;
    def get_status(self: DeploymentTarget, app_name: str) -> ResourceStatusInfo;
    def scale(self: DeploymentTarget, app_name: str, replicas: int) -> None;
    def get_service_url(self: DeploymentTarget, app_name: str) -> (str | None);
    def get_full_status(self: DeploymentTarget, app_name: str) -> dict;
}
