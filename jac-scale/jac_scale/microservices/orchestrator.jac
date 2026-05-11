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
import from jac_scale.microservices._util {
    DEFAULT_GATEWAY_PORT,
    DEFAULT_GATEWAY_HOST,
    DEFAULT_CLIENT_DIST_DIR
}

glob logger = logging.getLogger(__name__);


"""Parse static_mounts entries into {url_prefix, local_path} dicts;
skips malformed entries."""
def _parse_static_mounts(client_config: dict[str, Any]) -> list[dict[str, str]] {
    out: list[dict[str, str]] = [];
    if not client_config {
        return out;
    }
    raw = dict(client_config).get("static_mounts", []);
    if not isinstance(raw, list) {
        return out;
    }
    for entry in raw {
        ed = dict(entry) if isinstance(entry, dict) else {};
        url_prefix = str(ed.get("url_prefix", "")).strip();
        local_path = str(ed.get("local_path", "")).strip();
        if url_prefix and local_path {
            out.append({"url_prefix": url_prefix, "local_path": local_path});
        }
    }
    return out;
}


"""Read client.dist_dir; defaults to `.jac/client/dist`."""
def _client_dist_dir(client_config: dict[str, Any]) -> str {
    if not client_config {
        return DEFAULT_CLIENT_DIST_DIR;
    }
    return str(dict(client_config).get("dist_dir", DEFAULT_CLIENT_DIST_DIR));
}

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
    client_dist: str = _client_dist_dir(client_config);

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

    # jac.toml overrides for boot + recovery cadences (defaults 60/90/10s).
    pm._boot_health_timeout = float(
        ms_config.get("boot_health_timeout", pm._boot_health_timeout)
    );
    pm._health_monitor_interval = float(
        ms_config.get("health_monitor_interval", pm._health_monitor_interval)
    );
    max_wait: int = int(ms_config.get("boot_max_wait", 90));

    # Register cleanup on exit
    atexit.register(deployer.destroy_all);

    # 3. Wait for services to become healthy
    logger.info("Waiting for services to start...");
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

    # Background recovery loop: services that miss the boot bar by a
    # few seconds flip back to HEALTHY automatically via check_all_health.
    # destroy_all -> stop_all -> stop_health_monitor handles teardown.
    pm.start_health_monitor();

    # 4. Print startup banner
    gateway_port: int = int(ms_config.get("gateway_port", DEFAULT_GATEWAY_PORT));
    gateway_host: str = str(ms_config.get("gateway_host", DEFAULT_GATEWAY_HOST));
    client_config = ms_config.get("client", {});
    client_dist: str = _client_dist_dir(client_config);

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

    # 5. Build optional static_mounts list. Each entry maps a URL prefix to
    #    a local directory the gateway should serve from BEFORE falling back
    #    to client_dist_dir. Configured as:
    #      [[plugins.scale.microservices.client.static_mounts]]
    #      url_prefix = "/static/assets"
    #      local_path = "assets"
    #    Tolerates missing/empty config — defaults to no extra mounts.
    static_mounts: list[dict[str, str]] = _parse_static_mounts(client_config);
    if static_mounts {
        console.print();
        console.print("  [bold]Static mounts[/bold]");
        console.print(f"  [dim]{'─' * 48}[/dim]");
        for mount in static_mounts {
            console.print(
                f"  [cyan]→[/cyan] {mount['url_prefix']:20s} -> {mount['local_path']}"
            );
            logger.info(
                f"Static mount: {mount['url_prefix']} -> {mount['local_path']}"
            );
        }
    }
    console.print();

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


"""Pre-mark every registry entry HEALTHY for K8s gateway mode (K8s
gates routing on real readinessProbes; gateway's status check would
otherwise 503 every request). Factored out for testability."""
def _mark_all_healthy_k8s(registry: ServiceRegistry) {
    for (_name, _entry) in registry.entries.items() {
        _entry.status = ServiceStatus.HEALTHY;
    }
}


"""Write get_sv_registry()'s DNS URLs onto registry entries so the
gateway's built-in passthrough loop (which reads svc_entry.url
directly, not the hookspec) finds K8s peers. Silent on lookup
failure - empty-url entries are skipped by the passthrough loop."""
def _populate_k8s_urls(registry: ServiceRegistry) {
    try {
        import jaclang;
        dns_map: dict[str, str] = jaclang.JacRuntime.get_sv_registry();
    } except Exception as e {
        logger.warning(f"K8s URL population failed: {e}");
        return;
    }
    for (svc_name, _entry) in registry.entries.items() {
        url = dns_map.get(svc_name, "");
        if url {
            _entry.url = url;
        }
    }
    logger.info(
        f"K8s URLs populated: {sum(
            1
            for e in registry.entries.values()
            if e.url
        )}"
        f"/{len(registry.entries)} services"
    );
}


"""Start ONLY the gateway (used by the K8s gateway pod). Skips local-
mode steps - K8s manages service pod lifecycle. Peer URLs come via
get_sv_registry() which returns DNS when KUBERNETES_SERVICE_HOST is set."""
def start_gateway_only(ms_config: dict[str, Any]) -> None {
    if not ms_config.get("routes", {}) {
        logger.error("No routes declared in [plugins.scale.microservices.routes]");
        return;
    }

    registry = build_registry(ms_config);
    _mark_all_healthy_k8s(registry);
    # Built-in passthrough reads svc_entry.url directly (not the hookspec).
    _populate_k8s_urls(registry);

    gateway_port = int(ms_config.get("gateway_port", DEFAULT_GATEWAY_PORT));
    gateway_host = ms_config.get("gateway_host", DEFAULT_GATEWAY_HOST);

    client_config = ms_config.get("client", {});
    client_dist: str = _client_dist_dir(client_config);

    static_mounts: list[dict[str, str]] = _parse_static_mounts(client_config);

    gateway = MicroserviceGateway(
        registry=registry,
        port=gateway_port,
        host=gateway_host,
        client_dist_dir=client_dist,
        static_mounts=static_mounts
    );
    logger.info(
        f"Starting gateway-only mode on {gateway_host}:{gateway_port} "
        f"(K8s pod context; no service spawning)"
    );
    gateway.start();
}
