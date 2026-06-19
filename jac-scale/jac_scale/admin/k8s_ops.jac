"""Gateway-runtime Kubernetes API access for the Ops Console.

Read-mostly, in-cluster-only client helpers shared by the Ops Console admin
page (deploy health, endpoints/ingress/PVC, pod env, events, image
freshness, mutations). Everything degrades to a clean "unavailable" when
the kubernetes client isn't installed or the process isn't running inside
a cluster, so the endpoints render an empty state instead of a 500.

RBAC: these calls need the read-only namespace Role + RoleBinding the
microservice target provisions when `[plugins.scale.kubernetes].ops_console`
is set; mutations additionally need `ops_console_mutations`. There is
NO ClusterRole - all access is namespace-scoped to keep per-app-
namespace multi-tenancy intact. A 403 here means the Role isn't bound to the
pod's ServiceAccount (see `api_error_detail`).
"""
import os;
import logging;
import from jac_scale._optdeps.kubernetes {
    client,
    config,
    ApiException,
    HAS_KUBERNETES
}
import from jac_scale.microservices.runtime.util { in_cluster_namespace }

glob logger = logging.getLogger(__name__);

# In-cluster config is loaded once per process; cache the outcome so every
# endpoint call doesn't re-read the SA token mount.
glob _config_loaded: bool = False,
     _config_ok: bool = False;


"""True when the kubernetes client is importable AND this process is
running inside a pod (the API server env var is injected by K8s)."""
def k8s_available -> bool {
    if not HAS_KUBERNETES {
        return False;
    }
    return bool(os.getenv("KUBERNETES_SERVICE_HOST", "").strip());
}


"""Load in-cluster config exactly once (idempotent). Returns True on
success. False when not in a cluster or the load raised (e.g. no SA token
mounted), in which case the api accessors all return None."""
def _ensure_config -> bool {
    global _config_loaded,_config_ok;
    if _config_loaded {
        return _config_ok;
    }
    if not k8s_available() {
        _config_ok = False;
        _config_loaded = True;
        return False;
    }
    try {
        config.load_incluster_config();
        _config_ok = True;
    } except Exception as e {
        logger.warning(f"in-cluster config load failed: {e}");
        _config_ok = False;
    }
    # Set last so a racing first call can't read a half-set _config_ok.
    _config_loaded = True;
    return _config_ok;
}


"""The namespace this pod runs in. Each app gets its own
namespace, so this doubles as the app scope for every list call."""
def ops_namespace -> str {
    return in_cluster_namespace();
}


"""CoreV1Api (pods/services/endpoints/events/PVCs) or None when
unavailable."""
def core_api -> any {
    if not _ensure_config() {
        return None;
    }
    try {
        return client.CoreV1Api();
    } except Exception as e {
        logger.warning(f"CoreV1Api init failed: {e}");
        return None;
    }
}


"""AppsV1Api (deployments/replicasets/statefulsets/daemonsets) or None."""
def apps_api -> any {
    if not _ensure_config() {
        return None;
    }
    try {
        return client.AppsV1Api();
    } except Exception as e {
        logger.warning(f"AppsV1Api init failed: {e}");
        return None;
    }
}


"""NetworkingV1Api (ingresses) or None when unavailable."""
def networking_api -> any {
    if not _ensure_config() {
        return None;
    }
    try {
        return client.NetworkingV1Api();
    } except Exception as e {
        logger.warning(f"NetworkingV1Api init failed: {e}");
        return None;
    }
}


"""A short, operator-actionable detail string from a kubernetes
ApiException (or any error). A 403 is the common one and means the Ops
Console Role isn't bound to the pod's ServiceAccount."""
def api_error_detail(e: any) -> str {
    status = e?.status;
    reason = str(getattr(e, "reason", "") or "");
    if status == 403 {
        return (
            "RBAC denied (403). Set [plugins.scale.kubernetes].ops_console = true "
            "and redeploy so the read-only Role binds to the gateway ServiceAccount."
        );
    }
    if status {
        return f"Kubernetes API error {status} {reason}".strip();
    }
    return str(e);
}


"""Standard 'cluster API unavailable' payload so every Ops Console endpoint
renders the same empty state off-cluster instead of a 500."""
def unavailable_detail -> str {
    if not HAS_KUBERNETES {
        return "kubernetes client not installed (image lacks jac-scale[deploy]).";
    }
    if not os.getenv("KUBERNETES_SERVICE_HOST", "").strip() {
        return "not running inside a Kubernetes cluster.";
    }
    return "in-cluster Kubernetes config could not be loaded.";
}
