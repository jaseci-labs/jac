import subprocess;
import logging;
import threading;
import from urllib.request { urlopen, Request as URLRequest }
import from urllib.error { URLError }
import from jaclang.scale.deploy.target.service_deployer { ServiceDeployer }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}

glob logger = logging.getLogger(__name__),
     _LEAD_HEARTBEAT_SECONDS: float = 30.0;

obj ServiceProcessManager {
    has registry: ServiceRegistry,
        deployer: (ServiceDeployer | None) = None,
        processes: dict[str, subprocess.Popen] = {},
        _own_sessions: dict[int, bool] = {},
        _health_check_timeout: int = 3,
        _max_failures: int = 3,
        _failure_counts: dict[str, int] = {},
        _next_port: int = 8001,
        dev_mode: bool = False,
        app_boot_timeout: float = 900.0,
        _booting: bool = False,
        _boot_health_timeout: float = 60.0,
        _health_monitor_interval: float = 10.0,
        _health_monitor_thread: (any | None) = None,
        _health_monitor_stop: (any | None) = None;

    def _url_for(service_entry: ServiceEntry) -> str;
    def _ports_in_use -> set[int];
    def _assign_port(service_entry: ServiceEntry) -> int;
    def _assign_free_port(service_entry: ServiceEntry) -> int;
    def _prepare_ports(service_entry: ServiceEntry) -> None;
    def _boot_order -> list[str];
    def _await_lead(name: str) -> None;
    def start_service(name: str) -> bool;
    def start_all -> None;
    def stop_service(name: str) -> bool;
    def stop_all -> None;
    def restart_service(name: str) -> bool;
    def check_health(name: str) -> bool;
    def check_all_health -> dict[str, bool];
    def start_health_monitor(interval: float | None = None) -> None;
    def end_boot -> None;
    def stop_health_monitor -> None;
}
