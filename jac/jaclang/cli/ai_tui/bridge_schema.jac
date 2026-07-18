import json;

glob SCHEMA_ID: str = "jac.ai_tui.bridge.v1";

glob CMD_KIND_PROMPT: str = "prompt",
     CMD_KIND_ABORT: str = "abort",
     CMD_KIND_RESET: str = "reset",
     CMD_KIND_APPLY_SETTINGS: str = "apply_settings",
     CMD_KIND_SELECT_MODEL: str = "select_model",
     CMD_KIND_LIST_MODELS: str = "list_models",
     CMD_KIND_SEARCH_FILES: str = "search_files",
     CMD_KIND_NEW_SESSION: str = "new_session",
     CMD_KIND_RESUME_SESSION: str = "resume_session",
     CMD_KIND_FORK_SESSION: str = "fork_session";

glob DISP_STARTED: str = "started",
     DISP_QUEUED: str = "queued",
     DISP_NO_OP: str = "no_op",
     DISP_REJECTED: str = "rejected";

glob LIFE_STARTING: str = "starting",
     LIFE_IDLE: str = "idle",
     LIFE_RUNNING: str = "running",
     LIFE_STOPPING: str = "stopping",
     LIFE_QUIESCING: str = "quiescing",
     LIFE_DISPOSED: str = "disposed",
     LIFE_FAILED: str = "failed";

glob MUT_SNAPSHOT_REQUIRED: str = "snapshot_required",
     MUT_AGENT_START: str = "agent_start",
     MUT_AGENT_END: str = "agent_end",
     MUT_AGENT_SETTLED: str = "agent_settled",
     MUT_MESSAGE_START: str = "message_start",
     MUT_MESSAGE_UPDATE: str = "message_update",
     MUT_MESSAGE_END: str = "message_end",
     MUT_TOOL_START: str = "tool_execution_start",
     MUT_TOOL_UPDATE: str = "tool_execution_update",
     MUT_TOOL_END: str = "tool_execution_end",
     MUT_STATUS: str = "runtime_state_changed",
     MUT_DIAGNOSTIC: str = "diagnostic",
     MUT_RUNTIME_REPLACED: str = "runtime_replaced";


def _dumps(value: dict[str, any]) -> str {
    return json.dumps(value, ensure_ascii=False);
}


def _loads(raw: str) -> dict[str, any] {
    data = json.loads(raw);
    if not isinstance(data, dict) {
        raise ValueError("bridge value must be a JSON object");
    }
    return data;
}


def _require_schema(data: dict[str, any]) {
    sid = data.get("schema_id");
    if sid != SCHEMA_ID {
        raise ValueError(f"schema_id mismatch: {sid!r} != {SCHEMA_ID!r}");
    }
}


def encode_receipt(
    accepted: bool,
    disposition: str,
    command_id: str = "",
    prompt_id: str = "",
    error_code: str = "",
    error_message: str = "",
    retryable: bool = False
) -> str {
    return _dumps(
        {
            "schema_id": SCHEMA_ID,
            "kind": "command_receipt",
            "accepted": accepted,
            "disposition": disposition,
            "command_id": command_id,
            "prompt_id": prompt_id,
            "error": {
                "code": error_code,
                "message": error_message,
                "retryable": retryable
            }
        }
    );
}


def decode_receipt(raw: str) -> dict[str, any] {
    data = _loads(raw);
    _require_schema(data);
    if data.get("kind") != "command_receipt" {
        raise ValueError(f"expected command_receipt, got {data.get('kind')!r}");
    }
    return data;
}


def encode_batch(
    epoch: int, first_seq: int, last_seq: int, mutations: list[any]
) -> str {
    return _dumps(
        {
            "schema_id": SCHEMA_ID,
            "kind": "session_event_batch",
            "epoch": epoch,
            "first_seq": first_seq,
            "last_seq": last_seq,
            "mutations": mutations
        }
    );
}


def decode_batch(raw: str) -> dict[str, any] {
    data = _loads(raw);
    _require_schema(data);
    if data.get("kind") != "session_event_batch" {
        raise ValueError(f"expected session_event_batch, got {data.get('kind')!r}");
    }
    if "mutations" not in data or not isinstance(data["mutations"], list) {
        raise ValueError("batch.mutations must be a list");
    }
    return data;
}


def encode_snapshot(
    epoch: int,
    base_seq: int,
    lifecycle: str,
    messages: list[any],
    model_name: str = "",
    active: str = ""
) -> str {
    return _dumps(
        {
            "schema_id": SCHEMA_ID,
            "kind": "ui_snapshot",
            "epoch": epoch,
            "base_seq": base_seq,
            "lifecycle": lifecycle,
            "model_name": model_name,
            "active": active,
            "messages": messages
        }
    );
}


def decode_snapshot(raw: str) -> dict[str, any] {
    data = _loads(raw);
    _require_schema(data);
    if data.get("kind") != "ui_snapshot" {
        raise ValueError(f"expected ui_snapshot, got {data.get('kind')!r}");
    }
    if "messages" not in data or not isinstance(data["messages"], list) {
        raise ValueError("snapshot.messages must be a list");
    }
    return data;
}


def encode_command(
    kind: str, payload: dict[str, any] | None = None, command_id: str = ""
) -> str {
    body: dict[str, any] = payload if payload is not None else {};
    return _dumps(
        {
            "schema_id": SCHEMA_ID,
            "kind": "session_command",
            "command": kind,
            "command_id": command_id,
            "payload": body
        }
    );
}


def decode_command(raw: str) -> dict[str, any] {
    data = _loads(raw);
    _require_schema(data);
    if data.get("kind") != "session_command" {
        raise ValueError(f"expected session_command, got {data.get('kind')!r}");
    }
    return data;
}


def encode_start_result(
    ok: bool, session_id: str = "", epoch: int = 0, error: str = ""
) -> str {
    return _dumps(
        {
            "schema_id": SCHEMA_ID,
            "kind": "start_result",
            "ok": ok,
            "session_id": session_id,
            "epoch": epoch,
            "error": error
        }
    );
}


def decode_start_result(raw: str) -> dict[str, any] {
    data = _loads(raw);
    _require_schema(data);
    if data.get("kind") != "start_result" {
        raise ValueError(f"expected start_result, got {data.get('kind')!r}");
    }
    return data;
}


def encode_dispose_result(
    ok: bool, timed_out: bool = False, reason: str = "", joined_workers: int = 0
) -> str {
    return _dumps(
        {
            "schema_id": SCHEMA_ID,
            "kind": "dispose_result",
            "ok": ok,
            "timed_out": timed_out,
            "reason": reason,
            "joined_workers": joined_workers
        }
    );
}


def decode_dispose_result(raw: str) -> dict[str, any] {
    data = _loads(raw);
    _require_schema(data);
    if data.get("kind") != "dispose_result" {
        raise ValueError(f"expected dispose_result, got {data.get('kind')!r}");
    }
    return data;
}
