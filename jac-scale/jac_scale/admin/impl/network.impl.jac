"""Implementation of JacAPIServerNetwork.

Pure reshape helpers (tested with mocked `.to_dict()` payloads) + thin K8s
list calls. Surfaces, for the pod's namespace:
  - services with their ready backing endpoint count (so a service with 0
    ready backends - the classic "no endpoints" 503 - is obvious),
  - ingress rules resolved to host -> path -> service:port, plus the
    load-balancer address,
  - PVCs with bind phase + capacity + the pods currently mounting them.
"""
import asyncio;
import logging;
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jac_scale.jserver.jserver { HTTPMethod, JEndPoint }
import from jac_scale.admin.k8s_ops {
    core_api,
    networking_api,
    ops_namespace,
    k8s_available,
    api_error_detail,
    unavailable_detail
}

glob logger = logging.getLogger(__name__);


"""'' for None, else str(v)."""
def _s(v: any) -> str {
    if v is None {
        return "";
    }
    return str(v);
}


# =========================================================================
# (a) PURE reshape helpers.
# =========================================================================
"""Count ready vs not-ready addresses across a V1Endpoints dict's
subsets. Returns {ready, not_ready}."""
def endpoint_ready_counts(ep: dict) -> dict {
    ready = 0;
    not_ready = 0;
    for subset in (ep.get("subsets", []) or []) {
        ready += len(subset.get("addresses", []) or []);
        not_ready += len(subset.get("not_ready_addresses", []) or []);
    }
    return {"ready": ready, "not_ready": not_ready};
}


"""Flatten a V1Service dict to {name, type, cluster_ip, ports[]}."""
def summarize_service(svc: dict, ready_by_name: dict) -> dict {
    meta = svc.get("metadata", {}) or {};
    spec = svc.get("spec", {}) or {};
    name = _s(meta.get("name"));
    ports: list = [];
    for p in (spec.get("ports", []) or []) {
        ports.append(
            {
                "port": int(p.get("port", 0) or 0),
                "target": _s(p.get("target_port")),
                "protocol": _s(p.get("protocol"))
            }
        );
    }
    counts = ready_by_name.get(name, {"ready": 0, "not_ready": 0});
    return {
        "name": name,
        "type": _s(spec.get("type")),
        "cluster_ip": _s(spec.get("cluster_ip")),
        "ports": ports,
        "ready_backends": int(counts.get("ready", 0) or 0),
        "not_ready_backends": int(counts.get("not_ready", 0) or 0)
    };
}


"""Flatten a V1Ingress dict to {name, rules[], lb[]}.

Each rule is {host, path, service, port}. `lb` is the resolved
loadBalancer ingress (hostname or ip)."""
def summarize_ingress(ing: dict) -> dict {
    meta = ing.get("metadata", {}) or {};
    spec = ing.get("spec", {}) or {};
    status = ing.get("status", {}) or {};
    rules_out: list = [];
    for rule in (spec.get("rules", []) or []) {
        host = _s(rule.get("host"));
        http = rule.get("http", {}) or {};
        for path in (http.get("paths", []) or []) {
            backend = path.get("backend", {}) or {};
            svc = backend.get("service", {}) or {};
            svc_port = svc.get("port", {}) or {};
            rules_out.append(
                {
                    "host": host,
                    "path": _s(path.get("path")),
                    "service": _s(svc.get("name")),
                    "port": _s(svc_port.get("number") or svc_port.get("name"))
                }
            );
        }
    }
    lb: list = [];
    ingress_status = (status.get("load_balancer", {}) or {}).get("ingress", []) or [];
    for entry in ingress_status {
        addr = entry.get("hostname") or entry.get("ip");
        if addr {
            lb.append(str(addr));
        }
    }
    return {"name": _s(meta.get("name")), "rules": rules_out, "lb": lb};
}


"""Map PVC name -> [pod names] that mount it, from a pod list dict."""
def pvc_claimants(pods: list) -> dict {
    out: dict = {};
    for pod in pods {
        meta = pod.get("metadata", {}) or {};
        spec = pod.get("spec", {}) or {};
        pod_name = _s(meta.get("name"));
        for vol in (spec.get("volumes", []) or []) {
            pvc = vol.get("persistent_volume_claim");
            if pvc {
                claim = _s(pvc.get("claim_name"));
                if claim {
                    if claim not in out {
                        out[claim] = [];
                    }
                    out[claim].append(pod_name);
                }
            }
        }
    }
    return out;
}


