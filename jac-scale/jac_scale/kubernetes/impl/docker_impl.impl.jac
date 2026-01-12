"""Build and push docker image using new factory-based architecture."""

impl build_and_push_docker(code_folder: str) -> None {
    # Use new factory-based architecture
    import from jac_scale.factories.registry_factory { ImageRegistryFactory }
    import from jac_scale.config_loader { get_scale_config }
    # Get configuration
    scale_config = get_scale_config();
    registry_config = scale_config.get_kubernetes_config();
    # Create image registry
    image_registry = ImageRegistryFactory.create('dockerhub', registry_config);
    # Build and push
    image_registry.build_and_push(code_folder);
}
