"""EmbedSessionClient — session-shaped native adapter over EmbedRuntime.

Performs bridge encode/decode; exposes owned session values to the TUI loop.
Does not import CPython symbols (PLAN.md §5.4).
"""

import from .embed_runtime { EmbedRuntime }
import from .embed_models {
    AgentRequest,
    NativeCommandReceipt,
    NativeStartResult,
    NativeDisposeResult,
    NativeSessionBatch,
    NativeUiSnapshot
}
import from .bridge_schema {
    encode_command,
    encode_start_request,
    encode_dispose_spec,
    decode_receipt,
    decode_batch,
    decode_snapshot,
    decode_start_result,
    decode_dispose_result,
    as_str,
    as_int,
    as_bool,
    CMD_KIND_PROMPT,
    CMD_KIND_ABORT,
    CMD_KIND_RESET,
    CMD_KIND_APPLY_SETTINGS,
    DISP_REJECTED
}
import from .state { TuiState, EventKind }
import from .session_apply { apply_batch, apply_snapshot }
import from .ipc_schema {
    CMD_SEND,
    CMD_STOP,
    CMD_RESET,
    CMD_QUIT,
    CMD_APPLY,
    RECEIPT_ACCEPTED,
    RECEIPT_REJECTED_BUSY,
    RECEIPT_REJECTED_EMPTY,
    RECEIPT_REJECTED_ERROR
}
import from .transport { CmdQueue }


