import os;
import sys;
import from collections.abc { Callable, Iterator, Sequence }
import from contextlib { contextmanager }

def diagnostic_policy_for(
    check: CheckSettings, extra_suppress_tokens: (list[str] | None) = None
) -> DiagnosticPolicy;

def build_diagnostic_policy(prog: JacProgram) -> DiagnosticPolicy;

def _alert_in_internal_stub(loc_path: str) -> bool;

def deliver_alerts(
    errors: Sequence[Alert],
    warnings: Sequence[Alert],
    prog: JacProgram,
    policy: (DiagnosticPolicy | None) = None,
    module_path: str = ""
);

def run_pass[W: CompilerPass](
    pass_cls: type[W],
    ir_in: Module,
    prog: JacProgram,
    cancel_token: (CancelToken | None) = None,
    policy: (DiagnosticPolicy | None) = None
) -> W;


obj CompileProgress {
    has _listeners: list[Callable[[str], None]] postinit,
        _finished_listeners: list[Callable[[str], None]] postinit;

    def postinit -> None;
    def notify(file_path: str) -> None;
    @contextmanager
    def track(file_path: str) -> Iterator[None];

    @contextmanager
    def listen(
        callback: Callable[[str], None],
        on_finished: Callable[[str], None] | None = None
    ) -> Iterator[None];
}

glob compile_progress = CompileProgress();
