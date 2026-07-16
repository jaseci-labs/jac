import uuid;

import from jaclang.cli.ai_tui.bridge_schema {
    CMD_KIND_FORK_SESSION,
    CMD_KIND_NEW_SESSION,
    CMD_KIND_RESUME_SESSION,
    DISP_REJECTED,
    DISP_STARTED,
    LIFE_IDLE,
    MUT_RUNTIME_REPLACED,
    MUT_STATUS
}
import from jaclang.cli.ai_tui.session_models {
    CommandError,
    CommandReceipt,
    DisposeResult,
    ReplacementResult,
    RuntimeSnapshot,
    SessionCommand,
    SessionTarget,
    Subscription,
    UiMutation
}
import from jaclang.cli.ai_tui.core.session_manager { SessionManager }
import from jaclang.cli.ai_tui.core.agent_session { AgentSession }


obj AgentSessionRuntime {
    has cwd: str = "",
        epoch: int = 1,
        stub: bool = True,
        model_name: str = "stub",
        disposed: bool = False,
        _session: AgentSession | None = None,
        _listeners: list[any] = [],
        _sub_seq: int = 0;

    def postinit {
        if self._session is None {
            self._install_new_session(self.cwd or ".");
        }
    }

    def current -> AgentSession {
        if self._session is None or self.disposed {
            raise RuntimeError("runtime has no active session");
        }
        return self._session;
    }

    def submit(cmd: SessionCommand) -> CommandReceipt {
        if self.disposed {
            return CommandReceipt(
                accepted=False,
                disposition=DISP_REJECTED,
                command_id=cmd.command_id,
                error=CommandError(code="disposed", message="runtime disposed")
            );
        }
        kind = cmd.kind;
        if kind in (
            CMD_KIND_NEW_SESSION,
            CMD_KIND_RESUME_SESSION,
            CMD_KIND_FORK_SESSION,
            "new_session",
            "resume_session",
            "fork_session"
        ) {
            mode = "new";
            if "resume" in kind {
                mode = "resume";
            } elif "fork" in kind {
                mode = "fork";
            }
            cwd = str(cmd.payload.get("cwd", self.cwd) if cmd.payload else self.cwd);
            sid = str(cmd.payload.get("session_id", "") if cmd.payload else "");
            result = self.replace(SessionTarget(cwd=cwd, session_id=sid, mode=mode));
            if not result.ok {
                return CommandReceipt(
                    accepted=False,
                    disposition=DISP_REJECTED,
                    command_id=cmd.command_id,
                    error=CommandError(code="replace_failed", message=result.error)
                );
            }
            return CommandReceipt(
                accepted=True,
                disposition=DISP_STARTED,
                command_id=cmd.command_id,
                prompt_id=result.session_id
            );
        }
        return self.current().submit(cmd);
    }

    def subscribe(listener: any) -> Subscription {
        self._sub_seq += 1;
        sid = f"rt{self._sub_seq}";
        self._listeners.append((sid, listener));
        return Subscription(id=sid, active=True);
    }

    def replace(target: SessionTarget) -> ReplacementResult {
        if self.disposed {
            return ReplacementResult(ok=False, error="runtime disposed");
        }
        old = self._session;
        if old is not None {
            if old.lifecycle in ("running", "stopping") {
                return ReplacementResult(
                    ok=False,
                    epoch=self.epoch,
                    session_id=old.session_id,
                    error="cannot replace while session is active"
                );
            }
            old.manager.flush();
            old.dispose(reason="replaced", deadline_ms=1500);
        }
        cwd = target.cwd or self.cwd;
        self.cwd = cwd;
        self.epoch += 1;
        session = self._install_new_session(cwd, session_id=target.session_id);
        replaced = UiMutation(
            kind=MUT_RUNTIME_REPLACED,
            epoch=self.epoch,
            lifecycle=LIFE_IDLE,
            diagnostic=f"mode={target.mode}"
        );
        self._fanout(replaced);
        self._fanout(
            UiMutation(kind=MUT_STATUS, epoch=self.epoch, lifecycle=LIFE_IDLE)
        );
        return ReplacementResult(
            ok=True, epoch=self.epoch, session_id=session.session_id
        );
    }

    def snapshot -> RuntimeSnapshot {
        sess = self._session;
        life = LIFE_IDLE;
        sid = "";
        model = self.model_name;
        if sess is not None {
            life = sess.lifecycle;
            sid = sess.session_id;
            model = sess.model_name;
        }
        return RuntimeSnapshot(
            epoch=self.epoch,
            cwd=self.cwd,
            session_id=sid,
            lifecycle=life,
            model_name=model
        );
    }

    def dispose(reason: str = "dispose", deadline_ms: int = 2000) -> DisposeResult {
        if self.disposed {
            return DisposeResult(ok=True, reason=reason, joined_workers=0);
        }
        self.disposed = True;
        joined = 0;
        timed_out = False;
        if self._session is not None {
            result = self._session.dispose(reason=reason, deadline_ms=deadline_ms);
            joined = result.joined_workers;
            timed_out = result.timed_out;
            self._session = None;
        }
        self._listeners = [];
        if timed_out {
            return DisposeResult(
                ok=False, timed_out=True, reason=reason, joined_workers=joined
            );
        }
        return DisposeResult(ok=True, reason=reason, joined_workers=joined);
    }

    def _install_new_session(cwd: str, session_id: str = "") -> AgentSession {
        mgr = SessionManager.in_memory(cwd);
        sid = session_id or str(uuid.uuid4());
        session = AgentSession(
            session_id=sid,
            cwd=cwd,
            manager=mgr,
            model_name=self.model_name,
            stub=self.stub
        );
        session.subscribe(self._fanout);
        session.start_feed();
        self._session = session;
        return session;
    }

    def _fanout(event: UiMutation) {
        if event.epoch == 0 {
            event.epoch = self.epoch;
        }
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
