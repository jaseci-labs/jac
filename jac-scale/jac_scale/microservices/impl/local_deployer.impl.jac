"""Implementation of LocalDeployer - subprocess-based service management."""

"""Initialize the process manager if needed.

Injects `self` into the ServiceProcessManager so its URL construction
(both for `entry.url` and for peer `JAC_SV_{NAME}_URL` env vars) routes
through `LocalDeployer.url_for`, matching the interface K8sDeployer
will override with DNS names.
"""
impl LocalDeployer._ensure_pm -> ServiceProcessManager {
    if self.process_manager is None {
        self.process_manager = ServiceProcessManager(
            registry=self.registry, deployer=self
        );
    }
    return self.process_manager;
}

"""Loopback URL for a service running as a local subprocess."""
impl LocalDeployer.url_for(service_entry: ServiceEntry) -> str {
    return f"http://127.0.0.1:{service_entry.port}";
}

"""Deploy a single service as a subprocess."""
impl LocalDeployer.deploy_service(name: str) -> bool {
    pm = self._ensure_pm();
    if name not in self.registry.entries {
        logger.error(f"Service '{name}' not found in registry");
        return False;
    }
    # Stop if already running
    if name in pm.processes {
        pm.stop_service(name);
    }
    return pm.start_service(name);
}

"""Stop a running service subprocess."""
impl LocalDeployer.stop_service(name: str) -> bool {
    pm = self._ensure_pm();
    return pm.stop_service(name);
}

"""Restart a service (stop + start)."""
impl LocalDeployer.restart_service(name: str) -> bool {
    pm = self._ensure_pm();
    return pm.restart_service(name);
}

"""Scale is not supported locally - always 1 replica."""
impl LocalDeployer.scale_service(name: str, replicas: int) -> bool {
    if replicas != 1 {
        logger.warning(
            f"Local deployer only supports 1 replica per service (requested {replicas})"
        );
    }
    # If replicas is 0, stop the service
    if replicas == 0 {
        return self.stop_service(name);
    }
    # If not running, deploy it
    pm = self._ensure_pm();
    if name not in pm.processes {
        return self.deploy_service(name);
    }
    return True;
}

"""Get status of all services."""
impl LocalDeployer.status -> dict[str, dict] {
    pm = self._ensure_pm();
    # Update health status
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

"""Get logs for a service - reads from .jac/logs/{name}.log."""
impl LocalDeployer.get_logs(name: str, lines: int = 50) -> str {
    import from pathlib { Path }

    if name not in self.registry.entries {
        return f"Service '{name}' not found";
    }

    log_file = Path(".jac/logs") / f"{name}.log";
    if not log_file.exists() {
        return f"No log file for '{name}' (service may not have started yet)";
    }

    # Read last N lines
    all_lines = log_file.read_text().splitlines();
    tail = all_lines[-lines:] if len(all_lines) > lines else all_lines;
    return "\n".join(tail);
}

"""Stop all services."""
impl LocalDeployer.destroy_all -> bool {
    pm = self._ensure_pm();
    pm.stop_all();
    logger.info("All services stopped");
    return True;
}

"""Deploy all registered services."""
impl LocalDeployer.deploy_all -> bool {
    pm = self._ensure_pm();
    pm.start_all();
    return True;
}