"""Flatten a V1PersistentVolumeClaim dict to {name, phase, capacity,
storage_class, volume, claimants}."""
def summarize_pvc(pvc: dict, claimants_by_name: dict) -> dict {
    meta = pvc.get("metadata", {}) or {};
    spec = pvc.get("spec", {}) or {};
    status = pvc.get("status", {}) or {};
    name = _s(meta.get("name"));
    capacity = (status.get("capacity", {}) or {}).get("storage");
    return {
        "name": name,
        "phase": _s(status.get("phase")),
        "capacity": _s(capacity),
        "storage_class": _s(spec.get("storage_class_name")),
        "volume": _s(spec.get("volume_name")),
        "claimants": claimants_by_name.get(name, [])
    };
}


"""Assemble the network/storage payload from already-listed dicts (pure)."""
def build_network(
    namespace: str,
    services: list,
    endpoints: list,
    ingresses: list,
    pvcs: list,
    pods: list
) -> dict {
    ready_by_name: dict = {};
    for ep in endpoints {
        nm = _s((ep.get("metadata", {}) or {}).get("name"));
        if nm {
            ready_by_name[nm] = endpoint_ready_counts(ep);
        }
    }
    svc_out = [summarize_service(s, ready_by_name) for s in services];
    ing_out = [summarize_ingress(i) for i in ingresses];
    claimants = pvc_claimants(pods);
    pvc_out = [summarize_pvc(v, claimants) for v in pvcs];
    svc_out.sort(key=lambda s : s.get("name", ""));
    pvc_out.sort(key=lambda v : v.get("name", ""));
    return {
        "available": True,
        "namespace": namespace,
        "services": svc_out,
        "ingresses": ing_out,
        "pvcs": pvc_out
    };
}


# =========================================================================
# (b) Thin K8s list calls -> pure helpers.
# =========================================================================
def _collect_network -> dict {
    if not k8s_available() {
        return {"available": False, "detail": unavailable_detail()};
    }
    core = core_api();
    net = networking_api();
    if core is None {
        return {"available": False, "detail": unavailable_detail()};
    }
    ns = ops_namespace();
    try {
        svc_objs = core.list_namespaced_service(namespace=ns).items;
        ep_objs = core.list_namespaced_endpoints(namespace=ns).items;
        pvc_objs = core.list_namespaced_persistent_volume_claim(namespace=ns).items;
        pod_objs = core.list_namespaced_pod(namespace=ns).items;
        ing_objs = [];
        if net is not None {
            ing_objs = net.list_namespaced_ingress(namespace=ns).items;
        }
    } except Exception as e {
        logger.warning(f"network list failed: {e}");
        return {"available": False, "detail": api_error_detail(e)};
    }
    return build_network(
        ns,
        [s.to_dict() for s in (svc_objs or [])],
        [e.to_dict() for e in (ep_objs or [])],
        [i.to_dict() for i in (ing_objs or [])],
        [v.to_dict() for v in (pvc_objs or [])],
        [p.to_dict() for p in (pod_objs or [])]
    );
}


impl JacAPIServerNetwork.register_network_endpoints -> None {
    async def network_handler(request: Request) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get("http_status", 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        try {
            data = await asyncio.to_thread(_collect_network);
        } except Exception as e {
            logger.warning(f"network handler error: {e}");
            data = {"available": False, "detail": f"self-check error: {e}"};
        }
        return JSONResponse(content={"ok": True, "data": data});
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/ops/network",
            callback=network_handler,
            parameters=[],
            response_model=None,
            tags=["Operations"],
            summary="Endpoints, ingress, and PVC status",
            description=(
                "Namespace-scoped read of services (+ ready backend count), "
                "ingress rules (host -> path -> service:port + LB address), "
                "and PVCs (bind phase, capacity, claimant pods). Needs the "
                "read-only Ops Console Role; 'unavailable' off-cluster."
            )
        )
    );
    logger.info("Network endpoint registered: /admin/ops/network");
}
