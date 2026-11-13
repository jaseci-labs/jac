import os;
import socket;
import shutil;

def pick_free_port(
    name: str, base: int = 18000, retries: int = 100, avoid: set[int] | None = None
) -> int;

def jac_executable -> str;

glob _DEFAULT_HTTP_FORWARD_TIMEOUT: float = 30.0,
     _DEFAULT_ROUTE_REFRESH_SECONDS: float = 30.0,
     _DEFAULT_BOOT_HEALTH_TIMEOUT: float = 60.0;

glob DEFAULT_GATEWAY_PORT: int = 8000,
     DEFAULT_GATEWAY_HOST: str = "0.0.0.0",
     DEFAULT_CLIENT_DIST_DIR: str = ".jac/client/dist",
     K8S_CLUSTER_DNS_SUFFIX: str = "svc.cluster.local",
     _RFC1123_MAX_LEN: int = 253;


def k8s_service_dns_host(service_name: str, namespace: str) -> str;


def k8s_service_dns_url(safe_name: str, namespace: str, port: int) -> str;


def in_cluster_namespace -> str;


def http_forward_timeout(app_name: str | None = None) -> float;


def route_refresh_seconds -> float;


def boot_health_timeout -> float;


def wait_for_health(
    base_url: str,
    proc_alive: any,
    timeout: float = 15.0,
    poll_interval: float = 0.1,
    progress: any = None
) -> bool;


glob GATEWAY_NAME: str = "__gateway__";

def k8s_safe_name(svc_name: str) -> str;
