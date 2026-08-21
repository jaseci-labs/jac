impl HostRegistry.register(host: Host) -> None {
    self._hosts[host.name] = host;
}

impl HostRegistry.get(name: str) -> Optional[Host] {
    return self._hosts.get(name);
}

impl HostRegistry.get_all -> list[Host] {
    return list(self._hosts.values());
}

impl HostRegistry.clear -> None {
    self._hosts = {};
}

impl HostFactory.create(name: str, project_dir: Path) -> Host {
    import from jaclang.jac0core.host { resolve_registry_name }
    import from jaclang.runtimelib.client.targets.registry { get_host_registry }
    registry = get_host_registry();
    available = [h.name for h in registry.get_all()];
    key = resolve_registry_name(name, available);
    host = registry.get(key) if key is not None else None;
    if host is None {
        raise ValueError(f"Unknown host: {name}. Available: {', '.join(available)}.");
    }
    host.project_dir = project_dir;
    return host;
}

impl HostFactory.get_available_host_names -> list[str] {
    import from jaclang.runtimelib.client.targets.registry { get_host_registry }
    registry = get_host_registry();
    return [host.name for host in registry.get_all()];
}

impl HostFactory.get_available_target_names -> list[str] {
    return self.get_available_host_names();
}
