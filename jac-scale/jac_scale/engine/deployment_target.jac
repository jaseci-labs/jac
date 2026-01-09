"""Abstract base class for deployment targets.

This is the core interface that all deployment targets (K8s, EKS, GKE, etc.) must implement.
Future targets can extend this class to add new deployment capabilities.
"""
import from typing { Any }

"""Abstract base class for all deployment targets."""
abstract class DeploymentTarget {
    """Deploy an application to the target platform."""
    abstract def deploy(app_config: Any) -> Any;
    
    """Destroy/cleanup an application deployment."""
    abstract def destroy(app_name: str) -> None;
    
    """Get the service URL for a deployed application."""
    abstract def get_service_url(app_name: str) -> str;
    
    """Check the status of a deployment."""
    abstract def check_status(app_name: str) -> dict[str, Any];
}
