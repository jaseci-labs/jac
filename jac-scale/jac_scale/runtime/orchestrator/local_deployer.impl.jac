impl LocalDeployer._ensure_pm -> ServiceProcessManager {
    if self.process_manager is None {
        self.process_manager = ServiceProcessManager(
            registry=self.registry, deployer=self
        );
    }
    return self.process_manager;
}

impl LocalDeployer.url_for(service_entry: ServiceEntry) -> str {
    return f"http://127.0.0.1:{service_entry.port}";
}

impl LocalDeployer.deploy_service(name: str) -> bool {
    pm = self._ensure_pm();
    if name not in self.registry.entries {
        logger.error(f"Service '{name}' not found in registry");
        return False;
    }

    if name in pm.processes {
        pm.stop_service(name);
    }
    return pm.start_service(name);
}

impl LocalDeployer.stop_service(name: str) -> bool {
    pm = self._ensure_pm();
    return pm.stop_service(name);
}

impl LocalDeployer.restart_service(name: str) -> bool {
    pm = self._ensure_pm();
    return pm.restart_service(name);
}

impl LocalDeployer.scale_service(name: str, replicas: int) -> bool {
    if replicas != 1 {
        logger.warning(
            f"Local deployer only supports 1 replica per service (requested {replicas})"
        );
    }

    if replicas == 0 {
        return self.stop_service(name);
    }

    pm = self._ensure_pm();
    if name not in pm.processes {
        return self.deploy_service(name);
    }
    return True;
}

impl LocalDeployer.status -> dict[str, dict] {
    pm = self._ensure_pm();

    pm.check_all_health();
    result: dict[str, dict] = {};
    for (name, svc_entry) in self.registry.entries.items() {
        is_running = name in pm.processes;
        proc = pm.processes.get(name);
        result[name] = {
            "name": svc_entry.name,
            "file": svc_entry.file,
            "prefix": svc_entry.prefix,
            "port": svc_entry.port,
            "pid": svc_entry.pid,
            "status": svc_entry.status.value,
            "running": is_running,
            "url": svc_entry.url,
            "target": "local"
        };
    }
    return result;
}

impl LocalDeployer.get_logs(name: str, lines: int = 50) -> str {
    import from pathlib { Path }

    if name not in self.registry.entries {
        return f"Service '{name}' not found";
    }

    log_file = Path(".jac/logs") / f"{name}.log";
    if not log_file.exists() {
        return f"No log file for '{name}' (service may not have started yet)";
    }

    all_lines = log_file.read_text().splitlines();
    tail = all_lines[-lines:] if len(all_lines) > lines else all_lines;
    return "\n".join(tail);
}

impl LocalDeployer.destroy_all -> bool {
    pm = self._ensure_pm();
    pm.stop_all();
    logger.info("All services stopped");
    return True;
}

impl LocalDeployer.deploy_all -> bool {
    pm = self._ensure_pm();
    pm.start_all();
    return True;
}
