"""Implementation of JacAPIServerImages (V-06).

Pure reshape helpers (tested with mocked pod dicts) + one thin pod list.
For each app it reports the spec image tag vs the resolved `imageID`
sha256 digest per replica, flags cross-replica digest drift (different
nodes pulled different bytes for the same tag - the image-cache bug), and
surfaces the B-01 build identity (JAC_IMAGE_REF / JAC_BUILD_SHA) from pod
env so an operator can answer "did my deploy actually update?".
"""
import logging;
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jac_scale.jserver.jserver { HTTPMethod, JEndPoint }
import from jac_scale.admin.k8s_ops {
    core_api,
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

"""Read an env var's value from a pod dict's first container env list.
Returns '' when absent. Only handles literal `value` (not valueFrom),
which is what B-01 injects for JAC_IMAGE_REF / JAC_BUILD_SHA."""
def _pod_env(pod: dict, key: str) -> str {
    spec = pod.get("spec", {}) or {};
    for c in (spec.get("containers", []) or []) {
        for e in (c.get("env", []) or []) {
            if e.get("name") == key {
                return _s(e.get("value"));
            }
        }
    }
    return "";
}


"""The first container's resolved imageID (sha256 digest ref) from pod
status. '' when the pod hasn't pulled yet."""
def _pod_image_id(pod: dict) -> str {
    status = pod.get("status", {}) or {};
    for cs in (status.get("container_statuses", []) or []) {
        iid = cs.get("image_id");
        if iid {
            return _s(iid);
        }
    }
    return "";
}


"""The first container's spec image (the tag ref)."""
def _pod_image(pod: dict) -> str {
    spec = pod.get("spec", {}) or {};
    for c in (spec.get("containers", []) or []) {
        img = c.get("image");
        if img {
            return _s(img);
        }
    }
    return "";
}


"""Group pods by their `app` label and build per-app image freshness.

Each app: {app, replicas, tag, distinct_digests[], drift, build_sha,
image_ref, pods[]}. `drift` is True when replicas resolved more than one
distinct digest for the same tag (the cross-replica image-cache bug)."""
def build_image_freshness(pods: list) -> dict {
    by_app: dict = {};
    order: list = [];
    for pod in pods {
        meta = pod.get("metadata", {}) or {};
        labels = meta.get("labels", {}) or {};
        app = _s(labels.get("app")) or "unlabeled";
        if app not in by_app {
            by_app[app] = [];
            order.append(app);
        }
        by_app[app].append({
            "pod": _s(meta.get("name")),
            "tag": _pod_image(pod),
            "digest": _pod_image_id(pod),
            "build_sha": _pod_env(pod, "JAC_BUILD_SHA"),
            "image_ref": _pod_env(pod, "JAC_IMAGE_REF")
        });
    }

    apps: list = [];
    for app in order {
        entries = by_app[app];
        digests: list = [];
        tags: list = [];
        for e in entries {
            if e["digest"] and e["digest"] not in digests {
                digests.append(e["digest"]);
            }
            if e["tag"] and e["tag"] not in tags {
                tags.append(e["tag"]);
            }
        }
        # Build identity is read from the first replica that carries it.
        build_sha = "";
        image_ref = "";
        for e in entries {
            if not build_sha and e["build_sha"] {
                build_sha = e["build_sha"];
            }
            if not image_ref and e["image_ref"] {
                image_ref = e["image_ref"];
            }
        }
        apps.append({
            "app": app,
            "replicas": len(entries),
            "tags": tags,
            "distinct_digests": digests,
            "drift": len(digests) > 1,
            "build_sha": build_sha,
            "image_ref": image_ref,
            "pods": entries
        });
    }
    apps.sort(key=lambda a : a.get("app", ""));
    return {"available": True, "apps": apps};
}


# =========================================================================
# (b) Thin pod list -> pure helper.
# =========================================================================

def _collect_images -> dict {
    if not k8s_available() {
        return {"available": False, "detail": unavailable_detail()};
    }
    core = core_api();
    if core is None {
        return {"available": False, "detail": unavailable_detail()};
    }
    ns = ops_namespace();
    try {
        pod_objs = core.list_namespaced_pod(namespace=ns).items;
    } except Exception as e {
        logger.warning(f"image-freshness list failed: {e}");
        return {"available": False, "detail": api_error_detail(e)};
    }
    data = build_image_freshness([p.to_dict() for p in (pod_objs or [])]);
    data["namespace"] = ns;
    return data;
}


impl JacAPIServerImages.register_images_endpoints -> None {
    async def images_handler(request: Request) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get("http_status", 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        try {
            data = _collect_images();
        } except Exception as e {
            logger.warning(f"image-freshness handler error: {e}");
            data = {"available": False, "detail": f"self-check error: {e}"};
        }
        return JSONResponse(content={"ok": True, "data": data});
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/ops/images",
            callback=images_handler,
            parameters=[],
            response_model=None,
            tags=["Operations"],
            summary="Image / build freshness",
            description=(
                "Per app: spec image tag vs resolved imageID digest, cross-"
                "replica digest drift, and the B-01 build identity "
                "(JAC_IMAGE_REF / JAC_BUILD_SHA) from pod env. Answers 'did "
                "my deploy actually update?'. Needs the read-only Ops Console "
                "Role; 'unavailable' off-cluster."
            )
        )
    );
    logger.info("Image-freshness endpoint registered: /admin/ops/images");
}
