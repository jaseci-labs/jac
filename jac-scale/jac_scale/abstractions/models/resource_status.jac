"""Resource status model."""
import from enum { Enum }

"""Status of a deployed resource."""
class ResourceStatus(Enum) {
    has UNKNOWN: str = 'unknown';
    has PENDING: str = 'pending';
    has RUNNING: str = 'running';
    has FAILED: str = 'failed';
    has STOPPED: str = 'stopped';
}

"""Detailed resource status information."""
class ResourceStatusInfo {
    has status: ResourceStatus;
    has replicas: int = 0;
    has ready_replicas: int = 0;
    has message: (str | None) = None;

    def is_ready(self: ResourceStatusInfo) -> bool {
        return self.status == ResourceStatus.RUNNING and self.replicas > 0 and self.ready_replicas == self.replicas;
    }
}

