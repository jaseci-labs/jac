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
    abstract def deploy(config: dict[str, Any]) -> dict[str, Any];
    
    """Get the connection string for the database."""
    abstract def get_connection_string() -> str;
    
    """Check if the database is available."""
    abstract def is_available() -> bool;
    
    """Cleanup/remove the database."""
    abstract def cleanup() -> None;
}

