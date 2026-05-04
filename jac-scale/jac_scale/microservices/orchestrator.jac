"""Orchestrates the microservice mode lifecycle: registry -> processes -> gateway."""

import time;
import atexit;
import logging;
import from typing { Any }
import from jaclang.cli.console { console }
import from jac_scale.microservices.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}
import from jac_scale.microservices.process_manager { ServiceProcessManager }
import from jac_scale.microservices.local_deployer { LocalDeployer }
import from jac_scale.microservices.gateway { MicroserviceGateway }

glob logger = logging.getLogger(__name__);

"""Build a ServiceRegistry from a `routes` map: {module_name: prefix}.

Entries have `file = {module_name}.jac` by convention - the same file the
`sv import` machinery resolves on cold start.
"""
def build_registry(ms_config: dict[str, Any]) -> ServiceRegistry {
    registry = ServiceRegistry();

    routes = ms_config.get("routes", {});
    for (route_name, prefix) in routes.items() {
        name_str: str = str(route_name);
        svc_entry = ServiceEntry(
            name=name_str, file=f"{name_str}.jac", prefix=str(prefix), port=0
        );
        registry.register(svc_entry);
        logger.info(f"Registered route: {name_str} -> {svc_entry.prefix}");
    }

    return registry;
}

"""
Bootstrap and run microservice mode locally.

1. Reads service config from TOML
2. Builds the ServiceRegistry
3. Starts all service subprocesses
4. Waits for health checks
5. Starts the gateway (blocking)
6. On shutdown: stops all services
"""
def start_microservice_mode(ms_config: dict[str, Any]) -> None {
    if not ms_config.get("routes", {}) {
        logger.error("No routes declared in [plugins.scale.microservices.routes]");
        logger.error("Run `jac setup microservice` to configure.");
        return;
    }

    # 0. Build client if configured
    client_config = ms_config.get("client", {});
    client_entry: str = str(dict(client_config).get("entry", ""))
        if client_config
        else "";
    client_dist: str = str(dict(client_config).get("dist_dir", ".jac/client/dist"))
        if client_config
        else ".jac/client/dist";

    if client_entry {
        import subprocess;
        import from pathlib { Path }
        dist_path = Path(client_dist);
        index_file = dist_path / "index.html";

        if not index_file.exists() {
            console.print(f"  Building client from {client_entry}...");
            try {
                build_result = subprocess.run(
                    ["jac", "build", client_entry], timeout=120
                );
                if build_result.returncode == 0 {
                    console.print("  Client build complete");
                } else {
                    logger.warning(
                        "Client build failed - gateway will start without client UI"
                    );
                }
            } except subprocess.TimeoutExpired {
                logger.warning("Client build timed out");
            } except FileNotFoundError {
                logger.warning("jac build command not found");
            }
        } else {
            logger.info("Client already built, skipping build");
        }
    }

    # 1. Build registry from routes (v2) + services (v1 legacy)
    registry = build_registry(ms_config);
    logger.info(f"Registry: {len(registry.entries)} services");

    # 2. Start services via deployer
    deployer = LocalDeployer(registry=registry);
    deployer.deploy_all();
    pm = deployer._ensure_pm();

    # Register cleanup on exit
    atexit.register(deployer.destroy_all);

    # 3. Wait for services to become healthy
    logger.info("Waiting for services to start...");
    max_wait: int = 30;
    start_time: float = time.time();
    all_healthy = False;

    while time.time() - start_time < max_wait {
        results = pm.check_all_health();
        healthy_count: int = 0;
        for v in results.values() {
            if v {
                healthy_count += 1;
            }
        }
        if healthy_count == len(results) {
            all_healthy = True;
            logger.info(f"All {len(results)} services healthy!");
            break;
        }
        logger.info(f"  {healthy_count}/{len(results)} services healthy, waiting...");
        time.sleep(2);
    }

    if not all_healthy {
        for (name, entry) in registry.entries.items() {
            if entry.status != ServiceStatus.HEALTHY {
                logger.warning(f"  {name}: NOT HEALTHY");
            }
        }
        logger.warning("Proceeding with unhealthy services...");
    }

    # 4. Print startup banner
    gateway_port: int = int(ms_config.get("gateway_port", 8000));
    gateway_host: str = str(ms_config.get("gateway_host", "0.0.0.0"));
    client_config = ms_config.get("client", {});
    client_dist: str = str(dict(client_config).get("dist_dir", ".jac/client/dist"))
        if client_config
        else ".jac/client/dist";

    console.print();
    console.print("[bold cyan]  Jac Microservice Mode[/bold cyan]");
    console.print(f"  [bold]Gateway:[/bold] http://{gateway_host}:{gateway_port}");
    console.print();
    console.print("  [bold]Services[/bold]");
    console.print(f"  [dim]{'─' * 48}[/dim]");
    for (name, entry) in registry.entries.items() {
        if entry.status == ServiceStatus.HEALTHY {
            icon = "[green]●[/green]";
        } else {
            icon = "[yellow]○[/yellow]";
        }
        console.print(f"  {icon} {name:18s} {entry.prefix:20s} -> {entry.url}");
    }

    if client_config and dict(client_config).get("entry") {
        console.print();
        console.print(f"  [bold]Client:[/bold] {dict(client_config)['entry']}");
        console.print(f"  [bold]Static:[/bold] {client_dist}");
    }

    # Read static_mounts (used in step 5 below) so we can show them in the
    # banner. We re-read here for display only; the canonical list is built
    # again in step 5 to keep that block self-contained.
    _banner_mounts: list[Any] = [];
    if client_config {
        _raw = dict(client_config).get("static_mounts", []);
        if isinstance(_raw, list) {
            _banner_mounts = list(_raw);
        }
    }
    if _banner_mounts {
        console.print();
        console.print("  [bold]Static mounts[/bold]");
        console.print(f"  [dim]{'─' * 48}[/dim]");
        for _m in _banner_mounts {
            _md = dict(_m) if isinstance(_m, dict) else {};
            _u = str(_md.get("url_prefix", ""));
            _p = str(_md.get("local_path", ""));
            if _u and _p {
                console.print(f"  [cyan]→[/cyan] {_u:20s} -> {_p}");
            }
        }
    }
    console.print();

    # 5. Build optional static_mounts list. Each entry maps a URL prefix to
    #    a local directory the gateway should serve from BEFORE falling back
    #    to client_dist_dir. Configured as:
    #      [[plugins.scale.microservices.client.static_mounts]]
    #      url_prefix = "/static/assets"
    #      local_path = "assets"
    #    Tolerates missing/empty config — defaults to no extra mounts.
    static_mounts: list[dict[str, str]] = [];
    if client_config {
        raw_mounts: list[Any] = [];
        _raw = dict(client_config).get("static_mounts", []);
        if isinstance(_raw, list) {
            raw_mounts = list(_raw);
        }
        for entry in raw_mounts {
            ed = dict(entry) if isinstance(entry, dict) else {};
            url_prefix = str(ed.get("url_prefix", "")).strip();
            local_path = str(ed.get("local_path", "")).strip();
            if url_prefix and local_path {
                static_mounts.append(
                    {"url_prefix": url_prefix, "local_path": local_path,}
                );
                logger.info(f"Static mount: {url_prefix} -> {local_path}");
            }
        }
    }

    # 6. Start gateway (blocking)
    gateway = MicroserviceGateway(
        registry=registry,
        port=gateway_port,
        host=gateway_host,
        client_dist_dir=client_dist,
        static_mounts=static_mounts
    );
    gateway.start();

    # 6. Cleanup (runs when gateway shuts down)
    deployer.destroy_all();
}
