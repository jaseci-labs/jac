import from typing { Any }

enum SandboxState {
    PENDING = "pending",
    STARTING = "starting",
    RUNNING = "running",
    STOPPING = "stopping",
    STOPPED = "stopped",
    ERROR = "error"
}

obj SandboxStatus {
    has state: SandboxState,
        sandbox_id: str = "",
        uptime_seconds: float = 0.0,
        url: str = "",
        port: int = 0,
        message: (str | None) = None;

    def is_running -> bool {
        return self.state == SandboxState.RUNNING;
    }
}

obj SandboxInfo {
    has sandbox_id: str,
        user_id: str,
        project_id: str,
        state: SandboxState,
        url: str = "",
        created_at: float = 0.0;
}
