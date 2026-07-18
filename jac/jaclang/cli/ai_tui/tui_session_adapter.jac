import os;

import from jaclang.cli.ai_tui.bridge_schema {
    CMD_KIND_ABORT,
    CMD_KIND_PROMPT,
    CMD_KIND_RESET,
    DISP_REJECTED,
    LIFE_IDLE
}
import from jaclang.cli.ai_tui.session_models {
    CommandError,
    CommandReceipt,
    DisposeResult,
    SessionCommand,
    SessionEventBatch,
    StartResult,
    UiMutation,
    UiSnapshot
}
import from jaclang.cli.ai_tui.ui_event_projector { UiEventProjector }
import from jaclang.cli.ai_tui.event_queue { TuiEventQueue }
import from jaclang.cli.ai_tui.core.agent_session_runtime { AgentSessionRuntime }


obj TuiSessionAdapter {
    has cwd: str = "",
        stub: bool = True,
        model_name: str = "stub",
        started: bool = False,
        disposed: bool = False,
        runtime: AgentSessionRuntime | None = None,
        projector: UiEventProjector = UiEventProjector(),
        queue: TuiEventQueue = TuiEventQueue(),
        _sub: any = None;

    def start(req: dict[str, any] | None = None) -> StartResult {
        if self.disposed {
            return StartResult(ok=False, error="adapter disposed");
        }
        if self.started and self.runtime is not None {
            snap = self.runtime.snapshot();
            return StartResult(ok=True, session_id=snap.session_id, epoch=snap.epoch);
        }
        body: dict[str, any] = req if req is not None else {};
        cwd = str(body.get("cwd", self.cwd) or self.cwd or os.getcwd());
        stub = bool(body.get("stub", self.stub));
        model = str(body.get("model_name", self.model_name) or self.model_name);
        self.cwd = cwd;
        self.stub = stub;
        self.model_name = model;
        self.projector = UiEventProjector();
        self.queue = TuiEventQueue();
        self.queue.epoch = 1;
        self.runtime = AgentSessionRuntime(
            cwd=cwd, stub=stub, model_name=model, epoch=1
        );
        self._sub = self.runtime.subscribe(self._on_runtime_event);
        self.started = True;
        snap = self.runtime.snapshot();
        self.projector.state.epoch = snap.epoch;
        return StartResult(ok=True, session_id=snap.session_id, epoch=snap.epoch);
    }

    def submit(cmd: SessionCommand) -> CommandReceipt {
        if self.disposed or self.runtime is None {
            return CommandReceipt(
                accepted=False,
                disposition=DISP_REJECTED,
                command_id=cmd.command_id,
                error=CommandError(code="not_started", message="adapter not started")
            );
        }
        return self.runtime.submit(cmd);
    }

    def poll(cap: int = 64) -> SessionEventBatch {
        if self.queue.closed {
            return SessionEventBatch();
        }
        return self.queue.drain(cap);
    }

    def snapshot -> UiSnapshot {
        return self.projector.snapshot();
    }

    def dispose(reason: str = "dispose", deadline_ms: int = 2000) -> DisposeResult {
        if self.disposed {
            return DisposeResult(ok=True, reason=reason, joined_workers=0);
        }
        self.disposed = True;
        self.queue.close();
        result = DisposeResult(ok=True, reason=reason);
        if self.runtime is not None {
            result = self.runtime.dispose(reason=reason, deadline_ms=deadline_ms);
            self.runtime = None;
        }
        self.started = False;
        self._sub = None;
        return result;
    }

    def _on_runtime_event(event: UiMutation) {
        try {
            projected = self.projector.apply(event);
            for m in projected {
                self.queue.submit(m);
            }
        } except ValueError as e {
            self.queue.require_snapshot(str(e));
        } except Exception as e {
            self.queue.require_snapshot(f"projector_error:{e}");
        }
    }
}


def make_prompt_command(text: str, command_id: str = "") -> SessionCommand {
    return SessionCommand(
        kind=CMD_KIND_PROMPT, command_id=command_id, payload={"text": text}
    );
}


def make_abort_command(command_id: str = "") -> SessionCommand {
    return SessionCommand(kind=CMD_KIND_ABORT, command_id=command_id);
}


def make_reset_command(command_id: str = "") -> SessionCommand {
    return SessionCommand(kind=CMD_KIND_RESET, command_id=command_id);
}
