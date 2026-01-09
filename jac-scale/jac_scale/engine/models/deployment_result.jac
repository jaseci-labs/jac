"""Deployment result model."""
"""Result of a deployment operation."""
class DeploymentResult {
    has success: bool;
    has service_url: (str | None) = None;
    has deployment_id: str = '';
    has errors: list[str] = [];
    has warnings: list[str] = [];
}

