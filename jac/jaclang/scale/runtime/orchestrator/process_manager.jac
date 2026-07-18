import subprocess;
import logging;
import threading;
import from typing { Any }
import from urllib.request { urlopen, Request as URLRequest }
import from urllib.error { URLError }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}

glob logger = logging.getLogger(__name__);

obj ServiceProcessManager {
    has registry: ServiceRegistry,
        deployer: (Any | None) = None,
        processes: dict[str, subprocess.Popen] = {},
        _health_check_timeout: int = 3,
        _max_failures: int = 3,
        _failure_counts: dict[str, int] = {},
        _next_port: int = 8001,
        _boot_health_timeout: float = 60.0,
        _health_monitor_interval: float = 10.0,
        _health_monitor_thread: (Any | None) = None,
        _health_monitor_stop: (Any | None) = None;

    def _url_for(service_entry: ServiceEntry) -> str;
    def _assign_port(service_entry: ServiceEntry) -> int;
    def start_service(name: str) -> bool;
    def start_all -> None;
    def stop_service(name: str) -> bool;
    def stop_all -> None;
    def restart_service(name: str) -> bool;
    def check_health(name: str) -> bool;
    def check_all_health -> dict[str, bool];
    def start_health_monitor(interval: float | None = None) -> None;
    def stop_health_monitor -> None;
}
