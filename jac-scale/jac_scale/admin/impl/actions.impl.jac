"""Implementation of JacAPIServerActions (V-10).

Pure patch-body builders + validators (unit-tested) and thin mutating K8s
calls. Every handler: admin-gate -> resolve actor -> validate input ->
execute inside try/except -> AUDIT-LOG (actor, action, target, namespace,
result) -> return a flat {ok, message|error}. A missing mutation RBAC
surfaces as a 403 detail, never a 500.
"""
import logging;
import from datetime { datetime, UTC }
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jac_scale.jserver.jserver { HTTPMethod, JEndPoint }
import from jac_scale.admin.k8s_ops {
    apps_api,
    core_api,
    ops_namespace,
    k8s_available,
    api_error_detail,
    unavailable_detail
}

glob logger = logging.getLogger(__name__);
glob _MAX_REPLICAS: int = 50;


# =========================================================================
# (a) PURE patch-body builders + validators.
# =========================================================================

"""Deployment patch that triggers a rollout restart by stamping the pod
template with a restart annotation (the same mechanism `kubectl rollout
restart` uses)."""
def restart_patch(timestamp: str) -> dict {
    return {
        "spec": {
            "template": {
                "metadata": {
                    "annotations": {
                        "jac-scale.ops/restartedAt": timestamp
                    }
                }
            }
        }
    };
}


"""Scale subresource patch to `replicas`."""
def scale_patch(replicas: int) -> dict {
    return {"spec": {"replicas": replicas}};
}


"""PVC patch that clears finalizers so a stuck Terminating PVC can
delete. `null` finalizers removes the array."""
def unstick_patch -> dict {
    return {"metadata": {"finalizers": None}};
}


"""Validate + clamp a replica count. Returns (ok, value, error)."""
def validate_replicas(raw: any) -> dict {
    try {
        n = int(raw);
    } except (ValueError, TypeError) {
        return {"ok": False, "value": 0, "error": "replicas must be an integer"};
    }
    if n < 0 {
        return {"ok": False, "value": 0, "error": "replicas must be >= 0"};
    }
    if n > _MAX_REPLICAS {
        return {
            "ok": False,
            "value": 0,
            "error": f"replicas must be <= {_MAX_REPLICAS}"
        };
    }
    return {"ok": True, "value": n, "error": ""};
}


"""Reject empty / non-string resource names early (defense before the API
call). Returns '' when ok, else an error string."""
def validate_name(name: any) -> str {
    if not name or not isinstance(name, str) {
        return "a non-empty resource name is required";
    }
    return "";
}


# =========================================================================
# Audit + response helpers.
# =========================================================================

"""Emit a structured audit line for a mutation attempt."""
def _audit(actor: str, action: str, target: str, namespace: str, result: str) {
    logger.info(
        f"OPS-AUDIT action={action} actor={actor} target={target} "
        f"namespace={namespace} result={result}"
    );
}


def _err(message: str, status: int = 400) -> JSONResponse {
    return JSONResponse(
        status_code=status, content={"ok": False, "error": {"message": message}}
    );
}


# =========================================================================
# (b) Endpoint registration.
# =========================================================================

impl JacAPIServerActions.register_actions_endpoints -> None {

    # --- POST /admin/ops/actions/rollout-restart ----------------------
    async def restart_handler(request: Request) -> JSONResponse {
        auth_header = request.headers.get("Authorization");
        auth_error = self.require_admin(auth_header);
        if auth_error {
            return _err("Unauthorized", auth_error.meta.extra.get("http_status", 403));
        }
        actor = self.validate_admin_token(auth_header) or "unknown";
        try {
            body = await request.json();
        } except Exception {
            body = {};
        }
        dep = (body or {}).get("deployment");
        name_err = validate_name(dep);
        if name_err {
            return _err(name_err);
        }
        if not k8s_available() {
            return _err(unavailable_detail(), 503);
        }
        apps = apps_api();
        if apps is None {
            return _err(unavailable_detail(), 503);
        }
        ns = ops_namespace();
        try {
            ts = datetime.now(UTC).isoformat();
            apps.patch_namespaced_deployment(
                name=dep, namespace=ns, body=restart_patch(ts)
            );
        } except Exception as e {
            _audit(actor, "rollout-restart", dep, ns, f"error:{e}");
            return _err(api_error_detail(e), 502);
        }
        _audit(actor, "rollout-restart", dep, ns, "ok");
        return JSONResponse(
            content={
                "ok": True,
                "data": {"message": f"Rollout restart triggered for {dep}"}
            }
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path="/admin/ops/actions/rollout-restart",
            callback=restart_handler,
            parameters=[],
            response_model=None,
            tags=["Operations"],
            summary="Rollout restart a deployment",
            description=(
                "Body {deployment}. Stamps the pod template with a restart "
                "annotation (kubectl rollout restart). Admin-gated, audit-"
                "logged, needs ops_console_mutations RBAC."
            )
        )
    );

