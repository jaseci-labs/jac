"""Factory for creating image registries."""
import from typing { Any }
import from jac_scale.abstractions.image_registry { ImageRegistry }

"""Factory for creating image registry instances."""
class ImageRegistryFactory {
    """Create an image registry based on type.

    Args:
        registry_type: Type of image registry ('dockerhub', 'ecr', 'gcr', etc.)
        config: Configuration dictionary

    Returns:
        ImageRegistry instance

    Raises:
        ValueError: If registry_type is not supported
        NotImplementedError: If registry is not yet implemented
    """
    static def create(registry_type: str, config: dict[str, Any]) -> ImageRegistry {
        if registry_type == 'dockerhub' {
            import from jac_scale.providers.registry.dockerhub { DockerHubRegistry }
            return DockerHubRegistry(config=config);
        } elif registry_type == 'ecr' {
            raise NotImplementedError("AWS ECR registry not yet implemented") ;
        } elif registry_type == 'gcr' {
            raise NotImplementedError("GCP GCR registry not yet implemented") ;
        } else {
            raise ValueError(f"Unsupported image registry type: {registry_type}") ;
        }
    }
}
