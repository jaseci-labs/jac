impl DeploymentTargetRegistry.register(target_type: str, factory: TargetFactory) {
    DeploymentTargetRegistry._registry[target_type] = factory;
}

impl DeploymentTargetRegistry.known_targets -> list[str] {
    names: set[str] = set(BUILTIN_TARGET_TYPES);
    names.update(DeploymentTargetRegistry._registry.keys());
    return sorted(names);
}
