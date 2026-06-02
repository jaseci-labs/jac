"""Implementation of target registry."""

"""Register a new build target."""
impl TargetRegistry.register(target: ClientTarget) -> None {
    self._targets[target.name] = target;
    if target.default {
        self._default_target = target.name;
    }
}

"""Get a target by name."""
impl TargetRegistry.get(name: str) -> Optional[ClientTarget] {
    return self._targets.get(name);
}

"""Get the default target."""
impl TargetRegistry.get_default -> Optional[ClientTarget] {
    if self._default_target {
        return self._targets.get(self._default_target);
    }
    # Find first target marked as default
    for target in self._targets.values() {
        if target.default {
            return target;
        }
    }
    return None;
}

"""Get all registered targets."""
impl TargetRegistry.get_all -> list[ClientTarget] {
    return list(self._targets.values());
}

"""Check if a target is registered."""
impl TargetRegistry.`has(name: str) -> bool {
    return name in self._targets;
}

"""Set the default target."""
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

"""Clear all registered targets (for testing)."""
impl TargetRegistry.clear -> None {
    self._targets.clear();
    self._default_target = None;
}

"""Create a target by name string from the plugin registry."""
impl TargetFactory.create(name: str, project_dir: Path) -> ClientTarget {
    import from jac_client.plugin.src.targets.registry { get_target_registry }
    registry = get_target_registry();
    target_name = name.lower().strip();
    target = registry.get(target_name);
    if target is None {
        available = [t.name for t in registry.get_all()];
        hint = "";
        if target_name == "desktop" {
            hint = " Install jac-desktop: pip install jac-desktop";
        }
        raise ValueError(
            f"Unknown target: {name}. Available: {', '.join(available)}.{hint}"
        );
    }
    target.project_dir = project_dir;
    return target;
}

"""Create a target by TargetType enum (preferred method)."""
impl TargetFactory.create_by_type(
    target_type: TargetType, project_dir: Path
) -> ClientTarget {
    import from jac_client.plugin.src.targets.registry { TargetType }
    return self.create(target_type.value, project_dir);
}

"""Get the default (web) target, cached for fast access."""
impl TargetFactory.get_default(project_dir: Path) -> ClientTarget {
    if self._web_target is None {
        import from jac_client.plugin.src.targets.web_target { WebTarget }
        self._web_target = WebTarget();
    }
    self._web_target.project_dir = project_dir;
    return self._web_target;
}

"""Get list of available target types from the registry."""
impl TargetFactory.get_available_targets -> list[TargetType] {
    import from jac_client.plugin.src.targets.registry {
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

"""Get list of available target names as strings."""
impl TargetFactory.get_available_target_names -> list[str] {
    import from jac_client.plugin.src.targets.registry { get_target_registry }
    registry = get_target_registry();
    return [target.name for target in registry.get_all()];
}

"""Clear cached targets (for testing)."""
impl TargetFactory.clear_cache -> None {
    self._web_target = None;
    self._cached_targets.clear();
}
