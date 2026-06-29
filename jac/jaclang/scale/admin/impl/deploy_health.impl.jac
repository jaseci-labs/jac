"""Implementation of JacAPIServerDeployHealth.

Same two-layer split as the self-check:
  (a) PURE reshape helpers - take a kubernetes object's `.to_dict()` and
      flatten it to the compact shape the React table needs. No I/O, so
      `test_ops_deploy.jac` feeds them mocked API dicts.
  (b) Thin K8s list calls (via admin/k8s_ops.jac) that fetch the live
      objects, `.to_dict()` them, and run the pure helpers.

All datetimes are stringified here so JSONResponse never chokes; a dead /
forbidden API renders `available: false` with a detail, never a 500.
"""
import asyncio;
import logging;
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jaclang.scale.jserver.jserver { HTTPMethod, JEndPoint }
import from jaclang.scale.admin.k8s_ops {
    apps_api,
    core_api,
    ops_namespace,
    k8s_available,
    api_error_detail,
    unavailable_detail
}

glob logger = logging.getLogger(__name__);


# =========================================================================
# (a) PURE reshape helpers - unit-tested with mocked `.to_dict()` payloads.
# =========================================================================
"""Best-effort string for any value (stringifies datetimes so the JSON
encoder never chokes). None -> ''."""
def _s(v: any) -> str {
    if v is None {
        return "";
    }
    return str(v);
}


"""Derive a coarse rollout status from a Deployment dict.

Returns {status, reason, message}: 'complete' when updated==available==
desired; 'stuck' when a Progressing condition reports
ProgressDeadlineExceeded; otherwise 'progressing'. Pure - reads only
spec/status counts + conditions."""
def _rollout_status(dep: dict) -> dict {
    spec = dep.get("spec", {}) or {};
    status = dep.get("status", {}) or {};
    desired = int(spec.get("replicas", 0) or 0);
    updated = int(status.get("updated_replicas", 0) or 0);
    available = int(status.get("available_replicas", 0) or 0);
    conditions = status.get("conditions", []) or [];

    for c in conditions {
        if c.get("type") == "Progressing"
        and str(c.get("reason", "")) == "ProgressDeadlineExceeded" {
            return {
                "status": "stuck",
                "reason": "ProgressDeadlineExceeded",
                "message": _s(c.get("message"))
            };
        }
    }
    # At desired replica count (including a deliberate scale-to-zero) -> done.
    if updated == desired and available == desired {
        return {"status": "complete", "reason": "", "message": ""};
    }
    return {
        "status": "progressing",
        "reason": "",
        "message": f"{available}/{desired} available, {updated} updated"
    };
}


"""Flatten a V1Deployment dict to {name, desired, ready, available,
updated, images, rollout}."""
def summarize_deployment(dep: dict) -> dict {
    meta = dep.get("metadata", {}) or {};
    spec = dep.get("spec", {}) or {};
    status = dep.get("status", {}) or {};
    containers = ((spec.get("template", {}) or {}).get("spec", {}) or {}).get(
        "containers", []
    )
    or [];
    images: list = [];
    for c in containers {
        img = c.get("image");
        if img {
            images.append(str(img));
        }
    }
    return {
        "name": _s(meta.get("name")),
        "desired": int(spec.get("replicas", 0) or 0),
        "ready": int(status.get("ready_replicas", 0) or 0),
        "available": int(status.get("available_replicas", 0) or 0),
        "updated": int(status.get("updated_replicas", 0) or 0),
        "images": images,
        "rollout": _rollout_status(dep)
    };
}


"""Extract the active container state as {state, reason} from a
container_status dict. state is one of running/waiting/terminated."""
def _container_state(cs: dict) -> dict {
    state = cs.get("state", {}) or {};
    if state.get("running") {
        return {"state": "running", "reason": ""};
    }
    if state.get("waiting") {
        w = state.get("waiting", {}) or {};
        return {"state": "waiting", "reason": _s(w.get("reason"))};
    }
    if state.get("terminated") {
        t = state.get("terminated", {}) or {};
        return {"state": "terminated", "reason": _s(t.get("reason"))};
    }
    return {"state": "unknown", "reason": ""};
}


