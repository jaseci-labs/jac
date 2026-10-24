import time;
import atexit;
import logging;

glob logger = logging.getLogger(__name__),
     _BOOT_RECHECK_INTERVAL: float = 2.0;


def _log_gateway_only_ready(host: str, bound: int);


obj FleetOrchestrator {
    has fleet: FleetSpec,
        gateway_config: dict[str, any] = {};

    def _gateway_port -> int;
    def _gateway_host -> str;
    def _port_pinned -> bool;
    def start_local -> None;
    def start_gateway_only -> None;
    def _dev_mode -> bool;
    def _app_serves_client -> bool;
    def _build_registry -> ServiceRegistry;
    def _wait_for_health(
        pm: ServiceProcessManager, registry: ServiceRegistry, max_wait: int
    ) -> bool;

    def _print_startup_banner(
        registry: ServiceRegistry, gateway_host: str, gateway_port: int
    );
}


def build_registry(fleet: FleetSpec) -> ServiceRegistry;

def start_fleet_mode(fleet: FleetSpec, gateway_config: dict[str, any]);

def start_gateway_only(fleet: FleetSpec, gateway_config: dict[str, any]);


def _populate_k8s_urls(registry: ServiceRegistry);
