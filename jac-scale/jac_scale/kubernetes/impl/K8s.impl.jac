"""Deploy jac application to K8s using new factory-based architecture."""

impl deploy_K8s(
    code_folder: str,
    file_name: str = 'none',
    build: bool = False,
    testing: bool = False
) -> None {
    # Use new factory-based architecture
    import from jac_scale.factories.deployment_factory { DeploymentTargetFactory }
    import from jac_scale.factories.registry_factory { ImageRegistryFactory }
    import from jac_scale.factories.utility_factory { UtilityFactory }
    import from jac_scale.abstractions.config.app_config { AppConfig }
    import from jac_scale.config_loader { get_scale_config }
    
    # Get configuration
    scale_config = get_scale_config();
    target_config = scale_config.get_kubernetes_config();
    
    # Create logger
    logger = UtilityFactory.create_logger('standard');
    
    # Create deployment target
    deployment_target = DeploymentTargetFactory.create('kubernetes', target_config, logger);
    
    # Handle image registry if build is requested
    if build {
        image_registry = ImageRegistryFactory.create('dockerhub', target_config);
        deployment_target.image_registry = image_registry;
    }
    
    # Create app config
    app_config = AppConfig(
        code_folder=code_folder,
        file_name=file_name,
        build=build,
        testing=testing
    );
    
    # Deploy
    result = deployment_target.deploy(app_config);
    
    if not result.success {
        raise RuntimeError(result.message or "Deployment failed");
    }
}