"""Flatten a V1Pod dict to {name, app, phase, ready, total, restarts,
node, created, containers[]}. `containers[]` carries the per-container
spec image vs resolved imageID digest."""
def summarize_pod(pod: dict) -> dict {
    meta = pod.get("metadata", {}) or {};
    spec = pod.get("spec", {}) or {};
    status = pod.get("status", {}) or {};
    labels = meta.get("labels", {}) or {};
    cstatuses = status.get("container_statuses", []) or [];

    ready_count = 0;
    restart_total = 0;
    containers: list = [];
    for cs in cstatuses {
        is_ready = bool(cs.get("ready", False));
        if is_ready {
            ready_count += 1;
        }
        restarts = int(cs.get("restart_count", 0) or 0);
        restart_total += restarts;
        st = _container_state(cs);
        containers.append(
            {
                "name": _s(cs.get("name")),
                "image": _s(cs.get("image")),
                "image_id": _s(cs.get("image_id")),
                "ready": is_ready,
                "restarts": restarts,
                "state": st["state"],
                "reason": st["reason"]
            }
        );
    }

    return {
        "name": _s(meta.get("name")),
        "app": _s(labels.get("app")),
        "phase": _s(status.get("phase")),
        "ready": ready_count,
        "total": len(cstatuses),
        "restarts": restart_total,
        "node": _s(spec.get("node_name")),
        "created": _s(meta.get("creation_timestamp")),
        "containers": containers
    };
}


"""Assemble the deploy-health payload from already-listed deployment + pod
dicts (pure). Kept separate so the test can build the whole response from
mocked lists."""
def build_deploy_health(namespace: str, deployments: list, pods: list) -> dict {
    deps = [summarize_deployment(d) for d in deployments];
    pds = [summarize_pod(p) for p in pods];
    deps.sort(key=lambda d : d.get("name", ""));
    pds.sort(key=lambda p : p.get("name", ""));
    return {
        "available": True,
        "namespace": namespace,
        "deployments": deps,
        "pods": pds
    };
}


# =========================================================================
# (b) Thin K8s list calls -> pure helpers.
# =========================================================================
"""Fetch + reshape deploy health for the pod's namespace. Best-effort:
returns {available: False, detail} when off-cluster or on any API error."""
def _collect_deploy_health -> dict {
    if not k8s_available() {
        return {"available": False, "detail": unavailable_detail()};
    }
    apps = apps_api();
    core = core_api();
    if apps is None or core is None {
        return {"available": False, "detail": unavailable_detail()};
    }
    ns = ops_namespace();
    try {
        dep_objs = apps.list_namespaced_deployment(namespace=ns).items;
        pod_objs = core.list_namespaced_pod(namespace=ns).items;
    } except Exception as e {
        logger.warning(f"deploy-health list failed: {e}");
        return {"available": False, "detail": api_error_detail(e)};
    }
    deployments = [d.to_dict() for d in (dep_objs or [])];
    pods = [p.to_dict() for p in (pod_objs or [])];
    return build_deploy_health(ns, deployments, pods);
}


impl JacAPIServerDeployHealth.register_deploy_health_endpoints -> None {
    async def deploy_handler(request: Request) -> JSONResponse {
        guard = self.require_admin_json(request.headers.get("Authorization"));
        if guard {
            return guard;
        }
        try {
            data = await asyncio.to_thread(_collect_deploy_health);
        } except Exception as e {
            logger.warning(f"deploy-health handler error: {e}");
            data = {"available": False, "detail": f"self-check error: {e}"};
        }
        return JSONResponse(content={"ok": True, "data": data});
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/ops/deploy",
            callback=deploy_handler,
            parameters=[],
            response_model=None,
            tags=["Operations"],
            summary="Deploy health (pods + deployments)",
            description=(
                "Namespace-scoped read of deployments (desired/ready/"
                "available/updated + rollout status) and pods (phase, ready "
                "containers, restarts, node, per-container image vs imageID). "
                "Needs the read-only Ops Console Role; renders 'unavailable' "
                "off-cluster, never a 500."
            )
        )
    );
    logger.info("Deploy-health endpoint registered: /admin/ops/deploy");
}
