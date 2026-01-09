"""Abstract base class for image registries.

This allows different image registries (DockerHub, ECR, GCR, etc.) to be used
without changing deployment logic.
"""
"""Abstract base class for image registries."""
abstract class ImageRegistry {
    """Build a Docker image."""
    abstract def build_image(image_name: str, code_folder: str) -> str;
    
    """Push an image to the registry."""
    abstract def push_image(image_name: str) -> None;
    
    """Get the full image URL for the registry."""
    abstract def get_image_url(image_name: str) -> str;
}

