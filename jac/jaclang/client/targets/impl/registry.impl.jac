impl TargetRegistry.register(target: ClientTarget) -> None {
    self._targets[target.name] = target;
}

impl TargetRegistry.get(name: str) -> Optional[ClientTarget] {
    return self._targets.get(name);
}

impl TargetRegistry.get_all -> list[ClientTarget] {
    return list(self._targets.values());
}

impl TargetRegistry.clear -> None {
    self._targets = {};
}

impl target_for_kind(kind: str, project_dir: Path) -> ClientTarget {
    import from jaclang.client.targets.registry { get_target_registry }
    target_name = KIND_TARGET.get(kind, "");
    if not target_name {
        raise ValueError(
            f"Kind '{kind}' has no client; client kinds are "
            f"{', '.join(KIND_TARGET.keys())}."
        );
    }
    target = get_target_registry().get(target_name);
    if target is None {
        raise ValueError(f"No client target registered for kind '{kind}'.");
    }
    target.project_dir = project_dir;
    return target;
}

impl target_for_app(app: AppConfig, project_dir: Path) -> ClientTarget {
    import from jaclang.project.config { get_config }
    cfg = get_config();
    kind = cfg.resolved_kind(app) if cfg is not None else app.kind;
    return target_for_kind(kind, project_dir);
}
