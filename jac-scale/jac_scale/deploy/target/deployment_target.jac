"""Base deployment target abstraction for jac_scale.

All deployment target implementations should inherit from this class.
"""
import from jac_scale.config.app_config { AppConfig }
import from jac_scale.config.base_config { BaseConfig }
import from jac_scale.models.deployment_result { DeploymentResult }
import from jac_scale.models.resource_status { ResourceStatusInfo }
import from jac_scale.deploy.database.database_provider { DatabaseProvider }
import from jac_scale.observability.logger { Logger }

"""Base class for all deployment target implementations."""
class DeploymentTarget {
    has config: BaseConfig,
        logger: (Logger | None) = None,
        database_providers: list[DatabaseProvider] = [];

    """Deploy an application.

    Args:
        app_config: Application configuration

    Returns:
        Deployment result with success status and service URL
    """
    def deploy(self: DeploymentTarget, app_config: AppConfig) -> DeploymentResult;

    """Destroy/remove a deployed application.

    Args:
        app_name: Name of the application to destroy
    """
    def destroy(self: DeploymentTarget, app_name: str, component: str = "") -> None;

    """Get the status of a deployed application.

    Args:
        app_name: Name of the application

    Returns:
        Resource status information
    """
    def get_status(self: DeploymentTarget, app_name: str) -> ResourceStatusInfo;

    """Scale an application to a specific number of replicas.

    Args:
        app_name: Name of the application
        replicas: Number of replicas desired
    """
    def scale(self: DeploymentTarget, app_name: str, replicas: int) -> None;

    """Get the service URL for a deployed application.

    Args:
        app_name: Name of the application

    Returns:
        Service URL or None if not available
    """
    def get_service_url(self: DeploymentTarget, app_name: str) -> (str | None);

    """Get comprehensive status of all deployed components.

    Args:
        app_name: Name of the application

    Returns:
        Dictionary with 'app_name', 'namespace', 'components' list, and 'urls' dict.
        Each component has 'name', 'status', 'ready', 'total' keys.
    """
    def get_full_status(self: DeploymentTarget, app_name: str) -> dict;
}
