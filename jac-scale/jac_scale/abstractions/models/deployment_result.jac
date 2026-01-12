"""Deployment result model."""
import from typing { Any }

"""Result of a deployment operation."""
class DeploymentResult {
    has success: bool,
        service_url: (str | None) = None,
        message: (str | None) = None,
        details: dict[str, Any] = {};

    def init(
        self: DeploymentResult,
        success: bool,
        service_url: (str | None) = None,
        message: (str | None) = None,
        details: dict[str, Any] = {}
    ) -> None {
        self.success = success;
        self.service_url = service_url;
        self.message = message;
        self.details = details;
    }

    def is_successful(self: DeploymentResult) -> bool {
        return self.success;
    }
}
