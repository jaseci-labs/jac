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
        raise ValueError(f"ClientTarget '{name}' is not registered") ;
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

"""Create a target by name string with lazy loading for non-web targets."""
impl TargetFactory.create(name: str, project_dir: Path) -> ClientTarget {
    # Import inside function to avoid circular import
    import from jac_client.plugin.src.targets.registry { get_target_type }
    target_type = get_target_type(name);
    return self.create_by_type(target_type, project_dir);
}

"""Create a target by TargetType enum (preferred method)."""
impl TargetFactory.create_by_type(
    target_type: TargetType, project_dir: Path
) -> ClientTarget {
    # Import inside function to avoid circular import
    import from jac_client.plugin.src.targets.registry { TargetType }
    # Fast path: web target (default, always loaded)
    if target_type == TargetType.WEB {
        return self.get_default(project_dir);
    }
    cache_key = f"{target_type.value}:{project_dir}";
    if cache_key in self._cached_targets {
        return self._cached_targets[cache_key];
    }
    target: ClientTarget;
    if target_type == TargetType.DESKTOP {
        import from jac_client.plugin.src.targets.desktop_target { DesktopTarget }
        target = DesktopTarget();
        target.project_dir = project_dir;
    } elif target_type == TargetType.PWA {
        import from jac_client.plugin.src.targets.pwa_target { PWATarget }
        target = PWATarget();
        target.project_dir = project_dir;
    } else {
        # This shouldn't happen if TargetType enum is exhaustive
        raise ValueError(f"Unhandled target type: {target_type}") ;
    }
    self._cached_targets[cache_key] = target;
    return target;
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

"""Get list of available target types."""
impl TargetFactory.get_available_targets -> list[TargetType] {
    # Import inside function to avoid circular import
    import from jac_client.plugin.src.targets.registry { TargetType }
    return [TargetType.WEB, TargetType.DESKTOP, TargetType.PWA];
}

"""Get list of available target names as strings."""
impl TargetFactory.get_available_target_names -> list[str] {
    return [t.value for t in self.get_available_targets()];
}

"""Clear cached targets (for testing)."""
impl TargetFactory.clear_cache -> None {
    self._web_target = None;
    self._cached_targets.clear();
}
