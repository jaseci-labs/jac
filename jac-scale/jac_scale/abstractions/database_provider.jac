"""Base database provider abstraction for jac_scale.

All database provider implementations should inherit from this class.
"""
import from typing { Any }

"""Base class for all database provider implementations."""
class DatabaseProvider {
    """Deploy the database service.

    Args:
        config: Database-specific configuration

    Returns:
        Dictionary with deployment information (e.g., service name, connection details)
    """
    def deploy(self: DatabaseProvider, config: dict[str, Any]) -> dict[str, Any];

    """Get the connection string for the database.

    Returns:
        Connection string/URI for the database
    """
    def get_connection_string(self: DatabaseProvider) -> str;

    """Check if the database is available/ready.

    Returns:
        True if database is available, False otherwise
    """
    def is_available(self: DatabaseProvider) -> bool;

    """Clean up database resources.

    This should remove all resources created by deploy().
    """
    def cleanup(self: DatabaseProvider) -> None;
}
