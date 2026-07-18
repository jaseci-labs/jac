"""Native mirror of the dual-code-space bridge contract (PLAN.md §5.3).

Complete owned JSON strings per embed call. Array construction uses list[any]
+ .append(). Never use str()/int()/bool() on decoded `any` values — native IR
returns the value's tag; use as_str()/as_int()/as_bool() instead.
"""

import json;

glob SCHEMA_ID: str = "jac.ai_tui.bridge.v1";

glob CMD_KIND_PROMPT: str = "prompt",
     CMD_KIND_ABORT: str = "abort",
     CMD_KIND_RESET: str = "reset",
     CMD_KIND_APPLY_SETTINGS: str = "apply_settings",
     CMD_KIND_SELECT_MODEL: str = "select_model";

glob DISP_STARTED: str = "started",
     DISP_QUEUED: str = "queued",
     DISP_NO_OP: str = "no_op",
     DISP_REJECTED: str = "rejected";

glob LIFE_IDLE: str = "idle",
     LIFE_RUNNING: str = "running",
     LIFE_STOPPING: str = "stopping",
     LIFE_DISPOSED: str = "disposed",
     LIFE_FAILED: str = "failed";

glob MUT_SNAPSHOT_REQUIRED: str = "snapshot_required",
     MUT_AGENT_START: str = "agent_start",
     MUT_AGENT_END: str = "agent_end",
     MUT_AGENT_SETTLED: str = "agent_settled",
     MUT_MESSAGE_START: str = "message_start",
     MUT_MESSAGE_UPDATE: str = "message_update",
     MUT_MESSAGE_END: str = "message_end",
     MUT_STATUS: str = "runtime_state_changed",
     MUT_DIAGNOSTIC: str = "diagnostic";


def _dumps(value: dict[str, any]) -> str {
    return json.dumps(value);
}


def _loads(raw: str) -> dict[str, any] {
    data = json.loads(raw);
    if not isinstance(data, dict) {
        raise ValueError("bridge value must be a JSON object");
    }
    return data;
}


# Native JSON decodes to tagged `any` values. `str(any)` yields the value's
# tag (e.g. "2" for a string), NOT the underlying scalar — so every typed
# extraction from a decoded bridge value MUST go through isinstance+assign.
# This was the Phase 4 startup-seam root cause: `str(data.get("schema_id"))`
# returned the tag and made every real start_result look like a schema mismatch,
# so the host finalized over a live _legacy_feed thread and hung.


def as_str(v: any, fallback: str = "") -> str {
    if isinstance(v, str) {
        s: str = v;
        return s;
    }
    return fallback;
}


def as_int(v: any, fallback: int = 0) -> int {
    if isinstance(v, int) {
        i: int = v;
        return i;
    }
    if isinstance(v, float) {
        f: float = v;
        return int(f);
    }
    if isinstance(v, str) {
        s: str = v;
        try {
            return int(s);
        } except Exception {
            return fallback;
        }
    }
    return fallback;
}


def as_bool(v: any) -> bool {
    if isinstance(v, bool) {
        b: int = v;
        return b != 0;
    }
    if isinstance(v, str) {
        s: str = v;
        if s == "True" or s == "true" or s == "1" {
            return True;
        }
    }
    return False;
}


def _require_schema(data: dict[str, any]) {
    sid: str = as_str(data.get("schema_id", ""));
    if sid != SCHEMA_ID {
        raise ValueError("schema_id mismatch");
    }
}


def _kind_of(data: dict[str, any]) -> str {
    return as_str(data.get("kind", ""));
}


def encode_command(kind: str, payload: dict[str, any], command_id: str = "") -> str {
    body: dict[str, any] = {
        "schema_id": SCHEMA_ID,
        "kind": "session_command",
        "command": kind,
        "command_id": command_id,
        "payload": payload
    };
    return _dumps(body);
}


def decode_command(raw: str) -> dict[str, any] {
    data = _loads(raw);
    _require_schema(data);
    if _kind_of(data) != "session_command" {
        raise ValueError("expected session_command");
    }
    return data;
}


def decode_receipt(raw: str) -> dict[str, any] {
    data = _loads(raw);
    _require_schema(data);
    if _kind_of(data) != "command_receipt" {
        raise ValueError("expected command_receipt");
    }
    return data;
}


def decode_batch(raw: str) -> dict[str, any] {
    data = _loads(raw);
    _require_schema(data);
    if _kind_of(data) != "session_event_batch" {
        raise ValueError("expected session_event_batch");
    }
    muts = data.get("mutations", None);
    if muts is None or not isinstance(muts, list) {
        raise ValueError("batch.mutations must be a list");
    }
    return data;
}


def decode_snapshot(raw: str) -> dict[str, any] {
    data = _loads(raw);
    _require_schema(data);
    if _kind_of(data) != "ui_snapshot" {
        raise ValueError("expected ui_snapshot");
    }
    msgs = data.get("messages", None);
    if msgs is None or not isinstance(msgs, list) {
        raise ValueError("snapshot.messages must be a list");
    }
    return data;
}


def decode_start_result(raw: str) -> dict[str, any] {
    data = _loads(raw);
    _require_schema(data);
    if _kind_of(data) != "start_result" {
        raise ValueError("expected start_result");
    }
    return data;
}


def decode_dispose_result(raw: str) -> dict[str, any] {
    data = _loads(raw);
    _require_schema(data);
    if _kind_of(data) != "dispose_result" {
        raise ValueError("expected dispose_result");
    }
    return data;
}


def encode_start_request(cwd: str, stub: bool, model_name: str) -> str {
    payload: dict[str, any] = {
        "schema_id": SCHEMA_ID,
        "kind": "agent_request",
        "cwd": cwd,
        "stub": stub,
        "model_name": model_name
    };
    return _dumps(payload);
}


def encode_dispose_spec(reason: str, deadline_ms: int) -> str {
    payload: dict[str, any] = {
        "schema_id": SCHEMA_ID,
        "kind": "dispose_spec",
        "reason": reason,
        "deadline_ms": deadline_ms
    };
    return _dumps(payload);
}
