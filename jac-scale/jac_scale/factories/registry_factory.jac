import from typing { Callable }
import from jac_scale.abstractions.image_registry { ImageRegistry }

"""Type alias for registry factory callables.""" type RegistryFactory = Callable[
    [dict[str, any]],
    ImageRegistry
];


class ImageRegistryFactory {
    static has _registry: dict[str, RegistryFactory] = {};

    static def register(registry_type: str, factory: RegistryFactory) {
        ImageRegistryFactory._registry[registry_type] = factory;
    }

    static def create(registry_type: str, config: dict[str, any]) -> ImageRegistry {
        if registry_type in ImageRegistryFactory._registry {
            factory = ImageRegistryFactory._registry[registry_type];
            return factory(config);
        }
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
