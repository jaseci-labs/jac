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

impl run_pass[W: CompilerPass](
    pass_cls: type[W],
    ir_in: Module,
    prog: JacProgram,
    cancel_token: (CancelToken | None) = None,
    policy: (DiagnosticPolicy | None) = None
) -> W {
    pol = policy if policy is not None else build_diagnostic_policy(prog);
    errors: list[Alert] = [];
    warnings: list[Alert] = [];
    inst: (W | None) = None;
    completed = prog.analysis.take_early(ir_in, pass_cls.__name__);
    if completed is not None {
        for alert in completed.errors_had + completed.warnings_had {
            alert.from_pass = pass_cls;
        }
        if completed.errors_had or completed.warnings_had {
            sources: dict[str, Source] = {ir_in.source.file_path: ir_in.source};
            for nd in ir_in._in_mod_nodes or [] {
                sources[nd.loc.mod_path] = nd.loc.orig_src;
            }
            completed.errors_had = [
                alert
                for alert in completed.errors_had
                if alert.code is None
                    or not pol.is_suppressed(
                        alert.code, alert.loc, source=sources.get(alert.loc.mod_path)
                    )
            ];
            completed.warnings_had = [
                alert
                for alert in completed.warnings_had
                if alert.code is None
                    or not pol.is_suppressed(
                        alert.code, alert.loc, source=sources.get(alert.loc.mod_path)
                    )
            ];
        }
    }
    try {
        inst = run_walker(
            pass_cls,
            module=ir_in,
            prog=prog,
            cancel_token=cancel_token,
            cancel_requested=bool(cancel_token is not None and cancel_token.is_set()),
            policy=pol,
            errors_had=errors,
            warnings_had=warnings,
            completed=completed
        );
        return inst;
    } finally {
        eff = inst.ctx.policy
            if (inst is not None and inst.ctx.policy is not None)
            else pol;
        deliver_alerts(errors, warnings, prog, eff, module_path=ir_in.loc.mod_path);
        try {
            ledger = prog.analysis;
            pass_name = pass_cls.__name__;
            ledger.pass_runs[pass_name] = ledger.pass_runs.get(pass_name, 0) + 1;
            if inst is not None {
                ledger.pass_time[pass_name] = (
                    ledger.pass_time.get(pass_name, 0.0) + inst.ctx.time_taken
                );
            }
        } except Exception {}
    }
}
