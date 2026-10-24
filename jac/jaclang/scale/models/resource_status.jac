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
        current_replicas: int = 0,
        ready_replicas: int = 0,
        available_replicas: int = 0,
        updated_replicas: int = 0,
        replica_floor: int = 1,
        reason: str = "",
        message: (str | None) = None;

    def is_settled -> bool;
    def is_serving -> bool;
}

def field_of(source: any, key: str) -> any;

def _count(source: any, key: str) -> int;

def replica_floor_of(deployment: any) -> int;

def assess_workload(
    deployment: any, crashlooping: bool = False, replica_floor: (int | None) = None
) -> ResourceStatusInfo;
