"""Shared observability-service URL resolution for the admin endpoints."""

import os;

import from jaclang.scale.config.config_loader { get_scale_config }


"""Resolve a service base URL: explicit env var, else the k8s app-name
service DNS, else localhost."""
def service_base_url(env_var: str, svc_suffix: str, port: int) -> str {
    env = os.getenv(env_var, "").strip();
    if env {
        return env.rstrip("/");
    }
    app_name = os.getenv("K8S_APP_NAME", "").strip();
    if not app_name {
        try {
            k8s_cfg = get_scale_config().get_kubernetes_config();
            raw = str(k8s_cfg.get("app_name", "") or "").strip();
            expanded = os.path.expandvars(raw);
            if expanded and "${" not in expanded {
                app_name = expanded;
            }
        } except Exception {
            app_name = "";
        }
    }
    if not app_name {
        return f"http://localhost:{port}";
    }
    return f"http://{app_name}-{svc_suffix}:{port}";
}
