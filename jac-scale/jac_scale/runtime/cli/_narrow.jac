"""Shared narrowing helpers for plan.jac + diagnostics.jac.

The K8s manifest bundle that flows through the dry-run path is
heterogeneous (every key is typed `Any`); these helpers are the
single boundary where Any is narrowed to dict / list / str / int /
bool with sensible fallbacks. Both plan rendering and lint
validation import from here, so they cross the boundary the same way."""

import from typing { Any }


def dget(blob: Any, key: str) -> dict {
    if not isinstance(blob, dict) {
        return {};
    }
    val = blob.get(key);
    return val if isinstance(val, dict) else {};
}


def lget(blob: Any, key: str) -> list {
    if not isinstance(blob, dict) {
        return [];
    }
    val = blob.get(key);
    return val if isinstance(val, list) else [];
}


def sget(blob: Any, key: str) -> str | None {
    if not isinstance(blob, dict) {
        return None;
    }
    val = blob.get(key);
    return str(val) if val is not None else None;
}


def bget(blob: Any, key: str, fallback: bool) -> bool {
    if not isinstance(blob, dict) {
        return fallback;
    }
    val = blob.get(key);
    return bool(val) if val is not None else fallback;
}


def iget(blob: Any, key: str, fallback: int) -> int {
    if not isinstance(blob, dict) {
        return fallback;
    }
    val = blob.get(key);
    if val is None {
        return fallback;
    }
    try {
        return int(val);
    } except Exception {
        return fallback;
    }
}


"""First pod template spec from a Deployment manifest; {} if absent.
Walks .spec.template.spec which is the canonical K8s pod-spec
location for Deployment/StatefulSet/DaemonSet/Job."""
def pod_spec(deployment: Any) -> dict {
    return dget(dget(dget(deployment, "spec"), "template"), "spec");
}


"""Pull (cpu_request, cpu_limit, mem_request, mem_limit) from the first
container of a rendered Deployment. None for any field that didn't
make it into the manifest (post-fallback effective values)."""
def effective_resources(
    deployment: Any
) -> tuple[str | None, str | None, str | None, str | None] {
    containers = lget(pod_spec(deployment), "containers");
    if not containers or not isinstance(containers[0], dict) {
        return (None, None, None, None);
    }
    resources = dget(containers[0], "resources");
    requests = dget(resources, "requests");
    limits = dget(resources, "limits");
    return (
        sget(requests, "cpu"),
        sget(limits, "cpu"),
        sget(requests, "memory"),
        sget(limits, "memory")
    );
}