    # --- POST /admin/ops/actions/scale --------------------------------
    async def scale_handler(request: Request) -> JSONResponse {
        auth_header = request.headers.get("Authorization");
        auth_error = self.require_admin(auth_header);
        if auth_error {
            return _err("Unauthorized", auth_error.meta.extra.get("http_status", 403));
        }
        actor = self.validate_admin_token(auth_header) or "unknown";
        try {
            body = await request.json();
        } except Exception {
            body = {};
        }
        dep = (body or {}).get("deployment");
        name_err = validate_name(dep);
        if name_err {
            return _err(name_err);
        }
        rep = validate_replicas((body or {}).get("replicas"));
        if not rep["ok"] {
            return _err(rep["error"]);
        }
        if not k8s_available() {
            return _err(unavailable_detail(), 503);
        }
        apps = apps_api();
        if apps is None {
            return _err(unavailable_detail(), 503);
        }
        ns = ops_namespace();
        try {
            apps.patch_namespaced_deployment_scale(
                name=dep, namespace=ns, body=scale_patch(rep["value"])
            );
        } except Exception as e {
            _audit(actor, f"scale={rep['value']}", dep, ns, f"error:{e}");
            return _err(api_error_detail(e), 502);
        }
        _audit(actor, f"scale={rep['value']}", dep, ns, "ok");
        return JSONResponse(
            content={
                "ok": True,
                "data": {"message": f"Scaled {dep} to {rep['value']} replica(s)"}
            }
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path="/admin/ops/actions/scale",
            callback=scale_handler,
            parameters=[],
            response_model=None,
            tags=["Operations"],
            summary="Scale a deployment",
            description=(
                "Body {deployment, replicas}. Patches the scale subresource "
                f"(0..{_MAX_REPLICAS}). Admin-gated, audit-logged, needs "
                "ops_console_mutations RBAC."
            )
        )
    );

    # --- POST /admin/ops/actions/delete-pod ---------------------------
    async def delete_pod_handler(request: Request) -> JSONResponse {
        auth_header = request.headers.get("Authorization");
        auth_error = self.require_admin(auth_header);
        if auth_error {
            return _err("Unauthorized", auth_error.meta.extra.get("http_status", 403));
        }
        actor = self.validate_admin_token(auth_header) or "unknown";
        try {
            body = await request.json();
        } except Exception {
            body = {};
        }
        pod = (body or {}).get("pod");
        name_err = validate_name(pod);
        if name_err {
            return _err(name_err);
        }
        if not k8s_available() {
            return _err(unavailable_detail(), 503);
        }
        core = core_api();
        if core is None {
            return _err(unavailable_detail(), 503);
        }
        ns = ops_namespace();
        try {
            core.delete_namespaced_pod(name=pod, namespace=ns);
        } except Exception as e {
            _audit(actor, "delete-pod", pod, ns, f"error:{e}");
            return _err(api_error_detail(e), 502);
        }
        _audit(actor, "delete-pod", pod, ns, "ok");
        return JSONResponse(
            content={
                "ok": True,
                "data": {"message": f"Deleted pod {pod} (a fresh one will replace it)"}
            }
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path="/admin/ops/actions/delete-pod",
            callback=delete_pod_handler,
            parameters=[],
            response_model=None,
            tags=["Operations"],
            summary="Delete a pod",
            description=(
                "Body {pod}. Deletes a pod so its controller recreates a "
                "fresh one. Admin-gated, audit-logged, needs "
                "ops_console_mutations RBAC."
            )
        )
    );

    # --- POST /admin/ops/actions/unstick-pvc --------------------------
    async def unstick_pvc_handler(request: Request) -> JSONResponse {
        auth_header = request.headers.get("Authorization");
        auth_error = self.require_admin(auth_header);
        if auth_error {
            return _err("Unauthorized", auth_error.meta.extra.get("http_status", 403));
        }
        actor = self.validate_admin_token(auth_header) or "unknown";
        try {
            body = await request.json();
        } except Exception {
            body = {};
        }
        pvc = (body or {}).get("pvc");
        name_err = validate_name(pvc);
        if name_err {
            return _err(name_err);
        }
        if not k8s_available() {
            return _err(unavailable_detail(), 503);
        }
        core = core_api();
        if core is None {
            return _err(unavailable_detail(), 503);
        }
        ns = ops_namespace();
        try {
            core.patch_namespaced_persistent_volume_claim(
                name=pvc, namespace=ns, body=unstick_patch()
            );
        } except Exception as e {
            _audit(actor, "unstick-pvc", pvc, ns, f"error:{e}");
            return _err(api_error_detail(e), 502);
        }
        _audit(actor, "unstick-pvc", pvc, ns, "ok");
        return JSONResponse(
            content={
                "ok": True,
                "data": {"message": f"Cleared finalizers on PVC {pvc}"}
            }
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path="/admin/ops/actions/unstick-pvc",
            callback=unstick_pvc_handler,
            parameters=[],
            response_model=None,
            tags=["Operations"],
            summary="Unstick a terminating PVC",
            description=(
                "Body {pvc}. Clears finalizers on a PVC stuck in Terminating. "
                "Admin-gated, audit-logged, needs ops_console_mutations RBAC."
            )
        )
    );

    logger.info("Ops action endpoints registered: /admin/ops/actions/*");
}
