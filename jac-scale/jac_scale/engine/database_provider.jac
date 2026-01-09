"""Abstract base class for database providers.

This allows different database implementations (K8s MongoDB, AWS DocumentDB, etc.)
to be plugged in without changing deployment logic.
"""
import from typing { Any }
import from .deployment_target { DeploymentTarget }

"""Abstract base class for database providers."""
abstract class DatabaseProvider {
    has target: DeploymentTarget;

    """Deploy the database."""
    def deploy(config: dict[str, Any]) -> dict[str, Any] abs;

    """Get the connection string for the database."""
    def get_connection_string() -> str abs;

    """Check if the database is available."""
    def is_available() -> bool abs;

    """Cleanup/remove the database."""
    def cleanup() -> None abs;
}
