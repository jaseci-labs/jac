glob ROLLOUT_WAIT_READY: str = "ready",
     ROLLOUT_WAIT_FULL: str = "full",
     ROLLOUT_WAIT_MODES: tuple = ("ready", "full"),
     PROGRESS_DEADLINE_REASON: str = "ProgressDeadlineExceeded",
     STALL_CONFIRM_POLLS: int = 3;


def normalize_rollout_wait(mode: any) -> str {
    candidate = str(mode or ROLLOUT_WAIT_READY).strip().lower();
    if candidate not in ROLLOUT_WAIT_MODES {
        raise ValueError(
            f"invalid rollout wait mode '{mode}': expected one of "
            f"{', '.join(ROLLOUT_WAIT_MODES)}"
        );
    }
    return candidate;
}


def normalize_rollout_timeout(value: any) -> int {
    try {
        seconds = int(value);
    } except (TypeError, ValueError) {
        seconds = 0;
    }
    if seconds < 1 {
        raise ValueError(
            f"invalid rollout timeout '{value}': expected a positive number "
            "of seconds"
        );
    }
    return seconds;
}


def _non_negative_int(value: any) -> int {
    try {
        return max(int(value or 0), 0);
    } except (TypeError, ValueError) {
        return 0;
    }
}


def _field(source: any, name: str) -> any {
    if isinstance(source, dict) {
        return source.get(name);
    }
    return getattr(source, name, None);
}


def _stall_condition(status: any) -> tuple {
    conditions = _field(status, "conditions");
    if not isinstance(conditions, list) {
        return ("", "");
    }
    for cond in conditions {
        if str(_field(cond, "type") or "") != "Progressing" {
            continue;
        }
        reason = str(_field(cond, "reason") or "");
        if reason != PROGRESS_DEADLINE_REASON {
            continue;
        }
        return (reason, str(_field(cond, "message") or "").strip());
    }
    return ("", "");
}


obj RolloutStatus {
    has desired: int = 0,
        updated: int = 0,
        available: int = 0,
        total: int = 0,
        generation: int = 0,
        observed_generation: int = 0,
        stall_reason: str = "",
        stall_message: str = "";

    def is_observed -> bool {
        return self.observed_generation >= self.generation;
    }

    def updated_available -> int {
        outdated = max(self.total - self.updated, 0);
        return max(self.available - outdated, 0);
    }

    def is_complete -> bool {
        return self.updated >= self.desired
            and self.total <= self.updated
            and self.available >= self.desired;
    }

    def satisfies(mode: str) -> bool {
        if not self.is_observed() {
            return False;
        }
        if mode == ROLLOUT_WAIT_FULL or self.desired <= 0 {
            return self.is_complete();
        }
        return self.updated_available() >= 1;
    }

    def stall -> str {
        if not self.stall_reason or not self.is_observed() {
            return "";
        }
        return f"{self.stall_reason}: {self.stall_message}"
            if self.stall_message
            else self.stall_reason;
    }
}


def read_rollout_status(deployment: any) -> RolloutStatus {
    meta = _field(deployment, "metadata");
    spec = _field(deployment, "spec");
    status = _field(deployment, "status");
    (stall_reason, stall_message) = _stall_condition(status);
    return RolloutStatus(
        desired=_non_negative_int(_field(spec, "replicas")),
        updated=_non_negative_int(_field(status, "updated_replicas")),
        available=_non_negative_int(_field(status, "available_replicas")),
        total=_non_negative_int(_field(status, "replicas")),
        generation=_non_negative_int(_field(meta, "generation")),
        observed_generation=_non_negative_int(_field(status, "observed_generation")),
        stall_reason=stall_reason,
        stall_message=stall_message
    );
}
