import json;
import os;
import sys;

import from jaclang.cli.ai_tui.bridge_schema {
    CMD_KIND_ABORT,
    CMD_KIND_APPLY_SETTINGS,
    CMD_KIND_PROMPT,
    CMD_KIND_RESET,
    DISP_REJECTED,
    DISP_STARTED,
    encode_batch,
    encode_dispose_result,
    encode_receipt,
    encode_snapshot,
    encode_start_result,
    decode_command
}
import from jaclang.cli.ai_tui.ipc_schema {
    RECEIPT_ACCEPTED,
    RECEIPT_REJECTED_BUSY,
    RECEIPT_REJECTED_EMPTY,
    RECEIPT_REJECTED_ERROR,
    RECEIPT_OK
}
import from jaclang.cli.ai_tui.session_models {
    CommandError,
    CommandReceipt,
    SessionCommand,
    mutation_dict
}
import from jaclang.cli.ai_tui.tui_session_adapter {
    TuiSessionAdapter,
    make_abort_command,
    make_prompt_command,
    make_reset_command
}
import from jaclang.cli.ai_tui.tui_shared {
    _dispatch_cmd,
    _debug_log,
    _silence_logging_for_tui
}


glob _adapter: TuiSessionAdapter | None = None,
     _poll_count: int = 0;


def _apply_path_env {
    byllm = os.environ.get("JAC_AI_TUI_BYLLM_SRC", "");
    if byllm and byllm not in sys.path {
        sys.path.insert(0, byllm);
    }
    for d in os.environ.get("JAC_AI_TUI_DEPS", "").split(os.pathsep) {
        if d and d not in sys.path {
            sys.path.append(d);
        }
    }
}


def _active -> TuiSessionAdapter {
    if _adapter is None {
        raise RuntimeError("embed agent not started");
    }
    return _adapter;
}


def _receipt_obj(receipt: CommandReceipt) -> str {
    err = receipt.error if receipt.error is not None else CommandError();
    return encode_receipt(
        receipt.accepted,
        receipt.disposition,
        command_id=receipt.command_id,
        prompt_id=receipt.prompt_id,
        error_code=err.code,
        error_message=err.message,
        retryable=err.retryable
    );
}


def _receipt_wire(receipt: CommandReceipt) -> str {
    if receipt.accepted {
        if receipt.disposition == DISP_STARTED or receipt.disposition == "started" {
            return RECEIPT_ACCEPTED;
        }
        return RECEIPT_OK;
    }
    code = "";
    try {
        code = str(receipt.error.code);
    } except Exception {
        code = "";
    }
    if code == "busy" {
        return RECEIPT_REJECTED_BUSY;
    }
    if code == "empty" {
        return RECEIPT_REJECTED_EMPTY;
    }
    return RECEIPT_REJECTED_ERROR;
}


def _start_adapter(
    stub: bool, model_name: str = "stub", reason: str = ""
) -> dict[str, any] {
    global _adapter;
    if reason {
        sys.stderr.write(f"jac-ai-tui: using stub agent ({reason})\n");
        sys.stderr.write(
            "  set JAC_AI_TUI_BYLLM_SRC=<jac-byllm checkout> and "
            "JAC_AI_TUI_DEPS=<dep dirs (litellm, openai, ...)> for the real agent.\n"
        );
    }
    adapter = TuiSessionAdapter(cwd=os.getcwd(), stub=stub, model_name=model_name);
    result = adapter.start(
        {"cwd": os.getcwd(), "stub": stub, "model_name": model_name}
    );
    if not result.ok {
        return {"ok": False, "error": result.error or "adapter start failed"};
    }
    _adapter = adapter;
    return {
        "ok": True,
        "session_id": result.session_id,
        "epoch": result.epoch,
        "error": ""
    };
}


def _start_real -> dict[str, any] {
    import from jaclang.cli.ai_agent { ui_configure }
    import from jaclang.cli.ai_tui.tui_shared { _debug_log }

    _debug_log("_start_real: calling ui_configure");
    ui_configure();

    import from jaclang.cli.ai_agent { agent as _agent_rt, agent_model as _am }
    model_name = "";
    try {
        model_name = str(_am.model_name);
    } except Exception {
        model_name = str(_agent_rt.bus.model_name);
    }
    _debug_log(
        f"_start_real: ui_configure done; bus.model_name={_agent_rt.bus.model_name!r} agent_model={model_name!r}"
    );
    return _start_adapter(stub=False, model_name=model_name or "agent");
}


