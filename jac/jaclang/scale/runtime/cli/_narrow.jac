def dget(blob: any, key: str) -> dict {
    if not isinstance(blob, dict) {
        return {};
    }
    val = blob.get(key);
    return val if isinstance(val, dict) else {};
}


def lget(blob: any, key: str) -> list {
    if not isinstance(blob, dict) {
        return [];
    }
    val = blob.get(key);
    return val if isinstance(val, list) else [];
}


def sget(blob: any, key: str) -> str | None {
    if not isinstance(blob, dict) {
        return None;
    }
    val = blob.get(key);
    return str(val) if val is not None else None;
}


def bget(blob: any, key: str, fallback: bool) -> bool {
    if not isinstance(blob, dict) {
        return fallback;
    }
    val = blob.get(key);
    return bool(val) if val is not None else fallback;
}


def iget(blob: any, key: str, fallback: int) -> int {
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


def fget(blob: any, key: str, fallback: float) -> float {
    if not isinstance(blob, dict) {
        return fallback;
    }
    val = blob.get(key);
    if val is None {
        return fallback;
    }
    try {
        return float(val);
    } except Exception {
        return fallback;
    }
}


def pod_spec(deployment: any) -> dict {
    return dget(dget(dget(deployment, "spec"), "template"), "spec");
}


def effective_resources(
    deployment: any
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
