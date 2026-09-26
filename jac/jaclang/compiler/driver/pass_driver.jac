import from jaclang.compiler.passes.execution { run_walker }
import os;
import sys;
import from collections.abc { Callable, Iterator, Sequence }
import from contextlib { contextmanager }
import from jaclang.compiler.passes.context { Alert, CompilerPass, DiagnosticPolicy }
import from jaclang.compiler.driver.compile_options { CancelToken }
import from jaclang.compiler.frontend.unitree { Module, Source }
import from jaclang.compiler.frontend.host { CheckSettings, active_host }
import from jaclang.compiler.driver.program { JacProgram }

def diagnostic_policy_for(
    check: CheckSettings, extra_suppress_tokens: (list[str] | None) = None
) -> DiagnosticPolicy {
    import from jaclang.compiler.frontend.diagnostic_utils { resolve_diagnostic_tokens }
    tokens: list[str] = list(check.suppress);
    if extra_suppress_tokens {
        tokens.extend(extra_suppress_tokens);
    }
    resolved: list[str] = [];
    if tokens {
        (resolved, _unknown) = resolve_diagnostic_tokens(tokens);
    }
    return DiagnosticPolicy(
        suppress_codes=resolved,
        suppress_categories=list(check.suppress_categories),
        lint_active=check.lint_active,
        lint_select=list(check.lint_select),
        lint_ignore=list(check.lint_ignore)
    );
}

def build_diagnostic_policy(prog: JacProgram) -> DiagnosticPolicy {
    opts = prog.options;
    check = active_host().check_settings(opts.target_app if opts is not None else '');
    extra: list[str] = (
        list(opts.suppress_codes) if (opts is not None and opts.suppress_codes) else []
    );
    return diagnostic_policy_for(check, extra);
}

def _alert_in_internal_stub(loc_path: str) -> bool {
    import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }
    if not loc_path.endswith('.pyi') {
        return False;
    }
    _p = os.path.realpath(loc_path);
    _pkg = os.path.realpath(os.path.join(jaclang_pkg_root(), 'compiler'));
    if _p.startswith(_pkg + os.sep) {
        return True;
    }
    return (os.sep + 'typeshed' + os.sep) in _p;
}

def deliver_alerts(
    errors: Sequence[Alert],
    warnings: Sequence[Alert],
    prog: JacProgram,
    policy: (DiagnosticPolicy | None) = None
) {
    pol = policy if policy is not None else build_diagnostic_policy(prog);
    for alrt in errors {
        if alrt.code is not None and pol.is_suppressed(alrt.code, alrt.loc) {
            continue;
        }
        if alrt.code is not None
            and not alrt.code.code.startswith("E9")
            and _alert_in_internal_stub(str(alrt.loc.mod_path or "")) {
            continue;
        }
        prog.errors_had.append(alrt);
    }
    for alrt in warnings {
        if alrt.code is not None and pol.is_suppressed(alrt.code, alrt.loc) {
            continue;
        }
        if alrt.code is not None
            and _alert_in_internal_stub(str(alrt.loc.mod_path or "")) {
            continue;
        }
        prog.warnings_had.append(alrt);
    }
}

def run_pass[W: CompilerPass](
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
            for nd in ir_in._in_mod_nodes {
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
        deliver_alerts(errors, warnings, prog, eff);
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
