import os;
import socket;
import shutil;

def pick_free_port(
    name: str, base: int = 18000, retries: int = 100, avoid: set[int] | None = None
) -> int {
    blocked: set[int] = set(avoid) if avoid else set();
    start: int = base + (hash(name) % 1000);
    port: int = start;
    for _ in range(retries) {
        if port in blocked {
            port = port + 1;
            continue;
        }
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
        try {
            s.bind(('127.0.0.1', port));
            s.close();
            return port;
        } except OSError {
            s.close();
            port = port + 1;
        }
    }
    raise RuntimeError(f"Could not find free port near {start}");
}

def jac_executable -> str {
    return os.environ.get("JAC_EXECUTABLE", "") or shutil.which("jac") or "jac";
}

glob _DEFAULT_HTTP_FORWARD_TIMEOUT: float = 30.0,
     _DEFAULT_ROUTE_REFRESH_SECONDS: float = 30.0,
     _DEFAULT_BOOT_HEALTH_TIMEOUT: float = 60.0;

glob DEFAULT_GATEWAY_PORT: int = 8000,
     DEFAULT_GATEWAY_HOST: str = "0.0.0.0",
     DEFAULT_CLIENT_DIST_DIR: str = ".jac/client/dist",
     K8S_CLUSTER_DNS_SUFFIX: str = "svc.cluster.local";


def k8s_service_dns_url(safe_name: str, namespace: str, port: int) -> str {
    return f"http://{safe_name}-service.{namespace}.{K8S_CLUSTER_DNS_SUFFIX}:{port}";
}


def in_cluster_namespace -> str {
    import os;
    ns: str = os.environ.get("POD_NAMESPACE", "");
    if ns {
        return ns;
    }
    try {
        ns_file = "/var/run/secrets/kubernetes.io/serviceaccount/namespace";
        with open(ns_file) as f {
            return f.read().strip() or "default";
        }
    } except Exception {
        return "default";
    }
}


def http_forward_timeout(app_name: str | None = None) -> float {
    try {
        import from jaclang.scale.config.config_loader { get_scale_config }
        scale_cfg = get_scale_config();
        if app_name {
            app_cfg = scale_cfg.get_app_scale_config(app_name);
            if "http_forward_timeout" in app_cfg {
                return float(app_cfg["http_forward_timeout"]);
            }
        }
        gw_cfg = scale_cfg.get_gateway_config();
        if "http_forward_timeout" in gw_cfg {
            return float(gw_cfg["http_forward_timeout"]);
        }
    } except Exception {}
    return _DEFAULT_HTTP_FORWARD_TIMEOUT;
}


def route_refresh_seconds -> float {
    try {
        import from jaclang.scale.config.config_loader { get_scale_config }
        gw_cfg = get_scale_config().get_gateway_config();
        if "route_refresh_seconds" in gw_cfg {
            return float(gw_cfg["route_refresh_seconds"]);
        }
    } except Exception {}
    return _DEFAULT_ROUTE_REFRESH_SECONDS;
}


def boot_health_timeout -> float {
    try {
        import from jaclang.scale.config.config_loader { get_scale_config }
        gw_cfg = get_scale_config().get_gateway_config();
        if "boot_health_timeout" in gw_cfg {
            return float(gw_cfg["boot_health_timeout"]);
        }
    } except Exception {}
    return _DEFAULT_BOOT_HEALTH_TIMEOUT;
}


def wait_for_health(
    base_url: str,
    proc_alive: any,
    timeout: float = 15.0,
    poll_interval: float = 0.1,
    progress: any = None
) -> bool {
    import time;
    import urllib.request;
    import from http.client { HTTPResponse }

    last_marker: any = progress() if progress is not None else None;
    deadline: float = time.time() + timeout;
    while time.time() < deadline {
        if not proc_alive() {
            return False;
        }
        try {
            opened: HTTPResponse = urllib.request.urlopen(
                f"{base_url}/healthz", timeout=1
            );
            with opened as resp {
                if resp.status < 500 {
                    return True;
                }
            }
        } except Exception {
            time.sleep(poll_interval);
        }
        if progress is not None {
            marker = progress();
            if marker != last_marker {
                last_marker = marker;
                deadline = time.time() + timeout;
            }
        }
    }
    return False;
}
