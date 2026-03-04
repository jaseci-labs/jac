"""Deployment result model."""
import from typing { Any }

"""Result of a deployment operation."""
obj DeploymentResult {
    has success: bool,
        service_url: (str | None) = None,
        message: (str | None) = None,
        details: dict[str, Any] = {};

    def is_successful -> bool {
        return self.success;
    }
}
