import os;
import logging;
import from jac_scale._optdeps.kubernetes {
    client,
    config,
    ApiException,
    HAS_KUBERNETES
}
import from jac_scale.runtime.context.util { in_cluster_namespace }

glob logger = logging.getLogger(__name__);

glob _config_loaded: bool = False,
     _config_ok: bool = False;


def k8s_available -> bool {
    if not HAS_KUBERNETES {
        return False;
    }
    return bool(os.getenv("KUBERNETES_SERVICE_HOST", "").strip());
}


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

    _config_loaded = True;
    return _config_ok;
}


def ops_namespace -> str {
    return in_cluster_namespace();
}


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


def unavailable_detail -> str {
    if not HAS_KUBERNETES {
        return "kubernetes client not installed (image lacks jac-scale[deploy]).";
    }
    if not os.getenv("KUBERNETES_SERVICE_HOST", "").strip() {
        return "not running inside a Kubernetes cluster.";
    }
    return "in-cluster Kubernetes config could not be loaded.";
}
