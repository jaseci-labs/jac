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
impl TargetRegistry.has(name: str) -> bool {
    return name in self._targets;
}

"""Set the default target."""
impl TargetRegistry.set_default(name: str) -> None {
    if name not in self._targets {
        raise ValueError(f"ClientTarget '{name}' is not registered") ;
    }
    # Unset previous default
    if self._default_target {
        prev_target = self._targets.get(self._default_target);
        if prev_target {
            prev_target.default = False;
        }
    }
    # Set new default
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
