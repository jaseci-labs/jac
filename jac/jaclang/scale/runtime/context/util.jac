import os;
import socket;
import shutil;

def pick_free_port(name: str, base: int = 18000, retries: int = 100) -> int {
    start: int = base + (hash(name) % 1000);
    port: int = start;
    for _ in range(retries) {
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
    # Re-invoking jac must not depend on `jac` being on PATH: the single-binary
    # launcher pins its real path in JAC_EXECUTABLE. Fall back to PATH, then a
    # bare name for dev / link-source runs.
    return os.environ.get("JAC_EXECUTABLE", "") or shutil.which("jac") or "jac";
}

glob _DEFAULT_HTTP_FORWARD_TIMEOUT: float = 30.0;

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


def http_forward_timeout(service_name: str | None = None) -> float {
    try {
        import from jaclang.scale.config.config_loader { get_scale_config }
        ms_cfg = get_scale_config().get_microservices_config();
        if service_name {
            svc_cfg = ms_cfg.get("services", {}).get(service_name, {});
            if "http_forward_timeout" in svc_cfg {
                return float(svc_cfg["http_forward_timeout"]);
            }
        }
        if "http_forward_timeout" in ms_cfg {
            return float(ms_cfg["http_forward_timeout"]);
        }
    } except Exception {
        ;
    }
    return _DEFAULT_HTTP_FORWARD_TIMEOUT;
}


def wait_for_health(
    base_url: str, proc_alive: any, timeout: float = 15.0, poll_interval: float = 0.1
) -> bool {
    import time;
    import urllib.request;

    deadline: float = time.time() + timeout;
    while time.time() < deadline {
        if not proc_alive() {
            return False;
        }
        try {
            with urllib.request.urlopen(f"{base_url}/healthz", timeout=1) as resp {
                if resp.status < 500 {
                    return True;
                }
            }
        } except Exception {
            time.sleep(poll_interval);
        }
    }
    return False;
}
