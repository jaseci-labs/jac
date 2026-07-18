import os;
import asyncio;
import logging;
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jaclang.scale.jserver.jserver { HTTPMethod, JEndPoint }
import from jaclang.scale.admin.k8s_ops {
    core_api,
    ops_namespace,
    k8s_available,
    api_error_detail,
    unavailable_detail
}

glob logger = logging.getLogger(__name__),
     _ENV_ALLOW_PREFIXES: list = [
         "OTEL_",
         "JAC_",
         "K8S_",
         "POD_",
         "KUBERNETES_",
         "TRACING_",
         "TEMPO_URL",
         "LOKI_URL",
         "PROMETHEUS_URL",
         "OTLP_",
         "SAMPLE_RATIO",
         "HOSTNAME"
     ],
     _MASK: str = "********";


def _s(v: any) -> str {
    if v is None {
        return "";
    }
    return str(v);
}


def is_allowed_key(key: str, prefixes: list) -> bool {
    for p in prefixes {
        if key.startswith(p) {
            return True;
        }
    }
    return False;
}


def redact_entry(item: dict, prefixes: list) -> dict {
    name = _s(item.get("name"));
    source = _s(item.get("source"));
    if source {
        return {
            "name": name,
            "value": f"(from {source})",
            "shown": False,
            "source": source
        };
    }
    if is_allowed_key(name, prefixes) {
        return {
            "name": name,
            "value": _s(item.get("value")),
            "shown": True,
            "source": ""
        };
    }
    return {"name": name, "value": _MASK, "shown": False, "source": ""};
}


def redact_env(entries: list, prefixes: list) -> list {
    return [redact_entry(e, prefixes) for e in entries];
}


def pod_env_entries(pod: dict) -> list {
    spec = pod.get("spec", {}) or {};
    out: list = [];
    containers = spec.get("containers", []) or [];
    if not containers {
        return out;
    }
    for e in (containers[0].get("env", []) or []) {
        source = "";
        value_from = e.get("value_from");
        if value_from {
            if value_from.get("secret_key_ref") {
                source = "secret";
            } elif value_from.get("config_map_key_ref") {
                source = "configMap";
            } elif value_from.get("field_ref") {
                source = "field";
            } elif value_from.get("resource_field_ref") {
                source = "resource";
            } else {
                source = "ref";
            }
        }
        out.append(
            {"name": _s(e.get("name")), "value": _s(e.get("value")), "source": source}
        );
    }
    return out;
}


def build_podenv(namespace: str, this_env: list, pods: list, prefixes: list) -> dict {
    pod_rows: list = [];
    for pod in pods {
        meta = pod.get("metadata", {}) or {};
        labels = meta.get("labels", {}) or {};
        pod_rows.append(
            {
                "pod": _s(meta.get("name")),
                "app": _s(labels.get("app")),
                "env": redact_env(pod_env_entries(pod), prefixes)
            }
        );
    }
    pod_rows.sort(key=lambda (p) { p.get("pod", ""); });
    return {
        "available": True,
        "namespace": namespace,
        "this_pod": redact_env(this_env, prefixes),
        "pods": pod_rows
    };
}


def _own_env_entries -> list {
    out: list = [];
    for (k, v) in os.environ.items() {
        out.append({"name": str(k), "value": str(v), "source": ""});
    }
    out.sort(key=lambda (e) { e.get("name", ""); });
    return out;
}


def _collect_podenv -> dict {
    own_env = _own_env_entries();
    if not k8s_available() {
        return {
            "available": False,
            "detail": unavailable_detail(),
            "this_pod": redact_env(own_env, _ENV_ALLOW_PREFIXES),
            "pods": []
        };
    }
    core = core_api();
    if core is None {
        return {
            "available": False,
            "detail": unavailable_detail(),
            "this_pod": redact_env(own_env, _ENV_ALLOW_PREFIXES),
            "pods": []
        };
    }
    ns = ops_namespace();
    try {
        pod_objs = core.list_namespaced_pod(namespace=ns).items;
    } except Exception as e {
        logger.warning(f"podenv list failed: {e}");
        return {
            "available": False,
            "detail": api_error_detail(e),
            "this_pod": redact_env(own_env, _ENV_ALLOW_PREFIXES),
            "pods": []
        };
    }
    return build_podenv(
        ns, own_env, [p.to_dict() for p in (pod_objs or [])], _ENV_ALLOW_PREFIXES
    );
}


impl JacAPIServerPodEnv.register_podenv_endpoints -> None {
    async def podenv_handler(request: Request) -> JSONResponse {
        guard = self.require_admin_json(request.headers.get("Authorization"));
        if guard {
            return guard;
        }
        try {
            data = await asyncio.to_thread(_collect_podenv);
        } except Exception as e {
            logger.warning(f"podenv handler error: {e}");
            data = {"available": False, "detail": f"self-check error: {e}", "pods": []};
        }
        return JSONResponse(content={"ok": True, "data": data});
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/ops/podenv",
            callback=podenv_handler,
            parameters=[],
            response_model=None,
            tags=["Operations"],
            summary="Pod environment (allowlist-redacted)",
            description=(
                "This pod's own process env + each pod's configured spec "
                "env, allowlist-redacted: only OTEL_*/JAC_*/K8S_*-class keys "
                "show values; everything else is masked, and secretRef "
                "values are never resolved. Needs the read-only Ops Console "
                "Role for other pods; always shows this pod's env."
            )
        )
    );
    logger.info("Pod-env endpoint registered: /admin/ops/podenv");
}
