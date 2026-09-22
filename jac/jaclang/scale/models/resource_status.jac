import from enum { StrEnum }

glob REPLICA_FLOOR_ANNOTATION: str = "jac-scale.replica-floor";

enum ResourceStatus(StrEnum) {
    UNKNOWN = "unknown",
    INACTIVE = "inactive",
    ACTIVATING = "activating",
    ACTIVE = "active",
    DEACTIVATING = "deactivating",
    DEGRADED = "degraded"
}

obj ResourceStatusInfo {
    has status: ResourceStatus,
        replicas: int = 0,
        ready_replicas: int = 0,
        available_replicas: int = 0,
        updated_replicas: int = 0,
        replica_floor: int = 1,
        reason: str = "",
        message: (str | None) = None;

    def is_settled -> bool {
        return self.status in (ResourceStatus.ACTIVE, ResourceStatus.INACTIVE);
    }

    def is_serving -> bool {
        if self.status == ResourceStatus.DEGRADED {
            return False;
        }
        return self.is_settled() or self.ready_replicas >= 1;
    }
}

def _field(source: any, key: str) -> any {
    if source is None {
        return None;
    }
    if isinstance(source, dict) {
        return source.get(key);
    }
    return getattr(source, key, None);
}

def _count(source: any, key: str) -> int {
    return int(_field(source, key) or 0);
}

def replica_floor_of(deployment: any) -> int {
    annotations = _field(_field(deployment, "metadata"), "annotations") or {};
    try {
        return int(annotations.get(REPLICA_FLOOR_ANNOTATION));
    } except (TypeError, ValueError) {
        return 1;
    }
}

def assess_workload(
    deployment: any, crashlooping: bool = False, replica_floor: (int | None) = None
) -> ResourceStatusInfo {
    if deployment is None {
        return ResourceStatusInfo(
            status=ResourceStatus.UNKNOWN,
            reason="NotFound",
            message="deployment not found"
        );
    }
    metadata = _field(deployment, "metadata");
    spec = _field(deployment, "spec");
    status = _field(deployment, "status");
    desired_raw = _field(spec, "replicas");
    info = ResourceStatusInfo(
        status=ResourceStatus.UNKNOWN,
        replicas=int(desired_raw) if desired_raw is not None else 1,
        ready_replicas=_count(status, "ready_replicas"),
        available_replicas=_count(status, "available_replicas"),
        updated_replicas=_count(status, "updated_replicas"),
        replica_floor=replica_floor
            if replica_floor is not None
            else replica_floor_of(deployment)
    );
    current = _count(status, "replicas");

    def verdict(
        state: ResourceStatus, reason: str = "", message: str = ""
    ) -> ResourceStatusInfo {
        info.status = state;
        info.reason = reason;
        info.message = message or None;
        return info;
    }

    for cond in (_field(status, "conditions") or []) {
        if _field(cond, "type") == "Progressing"
            and _field(cond, "reason") == "ProgressDeadlineExceeded" {
            return verdict(
                ResourceStatus.DEGRADED,
                "ProgressDeadlineExceeded",
                str(_field(cond, "message") or "")
            );
        }
    }
    if info.replicas == 0 {
        if info.replica_floor > 0 {
            return verdict(
                ResourceStatus.DEGRADED,
                "ScaledBelowFloor",
                f"0 replicas, replica floor is {info.replica_floor}"
            );
        }
        if current > 0 {
            return verdict(ResourceStatus.DEACTIVATING, "ScalingToZero");
        }
        return verdict(ResourceStatus.INACTIVE, "Idle");
    }
    if _count(status, "observed_generation") < _count(metadata, "generation") {
        return verdict(ResourceStatus.ACTIVATING, "RolloutPending");
    }
    if info.updated_replicas > info.replicas {
        return verdict(ResourceStatus.DEACTIVATING, "ScalingDown");
    }
    if info.updated_replicas < info.replicas
        or info.available_replicas < info.replicas
        or current > info.updated_replicas {
        if crashlooping {
            return verdict(
                ResourceStatus.DEGRADED, "CrashLoopBackOff", "pods are restarting"
            );
        }
        return verdict(ResourceStatus.ACTIVATING, "RollingOut");
    }
    return verdict(ResourceStatus.ACTIVE);
}
