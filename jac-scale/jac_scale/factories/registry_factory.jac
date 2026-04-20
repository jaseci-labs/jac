"""Factory for creating image registries.

Supports both built-in registries (dockerhub) and plugin-registered registries.
External packages can register custom registries via ImageRegistryFactory.register().
"""
import from typing { Any, Callable }
import from jac_scale.abstractions.image_registry { ImageRegistry }

"""Type alias for registry factory callables.""" type RegistryFactory = Callable[
    [dict[str, Any]],
    ImageRegistry
];

"""Factory for creating image registry instances.

Maintains a registry of factory callables that can be extended by external
plugins. Built-in registries (dockerhub) are always available. Custom
registries are checked first.

Example:
    ImageRegistryFactory.register(
        "ghcr",
        lambda config: GHCRRegistry(config=config)
    )
    registry = ImageRegistryFactory.create("ghcr", config)
"""
class ImageRegistryFactory {
    static has _registry: dict[str, RegistryFactory] = {};

    """Register a custom image registry factory.

    Args:
        registry_type: Unique name for the registry (e.g. 'ghcr')
        factory: Callable that accepts (config: dict) and returns an
                 ImageRegistry instance
    """
    static def register(registry_type: str, factory: RegistryFactory) {
        ImageRegistryFactory._registry[registry_type] = factory;
    }

    """Create an image registry based on type.

    Checks the plugin registry first, then falls back to built-in registries.

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
        # Check plugin registry first
        if registry_type in ImageRegistryFactory._registry {
            factory = ImageRegistryFactory._registry[registry_type];
            return factory(config);
        }
        # Built-in registries
        if registry_type == 'dockerhub' {
            import from jac_scale.providers.registry.dockerhub { DockerHubRegistry }
            return DockerHubRegistry(config=config);
        } elif registry_type == 'ecr' {
            raise NotImplementedError("AWS ECR registry not yet implemented");
        } elif registry_type == 'gcr' {
            raise NotImplementedError("GCP GCR registry not yet implemented");
        } else {
            raise ValueError(f"Unsupported image registry type: {registry_type}");
        }
    }
}
