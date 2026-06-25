"""Resource status model."""
import from enum { Enum }

"""Status of a deployed resource."""
class ResourceStatus(Enum) {
    has UNKNOWN: str = 'unknown',
        PENDING: str = 'pending',
        RUNNING: str = 'running',
        FAILED: str = 'failed',
        STOPPED: str = 'stopped';
}

"""Detailed resource status information."""
obj ResourceStatusInfo {
    has status: ResourceStatus,
        replicas: int = 0,
        ready_replicas: int = 0,
        message: (str | None) = None;

    def is_ready -> bool {
        return self.status == ResourceStatus.RUNNING
        and self.replicas > 0
        and self.ready_replicas == self.replicas;
    }
}
