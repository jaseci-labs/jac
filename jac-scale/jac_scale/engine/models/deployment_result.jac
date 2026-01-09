"""Deployment result model."""
"""Result of a deployment operation."""
class DeploymentResult {
    has success: bool,
        service_url: (str | None) = None,
        deployment_id: str = '',
        errors: list[str] = [],
        warnings: list[str] = [];
}
