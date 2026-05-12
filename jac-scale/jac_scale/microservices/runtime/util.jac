"""Shared helpers for jac-scale microservice mode.

Both the `ensure_sv_service` hookimpl (plugin.jac) and the
ServiceProcessManager (process_manager.impl.jac) need the same port-picking
and jac-binary-resolution logic. Keeping them here avoids duplication.
"""

import socket;
import shutil;
import sys;
import from pathlib { Path }
import from typing { Any }

"""Pick a free TCP port near `base + hash(name) % 1000` on 127.0.0.1.

Matches core's strategy so sv_client._registry URLs and deployer URLs
resolve consistently when the same module is re-spawned. Raises
RuntimeError if no free port is found within `retries` attempts.
"""
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

"""Resolve the `jac` binary path.

Tries PATH first, then falls back to the directory of the currently-running
Python interpreter (handles activated virtualenvs where jac lives next to
python but isn't on PATH yet). Returns the string "jac" as a last resort.
"""
def resolve_jac_binary -> str {
    found: str = shutil.which("jac") or "";
    if found {
        return found;
    }
    candidate = Path(sys.executable).parent / "jac";
    if candidate.exists() {
        return str(candidate);
    }
    return "jac";
}

"""Hardcoded fallback if config read fails (no jac.toml, malformed schema)."""
glob _DEFAULT_HTTP_FORWARD_TIMEOUT: float = 30.0;

# Microservice-mode defaults shared by gateway, orchestrator, and the K8s
# runtime adapter. Centralizing avoids drift if the gateway's listen
# port/host ever changes — the local-mode banner, K8s DNS map, and
# in-pod default were all hardcoding the same values independently.
glob DEFAULT_GATEWAY_PORT: int = 8000,
     DEFAULT_GATEWAY_HOST: str = "0.0.0.0",
     DEFAULT_CLIENT_DIST_DIR: str = ".jac/client/dist",
     # K8s in-cluster DNS suffix. Constant across every standard K8s
     # install; only changes if the cluster admin overrides
     # `--cluster-domain` on the kubelet, which we don't try to support.
     K8S_CLUSTER_DNS_SUFFIX: str = "svc.cluster.local";


"""Build the in-cluster DNS URL for a microservice's ClusterIP Service.

The naming convention `<safe_name>-service` mirrors what
`KubernetesMicroserviceTarget._build_service_manifest` emits, so the
caller is responsible for passing an already-DNS-1123-safe name (use
`k8s_target.k8s_safe_name` upstream). Used by:
  - `KubernetesMicroserviceTarget._peer_dns_url` (manifest-time
    `JAC_SV_<PEER>_URL` env injection)
  - `KubernetesDeployer.url_for` (gateway -> service forwarding)
  - `build_k8s_registry` (full registry map for `get_sv_registry`)
"""
def k8s_service_dns_url(safe_name: str, namespace: str, port: int) -> str {
    return f"http://{safe_name}-service.{namespace}.{K8S_CLUSTER_DNS_SUFFIX}:{port}";
}


"""Resolve the namespace this pod is running in.

Lookup order:
  1. `POD_NAMESPACE` env var (set via downward API on the pod spec)
  2. `/var/run/secrets/kubernetes.io/serviceaccount/namespace` (mounted
     by K8s on every pod that uses a ServiceAccount)
  3. fall back to `default`

Centralized here so the registry builder, the `ensure_sv_service`
hookimpl, and any future cross-pod resolver all read namespace the
same way. Without this, the three callers had independent copies and
the in-cluster-secret-file fallback would silently diverge.
"""
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


"""Resolve gateway-to-service forward timeout (seconds).

Lookup order:
  1. `[plugins.scale.microservices.services.NAME].http_forward_timeout`
     (per-service override; matches the rpc_timeout precedence pattern)
  2. `[plugins.scale.microservices].http_forward_timeout` (global default)
  3. `_DEFAULT_HTTP_FORWARD_TIMEOUT` (30s; only hit when config read fails)

Returns the resolved timeout in seconds. Never raises; on config
read failure (e.g. no jac.toml in tests) falls through to the default.
"""
def http_forward_timeout(service_name: str | None = None) -> float {
    try {
        import from jac_scale.config_loader { get_scale_config }
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
        # Fall through on config read failure.
        ;
    }
    return _DEFAULT_HTTP_FORWARD_TIMEOUT;
}


"""Poll `base_url/healthz` until the service responds <500 or the deadline hits.

`proc_alive` is called once per iteration; if it returns False, the
caller's process died before becoming healthy and wait_for_health
returns False immediately. Returns True if healthy within the timeout,
False otherwise (timeout or early exit). The caller decides how to
react (log a warning, raise, restart, etc.).
"""
def wait_for_health(
    base_url: str, proc_alive: Any, timeout: float = 15.0, poll_interval: float = 0.1
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
