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


"""Parse `[[microservices.client.static_mounts]]` entries into the
{url_prefix, local_path} dicts the gateway expects. Skips malformed
entries (non-dict, missing fields, empty strings). Used by both
`start_microservice_mode` (local) and `start_gateway_only` (K8s).
"""
def _parse_static_mounts(
    client_config: dict[str, Any]
) -> list[dict[str, str]] {
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


"""Read `client.dist_dir` from microservice config, defaulting to
`.jac/client/dist`. Centralized so the local-mode banner, build path,
and gateway-only mode all read it the same way.
"""
def _client_dist_dir(client_config: dict[str, Any]) -> str {
    if not client_config {
        return DEFAULT_CLIENT_DIST_DIR;
    }
    return str(
        dict(client_config).get("dist_dir", DEFAULT_CLIENT_DIST_DIR)
    );
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


"""Pre-mark every registry entry HEALTHY for K8s gateway mode.

In local mode, `LocalDeployer.deploy_service` flips an entry from
REGISTERED to HEALTHY after a successful spawn. K8s mode skips the
deployer entirely (kube-proxy + Endpoints already gates routing on
real readinessProbes), so without this step entries stay REGISTERED
forever and `handle_proxy` short-circuits every `/api/<svc>/*`
request with 503. Pre-marking is the K8s equivalent of
"trust the platform's health signal" - transport failures from a
not-yet-Ready service still surface naturally as 502/503 from the
http_forward layer when the connection refuses.

Factored out of `start_gateway_only` so unit tests can verify the
status flip without booting the gateway server.
"""
def _mark_all_healthy_k8s(registry: ServiceRegistry) {
    for (_name, _entry) in registry.entries.items() {
        _entry.status = ServiceStatus.HEALTHY;
    }
}


"""Populate svc_entry.url from the runtime DNS resolver.

`handle_proxy` (path-prefix routing for `/api/<svc>/*`) uses
`resolve_target_url` which calls `JacRuntime.get_sv_registry()` -
the hookimpl returns the K8s DNS map at request time. Works in K8s.

`handle_builtin_passthrough` (built-in routes like `/user/login`,
`/walker/*`, `/function/*`) is path-agnostic: it fans out to every
registered service looking for the first non-404 response. But it
uses `svc_entry.url` DIRECTLY, not the hookspec. In K8s mode
`build_registry` constructs entries with `url=""`, so the check
`if svc_entry.url` skips every service and the gateway returns
"Not found on any service" for every built-in route.

Fix: at gateway startup, call get_sv_registry() once and write the
DNS URLs onto each entry's `.url` field. This keeps the existing
passthrough loop intact while making it work in K8s. Falls back
silently if the hookspec isn't ready yet (the entry stays empty
and the existing skip-empty-url logic handles it).
"""
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


"""Start ONLY the gateway, no service spawning, no orchestrator.

Used by the K8s gateway pod (where K8s manages the service pod
lifecycle independently). Skips local-mode steps 1-4 (client build,
process start, health waits) since none apply when peers are real
K8s pods reachable via DNS.

URL resolution at runtime goes through `JacRuntime.get_sv_registry()`,
which the hookimpl turns into a DNS map when KUBERNETES_SERVICE_HOST
is set. So the gateway code is unchanged - only the registry source
differs between local and K8s.
"""
def start_gateway_only(ms_config: dict[str, Any]) -> None {
    if not ms_config.get("routes", {}) {
        logger.error("No routes declared in [plugins.scale.microservices.routes]");
        return;
    }

    registry = build_registry(ms_config);
    _mark_all_healthy_k8s(registry);
    # handle_proxy uses get_sv_registry() at request time, but
    # handle_builtin_passthrough (auth, walker, function fan-out)
    # reads svc_entry.url directly and skips entries with empty url.
    # Populate from the same DNS map so built-in routes work in K8s.
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
