import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.abstractions.config.base_config { BaseConfig }
import from jac_scale.abstractions.models.deployment_result { DeploymentResult }
import from jac_scale.abstractions.models.resource_status { ResourceStatusInfo }
import from jac_scale.abstractions.database_provider { DatabaseProvider }
import from jac_scale.abstractions.image_registry { ImageRegistry }
import from jac_scale.abstractions.logger { Logger }

class DeploymentTarget {
    has config: BaseConfig,
        logger: (Logger | None) = None,
        database_providers: list[DatabaseProvider] = [],
        image_registry: (ImageRegistry | None) = None;

    def deploy(self: DeploymentTarget, app_config: AppConfig) -> DeploymentResult;
    def destroy(self: DeploymentTarget, app_name: str, component: str = "") -> None;
    def get_status(self: DeploymentTarget, app_name: str) -> ResourceStatusInfo;
    def scale(self: DeploymentTarget, app_name: str, replicas: int) -> None;
    def get_service_url(self: DeploymentTarget, app_name: str) -> (str | None);
    def get_full_status(self: DeploymentTarget, app_name: str) -> dict;
}
