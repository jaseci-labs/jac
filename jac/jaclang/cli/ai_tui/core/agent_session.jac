import time;
import uuid;
import from threading { Event, Thread, Lock }

import from jaclang.cli.ai_tui.bridge_schema {
    CMD_KIND_ABORT,
    CMD_KIND_PROMPT,
    CMD_KIND_RESET,
    DISP_NO_OP,
    DISP_REJECTED,
    DISP_STARTED,
    LIFE_DISPOSED,
    LIFE_FAILED,
    LIFE_IDLE,
    LIFE_RUNNING,
    LIFE_STOPPING,
    MUT_AGENT_END,
    MUT_AGENT_SETTLED,
    MUT_AGENT_START,
    MUT_DIAGNOSTIC,
    MUT_MESSAGE_START,
    MUT_STATUS
}
import from jaclang.cli.ai_tui.session_models {
    CommandError,
    CommandReceipt,
    DisposeResult,
    SessionCommand,
    SessionMutation,
    SessionSnapshot,
    Subscription,
    UiMutation
}
import from jaclang.cli.ai_tui.core.session_manager { SessionManager }


obj AgentSession {
    has session_id: str = "",
        cwd: str = "",
        manager: SessionManager = SessionManager(),
        model_name: str = "stub",
        stub: bool = True,
        lifecycle: str = LIFE_IDLE,
        settled: bool = True,
        cancel_requested: bool = False,
        disposed: bool = False,
        _stop: any = None,
        _worker: any = None,
        _workers: list[any] = [],
        _lock: any = None,
        _listeners: list[any] = [],
        _sub_seq: int = 0,
        _prompt_id: int = 0;

    def postinit {
        if not self.session_id {
            self.session_id = str(uuid.uuid4());
        }
        if self._stop is None {
            self._stop = Event();
        }
        if self._lock is None {
            self._lock = Lock();
        }
    }

    def submit(cmd: SessionCommand) -> CommandReceipt {
        if self.disposed {
            return CommandReceipt(
                accepted=False,
                disposition=DISP_REJECTED,
                command_id=cmd.command_id,
                error=CommandError(code="disposed", message="session disposed")
            );
        }
        kind = cmd.kind;
        if kind == CMD_KIND_PROMPT or kind == "prompt" or kind == "SEND" {
            return self._submit_prompt(cmd);
        }
        if kind == CMD_KIND_ABORT or kind == "abort" or kind == "STOP" {
            return self._submit_abort(cmd);
        }
        if kind == CMD_KIND_RESET or kind == "reset" or kind == "RESET" {
            return self._submit_reset(cmd);
        }
        return CommandReceipt(
            accepted=False,
            disposition=DISP_REJECTED,
            command_id=cmd.command_id,
            error=CommandError(code="unknown_command", message=f"unknown: {kind}")
        );
    }

    def subscribe(listener: any) -> Subscription {
        self._sub_seq += 1;
        sid = f"sub{self._sub_seq}";
        self._listeners.append((sid, listener));
        return Subscription(id=sid, active=True);
    }

    def unsubscribe(sub: Subscription) {
        kept: list[any] = [];
        for (sid, listener) in self._listeners {
            if sid != sub.id {
                kept.append((sid, listener));
            }
        }
        self._listeners = kept;
        sub.active = False;
    }

    def snapshot -> SessionSnapshot {
        return SessionSnapshot(
            session_id=self.session_id,
            cwd=self.cwd,
            lifecycle=self.lifecycle,
            model_name=self.model_name,
            settled=self.settled
        );
    }

    def start_feed {
        if self._worker is not None {
            return;
        }
        self._stop.clear();
        if self.stub {
            self._worker = Thread(target=self._stub_feed, daemon=False);
        } else {
            self._worker = Thread(target=self._legacy_feed, daemon=False);
        }
        self._workers.append(self._worker);
        self._worker.start();
        self._emit_status(LIFE_IDLE);
    }

    def dispose(reason: str = "dispose", deadline_ms: int = 2000) -> DisposeResult {
        if self.disposed {
            return DisposeResult(ok=True, reason=reason, joined_workers=0);
        }
        self.disposed = True;
        self.lifecycle = LIFE_DISPOSED;
        self._stop.set();
        joined = 0;
        timed_out = False;
        timeout_s = max(0.0, deadline_ms / 1000.0);
        deadline = time.monotonic() + timeout_s;
        for w in list(self._workers) {
            remaining = max(0.0, deadline - time.monotonic());
            w.join(remaining);
            if w.is_alive() {
                timed_out = True;
            } else {
                joined += 1;
            }
        }
        self._workers = [];
        self._worker = None;
        self.manager.dispose();
        self._listeners = [];
        if timed_out {
            return DisposeResult(
                ok=False, timed_out=True, reason=reason, joined_workers=joined
            );
        }
        return DisposeResult(ok=True, reason=reason, joined_workers=joined);
    }

    def _submit_prompt(cmd: SessionCommand) -> CommandReceipt {
        text = str(cmd.payload.get("text", "") if cmd.payload else "").strip();
        if not text {
            text = str(cmd.payload.get("prompt", "") if cmd.payload else "").strip();
        }
        if not text {
            return CommandReceipt(
                accepted=False,
                disposition=DISP_REJECTED,
                command_id=cmd.command_id,
                error=CommandError(code="empty", message="empty prompt")
            );
        }
        self._lock.acquire();
        try {
            if self.lifecycle == LIFE_RUNNING or self.lifecycle == LIFE_STOPPING {
                return CommandReceipt(
                    accepted=False,
                    disposition=DISP_REJECTED,
                    command_id=cmd.command_id,
                    error=CommandError(
                        code="busy", message="session busy", retryable=True
                    )
                );
            }
            self._prompt_id += 1;
            pid = str(self._prompt_id);
            self.settled = False;
            self.cancel_requested = False;
            self.lifecycle = LIFE_RUNNING;
            self.manager.append(
                SessionMutation(kind="user", text=text, payload={"prompt_id": pid})
            );
            self._publish(UiMutation(kind=MUT_AGENT_START, lifecycle=LIFE_RUNNING));
            self._publish(
                UiMutation(kind=MUT_MESSAGE_START, message_id=pid, op="user", text=text)
            );
            self._publish(UiMutation(kind=MUT_STATUS, lifecycle=LIFE_RUNNING));
            if self.stub {
                tw = Thread(target=self._stub_turn, args=(pid, text), daemon=False);
                self._workers.append(tw);
                tw.start();
            } else {
                self._legacy_send(text);
            }
            return CommandReceipt(
                accepted=True,
                disposition=DISP_STARTED,
                command_id=cmd.command_id,
                prompt_id=pid
            );
        } finally {
            self._lock.release();
        }
    }

    def _submit_abort(cmd: SessionCommand) -> CommandReceipt {
        self._lock.acquire();
        try {
            if self.lifecycle != LIFE_RUNNING {
                return CommandReceipt(
                    accepted=True, disposition=DISP_NO_OP, command_id=cmd.command_id
                );
            }
            self.cancel_requested = True;
            self.lifecycle = LIFE_STOPPING;
            self._publish(UiMutation(kind=MUT_STATUS, lifecycle=LIFE_STOPPING));
            if not self.stub {
                try {
                    import from jaclang.cli.ai_agent { ui_stop }
                    ui_stop();
                } except Exception { }
            }
            return CommandReceipt(
                accepted=True, disposition=DISP_STARTED, command_id=cmd.command_id
            );
        } finally {
            self._lock.release();
        }
    }

    def _submit_reset(cmd: SessionCommand) -> CommandReceipt {
        self._lock.acquire();
        try {
            if self.lifecycle == LIFE_RUNNING or self.lifecycle == LIFE_STOPPING {
                self.cancel_requested = True;
                self.lifecycle = LIFE_STOPPING;
                self._publish(UiMutation(kind=MUT_STATUS, lifecycle=LIFE_STOPPING));
                return CommandReceipt(
                    accepted=True, disposition=DISP_STARTED, command_id=cmd.command_id
                );
            }

            self.manager = SessionManager.in_memory(self.cwd);
            self.lifecycle = LIFE_IDLE;
            self.settled = True;
            self._publish(UiMutation(kind=MUT_STATUS, lifecycle=LIFE_IDLE));
            return CommandReceipt(
                accepted=True, disposition=DISP_STARTED, command_id=cmd.command_id
            );
        } finally {
            self._lock.release();
        }
    }

    def _stub_turn(prompt_id: str, text: str) {
        time.sleep(0.02);
        if self.cancel_requested or self._stop.is_set() {
            self._settle_abort();
            return;
        }
        reply = f"echo: {text}";
        self.manager.append(SessionMutation(kind="assistant", text=reply));
        self._publish(
            UiMutation(
                kind="message_update",
                message_id=prompt_id,
                op="text_append",
                text=reply
            )
        );
        self._publish(UiMutation(kind=MUT_AGENT_END, lifecycle=LIFE_IDLE));
        self._settle_idle();
    }

    def _settle_abort {
        self._lock.acquire();
        try {
            self.lifecycle = LIFE_IDLE;
            self.cancel_requested = False;
            self.settled = True;
            self._publish(UiMutation(kind=MUT_AGENT_END, lifecycle=LIFE_IDLE));
            self._publish(UiMutation(kind=MUT_AGENT_SETTLED, lifecycle=LIFE_IDLE));
            self._publish(UiMutation(kind=MUT_STATUS, lifecycle=LIFE_IDLE));
        } finally {
            self._lock.release();
        }
    }

    def _settle_idle {
        self._lock.acquire();
        try {
            self.lifecycle = LIFE_IDLE;
            self.settled = True;
            self._publish(UiMutation(kind=MUT_AGENT_SETTLED, lifecycle=LIFE_IDLE));
            self._publish(UiMutation(kind=MUT_STATUS, lifecycle=LIFE_IDLE));
        } finally {
            self._lock.release();
        }
    }

    def _stub_feed {
        while not self._stop.is_set() {
            time.sleep(0.05);
        }
    }

    def _legacy_feed {
        try {
            import from jaclang.cli.ai_agent { ui_stream }
            import from jaclang.cli.ai_tui.legacy_event_normalizer {
                legacy_frame_to_mutations
            }
            for frame in ui_stream() {
                if self._stop.is_set() {
                    break;
                }
                if frame.get("heartbeat") {
                    continue;
                }
                frame_dict: dict[str, any] = frame if isinstance(frame, dict) else {};
                muts = legacy_frame_to_mutations(frame_dict, epoch=0, seq_start=0);
                for m in muts {
                    self._publish(m);
                }
                status = str(frame.get("status", "") or "");
                if status == "idle"
                and self.lifecycle in (LIFE_RUNNING, LIFE_STOPPING) {
                    self.lifecycle = LIFE_IDLE;
                    if not self.settled {
                        self.settled = True;
                        self._publish(
                            UiMutation(kind=MUT_AGENT_SETTLED, lifecycle=LIFE_IDLE)
                        );
                    }
                } elif status == "running" {
                    self.lifecycle = LIFE_RUNNING;
                } elif status == "stopping" {
                    self.lifecycle = LIFE_STOPPING;
                }
            }
        } except Exception as e {
            self.lifecycle = LIFE_FAILED;
            self._publish(
                UiMutation(
                    kind=MUT_DIAGNOSTIC,
                    diagnostic=f"agent feed stopped: {e!r}",
                    text=f"agent feed stopped: {e!r}"
                )
            );
        }
    }

    def _legacy_send(text: str) {
        try {
            import from jaclang.cli.ai_agent { ui_send }
            ui_send(text);
        } except Exception as e {
            self.lifecycle = LIFE_FAILED;
            self._publish(
                UiMutation(kind=MUT_DIAGNOSTIC, diagnostic=str(e), text=str(e))
            );
            self._settle_idle();
        }
    }

    def _emit_status(life: str) {
        self.lifecycle = life;
        self._publish(UiMutation(kind=MUT_STATUS, lifecycle=life));
    }

    def _publish(event: UiMutation) {
        dead: list[str] = [];
        for (sid, listener) in self._listeners {
            try {
                listener(event);
            } except Exception {
                dead.append(str(sid));
            }
        }
        if dead {
            self._listeners = [
                (sid, listener)
                for (sid, listener) in self._listeners
                if sid not in dead
            ];
        }
    }
}
