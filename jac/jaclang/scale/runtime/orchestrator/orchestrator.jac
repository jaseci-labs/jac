import time;
import atexit;
import logging;
import from jaclang.cli.console { console }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}
import from jaclang.scale.runtime.orchestrator.process_manager { ServiceProcessManager }
import from jaclang.scale.runtime.orchestrator.local_deployer { LocalDeployer }
import from jaclang.scale.runtime.gateway.process_gateway { ProcessGateway }
import from jaclang.scale.runtime.context.util {
    DEFAULT_GATEWAY_PORT,
    DEFAULT_GATEWAY_HOST,
    DEFAULT_CLIENT_DIST_DIR
}

glob logger = logging.getLogger(__name__);


obj MicroserviceOrchestrator {
    has ms_config: dict[str, any];

    def start_local -> None {
        if not self.ms_config.get("routes", {}) {
            logger.warning(
                "No microservices to run: no routes were declared or discovered "
                "(no `sv import` / `to sv:` markers next to the entry file). "
                "Set [scale.microservices.routes] to declare them explicitly."
            );
            return;
        }

        client_config = self.ms_config.get("client", {});
        client_dist: str = self._client_dist_dir(client_config);

        self._build_client_bundle_if_needed(client_config, client_dist);

        registry = self._build_registry();
        logger.info(f"Registry: {len(registry.entries)} services");

        deployer = LocalDeployer(registry=registry);
        deployer.deploy_all();
        pm = deployer._ensure_pm();

        pm._boot_health_timeout = float(
            self.ms_config.get("boot_health_timeout", pm._boot_health_timeout)
        );
        pm._health_monitor_interval = float(
            self.ms_config.get("health_monitor_interval", pm._health_monitor_interval)
        );
        max_wait: int = int(self.ms_config.get("boot_max_wait", 90));

        atexit.register(deployer.destroy_all);

        self._wait_for_health(pm, registry, max_wait);

        pm.start_health_monitor();

        gateway_port: int = int(
            self.ms_config.get("gateway_port", DEFAULT_GATEWAY_PORT)
        );
        gateway_host: str = str(
            self.ms_config.get("gateway_host", DEFAULT_GATEWAY_HOST)
        );

        static_mounts: list[dict[str, str]] = self._parse_static_mounts(client_config);
        self._print_startup_banner(
            registry,
            client_config,
            client_dist,
            gateway_host,
            gateway_port,
            static_mounts
        );

        gateway = ProcessGateway(
            registry=registry,
            port=gateway_port,
            host=gateway_host,
            client_dist_dir=client_dist,
            static_mounts=static_mounts
        );
        gateway.serve();

        deployer.destroy_all();
    }

    def start_gateway_only -> None {
        if not self.ms_config.get("routes", {}) {
            logger.error("No routes declared in [scale.microservices.routes]");
            return;
        }

        registry = self._build_registry();
        _mark_all_healthy_k8s(registry);

        _populate_k8s_urls(registry);

        gateway_port = int(self.ms_config.get("gateway_port", DEFAULT_GATEWAY_PORT));
        gateway_host = self.ms_config.get("gateway_host", DEFAULT_GATEWAY_HOST);

        client_config = self.ms_config.get("client", {});
        client_dist: str = self._client_dist_dir(client_config);

        static_mounts: list[dict[str, str]] = self._parse_static_mounts(client_config);

        gateway = ProcessGateway(
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
        gateway.serve();
    }

    def _build_registry -> ServiceRegistry {
        registry = ServiceRegistry();
        routes = self.ms_config.get("routes", {});
        service_files = dict(self.ms_config.get("service_files", {}) or {});
        for (route_name, prefix) in routes.items() {
            name_str: str = str(route_name);
            svc_file: str = str(service_files.get(name_str) or f"{name_str}.jac");
            svc_entry = ServiceEntry(
                name=name_str, file=svc_file, prefix=str(prefix), port=0
            );
            registry.register(svc_entry);
            logger.info(f"Registered route: {name_str} -> {svc_entry.prefix}");
        }
        return registry;
    }

    def _client_dist_dir(client_config: dict[str, any]) -> str {
        if not client_config {
            return DEFAULT_CLIENT_DIST_DIR;
        }
        return str(dict(client_config).get("dist_dir", DEFAULT_CLIENT_DIST_DIR));
    }

    def _parse_static_mounts(client_config: dict[str, any]) -> list[dict[str, str]] {
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

    def _build_client_bundle_if_needed(
        client_config: dict[str, any], client_dist: str
    ) -> None {
        client_entry: str = str(dict(client_config).get("entry", ""))
            if client_config
            else "";
        if not client_entry {
            return;
        }
        import subprocess;
        import from pathlib { Path }
        dist_path = Path(client_dist);
        index_file = dist_path / "index.html";

        if index_file.exists() {
            logger.info("Client already built, skipping build");
            return;
        }

        console.print(f"  Building client from {client_entry}...");
        try {
            build_result = subprocess.run(
                ["jac", "build", client_entry, "--client", "web"], timeout=120
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
    }

    def _wait_for_health(
        pm: ServiceProcessManager, registry: ServiceRegistry, max_wait: int
    ) {
        logger.info("Waiting for services to start...");
        start_time: float = time.time();
        all_healthy = False;

        while time.time() - start_time < max_wait {
            results = pm.check_all_health();
            healthy_count: int = 0;
            dead_count: int = 0;
            for (name, entry) in registry.entries.items() {
                if results.get(name) {
                    healthy_count += 1;
                } elif entry.status == ServiceStatus.STOPPED {
                    dead_count += 1;
                }
            }
            if healthy_count == len(results) {
                all_healthy = True;
                logger.info(f"All {len(results)} services healthy!");
                break;
            }
            if healthy_count + dead_count == len(results) {
                logger.warning(
                    f"{dead_count} service(s) exited during boot and cannot "
                    "become healthy; not waiting further"
                );
                break;
            }
            logger.info(
                f"  {healthy_count}/{len(results)} services healthy, waiting..."
            );
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
    }

    def _print_startup_banner(
        registry: ServiceRegistry,
        client_config: dict[str, any],
        client_dist: str,
        gateway_host: str,
        gateway_port: int,
        static_mounts: list[dict[str, str]]
    ) {
        console.print();
        console.print("  Jac Microservice Mode", style="bold cyan");
        console.print(f"  Gateway: http://{gateway_host}:{gateway_port}", style="bold");
        console.print();
        console.print("  Services", style="bold");
        console.print(f"  {'-' * 48}", style="muted");
        for (name, entry) in registry.entries.items() {
            if entry.status == ServiceStatus.HEALTHY {
                icon = "●";
                row_style = "success";
            } else {
                icon = "○";
                row_style = "warning";
            }
            console.print(
                f"  {icon} {name:18s} {entry.prefix:20s} -> {entry.url}",
                style=row_style
            );
        }

        if client_config and dict(client_config).get("entry") {
            console.print();
            console.print(f"  Client: {dict(client_config)['entry']}", style="bold");
            console.print(f"  Static: {client_dist}", style="bold");
        }

        if static_mounts {
            console.print();
            console.print("  Static mounts", style="bold");
            console.print(f"  {'-' * 48}", style="muted");
            for mount in static_mounts {
                console.print(
                    f"  -> {mount['url_prefix']:20s} -> {mount['local_path']}",
                    style="cyan"
                );
                logger.info(
                    f"Static mount: {mount['url_prefix']} -> {mount['local_path']}"
                );
            }
        }
        console.print();
    }
}


def build_registry(ms_config: dict[str, any]) -> ServiceRegistry {
    return MicroserviceOrchestrator(ms_config=ms_config)._build_registry();
}

def start_microservice_mode(ms_config: dict[str, any]) {
    MicroserviceOrchestrator(ms_config=ms_config).start_local();
}

def start_gateway_only(ms_config: dict[str, any]) {
    MicroserviceOrchestrator(ms_config=ms_config).start_gateway_only();
}


def _mark_all_healthy_k8s(registry: ServiceRegistry) {
    for (_name, _entry) in registry.entries.items() {
        _entry.status = ServiceStatus.HEALTHY;
    }
}


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
