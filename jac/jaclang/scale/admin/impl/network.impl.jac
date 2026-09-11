import asyncio;
import logging;
import from jaclang.server.serving.datatypes { Request }
import from jaclang.server.serving.datatypes { JSONResponse }
import from jaclang.server.serving.endpoint { HTTPMethod, JEndPoint }
import from jaclang.scale.admin.k8s_ops {
    core_api,
    networking_api,
    ops_namespace,
    k8s_available,
    api_error_detail,
    unavailable_detail
}

glob logger = logging.getLogger(__name__);


def _s(v: any) -> str {
    if v is None {
        return "";
    }
    return str(v);
}


def endpoint_ready_counts(ep: dict[str, any]) -> dict[str, int] {
    ready = 0;
    not_ready = 0;
    subsets: any = ep.get("subsets", []) or [];
    for subset in subsets {
        ready += len(subset.get("addresses", []) or []);
        not_ready += len(subset.get("not_ready_addresses", []) or []);
    }
    return {"ready": ready, "not_ready": not_ready};
}


def summarize_service(
    svc: dict[str, any], ready_by_name: dict[str, dict[str, int]]
) -> dict[str, any] {
    meta: any = svc.get("metadata", {}) or {};
    spec: any = svc.get("spec", {}) or {};
    name = _s(meta.get("name"));
    ports: list[dict[str, any]] = [];
    svc_ports: any = spec.get("ports", []) or [];
    for p in svc_ports {
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


def summarize_ingress(ing: dict[str, any]) -> dict[str, any] {
    meta: any = ing.get("metadata", {}) or {};
    spec: any = ing.get("spec", {}) or {};
    status: any = ing.get("status", {}) or {};
    rules_out: list[dict[str, any]] = [];
    rules: any = spec.get("rules", []) or [];
    for rule in rules {
        host = _s(rule.get("host"));
        http: any = rule.get("http", {}) or {};
        paths: any = http.get("paths", []) or [];
        for path in paths {
            backend: any = path.get("backend", {}) or {};
            svc: any = backend.get("service", {}) or {};
            svc_port: any = svc.get("port", {}) or {};
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
    lb: list[str] = [];
    ingress_status: any = (status.get("load_balancer", {}) or {}).get("ingress", [])
        or [];
    for `entry in ingress_status {
        addr = `entry.get("hostname") or `entry.get("ip");
        if addr {
            lb.append(str(addr));
        }
    }
    return {"name": _s(meta.get("name")), "rules": rules_out, "lb": lb};
}


def pvc_claimants(pods: list[dict[str, any]]) -> dict[str, list[str]] {
    out: dict[str, list[str]] = {};
    for pod in pods {
        meta: any = pod.get("metadata", {}) or {};
        spec: any = pod.get("spec", {}) or {};
        pod_name = _s(meta.get("name"));
        volumes: any = spec.get("volumes", []) or [];
        for vol in volumes {
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


def summarize_pvc(
    pvc: dict[str, any], claimants_by_name: dict[str, list[str]]
) -> dict[str, any] {
    meta: any = pvc.get("metadata", {}) or {};
    spec: any = pvc.get("spec", {}) or {};
    status: any = pvc.get("status", {}) or {};
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


def build_network(
    namespace: str,
    services: list[dict[str, any]],
    endpoints: list[dict[str, any]],
    ingresses: list[dict[str, any]],
    pvcs: list[dict[str, any]],
    pods: list[dict[str, any]]
) -> dict[str, any] {
    ready_by_name: dict[str, dict[str, int]] = {};
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
    svc_out.sort(key=lambda (s) { s.get("name", ""); });
    pvc_out.sort(key=lambda (v) { v.get("name", ""); });
    return {
        "available": True,
        "namespace": namespace,
        "services": svc_out,
        "ingresses": ing_out,
        "pvcs": pvc_out
    };
}


def _collect_network -> dict[str, any] {
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
        ing_objs: any = [];
        if net is not None {
            ing_objs = net.list_namespaced_ingress(namespace=ns).items;
        }
    } except Exception as e {
        logger.warning(f"network list failed: {e}");
        return {"available": False, "detail": api_error_detail(e)};
    }
    empty: list[any] = [];
    return build_network(
        ns,
        [s.to_dict() for s in (svc_objs or empty)],
        [e.to_dict() for e in (ep_objs or empty)],
        [i.to_dict() for i in (ing_objs or empty)],
        [v.to_dict() for v in (pvc_objs or empty)],
        [p.to_dict() for p in (pod_objs or empty)]
    );
}


impl JacAPIServerNetwork.register_network_endpoints -> None {
    async def network_handler(request: Request) -> JSONResponse {
        guard = self.require_admin_json(request.headers.get("Authorization"));
        if guard {
            return guard;
        }
        try {
            data = await asyncio.to_thread(_collect_network);
        } except Exception as e {
            logger.warning(f"network handler error: {e}");
            data = {"available": False, "detail": f"self-check error: {e}"};
        }
        return JSONResponse(content={"ok": True, "data": data});
    }
    server = self.server;
    if server is None {
        return;
    }
    server.add_endpoint(
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