def _parse_start_request(request: str) -> dict[str, any] {
    if not request or not request.strip() {
        return {};
    }
    data = json.loads(request);
    if not isinstance(data, dict) {
        raise ValueError("start request must be a JSON object");
    }
    return data;
}


def start(request: str = "{}") -> str {
    global _adapter,_poll_count;
    _apply_path_env();
    _silence_logging_for_tui();
    _poll_count = 0;
    if _adapter is not None {
        try {
            _adapter.dispose(reason="re-start", deadline_ms=1000);
        } except Exception { }
        _adapter = None;
    }
    body = _parse_start_request(request);
    prefer_stub = bool(body.get("stub", False));
    model_name = str(body.get("model_name", "") or "");
    _debug_log(
        f"start: stub={prefer_stub!r} model={model_name!r} "
        f"JAC_AI_UI_MODEL={os.environ.get('JAC_AI_UI_MODEL', '<unset>')!r}"
    );
    if prefer_stub {
        got = _start_adapter(stub=True, model_name=model_name or "stub");
        return encode_start_result(
            bool(got.get("ok")),
            session_id=str(got.get("session_id", "")),
            epoch=int(got.get("epoch", 0)),
            error=str(got.get("error", ""))
        );
    }
    try {
        got = _start_real();
        return encode_start_result(
            True,
            session_id=str(got.get("session_id", "")),
            epoch=int(got.get("epoch", 0))
        );
    } except Exception as e {
        _debug_log(f"_start_real failed: {e}");
        if os.environ.get("JAC_AI_TUI_NO_STUB") {
            return encode_start_result(False, error=str(e));
        }
        got = _start_adapter(stub=True, model_name="stub", reason=str(e));
        return encode_start_result(
            bool(got.get("ok")),
            session_id=str(got.get("session_id", "")),
            epoch=int(got.get("epoch", 0)),
            error=str(got.get("error", ""))
        );
    }
}


def submit(command: str) -> str {
    adapter = _active();
    try {
        data = decode_command(command);
    } except Exception as e {
        return encode_receipt(
            False, DISP_REJECTED, error_code="bad_command", error_message=str(e)
        );
    }
    kind = str(data.get("command", ""));
    command_id = str(data.get("command_id", ""));
    raw_payload = data.get("payload", {});
    body: dict[str, any] = raw_payload if isinstance(raw_payload, dict) else {};

    if kind == CMD_KIND_PROMPT {
        text = str(body.get("text", ""));
        return _receipt_obj(adapter.submit(make_prompt_command(text, command_id)));
    }
    if kind == CMD_KIND_ABORT {
        return _receipt_obj(adapter.submit(make_abort_command(command_id)));
    }
    if kind == CMD_KIND_RESET {
        return _receipt_obj(adapter.submit(make_reset_command(command_id)));
    }
    if kind == CMD_KIND_APPLY_SETTINGS {
        raw = str(body.get("raw", ""));
        if adapter.stub {
            return encode_receipt(
                False,
                DISP_REJECTED,
                command_id=command_id,
                error_code="stub",
                error_message="apply not supported in stub"
            );
        }
        import from threading { Event }
        line = "APPLY:" + raw if raw else "APPLY";
        try {
            _dispatch_cmd(line, Event(), None);
            return encode_receipt(True, "ok", command_id=command_id);
        } except Exception as e {
            return encode_receipt(
                False,
                DISP_REJECTED,
                command_id=command_id,
                error_code="apply_failed",
                error_message=str(e)
            );
        }
    }
    return encode_receipt(
        False,
        DISP_REJECTED,
        command_id=command_id,
        error_code="unknown",
        error_message=kind
    );
}


def poll(cap: str = "64") -> str {
    global _poll_count;
    _poll_count += 1;
    adapter = _active();
    n = 64;
    try {
        n = int(cap);
    } except Exception {
        n = 64;
    }
    if n <= 0 {
        n = 64;
    }
    batch = adapter.poll(n);
    muts: list[any] = [];
    for m in batch.mutations {
        muts.append(mutation_dict(m));
    }
    if _poll_count <= 5 or _poll_count % 100 == 0 {
        _debug_log(
            f"poll typed #{_poll_count} batched={len(muts)} epoch={batch.epoch}"
        );
    }
    return encode_batch(batch.epoch, batch.first_seq, batch.last_seq, muts);
}


