"""Deployment result model."""
import from typing { Any }

"""Result of a deployment operation."""
class DeploymentResult {
    has success: bool;
    has service_url: (str | None) = None;
    has message: (str | None) = None;
    has details: dict[str, Any] = {};

    def is_successful(self: DeploymentResult) -> bool {
        return self.success;
    }
}