obj EmbedSessionClient {
    has runtime: EmbedRuntime = EmbedRuntime(),
        started: bool = False,
        backend_dead: bool = False,
        last_epoch: int = 0;

    def start(req: AgentRequest) -> NativeStartResult {
        raw_req = encode_start_request(req.cwd, req.stub, req.model_name);
        call = self.runtime.call_start(raw_req);
        if not call.ok {
            # Managed start() never executed: no AgentSessionRuntime, no feed
            # thread. Nothing to quiesce; leave worker safety False so the
            # host's finalize_if_safe skips cleanly instead of force-finalizing.
            self.backend_dead = True;
            return NativeStartResult(ok=False, error=call.error);
        }
        # --- Managed start() executed: AgentSessionRuntime + _legacy_feed may live. ---
        try {
            data = decode_start_result(call.value);
            ok = as_bool(data.get("ok", False));
            result = NativeStartResult(
                ok=ok,
                session_id=as_str(data.get("session_id", "")),
                epoch=as_int(data.get("epoch", 0)),
                error=as_str(data.get("error", ""))
            );
            if ok {
                self.started = True;
                self.last_epoch = result.epoch;
                return result;
            }
            # Managed reported failure after side effects: bounded cleanup.
            self._cleanup_started_runtime(
                reason=result.error if result.error else "start_rejected"
            );
            return result;
        } except Exception {
            # Decode failed AFTER managed startup side effects. start() is a
            # side-effecting transaction: bounded cleanup, never "nothing started"
            # (the host must not finalize over a live _legacy_feed thread).
            self._cleanup_started_runtime(reason="bad_start_result");
            return NativeStartResult(ok=False, error="bad_start_result");
        }
    }

    def _cleanup_started_runtime(reason: str) {
        # Bounded dispose quiesces any workers the managed start() created.
        # Worker safety is set from runtime-confirmed quiescence (dispose's
        # timed_out), NOT from start.ok — so the host finalize gate never
        # finalizes over a live feed thread (the Phase 4 hang root cause).
        # Safe idempotent no-op if managed start() left nothing running.
        self.dispose(reason=reason, deadline_ms=1000);
        self.backend_dead = True;
    }

    def submit_prompt(text: str, command_id: str = "") -> NativeCommandReceipt {
        payload: dict[str, any] = {};
        payload["text"] = text;
        return self._submit_encoded(
            encode_command(CMD_KIND_PROMPT, payload, command_id)
        );
    }

    def submit_abort(command_id: str = "") -> NativeCommandReceipt {
        empty: dict[str, any] = {};
        return self._submit_encoded(
            encode_command(CMD_KIND_ABORT, empty, command_id)
        );
    }

    def submit_reset(command_id: str = "") -> NativeCommandReceipt {
        empty: dict[str, any] = {};
        return self._submit_encoded(
            encode_command(CMD_KIND_RESET, empty, command_id)
        );
    }

    def submit_apply_raw(raw_args: str) -> NativeCommandReceipt {
        payload: dict[str, any] = {};
        payload["raw"] = raw_args;
        return self._submit_encoded(
            encode_command(CMD_KIND_APPLY_SETTINGS, payload, "")
        );
    }

    def poll(cap: int = 64) -> NativeSessionBatch {
        call = self.runtime.call_poll(cap);
        if not call.ok {
            self.backend_dead = True;
            return NativeSessionBatch();
        }
        if not call.value {
            return NativeSessionBatch();
        }
        try {
            data = decode_batch(call.value);
            muts = data.get("mutations", None);
            out_muts: list[any] = [];
            if muts is not None {
                if isinstance(muts, list) {
                    for m in muts {
                        out_muts.append(m);
                    }
                }
            }
            epoch = as_int(data.get("epoch", 0));
            if epoch != 0 {
                self.last_epoch = epoch;
            }
            return NativeSessionBatch(
                epoch=epoch,
                first_seq=as_int(data.get("first_seq", 0)),
                last_seq=as_int(data.get("last_seq", 0)),
                mutations=out_muts,
                raw=call.value
            );
        } except Exception {
            self.backend_dead = True;
            return NativeSessionBatch();
        }
    }

    def snapshot -> NativeUiSnapshot {
        call = self.runtime.call_snapshot();
        if not call.ok {
            self.backend_dead = True;
            return NativeUiSnapshot();
        }
        try {
            data = decode_snapshot(call.value);
            msgs = data.get("messages", None);
            out_msgs: list[any] = [];
            if msgs is not None {
                if isinstance(msgs, list) {
                    for m in msgs {
                        out_msgs.append(m);
                    }
                }
            }
            return NativeUiSnapshot(
                epoch=as_int(data.get("epoch", 0)),
                base_seq=as_int(data.get("base_seq", 0)),
                lifecycle=as_str(data.get("lifecycle", "idle")),
                model_name=as_str(data.get("model_name", "")),
                active=as_str(data.get("active", "")),
                messages=out_msgs,
                raw=call.value
            );
        } except Exception {
            return NativeUiSnapshot();
        }
    }

    def dispose(reason: str = "dispose", deadline_ms: int = 2000) -> NativeDisposeResult {
        spec = encode_dispose_spec(reason, deadline_ms);
        call = self.runtime.call_dispose(spec);
        if not call.ok {
            return NativeDisposeResult(
                ok=False, timed_out=True, reason=reason, joined_workers=0
            );
        }
        try {
            data = decode_dispose_result(call.value);
            result = NativeDisposeResult(
                ok=as_bool(data.get("ok", True)),
                timed_out=as_bool(data.get("timed_out", False)),
                reason=as_str(data.get("reason", reason)),
                joined_workers=as_int(data.get("joined_workers", 0))
            );
            self.started = False;
            self.runtime.mark_workers_safe(not result.timed_out);
            return result;
        } except Exception {
            return NativeDisposeResult(
                ok=False, timed_out=True, reason=reason, joined_workers=0
            );
        }
    }

    def drain_into(state: TuiState, cap: int = 64) -> bool {
        if self.backend_dead {
            return False;
        }
        batch = self.poll(cap);
        if self.backend_dead {
            return False;
        }
        if not batch.raw {
            return True;
        }
        try {
            data = decode_batch(batch.raw);
            need_snap = apply_batch(state, data);
            if need_snap {
                snap = self.snapshot();
                if snap.raw {
                    apply_snapshot(state, decode_snapshot(snap.raw));
                }
            }
            return True;
        } except Exception {
            return False;
        }
    }

    def flush_outbound_cmds(cmd_queue: CmdQueue, state: TuiState) {
        for cmd in cmd_queue.drain_all() {
            receipt = self._dispatch_legacy_cmd(cmd);
            if len(cmd) >= 5 {
                if cmd[:5] == CMD_SEND + ":" {
                    _apply_send_receipt(state, receipt);
                }
            }
        }
    }

    def _dispatch_legacy_cmd(cmd: str) -> NativeCommandReceipt {
        raw = cmd.strip();
        if not raw {
            return NativeCommandReceipt(
                accepted=False,
                disposition=DISP_REJECTED,
                error_code="empty",
                error_message="empty"
            );
        }
        verb: str = "";
        payload: str = "";
        colon = -1;
        i: int = 0;
        rlen = len(raw);
        while i < rlen {
            if raw[i] == ":" {
                colon = i;
                break;
            }
            i += 1;
        }
        if colon > 0 {
            verb = raw[:colon].upper();
            payload = raw[colon + 1:];
        } else {
            parts = raw.split(" ");
            if parts {
                verb = parts[0].upper();
                if len(parts) > 1 {
                    payload = " ".join(parts[1:]);
                }
            }
        }
        if verb == CMD_SEND {
            return self.submit_prompt(payload);
        }
        if verb == CMD_STOP {
            return self.submit_abort();
        }
        if verb == CMD_RESET {
            return self.submit_reset();
        }
        if verb == CMD_QUIT {
            self.submit_abort();
            return NativeCommandReceipt(accepted=True, disposition="ok");
        }
        if verb == CMD_APPLY {
            return self.submit_apply_raw(payload);
        }
        return NativeCommandReceipt(
            accepted=False,
            disposition=DISP_REJECTED,
            error_code="unknown",
            error_message=verb
        );
    }

    def _submit_encoded(wire: str) -> NativeCommandReceipt {
        call = self.runtime.call_submit(wire);
        if not call.ok {
            self.backend_dead = True;
            return NativeCommandReceipt(
                accepted=False,
                disposition=DISP_REJECTED,
                error_code="python_exc",
                error_message=call.error
            );
        }
        try {
            data = decode_receipt(call.value);
            err = data.get("error", None);
            code = "";
            msg = "";
            if err is not None {
                if isinstance(err, dict) {
                    ed: dict[str, any] = err;
                    code = as_str(ed.get("code", ""));
                    msg = as_str(ed.get("message", ""));
                }
            }
            return NativeCommandReceipt(
                accepted=as_bool(data.get("accepted", False)),
                disposition=as_str(data.get("disposition", DISP_REJECTED)),
                command_id=as_str(data.get("command_id", "")),
                prompt_id=as_str(data.get("prompt_id", "")),
                error_code=code,
                error_message=msg
            );
        } except Exception {
            return NativeCommandReceipt(
                accepted=False,
                disposition=DISP_REJECTED,
                error_code="bad_receipt",
                error_message="decode failed"
            );
        }
    }
}


def _apply_send_receipt(state: TuiState, receipt: NativeCommandReceipt) {
    pending = state.pending_submission;
    if not pending.active {
        return;
    }
    if receipt.accepted {
        text = pending.text;
        if text {
            state.editor.add_history(text);
        }
        state.editor.clear();
        pending.clear();
        state.scroll_to_bottom();
        state.mark_layout_dirty();
        return;
    }
    pending.clear();
    detail = receipt.error_code if receipt.error_code else receipt.error_message;
    if not detail {
        detail = RECEIPT_REJECTED_ERROR;
    }
    state.upsert_event(-102, EventKind.ERROR, "prompt rejected: " + detail, "host");
    state.mark_layout_dirty();
}
