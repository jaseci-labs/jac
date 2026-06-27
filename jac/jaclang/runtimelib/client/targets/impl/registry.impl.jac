impl TargetRegistry.register(target: ClientTarget) -> None {
    self._targets[target.name] = target;
    if target.default {
        self._default_target = target.name;
    }
}

impl TargetRegistry.get(name: str) -> Optional[ClientTarget] {
    return self._targets.get(name);
}

impl TargetRegistry.get_default -> Optional[ClientTarget] {
    if self._default_target {
        return self._targets.get(self._default_target);
    }
    for target in self._targets.values() {
        if target.default {
            return target;
        }
    }
    return None;
}

impl TargetRegistry.get_all -> list[ClientTarget] {
    return list(self._targets.values());
}

impl TargetRegistry.`has(name: str) -> bool {
    return name in self._targets;
}

impl TargetRegistry.set_default(name: str) -> None {
    if name not in self._targets {
        raise ValueError(f"ClientTarget '{name}' is not registered");
    }
    if self._default_target {
        prev_target = self._targets.get(self._default_target);
        if prev_target {
            prev_target.default = False;
        }
    }
    self._default_target = name;
    target = self._targets.get(name);
    if target {
        target.default = True;
    }
}

impl TargetRegistry.clear -> None {
    self._targets.clear();
    self._default_target = None;
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

impl TargetFactory.get_default(project_dir: Path) -> ClientTarget {
    if self._web_target is None {
        import from jaclang.runtimelib.client.targets.web_target { WebTarget }
        self._web_target = WebTarget();
    }
    self._web_target.project_dir = project_dir;
    return self._web_target;
}

impl TargetFactory.get_available_targets -> list[TargetType] {
    import from jaclang.runtimelib.client.targets.registry {
        TargetType,
        get_target_type,
        get_target_registry
    }
    registry = get_target_registry();
    types: list[TargetType] = [];
    for target in registry.get_all() {
        try {
            types.append(get_target_type(target.name));
        } except ValueError { }
    }
    return types;
}

impl TargetFactory.get_available_target_names -> list[str] {
    import from jaclang.runtimelib.client.targets.registry { get_target_registry }
    registry = get_target_registry();
    return [target.name for target in registry.get_all()];
}

impl TargetFactory.clear_cache -> None {
    self._web_target = None;
    self._cached_targets.clear();
}
