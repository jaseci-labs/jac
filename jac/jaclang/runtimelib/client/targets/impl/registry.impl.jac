impl TargetRegistry.register(target: ClientTarget) -> None {
    self._targets[target.name] = target;
}

impl TargetRegistry.get(name: str) -> Optional[ClientTarget] {
    return self._targets.get(name);
}

impl TargetRegistry.get_all -> list[ClientTarget] {
    return list(self._targets.values());
}

impl TargetFactory.create(name: str, project_dir: Path) -> ClientTarget {
    import from jaclang.runtimelib.client.targets.registry { get_target_registry }
    registry = get_target_registry();
    target_name = name.lower().strip();
    target = registry.get(target_name);
    if target is None {
        available = [t.name for t in registry.get_all()];
        raise ValueError(f"Unknown target: {name}. Available: {', '.join(available)}.");
    }
    target.project_dir = project_dir;
    return target;
}

impl TargetFactory.create_by_type(
    target_type: TargetType, project_dir: Path
) -> ClientTarget {
    import from jaclang.runtimelib.client.targets.registry { TargetType }
    return self.create(target_type.value, project_dir);
}

impl TargetFactory.get_available_target_names -> list[str] {
    import from jaclang.runtimelib.client.targets.registry { get_target_registry }
    registry = get_target_registry();
    return [target.name for target in registry.get_all()];
}