def snapshot -> str {
    adapter = _active();
    snap = adapter.snapshot();
    msgs: list[any] = [];
    for m in snap.messages {
        parts: list[any] = [];
        for p in m.parts {
            parts.append(
                {
                    "id": p.id,
                    "part_type": p.part_type,
                    "text": p.text,
                    "tool_name": p.tool_name,
                    "tool_args": p.tool_args,
                    "image_ref": p.image_ref
                }
            );
        }
        msgs.append(
            {"id": m.id, "role": m.role, "created_at": m.created_at, "parts": parts}
        );
    }
    return encode_snapshot(
        snap.epoch,
        snap.base_seq,
        snap.lifecycle,
        msgs,
        model_name=snap.model_name,
        active=snap.active
    );
}


def dispose(spec: str = "{}") -> str {
    global _adapter;
    reason = "dispose";
    deadline_ms = 2000;
    try {
        data = json.loads(spec) if spec else {};
        if isinstance(data, dict) {
            reason = str(data.get("reason", reason));
            deadline_ms = int(data.get("deadline_ms", deadline_ms));
        }
    } except Exception { }
    if _adapter is None {
        return encode_dispose_result(True, False, reason, 0);
    }
    result = _adapter.dispose(reason=reason, deadline_ms=deadline_ms);
    if not _adapter.stub {
        try {
            import from jaclang.cli.ai_agent { ui_stop }
            ui_stop();
        } except Exception as e {
            _debug_log(f"dispose: ui_stop failed: {e}");
        }
    }
    _adapter = None;
    return encode_dispose_result(
        result.ok, result.timed_out, result.reason, result.joined_workers
    );
}


def setup {
    start("{}");
}


def poll_legacy -> str {
    adapter = _active();
    batch = adapter.poll(64);
    if not batch.mutations {
        return "";
    }
    import from jaclang.cli.ai_tui.tui_shared { _frame_blob }
    snap = adapter.snapshot();
    events = [];
    for m in batch.mutations {
        if m.kind == "message_start" and m.op == "user" {
            events.append(
                {
                    "id": int(m.message_id) if str(m.message_id).isdigit() else 1,
                    "kind": "user",
                    "node": "session",
                    "text": m.text
                }
            );
        } elif m.kind == "message_update" {
            events.append(
                {
                    "id": int(m.message_id) if str(m.message_id).isdigit() else 1,
                    "kind": "answer",
                    "node": "session",
                    "text": m.text
                }
            );
        } elif m.kind == "diagnostic" or m.kind == "runtime_state_changed" {
            if m.text or m.diagnostic {
                events.append(
                    {
                        "id": 1,
                        "kind": "system",
                        "node": "session",
                        "text": m.text or m.diagnostic
                    }
                );
            }
        }
    }
    frame = {
        "status": snap.lifecycle or "idle",
        "model_name": snap.model_name or adapter.model_name,
        "events": events
    };
    return _frame_blob(frame);
}


def send(line: str) -> str {
    adapter = _active();
    raw = line.strip();
    if not raw {
        return RECEIPT_REJECTED_EMPTY;
    }
    verb = "";
    payload = "";
    colon = raw.find(":");
    if colon > 0 {
        verb = raw[:colon].upper();
        payload = raw[colon + 1:];
    } else {
        parts = raw.split(None, 1);
        verb = parts[0].upper();
        payload = parts[1] if len(parts) > 1 else "";
    }

    if verb == "SEND" {
        receipt = adapter.submit(make_prompt_command(payload));
        return _receipt_wire(receipt);
    }
    if verb == "STOP" {
        receipt = adapter.submit(make_abort_command());
        return _receipt_wire(receipt);
    }
    if verb == "RESET" {
        receipt = adapter.submit(make_reset_command());
        return _receipt_wire(receipt);
    }
    if verb == "QUIT" {
        adapter.submit(make_abort_command());
        return RECEIPT_OK;
    }
    if adapter.stub {
        return RECEIPT_REJECTED_ERROR;
    }
    import from threading { Event }
    return _dispatch_cmd(line, Event(), None);
}


def stop {
    dispose(
        '{"schema_id":"jac.ai_tui.bridge.v1","kind":"dispose_spec","reason":"stop","deadline_ms":2000}'
    );
}
